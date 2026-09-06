//! Private synchronous ownership handoff with no lifecycle or schema policy.

use crate::logical_record::LogicalRecord;

#[derive(Clone, Debug, PartialEq, Eq)]
struct SourceError(String);

#[derive(Clone, Debug, PartialEq, Eq)]
struct SinkError(String);

#[derive(Clone, Debug, PartialEq, Eq)]
enum HandoffError {
    Source(SourceError),
    Sink(SinkError),
}

trait RecordSource {
    fn next_record(&mut self) -> Result<Option<LogicalRecord>, SourceError>;
}

trait RecordSink {
    fn accept(&mut self, record: LogicalRecord) -> Result<(), SinkError>;
}

fn handoff_owned_records<S, K>(source: &mut S, sink: &mut K) -> Result<usize, HandoffError>
where
    S: RecordSource,
    K: RecordSink,
{
    let mut accepted = 0;
    loop {
        let Some(record) = source.next_record().map_err(HandoffError::Source)? else {
            return Ok(accepted);
        };
        sink.accept(record).map_err(HandoffError::Sink)?;
        accepted += 1;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::logical_record::{Float64Bits, LogicalValue};
    use std::{cell::RefCell, rc::Rc, vec::IntoIter};

    #[derive(Clone, Debug, PartialEq, Eq)]
    enum Event {
        SourceCalled(usize),
        SourceReturned(usize),
        SourceExhausted(usize),
        SourceFailed(usize, SourceError),
        SinkCalled(usize),
        SinkAccepted(usize),
        SinkFailed(usize, SinkError),
    }

    struct SourceFake {
        results: IntoIter<Result<LogicalRecord, SourceError>>,
        calls: usize,
        events: Rc<RefCell<Vec<Event>>>,
    }

    impl SourceFake {
        fn new(
            results: Vec<Result<LogicalRecord, SourceError>>,
            events: Rc<RefCell<Vec<Event>>>,
        ) -> Self {
            Self {
                results: results.into_iter(),
                calls: 0,
                events,
            }
        }

        fn event(&self, event: Event) {
            self.events.borrow_mut().push(event);
        }
    }

    impl RecordSource for SourceFake {
        fn next_record(&mut self) -> Result<Option<LogicalRecord>, SourceError> {
            let call = self.calls;
            self.calls += 1;
            self.event(Event::SourceCalled(call));
            match self.results.next() {
                Some(Ok(record)) => {
                    self.event(Event::SourceReturned(call));
                    Ok(Some(record))
                }
                Some(Err(error)) => {
                    self.event(Event::SourceFailed(call, error.clone()));
                    Err(error)
                }
                None => {
                    self.event(Event::SourceExhausted(call));
                    Ok(None)
                }
            }
        }
    }

    struct SinkFake {
        records: Vec<LogicalRecord>,
        calls: usize,
        fail_at: Option<usize>,
        events: Rc<RefCell<Vec<Event>>>,
    }

    impl SinkFake {
        fn new(fail_at: Option<usize>, events: Rc<RefCell<Vec<Event>>>) -> Self {
            Self {
                records: Vec::new(),
                calls: 0,
                fail_at,
                events,
            }
        }

        fn event(&self, event: Event) {
            self.events.borrow_mut().push(event);
        }
    }

    impl RecordSink for SinkFake {
        fn accept(&mut self, record: LogicalRecord) -> Result<(), SinkError> {
            let call = self.calls;
            self.calls += 1;
            self.event(Event::SinkCalled(call));
            if self.fail_at == Some(call) {
                let error = SinkError(format!("sink-payload-{call}"));
                self.event(Event::SinkFailed(call, error.clone()));
                return Err(error);
            }
            self.records.push(record);
            self.event(Event::SinkAccepted(call));
            Ok(())
        }
    }

    fn record(id: i64) -> LogicalRecord {
        LogicalRecord::new(vec![LogicalValue::Signed64(id)])
    }

    fn run(
        inputs: Vec<Result<LogicalRecord, SourceError>>,
        sink_failure: Option<usize>,
    ) -> (Result<usize, HandoffError>, Vec<LogicalRecord>, Vec<Event>) {
        let events = Rc::new(RefCell::new(Vec::new()));
        let mut source = SourceFake::new(inputs, Rc::clone(&events));
        let mut sink = SinkFake::new(sink_failure, Rc::clone(&events));
        let result = handoff_owned_records(&mut source, &mut sink);
        let events = events.borrow().clone();
        (result, sink.records, events)
    }

    #[test]
    fn zero_records_calls_source_once_and_returns_zero() {
        let (result, records, events) = run(Vec::new(), None);
        assert_eq!(result, Ok(0));
        assert!(records.is_empty());
        assert_eq!(
            events,
            vec![Event::SourceCalled(0), Event::SourceExhausted(0)]
        );
    }

    #[test]
    fn multiple_records_move_in_order_and_count_only_after_exhaustion() {
        let (result, records, events) = run(vec![Ok(record(10)), Ok(record(20))], None);
        assert_eq!(result, Ok(2));
        assert_eq!(records, vec![record(10), record(20)]);
        assert_eq!(
            events,
            vec![
                Event::SourceCalled(0),
                Event::SourceReturned(0),
                Event::SinkCalled(0),
                Event::SinkAccepted(0),
                Event::SourceCalled(1),
                Event::SourceReturned(1),
                Event::SinkCalled(1),
                Event::SinkAccepted(1),
                Event::SourceCalled(2),
                Event::SourceExhausted(2),
            ]
        );
    }

    #[test]
    fn preserves_all_selected_stored_values_and_owned_text() {
        let mut original_text = String::from("owned 🦀\n");
        let expected_bits = [
            0x7fef_ffff_ffff_ffff,
            0xffef_ffff_ffff_ffff,
            0x0000_0000_0000_0001,
            0x8000_0000_0000_0001,
            0x0000_0000_0000_0000,
            0x8000_0000_0000_0000,
            0x7ff0_0000_0000_0000,
            0xfff0_0000_0000_0000,
            0x7ff8_0000_0000_0000,
            0x7ff8_0000_0000_0042,
            0xfff8_0000_0000_0042,
        ];
        let mut cells = vec![
            LogicalValue::Null,
            LogicalValue::Boolean(false),
            LogicalValue::Boolean(true),
            LogicalValue::Signed64(i64::MIN),
            LogicalValue::Signed64(i64::MAX),
            LogicalValue::Text(original_text.clone()),
            LogicalValue::Text(String::new()),
        ];
        cells.extend(
            expected_bits
                .map(|bits| LogicalValue::Float64(Float64Bits::from_float(f64::from_bits(bits)))),
        );
        let input = LogicalRecord::new(cells);
        original_text.push_str("changed after construction");
        let (result, records, events) = run(vec![Ok(input)], None);
        assert_eq!(result, Ok(1));
        assert_eq!(records.len(), 1);
        assert_eq!(
            events,
            vec![
                Event::SourceCalled(0),
                Event::SourceReturned(0),
                Event::SinkCalled(0),
                Event::SinkAccepted(0),
                Event::SourceCalled(1),
                Event::SourceExhausted(1),
            ]
        );
        let values: Vec<_> = records[0].cells().collect();
        assert_eq!(values[0], &LogicalValue::Null);
        assert_eq!(values[1], &LogicalValue::Boolean(false));
        assert_eq!(values[2], &LogicalValue::Boolean(true));
        assert_eq!(values[3], &LogicalValue::Signed64(i64::MIN));
        assert_eq!(values[4], &LogicalValue::Signed64(i64::MAX));
        assert_eq!(values[5], &LogicalValue::Text("owned 🦀\n".into()));
        assert_eq!(values[6], &LogicalValue::Text(String::new()));
        let actual_bits: Vec<_> = values[7..]
            .iter()
            .map(|value| match value {
                LogicalValue::Float64(value) => value.bits(),
                other => panic!("expected Float64, got {other:?}"),
            })
            .collect();
        assert_eq!(actual_bits, expected_bits);
    }

    #[test]
    fn source_failures_at_first_and_later_positions_stop_immediately() {
        let first = SourceError("source-payload-first".into());
        let (result, records, events) = run(vec![Err(first.clone()), Ok(record(99))], None);
        assert_eq!(result, Err(HandoffError::Source(first.clone())));
        assert!(records.is_empty());
        assert_eq!(
            events,
            vec![Event::SourceCalled(0), Event::SourceFailed(0, first)]
        );

        let later = SourceError("source-payload-later".into());
        let (result, records, events) = run(
            vec![Ok(record(10)), Err(later.clone()), Ok(record(99))],
            None,
        );
        assert_eq!(result, Err(HandoffError::Source(later.clone())));
        assert_eq!(records, vec![record(10)]);
        assert_eq!(
            events,
            vec![
                Event::SourceCalled(0),
                Event::SourceReturned(0),
                Event::SinkCalled(0),
                Event::SinkAccepted(0),
                Event::SourceCalled(1),
                Event::SourceFailed(1, later),
            ]
        );
    }

    #[test]
    fn sink_failures_at_first_and_later_positions_stop_immediately() {
        let first = SinkError("sink-payload-0".into());
        let (result, records, events) = run(vec![Ok(record(10)), Ok(record(99))], Some(0));
        assert_eq!(result, Err(HandoffError::Sink(first.clone())));
        assert!(records.is_empty());
        assert_eq!(
            events,
            vec![
                Event::SourceCalled(0),
                Event::SourceReturned(0),
                Event::SinkCalled(0),
                Event::SinkFailed(0, first),
            ]
        );

        let later = SinkError("sink-payload-1".into());
        let (result, records, events) = run(
            vec![Ok(record(10)), Ok(record(20)), Ok(record(99))],
            Some(1),
        );
        assert_eq!(result, Err(HandoffError::Sink(later.clone())));
        assert_eq!(records, vec![record(10)]);
        assert_eq!(
            events,
            vec![
                Event::SourceCalled(0),
                Event::SourceReturned(0),
                Event::SinkCalled(0),
                Event::SinkAccepted(0),
                Event::SourceCalled(1),
                Event::SourceReturned(1),
                Event::SinkCalled(1),
                Event::SinkFailed(1, later),
            ]
        );
    }
}
