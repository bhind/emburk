//! A deliberately small, limited-fallibility fixture lifecycle boundary.
//!
//! Only input run and the selected last output commit can fail here. Setup,
//! other output operations, scope teardown, and cleanup are infallible by
//! design for these test fakes; this is not a production plugin trait.

#[derive(Clone, Debug, Eq, PartialEq)]
struct EmptyPlan {
    input_tasks: usize,
    output_tasks: usize,
    output_task_cap: usize,
}
#[derive(Clone, Debug, Eq, PartialEq)]
enum PlanError {
    UnsupportedTaskCounts,
    OutputTaskCapExceeded,
}
impl EmptyPlan {
    fn validate(self) -> Result<Self, PlanError> {
        match (self.input_tasks, self.output_tasks) {
            (0, 0) | (1, 1..) => {}
            _ => return Err(PlanError::UnsupportedTaskCounts),
        }
        if self.output_tasks > self.output_task_cap {
            return Err(PlanError::OutputTaskCapExceeded);
        }
        Ok(self)
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
struct ReportToken(String);
#[derive(Clone, Debug, Eq, PartialEq)]
struct InputFailure(String);
#[derive(Clone, Debug, Eq, PartialEq)]
struct OutputFailure(String);
#[derive(Clone, Debug, Eq, PartialEq)]
enum CallbackFailure {
    Input(InputFailure),
    Output(OutputFailure),
}
#[derive(Clone, Debug, Eq, PartialEq)]
enum CoordinatorError {
    InvalidPlan(PlanError),
    InputFailed(InputFailure),
    OutputFailed(OutputFailure),
}
#[derive(Clone, Debug, Eq, PartialEq)]
struct CleanupContext {
    plan: EmptyPlan,
    reports: Vec<ReportToken>,
}

trait EmptyOutputHandle {
    fn finish(&mut self);
    fn commit(&mut self) -> Result<ReportToken, OutputFailure>;
    fn abort(&mut self);
    fn close(&mut self);
}
trait EmptyOutput {
    type Handle: EmptyOutputHandle;
    fn open_job(&mut self);
    fn open_control(&mut self);
    fn open_task(&self, task_index: usize) -> Self::Handle;
    fn close_control(&mut self, outcome: &Result<(), CallbackFailure>);
    fn close_job(&mut self, outcome: &Result<(), CallbackFailure>);
}
trait EmptyInput<H: EmptyOutputHandle> {
    fn open_job(&mut self);
    fn open_control(&mut self);
    fn run(&mut self, outputs: &mut [H]) -> Result<ReportToken, InputFailure>;
    fn close_control(&mut self, outcome: &Result<(), CallbackFailure>);
    fn close_job(&mut self, outcome: &Result<(), CallbackFailure>);
}
/// Cleanup is intentionally a distinct capability from either live job.
trait EmptyInputCleanup {
    fn cleanup(&mut self, context: CleanupContext);
}
/// Cleanup is intentionally a distinct capability from either live job.
trait EmptyOutputCleanup {
    fn cleanup(&mut self, context: CleanupContext);
}

fn coordinate_empty<I, O, IC, OC>(
    plan: EmptyPlan,
    input: &mut I,
    output: &mut O,
    input_cleanup: &mut IC,
    output_cleanup: &mut OC,
) -> Result<(), CoordinatorError>
where
    O: EmptyOutput,
    I: EmptyInput<O::Handle>,
    IC: EmptyInputCleanup,
    OC: EmptyOutputCleanup,
{
    let plan = plan.validate().map_err(CoordinatorError::InvalidPlan)?;
    input.open_job();
    input.open_control();
    output.open_job();
    output.open_control();
    let mut handles: Vec<O::Handle> = (0..plan.output_tasks)
        .map(|index| output.open_task(index))
        .collect();
    let input_result = if plan.input_tasks == 0 {
        Ok(None)
    } else {
        input.run(&mut handles).map(Some)
    };
    let (outcome, input_reports, output_reports) = match input_result {
        Ok(input_report) => {
            let mut output_reports = Vec::new();
            let mut output_failure = None;
            for handle in &mut handles {
                // This private boundary is exercised only for a fake's selected
                // last-index failure; it does not establish earlier/middle policy.
                match handle.commit() {
                    Ok(report) => output_reports.push(report),
                    Err(failure) => {
                        handle.abort();
                        output_failure = Some(failure);
                        break;
                    }
                }
            }
            for handle in &mut handles {
                handle.close();
            }
            match output_failure {
                Some(failure) => (
                    Err(CallbackFailure::Output(failure)),
                    input_report.into_iter().collect(),
                    output_reports,
                ),
                None => (Ok(()), input_report.into_iter().collect(), output_reports),
            }
        }
        Err(failure) => {
            for handle in &mut handles {
                handle.abort();
            }
            for handle in &mut handles {
                handle.close();
            }
            (Err(CallbackFailure::Input(failure)), Vec::new(), Vec::new())
        }
    };
    // No live task handles or transaction mutable state enter cleanup.
    drop(handles);
    output.close_control(&outcome);
    output.close_job(&outcome);
    input.close_control(&outcome);
    input.close_job(&outcome);
    input_cleanup.cleanup(CleanupContext {
        plan: plan.clone(),
        reports: input_reports,
    });
    output_cleanup.cleanup(CleanupContext {
        plan,
        reports: output_reports,
    });
    outcome.map_err(|failure| match failure {
        CallbackFailure::Input(failure) => CoordinatorError::InputFailed(failure),
        CallbackFailure::Output(failure) => CoordinatorError::OutputFailed(failure),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{cell::RefCell, rc::Rc};
    #[derive(Clone, Debug, Eq, PartialEq)]
    enum ScopeOutcome {
        Normal,
        Failed(CallbackFailure),
    }
    #[derive(Clone, Debug, Eq, PartialEq)]
    enum Event {
        InputJobOpened,
        InputControlOpened,
        InputRan,
        InputFinished,
        InputFailed,
        InputControlClosed(ScopeOutcome),
        InputJobClosed(ScopeOutcome),
        OutputJobOpened,
        OutputControlOpened,
        OutputTaskOpened(usize),
        OutputTaskFinished(usize),
        OutputTaskCommitted(usize),
        OutputTaskCommitFailed(usize, OutputFailure),
        OutputTaskAborted(usize),
        OutputTaskClosed(usize),
        OutputControlClosed(ScopeOutcome),
        OutputJobClosed(ScopeOutcome),
        InputCleaned,
        OutputCleaned,
    }
    fn outcome_event(outcome: &Result<(), CallbackFailure>) -> ScopeOutcome {
        match outcome {
            Ok(()) => ScopeOutcome::Normal,
            Err(failure) => ScopeOutcome::Failed(failure.clone()),
        }
    }
    fn selected_input_failure() -> CallbackFailure {
        CallbackFailure::Input(InputFailure("selected input failure".to_owned()))
    }
    fn selected_output_failure() -> CallbackFailure {
        CallbackFailure::Output(OutputFailure("selected last commit failure".to_owned()))
    }

    struct InputFake {
        events: Rc<RefCell<Vec<Event>>>,
        fail_before_finish: bool,
    }
    impl InputFake {
        fn new(events: Rc<RefCell<Vec<Event>>>, fail_before_finish: bool) -> Self {
            Self {
                events,
                fail_before_finish,
            }
        }
        fn event(&self, event: Event) {
            self.events.borrow_mut().push(event);
        }
    }
    impl<H: EmptyOutputHandle> EmptyInput<H> for InputFake {
        fn open_job(&mut self) {
            self.event(Event::InputJobOpened);
        }
        fn open_control(&mut self) {
            self.event(Event::InputControlOpened);
        }
        fn run(&mut self, outputs: &mut [H]) -> Result<ReportToken, InputFailure> {
            self.event(Event::InputRan);
            if self.fail_before_finish {
                self.event(Event::InputFailed);
                return Err(InputFailure("selected input failure".to_owned()));
            }
            for output in outputs {
                output.finish();
            }
            self.event(Event::InputFinished);
            Ok(ReportToken("input-report".to_owned()))
        }
        fn close_control(&mut self, outcome: &Result<(), CallbackFailure>) {
            self.event(Event::InputControlClosed(outcome_event(outcome)));
        }
        fn close_job(&mut self, outcome: &Result<(), CallbackFailure>) {
            self.event(Event::InputJobClosed(outcome_event(outcome)));
        }
    }
    struct OutputFake {
        events: Rc<RefCell<Vec<Event>>>,
        live_handles: Rc<RefCell<usize>>,
        failing_commit_index: Option<usize>,
    }
    impl OutputFake {
        fn new(
            events: Rc<RefCell<Vec<Event>>>,
            live_handles: Rc<RefCell<usize>>,
            failing_commit_index: Option<usize>,
        ) -> Self {
            Self {
                events,
                live_handles,
                failing_commit_index,
            }
        }
        fn event(&self, event: Event) {
            self.events.borrow_mut().push(event);
        }
    }
    struct OutputHandle {
        id: usize,
        events: Rc<RefCell<Vec<Event>>>,
        live_handles: Rc<RefCell<usize>>,
        fail_commit: bool,
    }
    impl OutputHandle {
        fn event(&self, event: Event) {
            self.events.borrow_mut().push(event);
        }
    }
    impl Drop for OutputHandle {
        fn drop(&mut self) {
            *self.live_handles.borrow_mut() -= 1;
        }
    }
    impl EmptyOutputHandle for OutputHandle {
        fn finish(&mut self) {
            self.event(Event::OutputTaskFinished(self.id));
        }
        fn commit(&mut self) -> Result<ReportToken, OutputFailure> {
            if self.fail_commit {
                let failure = OutputFailure("selected last commit failure".to_owned());
                self.event(Event::OutputTaskCommitFailed(self.id, failure.clone()));
                Err(failure)
            } else {
                self.event(Event::OutputTaskCommitted(self.id));
                Ok(ReportToken(format!("output-report-{}", self.id)))
            }
        }
        fn abort(&mut self) {
            self.event(Event::OutputTaskAborted(self.id));
        }
        fn close(&mut self) {
            self.event(Event::OutputTaskClosed(self.id));
        }
    }
    impl EmptyOutput for OutputFake {
        type Handle = OutputHandle;
        fn open_job(&mut self) {
            self.event(Event::OutputJobOpened);
        }
        fn open_control(&mut self) {
            self.event(Event::OutputControlOpened);
        }
        fn open_task(&self, task_index: usize) -> Self::Handle {
            *self.live_handles.borrow_mut() += 1;
            self.event(Event::OutputTaskOpened(task_index));
            OutputHandle {
                id: task_index,
                events: Rc::clone(&self.events),
                live_handles: Rc::clone(&self.live_handles),
                fail_commit: self.failing_commit_index == Some(task_index),
            }
        }
        fn close_control(&mut self, outcome: &Result<(), CallbackFailure>) {
            self.event(Event::OutputControlClosed(outcome_event(outcome)));
        }
        fn close_job(&mut self, outcome: &Result<(), CallbackFailure>) {
            self.event(Event::OutputJobClosed(outcome_event(outcome)));
        }
    }
    struct InputCleanupFake {
        events: Rc<RefCell<Vec<Event>>>,
        contexts: Vec<CleanupContext>,
        live_handles: Rc<RefCell<usize>>,
    }
    impl EmptyInputCleanup for InputCleanupFake {
        fn cleanup(&mut self, context: CleanupContext) {
            assert_eq!(
                *self.live_handles.borrow(),
                0,
                "handles must be dropped before cleanup"
            );
            self.events.borrow_mut().push(Event::InputCleaned);
            self.contexts.push(context);
        }
    }
    struct OutputCleanupFake {
        events: Rc<RefCell<Vec<Event>>>,
        contexts: Vec<CleanupContext>,
        live_handles: Rc<RefCell<usize>>,
    }
    impl EmptyOutputCleanup for OutputCleanupFake {
        fn cleanup(&mut self, context: CleanupContext) {
            assert_eq!(
                *self.live_handles.borrow(),
                0,
                "handles must be dropped before cleanup"
            );
            self.events.borrow_mut().push(Event::OutputCleaned);
            self.contexts.push(context);
        }
    }
    fn run(
        plan: EmptyPlan,
        fail_before_finish: bool,
    ) -> (
        Result<(), CoordinatorError>,
        InputCleanupFake,
        OutputCleanupFake,
        Vec<Event>,
    ) {
        run_with_commit_failure(plan, fail_before_finish, None)
    }
    fn run_with_commit_failure(
        plan: EmptyPlan,
        fail_before_finish: bool,
        failing_commit_index: Option<usize>,
    ) -> (
        Result<(), CoordinatorError>,
        InputCleanupFake,
        OutputCleanupFake,
        Vec<Event>,
    ) {
        let events = Rc::new(RefCell::new(Vec::new()));
        let live_handles = Rc::new(RefCell::new(0));
        let mut input = InputFake::new(Rc::clone(&events), fail_before_finish);
        let mut output = OutputFake::new(
            Rc::clone(&events),
            Rc::clone(&live_handles),
            failing_commit_index,
        );
        // These receivers are newly constructed and share no job state.
        let mut input_cleanup = InputCleanupFake {
            events: Rc::clone(&events),
            contexts: Vec::new(),
            live_handles: Rc::clone(&live_handles),
        };
        let mut output_cleanup = OutputCleanupFake {
            events: Rc::clone(&events),
            contexts: Vec::new(),
            live_handles,
        };
        let result = coordinate_empty(
            plan,
            &mut input,
            &mut output,
            &mut input_cleanup,
            &mut output_cleanup,
        );
        let trace = events.borrow().clone();
        (result, input_cleanup, output_cleanup, trace)
    }
    #[test]
    fn zero_zero_runs_scopes_and_fresh_cleanup_without_task_callbacks() {
        let (result, input_cleanup, output_cleanup, trace) = run(
            EmptyPlan {
                input_tasks: 0,
                output_tasks: 0,
                output_task_cap: 0,
            },
            false,
        );
        assert_eq!(result, Ok(()));
        assert!(input_cleanup.contexts[0].reports.is_empty());
        assert!(output_cleanup.contexts[0].reports.is_empty());
        assert_eq!(
            trace,
            vec![
                Event::InputJobOpened,
                Event::InputControlOpened,
                Event::OutputJobOpened,
                Event::OutputControlOpened,
                Event::OutputControlClosed(ScopeOutcome::Normal),
                Event::OutputJobClosed(ScopeOutcome::Normal),
                Event::InputControlClosed(ScopeOutcome::Normal),
                Event::InputJobClosed(ScopeOutcome::Normal),
                Event::InputCleaned,
                Event::OutputCleaned
            ]
        );
    }
    #[test]
    fn normal_one_to_one_and_one_to_many_preserve_full_distinct_reports_and_order() {
        for outputs in [1, 8] {
            let (result, input_cleanup, output_cleanup, trace) = run(
                EmptyPlan {
                    input_tasks: 1,
                    output_tasks: outputs,
                    output_task_cap: outputs,
                },
                false,
            );
            assert_eq!(result, Ok(()));
            assert_eq!(
                input_cleanup.contexts[0].reports,
                vec![ReportToken("input-report".to_owned())]
            );
            assert_eq!(
                output_cleanup.contexts[0].reports,
                (0..outputs)
                    .map(|index| ReportToken(format!("output-report-{index}")))
                    .collect::<Vec<_>>()
            );
            let mut expected = vec![
                Event::InputJobOpened,
                Event::InputControlOpened,
                Event::OutputJobOpened,
                Event::OutputControlOpened,
            ];
            expected.extend((0..outputs).map(Event::OutputTaskOpened));
            expected.push(Event::InputRan);
            expected.extend((0..outputs).map(Event::OutputTaskFinished));
            expected.push(Event::InputFinished);
            expected.extend((0..outputs).map(Event::OutputTaskCommitted));
            expected.extend((0..outputs).map(Event::OutputTaskClosed));
            expected.extend([
                Event::OutputControlClosed(ScopeOutcome::Normal),
                Event::OutputJobClosed(ScopeOutcome::Normal),
                Event::InputControlClosed(ScopeOutcome::Normal),
                Event::InputJobClosed(ScopeOutcome::Normal),
                Event::InputCleaned,
                Event::OutputCleaned,
            ]);
            assert_eq!(trace, expected);
        }
    }
    #[test]
    fn input_failure_aborts_all_then_closes_all_and_propagates_through_scopes() {
        for outputs in [1, 8] {
            let (result, input_cleanup, output_cleanup, trace) = run(
                EmptyPlan {
                    input_tasks: 1,
                    output_tasks: outputs,
                    output_task_cap: outputs,
                },
                true,
            );
            assert_eq!(
                result,
                Err(CoordinatorError::InputFailed(InputFailure(
                    "selected input failure".to_owned()
                )))
            );
            assert!(input_cleanup.contexts[0].reports.is_empty());
            assert!(output_cleanup.contexts[0].reports.is_empty());
            let mut expected = vec![
                Event::InputJobOpened,
                Event::InputControlOpened,
                Event::OutputJobOpened,
                Event::OutputControlOpened,
            ];
            expected.extend((0..outputs).map(Event::OutputTaskOpened));
            expected.extend([Event::InputRan, Event::InputFailed]);
            expected.extend((0..outputs).map(Event::OutputTaskAborted));
            expected.extend((0..outputs).map(Event::OutputTaskClosed));
            expected.extend([
                Event::OutputControlClosed(ScopeOutcome::Failed(selected_input_failure())),
                Event::OutputJobClosed(ScopeOutcome::Failed(selected_input_failure())),
                Event::InputControlClosed(ScopeOutcome::Failed(selected_input_failure())),
                Event::InputJobClosed(ScopeOutcome::Failed(selected_input_failure())),
                Event::InputCleaned,
                Event::OutputCleaned,
            ]);
            assert_eq!(trace, expected);
        }
    }
    #[test]
    fn last_commit_failure_retains_prior_tokens_and_propagates_output_payload() {
        for outputs in [1, 8] {
            let plan = EmptyPlan {
                input_tasks: 1,
                output_tasks: outputs,
                output_task_cap: outputs,
            };
            let (result, input_cleanup, output_cleanup, trace) =
                run_with_commit_failure(plan, false, Some(outputs - 1));
            assert_eq!(
                result,
                Err(CoordinatorError::OutputFailed(OutputFailure(
                    "selected last commit failure".to_owned()
                )))
            );
            assert_eq!(
                input_cleanup.contexts[0].reports,
                vec![ReportToken("input-report".to_owned())]
            );
            assert_eq!(
                output_cleanup.contexts[0].reports,
                (0..(outputs - 1))
                    .map(|index| ReportToken(format!("output-report-{index}")))
                    .collect::<Vec<_>>()
            );
            let mut expected = vec![
                Event::InputJobOpened,
                Event::InputControlOpened,
                Event::OutputJobOpened,
                Event::OutputControlOpened,
            ];
            expected.extend((0..outputs).map(Event::OutputTaskOpened));
            expected.push(Event::InputRan);
            expected.extend((0..outputs).map(Event::OutputTaskFinished));
            expected.push(Event::InputFinished);
            expected.extend((0..(outputs - 1)).map(Event::OutputTaskCommitted));
            expected.push(Event::OutputTaskCommitFailed(
                outputs - 1,
                OutputFailure("selected last commit failure".to_owned()),
            ));
            expected.push(Event::OutputTaskAborted(outputs - 1));
            expected.extend((0..outputs).map(Event::OutputTaskClosed));
            expected.extend([
                Event::OutputControlClosed(ScopeOutcome::Failed(selected_output_failure())),
                Event::OutputJobClosed(ScopeOutcome::Failed(selected_output_failure())),
                Event::InputControlClosed(ScopeOutcome::Failed(selected_output_failure())),
                Event::InputJobClosed(ScopeOutcome::Failed(selected_output_failure())),
                Event::InputCleaned,
                Event::OutputCleaned,
            ]);
            assert_eq!(trace, expected);
        }
    }
    #[test]
    fn cleanup_receivers_are_separate_from_jobs_and_handles_are_dropped() {
        let (_, input_cleanup, output_cleanup, _) = run(
            EmptyPlan {
                input_tasks: 1,
                output_tasks: 1,
                output_task_cap: 1,
            },
            true,
        );
        assert_eq!(input_cleanup.contexts.len(), 1);
        assert_eq!(output_cleanup.contexts.len(), 1);
        assert_eq!(
            input_cleanup.contexts[0].plan,
            output_cleanup.contexts[0].plan
        );
    }
    #[test]
    fn invalid_plans_reject_before_any_plugin_side_effect() {
        for plan in [
            EmptyPlan {
                input_tasks: 2,
                output_tasks: 2,
                output_task_cap: 2,
            },
            EmptyPlan {
                input_tasks: 0,
                output_tasks: 1,
                output_task_cap: 1,
            },
            EmptyPlan {
                input_tasks: 1,
                output_tasks: 0,
                output_task_cap: 1,
            },
            EmptyPlan {
                input_tasks: 1,
                output_tasks: 2,
                output_task_cap: 1,
            },
        ] {
            let (result, input_cleanup, output_cleanup, trace) = run(plan, false);
            assert!(matches!(result, Err(CoordinatorError::InvalidPlan(_))));
            assert!(trace.is_empty());
            assert!(input_cleanup.contexts.is_empty());
            assert!(output_cleanup.contexts.is_empty());
        }
    }

    mod differential_tests {
        include!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/src/empty_lifecycle/differential_tests.rs"
        ));
    }
}
