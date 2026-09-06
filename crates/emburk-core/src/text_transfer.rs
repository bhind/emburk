//! Bounded UTF-8 line transfer through the private owned-record handoff.

use crate::{
    logical_record::{LogicalRecord, LogicalValue},
    record_handoff::{
        HandoffError, RecordSink, RecordSource, SinkError, SourceError, handoff_owned_records,
    },
};
use std::io::{self, BufRead, Read, Write};

const MAX_PHYSICAL_LINE_BYTES: usize = 1024 * 1024;

/// Transfers UTF-8 physical lines as one private Text cell per logical record.
#[doc(hidden)]
pub fn transfer_lines<R: BufRead, W: Write>(input: R, output: W) -> io::Result<usize> {
    let mut source = TextSource { input };
    let mut sink = TextSink { output };
    let count = handoff_owned_records(&mut source, &mut sink).map_err(handoff_io_error)?;
    sink.output.flush()?;
    Ok(count)
}

fn handoff_io_error(error: HandoffError) -> io::Error {
    match error {
        HandoffError::Source(SourceError(message)) | HandoffError::Sink(SinkError(message)) => {
            io::Error::other(message)
        }
    }
}

struct TextSource<R> {
    input: R,
}

impl<R: BufRead> RecordSource for TextSource<R> {
    fn next_record(&mut self) -> Result<Option<LogicalRecord>, SourceError> {
        let mut bytes = Vec::with_capacity(MAX_PHYSICAL_LINE_BYTES.min(8192));
        let read = (&mut self.input)
            .take((MAX_PHYSICAL_LINE_BYTES + 1) as u64)
            .read_until(b'\n', &mut bytes)
            .map_err(|error| SourceError(format!("input read failed: {error}")))?;
        if read == 0 {
            return Ok(None);
        }
        if bytes.len() > MAX_PHYSICAL_LINE_BYTES {
            return Err(SourceError(format!(
                "input line exceeds {MAX_PHYSICAL_LINE_BYTES} bytes"
            )));
        }
        let had_lf = bytes.last() == Some(&b'\n');
        if had_lf {
            bytes.pop();
            if bytes.last() == Some(&b'\r') {
                bytes.pop();
            }
        }
        let text = String::from_utf8(bytes)
            .map_err(|error| SourceError(format!("input is not valid UTF-8: {error}")))?;
        Ok(Some(LogicalRecord::new(vec![LogicalValue::Text(text)])))
    }
}

struct TextSink<W> {
    output: W,
}

impl<W: Write> RecordSink for TextSink<W> {
    fn accept(&mut self, record: LogicalRecord) -> Result<(), SinkError> {
        let mut cells = record.cells();
        let Some(LogicalValue::Text(text)) = cells.next() else {
            return Err(SinkError(
                "internal transfer record is not one Text cell".into(),
            ));
        };
        if cells.next().is_some() {
            return Err(SinkError("internal transfer record is malformed".into()));
        }
        self.output
            .write_all(text.as_bytes())
            .and_then(|()| self.output.write_all(b"\n"))
            .map_err(|error| SinkError(format!("output write failed: {error}")))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Cursor, ErrorKind};

    #[test]
    fn normalizes_crlf_and_final_records_through_the_handoff() {
        let mut output = Vec::new();
        assert_eq!(
            transfer_lines(Cursor::new(b"a\r\nb\n\nfinal"), &mut output).unwrap(),
            4
        );
        assert_eq!(output, b"a\nb\n\nfinal\n");
        assert_eq!(transfer_lines(Cursor::new(b""), Vec::new()).unwrap(), 0);
    }

    #[test]
    fn rejects_invalid_utf8_and_oversized_physical_lines() {
        let invalid = transfer_lines(Cursor::new(vec![0xff, b'\n']), Vec::new()).unwrap_err();
        assert_eq!(invalid.kind(), ErrorKind::Other);
        let oversized = transfer_lines(
            Cursor::new(vec![b'x'; MAX_PHYSICAL_LINE_BYTES + 1]),
            Vec::new(),
        )
        .unwrap_err();
        assert_eq!(oversized.kind(), ErrorKind::Other);
    }

    #[test]
    fn accepts_boundary_lines_preserves_lone_cr_and_stops_after_invalid_prefix() {
        let mut output = Vec::new();
        let cap_minus_lf = [vec![b'a'; MAX_PHYSICAL_LINE_BYTES - 1], vec![b'\n']].concat();
        assert_eq!(
            transfer_lines(Cursor::new(cap_minus_lf), &mut output).unwrap(),
            1
        );
        assert_eq!(output.len(), MAX_PHYSICAL_LINE_BYTES);
        output.clear();
        assert_eq!(
            transfer_lines(
                Cursor::new(vec![b'b'; MAX_PHYSICAL_LINE_BYTES]),
                &mut output
            )
            .unwrap(),
            1
        );
        assert_eq!(output.len(), MAX_PHYSICAL_LINE_BYTES + 1);
        output.clear();
        assert_eq!(
            transfer_lines(Cursor::new(b"lone\r"), &mut output).unwrap(),
            1
        );
        assert_eq!(output, b"lone\r\n");
        let mut prefix = Vec::new();
        let error = transfer_lines(Cursor::new(b"ok\n\xff\nlater\n"), &mut prefix).unwrap_err();
        assert_eq!(error.kind(), ErrorKind::Other);
        assert_eq!(prefix, b"ok\n");
    }

    struct FailingReader;
    impl Read for FailingReader {
        fn read(&mut self, _: &mut [u8]) -> io::Result<usize> {
            Err(io::Error::other("read injection"))
        }
    }
    impl BufRead for FailingReader {
        fn fill_buf(&mut self) -> io::Result<&[u8]> {
            Err(io::Error::other("read injection"))
        }
        fn consume(&mut self, _: usize) {}
    }

    struct FailingWriter {
        fail_flush: bool,
    }
    impl Write for FailingWriter {
        fn write(&mut self, _: &[u8]) -> io::Result<usize> {
            Err(io::Error::other("write injection"))
        }
        fn flush(&mut self) -> io::Result<()> {
            if self.fail_flush {
                Err(io::Error::other("flush injection"))
            } else {
                Ok(())
            }
        }
    }

    #[test]
    fn propagates_injected_read_write_and_flush_errors() {
        assert!(transfer_lines(FailingReader, Vec::new()).is_err());
        assert!(transfer_lines(Cursor::new(b"x\n"), FailingWriter { fail_flush: false }).is_err());
        struct FlushWriter(Vec<u8>);
        impl Write for FlushWriter {
            fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
                self.0.extend_from_slice(bytes);
                Ok(bytes.len())
            }
            fn flush(&mut self) -> io::Result<()> {
                Err(io::Error::other("flush injection"))
            }
        }
        assert!(transfer_lines(Cursor::new(b"x\n"), FlushWriter(Vec::new())).is_err());
    }
}
