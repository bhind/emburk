use super::*;

const HEADER: &str = "T0013-S08\t1";
const OUTPUT_CAP: usize = 1024;
const MAX_EVENTS: usize = OUTPUT_CAP * 7 + 32;
const OUTPUT_FAILURE_MESSAGE: &str = "selected last commit failure";

#[derive(Clone, Debug)]
struct Case {
    name: String,
    plan: EmptyPlan,
    selected_index: usize,
    failing_commit_index: Option<usize>,
    expected_result: String,
    input_reports: usize,
    output_reports: usize,
    events: Vec<String>,
}

fn parse_count(value: &str, label: &str) -> Result<usize, String> {
    if value.is_empty() || !value.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err(format!("malformed {label}"));
    }
    value.parse().map_err(|_| format!("malformed {label}"))
}

fn parse_manifest(manifest: &str) -> Result<Vec<Case>, String> {
    if !manifest.ends_with('\n') || manifest.contains('\r') {
        return Err("manifest is not canonical TSV text".into());
    }
    let mut lines = manifest.lines();
    if lines.next() != Some(HEADER) {
        return Err("unsupported manifest header".into());
    }
    let mut cases = Vec::new();
    let mut seen = std::collections::BTreeSet::new();
    while let Some(row) = lines.next() {
        let fields: Vec<_> = row.split('\t').collect();
        if fields.len() != 11 || fields[0] != "CASE" {
            return Err("malformed case row".into());
        }
        let name = fields[1];
        if !matches!(name, "normal" | "commit-first" | "commit-middle")
            || !seen.insert(name.to_owned())
        {
            return Err("unknown or duplicate case".into());
        }
        let input_tasks = parse_count(fields[2], "input task count")?;
        let output_tasks = parse_count(fields[3], "output task count")?;
        let output_task_cap = parse_count(fields[4], "output task cap")?;
        let selected_index = parse_count(fields[5], "selected index")?;
        if input_tasks != 1 || output_tasks < 3 {
            return Err("unsupported selected plan".into());
        }
        if output_task_cap != OUTPUT_CAP || output_tasks > OUTPUT_CAP {
            return Err("unsupported output plan".into());
        }
        let failing_commit_index = match (name, fields[6], selected_index) {
            ("normal", "normal-output", index) if index == output_tasks - 1 => None,
            ("commit-first", "fail-first-commit", 0) => Some(0),
            ("commit-middle", "fail-middle-commit", index) if index == output_tasks / 2 => {
                Some(index)
            }
            _ => return Err("case selection or scenario mismatch".into()),
        };
        let expected_result = fields[7];
        match (failing_commit_index, expected_result) {
            (None, "success") | (Some(_), "selected-output-commit-failure") => {}
            _ => return Err("case result mismatch".into()),
        }
        let input_reports = parse_count(fields[8], "input report count")?;
        let output_reports = parse_count(fields[9], "output report count")?;
        let expected_output_reports = failing_commit_index.unwrap_or(output_tasks);
        if input_reports != 1 || output_reports != expected_output_reports {
            return Err("case report projection mismatch".into());
        }
        let event_count = parse_count(fields[10], "event count")?;
        if event_count == 0 || event_count > MAX_EVENTS || event_count > lines.clone().count() {
            return Err("unsupported or truncated event count".into());
        }
        let mut events = Vec::with_capacity(event_count);
        for _ in 0..event_count {
            let event = lines.next().ok_or("truncated event rows")?;
            let event_fields: Vec<_> = event.split('\t').collect();
            if event_fields.len() != 2 || event_fields[0] != "EVENT" || event_fields[1].is_empty() {
                return Err("malformed event row".into());
            }
            events.push(event_fields[1].to_owned());
        }
        cases.push(Case {
            name: name.to_owned(),
            plan: EmptyPlan {
                input_tasks,
                output_tasks,
                output_task_cap,
            },
            selected_index,
            failing_commit_index,
            expected_result: expected_result.to_owned(),
            input_reports,
            output_reports,
            events,
        });
    }
    if cases.len() != 3
        || cases
            .iter()
            .map(|case| case.name.as_str())
            .collect::<Vec<_>>()
            != ["normal", "commit-first", "commit-middle"]
    {
        return Err("case manifest is not exact and ordered".into());
    }
    Ok(cases)
}

fn selected_output_outcome(outcome: &ScopeOutcome) -> bool {
    matches!(
        outcome,
        ScopeOutcome::Failed(CallbackFailure::Output(OutputFailure(message)))
            if message == OUTPUT_FAILURE_MESSAGE
    )
}

fn scope_name(outcome: &ScopeOutcome) -> String {
    match outcome {
        ScopeOutcome::Normal => "Normal".into(),
        ScopeOutcome::Failed(CallbackFailure::Input(InputFailure(message))) => {
            format!("FailedInput:{message}")
        }
        ScopeOutcome::Failed(CallbackFailure::Output(OutputFailure(message))) => {
            format!("FailedOutput:{message}")
        }
    }
}

fn event_name(event: &Event) -> String {
    match event {
        Event::InputJobOpened => "InputJobOpened".into(),
        Event::InputControlOpened => "InputControlOpened".into(),
        Event::InputRan => "InputRan".into(),
        Event::InputFinished => "InputFinished".into(),
        Event::InputFailed => "InputFailed".into(),
        Event::InputControlClosed(outcome) => {
            format!("InputControlClosed:{}", scope_name(outcome))
        }
        Event::InputJobClosed(outcome) => format!("InputJobClosed:{}", scope_name(outcome)),
        Event::OutputJobOpened => "OutputJobOpened".into(),
        Event::OutputControlOpened => "OutputControlOpened".into(),
        Event::OutputTaskOpened(index) => format!("OutputTaskOpened:{index}"),
        Event::OutputTaskFinished(index) => format!("OutputTaskFinished:{index}"),
        Event::OutputTaskCommitted(index) => format!("OutputTaskCommitted:{index}"),
        Event::OutputTaskCommitFailed(index, OutputFailure(message)) => {
            format!("OutputTaskCommitFailed:{index}:{message}")
        }
        Event::OutputTaskAborted(index) => format!("OutputTaskAborted:{index}"),
        Event::OutputTaskClosed(index) => format!("OutputTaskClosed:{index}"),
        Event::OutputControlClosed(outcome) => {
            format!("OutputControlClosed:{}", scope_name(outcome))
        }
        Event::OutputJobClosed(outcome) => format!("OutputJobClosed:{}", scope_name(outcome)),
        Event::InputCleaned => "InputCleaned".into(),
        Event::OutputCleaned => "OutputCleaned".into(),
    }
}

fn normalize_events(case: &Case, trace: &[Event]) -> Result<Vec<String>, String> {
    if let Some(failing_index) = case.failing_commit_index {
        let exact_scopes = [
            trace.iter().filter(|event| matches!(event, Event::InputControlClosed(outcome) if selected_output_outcome(outcome))).count(),
            trace.iter().filter(|event| matches!(event, Event::InputJobClosed(outcome) if selected_output_outcome(outcome))).count(),
            trace.iter().filter(|event| matches!(event, Event::OutputControlClosed(outcome) if selected_output_outcome(outcome))).count(),
            trace.iter().filter(|event| matches!(event, Event::OutputJobClosed(outcome) if selected_output_outcome(outcome))).count(),
        ];
        let all_failed_scopes = trace
            .iter()
            .filter(|event| {
                matches!(
                    event,
                    Event::InputControlClosed(ScopeOutcome::Failed(_))
                        | Event::InputJobClosed(ScopeOutcome::Failed(_))
                        | Event::OutputControlClosed(ScopeOutcome::Failed(_))
                        | Event::OutputJobClosed(ScopeOutcome::Failed(_))
                )
            })
            .count();
        if exact_scopes != [1, 1, 1, 1] || all_failed_scopes != 4 {
            return Err(format!(
                "Rust output failure scopes differ for {}",
                case.name
            ));
        }
        let all_failures = trace
            .iter()
            .filter(|event| matches!(event, Event::OutputTaskCommitFailed(_, _)))
            .count();
        let exact_failures = trace
            .iter()
            .filter(|event| {
                matches!(event,
            Event::OutputTaskCommitFailed(index, OutputFailure(message))
                if *index == failing_index && message == OUTPUT_FAILURE_MESSAGE)
            })
            .count();
        if all_failures != 1 || exact_failures != 1 {
            return Err(format!("Rust failed commit differs for {}", case.name));
        }
        let position = |predicate: &dyn Fn(&Event) -> bool| {
            trace.iter().position(predicate).ok_or_else(|| {
                format!(
                    "Rust failure scope ordering event is absent for {}",
                    case.name
                )
            })
        };
        let last_close = trace
            .iter()
            .rposition(|event| matches!(event, Event::OutputTaskClosed(_)))
            .ok_or_else(|| format!("Rust task close is absent for {}", case.name))?;
        let output_control = position(
            &|event| matches!(event, Event::OutputControlClosed(outcome) if selected_output_outcome(outcome)),
        )?;
        let output_job = position(
            &|event| matches!(event, Event::OutputJobClosed(outcome) if selected_output_outcome(outcome)),
        )?;
        let input_control = position(
            &|event| matches!(event, Event::InputControlClosed(outcome) if selected_output_outcome(outcome)),
        )?;
        let input_job = position(
            &|event| matches!(event, Event::InputJobClosed(outcome) if selected_output_outcome(outcome)),
        )?;
        let input_cleanup = position(&|event| matches!(event, Event::InputCleaned))?;
        let output_cleanup = position(&|event| matches!(event, Event::OutputCleaned))?;
        if !(last_close < output_control
            && output_control < output_job
            && output_job < input_control
            && input_control < input_job
            && input_job < input_cleanup
            && input_cleanup < output_cleanup)
        {
            return Err(format!(
                "Rust failure scope order differs for {}",
                case.name
            ));
        }
    } else if trace.iter().any(|event| {
        matches!(
            event,
            Event::OutputTaskCommitFailed(_, _)
                | Event::InputControlClosed(ScopeOutcome::Failed(_))
                | Event::InputJobClosed(ScopeOutcome::Failed(_))
                | Event::OutputControlClosed(ScopeOutcome::Failed(_))
                | Event::OutputJobClosed(ScopeOutcome::Failed(_))
        )
    }) {
        return Err("unexpected Rust failure in normal execution".into());
    }

    let mut normalized = Vec::new();
    for event in trace {
        match event {
            Event::InputControlClosed(outcome) | Event::OutputControlClosed(outcome)
                if case.failing_commit_index.is_some() && selected_output_outcome(outcome) => {}
            Event::InputJobClosed(outcome)
                if case.failing_commit_index.is_some() && selected_output_outcome(outcome) =>
            {
                normalized.push("InputJobClosed:FailedOutput".into());
            }
            Event::OutputJobClosed(outcome)
                if case.failing_commit_index.is_some() && selected_output_outcome(outcome) =>
            {
                normalized.push("OutputJobClosed:FailedOutput".into());
            }
            Event::OutputTaskCommitFailed(index, OutputFailure(message))
                if case.failing_commit_index == Some(*index)
                    && message == OUTPUT_FAILURE_MESSAGE =>
            {
                normalized.push(format!("OutputTaskCommitFailed:{index}"));
            }
            _ => normalized.push(event_name(event)),
        }
    }
    Ok(normalized)
}

fn validate_execution(
    case: &Case,
    result: Result<(), CoordinatorError>,
    input_cleanup: &InputCleanupFake,
    output_cleanup: &OutputCleanupFake,
    trace: &[Event],
) -> Result<(), String> {
    let actual_result = match result {
        Ok(()) => "success",
        Err(CoordinatorError::OutputFailed(OutputFailure(message)))
            if message == OUTPUT_FAILURE_MESSAGE =>
        {
            "selected-output-commit-failure"
        }
        Err(other) => return Err(format!("unexpected Rust result: {other:?}")),
    };
    if actual_result != case.expected_result {
        return Err(format!("Rust result differs for {}", case.name));
    }
    if input_cleanup.contexts.len() != 1 || output_cleanup.contexts.len() != 1 {
        return Err(format!("Rust cleanup count differs for {}", case.name));
    }
    if input_cleanup.contexts[0].plan != case.plan || output_cleanup.contexts[0].plan != case.plan {
        return Err(format!("Rust cleanup plan differs for {}", case.name));
    }
    let expected_input = vec![ReportToken("input-report".into())];
    let expected_output = (0..case.output_reports)
        .map(|index| ReportToken(format!("output-report-{index}")))
        .collect::<Vec<_>>();
    if case.input_reports != expected_input.len()
        || input_cleanup.contexts[0].reports != expected_input
        || output_cleanup.contexts[0].reports != expected_output
    {
        return Err(format!("Rust cleanup reports differ for {}", case.name));
    }
    if normalize_events(case, trace)? != case.events {
        return Err(format!("Rust event projection differs for {}", case.name));
    }
    Ok(())
}

fn execute(
    case: &Case,
) -> (
    Result<(), CoordinatorError>,
    InputCleanupFake,
    OutputCleanupFake,
    Vec<Event>,
) {
    match case.failing_commit_index {
        None => run(case.plan.clone(), false),
        Some(index) => run_with_commit_failure(case.plan.clone(), false, Some(index)),
    }
}

fn compare_manifest(manifest: &str) -> Result<usize, String> {
    let cases = parse_manifest(manifest)?;
    for case in &cases {
        let (result, input_cleanup, output_cleanup, trace) = execute(case);
        validate_execution(case, result, &input_cleanup, &output_cleanup, &trace)?;
    }
    Ok(cases.len())
}

fn fixture_events(outputs: usize, failing_index: Option<usize>) -> Vec<String> {
    let mut events = vec![
        "InputJobOpened".into(),
        "InputControlOpened".into(),
        "OutputJobOpened".into(),
        "OutputControlOpened".into(),
    ];
    events.extend((0..outputs).map(|index| format!("OutputTaskOpened:{index}")));
    events.push("InputRan".into());
    events.extend((0..outputs).map(|index| format!("OutputTaskFinished:{index}")));
    events.push("InputFinished".into());
    match failing_index {
        None => events.extend((0..outputs).map(|index| format!("OutputTaskCommitted:{index}"))),
        Some(index) => {
            events.extend((0..index).map(|value| format!("OutputTaskCommitted:{value}")));
            events.push(format!("OutputTaskCommitFailed:{index}"));
            events.extend((index..outputs).map(|value| format!("OutputTaskAborted:{value}")));
        }
    }
    events.extend((0..outputs).map(|index| format!("OutputTaskClosed:{index}")));
    if failing_index.is_some() {
        events.extend([
            "OutputJobClosed:FailedOutput".into(),
            "InputJobClosed:FailedOutput".into(),
        ]);
    } else {
        events.extend([
            "OutputControlClosed:Normal".into(),
            "OutputJobClosed:Normal".into(),
            "InputControlClosed:Normal".into(),
            "InputJobClosed:Normal".into(),
        ]);
    }
    events.extend(["InputCleaned".into(), "OutputCleaned".into()]);
    events
}

fn valid_manifest_counts(output_counts: [usize; 3]) -> String {
    let fixtures = [
        ("normal", "normal-output", "success"),
        (
            "commit-first",
            "fail-first-commit",
            "selected-output-commit-failure",
        ),
        (
            "commit-middle",
            "fail-middle-commit",
            "selected-output-commit-failure",
        ),
    ];
    let mut rows = vec![HEADER.to_owned()];
    for ((name, scenario, result), outputs) in fixtures.into_iter().zip(output_counts) {
        let failure = match name {
            "normal" => None,
            "commit-first" => Some(0),
            "commit-middle" => Some(outputs / 2),
            _ => unreachable!(),
        };
        let selected = failure.unwrap_or(outputs - 1);
        let events = fixture_events(outputs, failure);
        let reports = failure.unwrap_or(outputs);
        rows.push(format!("CASE\t{name}\t1\t{outputs}\t{OUTPUT_CAP}\t{selected}\t{scenario}\t{result}\t1\t{reports}\t{}", events.len()));
        rows.extend(events.into_iter().map(|event| format!("EVENT\t{event}")));
    }
    rows.join("\n") + "\n"
}

fn valid_manifest(outputs: usize) -> String {
    valid_manifest_counts([outputs; 3])
}

fn remove_case_event(manifest: &str, case_name: &str, event: &str) -> String {
    let mut lines = manifest.lines().map(str::to_owned).collect::<Vec<_>>();
    let case_index = lines
        .iter()
        .position(|line| line.starts_with(&format!("CASE\t{case_name}\t")))
        .expect("case row");
    let mut fields = lines[case_index]
        .split('\t')
        .map(str::to_owned)
        .collect::<Vec<_>>();
    let count: usize = fields[10].parse().expect("event count");
    let event_index = ((case_index + 1)..(case_index + count + 1))
        .find(|index| lines[*index] == format!("EVENT\t{event}"))
        .expect("event row");
    lines.remove(event_index);
    fields[10] = (count - 1).to_string();
    lines[case_index] = fields.join("\t");
    lines.join("\n") + "\n"
}

fn replace_case_event_count(manifest: &str, case_name: &str, value: &str) -> String {
    let mut lines = manifest.lines().map(str::to_owned).collect::<Vec<_>>();
    let case = lines
        .iter_mut()
        .find(|line| line.starts_with(&format!("CASE\t{case_name}\t")))
        .expect("case row");
    let mut fields = case.split('\t').map(str::to_owned).collect::<Vec<_>>();
    fields[10] = value.to_owned();
    *case = fields.join("\t");
    lines.join("\n") + "\n"
}

fn swap_first_two_cases(manifest: &str) -> String {
    let lines = manifest.lines().collect::<Vec<_>>();
    let starts = lines
        .iter()
        .enumerate()
        .filter_map(|(index, line)| line.starts_with("CASE\t").then_some(index))
        .collect::<Vec<_>>();
    let mut reordered = vec![lines[0]];
    reordered.extend_from_slice(&lines[starts[1]..starts[2]]);
    reordered.extend_from_slice(&lines[starts[0]..starts[1]]);
    reordered.extend_from_slice(&lines[starts[2]..]);
    reordered.join("\n") + "\n"
}

#[test]
fn position_manifest_accepts_dynamic_three_and_eight_task_contracts() {
    for outputs in [3, 8] {
        assert_eq!(compare_manifest(&valid_manifest(outputs)), Ok(3));
    }
    assert_eq!(compare_manifest(&valid_manifest_counts([3, 8, 3])), Ok(3));
}

#[test]
fn position_manifest_rejects_case_report_selection_and_order_mutations() {
    let valid = valid_manifest(8);
    let missing_middle = format!(
        "{}\n",
        valid
            .split_once("\nCASE\tcommit-middle")
            .expect("middle case")
            .0
    );
    let bad = [
        valid.replacen(HEADER, "T0013-S08\t2", 1),
        valid.replacen("CASE\tnormal", "CASE\tunknown", 1),
        valid.replacen("CASE\tcommit-middle", "CASE\tcommit-first", 1),
        missing_middle,
        swap_first_two_cases(&valid),
        valid.replacen(
            "\t8\t1024\t7\tnormal-output",
            "\t1025\t1024\t7\tnormal-output",
            1,
        ),
        valid.replacen(
            "\t8\t1024\t7\tnormal-output",
            "\t8\t1024\t0\tnormal-output",
            1,
        ),
        valid.replacen("fail-first-commit", "fail-middle-commit", 1),
        valid.replacen(
            "\tsuccess\t1\t8\t",
            "\tselected-output-commit-failure\t1\t8\t",
            1,
        ),
        valid.replacen("\tsuccess\t1\t8\t", "\tsuccess\t0\t8\t", 1),
        valid.replacen("\tsuccess\t1\t8\t", "\tsuccess\t1\t7\t", 1),
        valid.replacen("OutputTaskCommitFailed:0", "OutputTaskCommitFailed:1", 1),
        valid.replacen("OutputTaskAborted:4", "OutputTaskCommitted:4", 1),
        remove_case_event(&valid, "commit-middle", "OutputTaskAborted:5"),
        remove_case_event(&valid, "commit-middle", "OutputTaskClosed:7"),
        replace_case_event_count(&valid, "normal", "x"),
        replace_case_event_count(&valid, "normal", "0"),
        replace_case_event_count(&valid, "normal", &(MAX_EVENTS + 1).to_string()),
        replace_case_event_count(
            &valid,
            "commit-middle",
            &(fixture_events(8, Some(4)).len() + 1).to_string(),
        ),
        valid.replacen(
            "EVENT\tInputRan\nEVENT\tOutputTaskFinished:0",
            "EVENT\tOutputTaskFinished:0\nEVENT\tInputRan",
            1,
        ),
        format!(
            "{valid}CASE\tnormal\t1\t3\t1024\t2\tnormal-output\tsuccess\t1\t3\t1\nEVENT\tInputCleaned\n"
        ),
    ];
    for manifest in bad {
        assert!(
            compare_manifest(&manifest).is_err(),
            "accepted bad manifest:\n{manifest}"
        );
    }
}

#[test]
fn actual_execution_validation_rejects_result_trace_report_and_plan_mutations() {
    let cases = parse_manifest(&valid_manifest(8)).expect("valid manifest");
    for case in &cases[1..] {
        let (result, input_cleanup, output_cleanup, trace) = execute(case);
        assert!(validate_execution(case, result, &input_cleanup, &output_cleanup, &trace).is_ok());

        let (_, input_cleanup, output_cleanup, trace) = execute(case);
        let error = validate_execution(
            case,
            Err(CoordinatorError::InputFailed(InputFailure(
                "changed".into(),
            ))),
            &input_cleanup,
            &output_cleanup,
            &trace,
        )
        .expect_err("changed result category");
        assert!(error.contains("unexpected Rust result"));

        let (_, input_cleanup, output_cleanup, trace) = execute(case);
        let error = validate_execution(case, Ok(()), &input_cleanup, &output_cleanup, &trace)
            .expect_err("success substituted for failure");
        assert!(error.contains("Rust result differs"));

        let (_, input_cleanup, output_cleanup, trace) = execute(case);
        let error = validate_execution(
            case,
            Err(CoordinatorError::OutputFailed(OutputFailure(
                "changed".into(),
            ))),
            &input_cleanup,
            &output_cleanup,
            &trace,
        )
        .expect_err("wrong output failure payload");
        assert!(error.contains("unexpected Rust result"));

        let (result, mut input_cleanup, output_cleanup, trace) = execute(case);
        input_cleanup.contexts[0].reports[0] = ReportToken("changed".into());
        let error = validate_execution(case, result, &input_cleanup, &output_cleanup, &trace)
            .expect_err("changed input report token");
        assert!(error.contains("cleanup reports"));

        let (result, input_cleanup, mut output_cleanup, trace) = execute(case);
        if output_cleanup.contexts[0].reports.is_empty() {
            output_cleanup.contexts[0]
                .reports
                .push(ReportToken("changed".into()));
        } else {
            output_cleanup.contexts[0].reports[0] = ReportToken("changed".into());
        }
        let error = validate_execution(case, result, &input_cleanup, &output_cleanup, &trace)
            .expect_err("changed output report token");
        assert!(error.contains("cleanup reports"));

        let (result, input_cleanup, mut output_cleanup, trace) = execute(case);
        output_cleanup.contexts[0].plan.output_tasks += 1;
        let error = validate_execution(case, result, &input_cleanup, &output_cleanup, &trace)
            .expect_err("changed cleanup plan");
        assert!(error.contains("cleanup plan"));

        let mutations = [
            (
                "wrong-payload",
                Event::OutputTaskCommitFailed(case.selected_index, OutputFailure("changed".into())),
            ),
            (
                "wrong-index",
                Event::OutputTaskCommitFailed(
                    (case.selected_index + 1) % case.plan.output_tasks,
                    OutputFailure(OUTPUT_FAILURE_MESSAGE.into()),
                ),
            ),
        ];
        for (_label, replacement) in mutations {
            let (_, _, _, mut changed) = execute(case);
            let target = changed
                .iter_mut()
                .find(|event| matches!(event, Event::OutputTaskCommitFailed(_, _)))
                .expect("failure event");
            *target = replacement;
            assert!(
                normalize_events(case, &changed)
                    .expect_err("changed failure event")
                    .contains("failed commit")
            );
        }
        for mutation in 0..9 {
            let (result, input_cleanup, output_cleanup, mut changed) = execute(case);
            let expected_diagnostic = match mutation {
                0 | 1 | 8 => "output failure scopes",
                7 => "failure scope order",
                _ => "event projection",
            };
            match mutation {
                0 => {
                    let index = changed
                        .iter()
                        .position(|event| matches!(event, Event::OutputControlClosed(_)))
                        .unwrap();
                    changed.remove(index);
                }
                1 => {
                    let index = changed
                        .iter()
                        .position(|event| matches!(event, Event::InputJobClosed(_)))
                        .unwrap();
                    changed[index] = Event::InputJobClosed(ScopeOutcome::Failed(
                        CallbackFailure::Input(InputFailure("changed".into())),
                    ));
                }
                2 => {
                    let index = changed.iter().position(|event| matches!(event, Event::OutputTaskAborted(value) if *value == case.selected_index)).unwrap();
                    changed.remove(index);
                }
                3 => {
                    let close = changed
                        .iter()
                        .position(|event| matches!(event, Event::OutputTaskClosed(_)))
                        .unwrap();
                    changed.remove(close);
                }
                4 => {
                    let failed = changed
                        .iter()
                        .position(|event| matches!(event, Event::OutputTaskCommitFailed(_, _)))
                        .unwrap();
                    changed.insert(
                        failed + 1,
                        Event::OutputTaskCommitted(case.selected_index + 1),
                    );
                }
                5 => {
                    let failed = changed
                        .iter()
                        .position(|event| matches!(event, Event::OutputTaskCommitFailed(_, _)))
                        .unwrap();
                    changed.insert(failed, Event::OutputTaskAborted(0));
                }
                6 => changed.swap(0, 1),
                7 => {
                    let control = changed
                        .iter()
                        .position(|event| matches!(event, Event::OutputControlClosed(_)))
                        .unwrap();
                    let job = changed
                        .iter()
                        .position(|event| matches!(event, Event::OutputJobClosed(_)))
                        .unwrap();
                    changed.swap(control, job);
                }
                _ => {
                    let scope = changed
                        .iter()
                        .find(|event| matches!(event, Event::InputControlClosed(_)))
                        .unwrap()
                        .clone();
                    changed.push(scope);
                }
            }
            let error = validate_execution(case, result, &input_cleanup, &output_cleanup, &changed)
                .expect_err("changed trace");
            assert!(error.contains(expected_diagnostic), "{mutation}: {error}");
        }

        if case.name == "commit-middle" {
            let (result, input_cleanup, output_cleanup, mut changed) = execute(case);
            let failed = changed
                .iter()
                .position(|event| matches!(event, Event::OutputTaskCommitFailed(_, _)))
                .unwrap();
            changed.insert(failed, Event::OutputTaskAborted(case.selected_index - 1));
            let error = validate_execution(case, result, &input_cleanup, &output_cleanup, &changed)
                .expect_err("abort of committed prefix");
            assert!(error.contains("event projection"));
        }
    }

    let normal = &cases[0];
    let (result, input_cleanup, output_cleanup, mut trace) = execute(normal);
    trace.push(Event::OutputTaskCommitFailed(
        0,
        OutputFailure(OUTPUT_FAILURE_MESSAGE.into()),
    ));
    assert!(validate_execution(normal, result, &input_cleanup, &output_cleanup, &trace).is_err());
}

#[test]
#[ignore = "requires the external T-0013/S07 live oracle driver"]
fn live_output_commit_position_differential() {
    let path =
        std::env::var("T0013_S08_MANIFEST").expect("T0013_S08_MANIFEST must name driver output");
    let manifest = std::fs::read_to_string(path).expect("read driver manifest");
    assert_eq!(compare_manifest(&manifest), Ok(3));
}
