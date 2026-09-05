use super::*;

const HEADER: &str = "T0013-S06\t1";
const OUTPUT_CAP: usize = 1024;
const MAX_EVENTS: usize = OUTPUT_CAP * 6 + 32;
const OUTPUT_FAILURE_MESSAGE: &str = "selected last commit failure";

#[derive(Debug)]
struct Case {
    name: String,
    plan: EmptyPlan,
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
        if fields.len() != 10 || fields[0] != "CASE" {
            return Err("malformed case row".into());
        }
        let name = fields[1];
        if !matches!(name, "normal" | "commit-failure") || !seen.insert(name.to_owned()) {
            return Err("unknown or duplicate case".into());
        }
        let input_tasks = parse_count(fields[2], "input task count")?;
        let output_tasks = parse_count(fields[3], "output task count")?;
        let output_task_cap = parse_count(fields[4], "output task cap")?;
        if input_tasks != 1 || output_tasks == 0 {
            return Err("unsupported selected plan".into());
        }
        if output_task_cap != OUTPUT_CAP || output_tasks > OUTPUT_CAP {
            return Err("unsupported output plan".into());
        }
        let failing_commit_index = match (name, fields[5]) {
            ("normal", "normal-output") => None,
            ("commit-failure", "fail-last-commit") => Some(output_tasks - 1),
            _ => return Err("case scenario mismatch".into()),
        };
        let expected_result = fields[6];
        match (name, expected_result) {
            ("normal", "success") | ("commit-failure", "selected-output-commit-failure") => {}
            _ => return Err("case result mismatch".into()),
        }
        let input_reports = parse_count(fields[7], "input report count")?;
        let output_reports = parse_count(fields[8], "output report count")?;
        let expected_output_reports = if failing_commit_index.is_some() {
            output_tasks - 1
        } else {
            output_tasks
        };
        if input_reports != 1 || output_reports != expected_output_reports {
            return Err("case report projection mismatch".into());
        }
        let event_count = parse_count(fields[9], "event count")?;
        if event_count > MAX_EVENTS || event_count > lines.clone().count() {
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
            failing_commit_index,
            expected_result: expected_result.to_owned(),
            input_reports,
            output_reports,
            events,
        });
    }
    if cases.len() != 2
        || cases[0].name != "normal"
        || cases[1].name != "commit-failure"
        || !seen.contains("normal")
        || !seen.contains("commit-failure")
    {
        return Err("case manifest is not exact and ordered".into());
    }
    Ok(cases)
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

fn selected_output_outcome(outcome: &ScopeOutcome) -> bool {
    matches!(
        outcome,
        ScopeOutcome::Failed(CallbackFailure::Output(OutputFailure(message)))
            if message == OUTPUT_FAILURE_MESSAGE
    )
}

fn normalize_events(case: &Case, trace: &[Event]) -> Result<Vec<String>, String> {
    if let Some(failing_index) = case.failing_commit_index {
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
        let exact_scope_counts = [
            trace.iter().filter(|event| matches!(event, Event::InputControlClosed(outcome) if selected_output_outcome(outcome))).count(),
            trace.iter().filter(|event| matches!(event, Event::InputJobClosed(outcome) if selected_output_outcome(outcome))).count(),
            trace.iter().filter(|event| matches!(event, Event::OutputControlClosed(outcome) if selected_output_outcome(outcome))).count(),
            trace.iter().filter(|event| matches!(event, Event::OutputJobClosed(outcome) if selected_output_outcome(outcome))).count(),
        ];
        if all_failed_scopes != 4 || exact_scope_counts != [1, 1, 1, 1] {
            return Err(format!(
                "Rust output failure scope payload differs for {}",
                case.name
            ));
        }
        let all_commit_failures = trace
            .iter()
            .filter(|event| matches!(event, Event::OutputTaskCommitFailed(_, _)))
            .count();
        let exact_commit_failures = trace
            .iter()
            .filter(|event| matches!(event, Event::OutputTaskCommitFailed(index, OutputFailure(message)) if *index == failing_index && message == OUTPUT_FAILURE_MESSAGE))
            .count();
        if all_commit_failures != 1 || exact_commit_failures != 1 {
            return Err(format!(
                "Rust failed commit payload or index differs for {}",
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

fn compare_manifest(manifest: &str) -> Result<usize, String> {
    let cases = parse_manifest(manifest)?;
    for case in &cases {
        let execution = match case.failing_commit_index {
            None => run(case.plan.clone(), false),
            Some(index) => run_with_commit_failure(case.plan.clone(), false, Some(index)),
        };
        let (result, input_cleanup, output_cleanup, trace) = execution;
        let actual_result = match result {
            Ok(()) => "success",
            Err(CoordinatorError::OutputFailed(OutputFailure(message)))
                if message == OUTPUT_FAILURE_MESSAGE =>
            {
                "selected-output-commit-failure"
            }
            Err(other) => {
                return Err(format!(
                    "unexpected Rust result for {}: {other:?}",
                    case.name
                ));
            }
        };
        if actual_result != case.expected_result {
            return Err(format!("Rust result differs for {}", case.name));
        }
        if input_cleanup.contexts.len() != 1 || output_cleanup.contexts.len() != 1 {
            return Err(format!(
                "Rust cleanup context count differs for {}",
                case.name
            ));
        }
        if input_cleanup.contexts[0].reports.len() != case.input_reports
            || output_cleanup.contexts[0].reports.len() != case.output_reports
        {
            return Err(format!(
                "Rust cleanup report counts differ for {}",
                case.name
            ));
        }
        let actual_events = normalize_events(case, &trace)?;
        if actual_events != case.events {
            return Err(format!("Rust event projection differs for {}", case.name));
        }
    }
    Ok(cases.len())
}

fn fixture_events(outputs: usize, failure: bool) -> Vec<String> {
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
    if failure {
        events.extend((0..(outputs - 1)).map(|index| format!("OutputTaskCommitted:{index}")));
        events.push(format!("OutputTaskCommitFailed:{}", outputs - 1));
        events.push(format!("OutputTaskAborted:{}", outputs - 1));
    } else {
        events.extend((0..outputs).map(|index| format!("OutputTaskCommitted:{index}")));
    }
    events.extend((0..outputs).map(|index| format!("OutputTaskClosed:{index}")));
    if failure {
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

fn valid_manifest(outputs: usize) -> String {
    let normal = fixture_events(outputs, false);
    let failure = fixture_events(outputs, true);
    let mut rows = vec![HEADER.to_owned()];
    rows.push(format!(
        "CASE\tnormal\t1\t{outputs}\t{OUTPUT_CAP}\tnormal-output\tsuccess\t1\t{outputs}\t{}",
        normal.len()
    ));
    rows.extend(normal.into_iter().map(|event| format!("EVENT\t{event}")));
    rows.push(format!(
        "CASE\tcommit-failure\t1\t{outputs}\t{OUTPUT_CAP}\tfail-last-commit\tselected-output-commit-failure\t1\t{}\t{}",
        outputs - 1,
        failure.len()
    ));
    rows.extend(failure.into_iter().map(|event| format!("EVENT\t{event}")));
    rows.join("\n") + "\n"
}

fn remove_case_event(manifest: &str, case_name: &str, event: &str) -> String {
    let mut lines: Vec<String> = manifest.lines().map(str::to_owned).collect();
    let case_index = lines
        .iter()
        .position(|line| line.starts_with(&format!("CASE\t{case_name}\t")))
        .expect("case row");
    let mut fields: Vec<String> = lines[case_index].split('\t').map(str::to_owned).collect();
    let event_count: usize = fields[9].parse().expect("event count");
    let event_index = ((case_index + 1)..(case_index + 1 + event_count))
        .find(|index| lines[*index] == format!("EVENT\t{event}"))
        .expect("event row");
    lines.remove(event_index);
    fields[9] = (event_count - 1).to_string();
    lines[case_index] = fields.join("\t");
    lines.join("\n") + "\n"
}

#[test]
fn rust_failure_normalization_rejects_component_and_payload_substitution() {
    let manifest = valid_manifest(2);
    let cases = parse_manifest(&manifest).expect("valid fixture manifest");
    let case = &cases[1];
    let (_, _, _, trace) = run_with_commit_failure(case.plan.clone(), false, Some(1));
    assert!(normalize_events(case, &trace).is_ok());

    let mut substituted_scope = trace.clone();
    let output_control = substituted_scope
        .iter()
        .position(|event| matches!(event, Event::OutputControlClosed(_)))
        .expect("output control close");
    substituted_scope.remove(output_control);
    let input_control = substituted_scope
        .iter()
        .find(|event| matches!(event, Event::InputControlClosed(_)))
        .expect("input control close")
        .clone();
    substituted_scope.push(input_control);
    assert!(normalize_events(case, &substituted_scope).is_err());

    let mut wrong_scope_payload = trace.clone();
    let input_job = wrong_scope_payload
        .iter_mut()
        .find(|event| matches!(event, Event::InputJobClosed(_)))
        .expect("input job close");
    *input_job = Event::InputJobClosed(ScopeOutcome::Failed(CallbackFailure::Output(
        OutputFailure("changed".into()),
    )));
    assert!(normalize_events(case, &wrong_scope_payload).is_err());

    for replacement in [
        Event::OutputTaskCommitFailed(0, OutputFailure(OUTPUT_FAILURE_MESSAGE.into())),
        Event::OutputTaskCommitFailed(1, OutputFailure("changed".into())),
    ] {
        let mut wrong_commit = trace.clone();
        let failed = wrong_commit
            .iter_mut()
            .find(|event| matches!(event, Event::OutputTaskCommitFailed(_, _)))
            .expect("failed commit");
        *failed = replacement;
        assert!(normalize_events(case, &wrong_commit).is_err());
    }
}

#[test]
fn output_commit_manifest_rejects_mutated_execution_contracts() {
    for outputs in [1, 8] {
        assert_eq!(compare_manifest(&valid_manifest(outputs)), Ok(2));
    }
    let valid = valid_manifest(2);
    let bad = vec![
        valid.replacen(HEADER, "T0013-S06\t2", 1),
        valid.replacen("CASE\tnormal", "CASE\tunknown", 1),
        valid.replacen("CASE\tcommit-failure", "CASE\tnormal", 1),
        valid.replacen("\nCASE\tcommit-failure", "\nCASE\tduplicate", 1),
        format!(
            "{}\n",
            valid
                .split_once("\nCASE\tcommit-failure")
                .expect("failure case")
                .0
        ),
        valid.replacen("\t2\t1024\tnormal-output", "\t1025\t1024\tnormal-output", 1),
        valid.replacen("\t2\t1024\tnormal-output", "\tx\t1024\tnormal-output", 1),
        valid.replacen("\tnormal-output\t", "\tfail-last-commit\t", 1),
        valid.replacen(
            "\tsuccess\t1\t2\t",
            "\tselected-output-commit-failure\t1\t2\t",
            1,
        ),
        valid.replacen("\tsuccess\t1\t2\t", "\tsuccess\t0\t2\t", 1),
        valid.replacen("\tsuccess\t1\t2\t", "\tsuccess\t1\t1\t", 1),
        valid.replacen("OutputTaskCommitFailed:1", "OutputTaskCommitFailed:0", 1),
        valid.replacen("OutputTaskCommitFailed:1", "OutputTaskCommitted:1", 1),
        valid.replacen(
            "OutputJobClosed:FailedOutput",
            "OutputJobClosed:FailedInput",
            1,
        ),
        valid.replacen(
            "EVENT\tInputRan\nEVENT\tOutputTaskFinished:0",
            "EVENT\tOutputTaskFinished:0\nEVENT\tInputRan",
            1,
        ),
        valid.replacen("OutputTaskCommitted:0", "OutputTaskCommitFailed:0", 1),
        remove_case_event(&valid, "commit-failure", "OutputTaskCommitted:0"),
        remove_case_event(&valid, "commit-failure", "OutputTaskAborted:1"),
        remove_case_event(&valid, "commit-failure", "OutputTaskClosed:1"),
        valid.replacen(
            "fail-last-commit\tselected-output-commit-failure\t1\t1\t19",
            "fail-last-commit\tselected-output-commit-failure\t1\t1\t20",
            1,
        ),
        format!("{valid}CASE\tnormal\t1\t1\t1024\tnormal-output\tsuccess\t1\t1\t0\n"),
    ];
    for manifest in bad {
        assert!(
            compare_manifest(&manifest).is_err(),
            "accepted bad manifest:\n{manifest}"
        );
    }
    let truncated = valid
        .lines()
        .take(valid.lines().count() - 1)
        .collect::<Vec<_>>()
        .join("\n");
    assert!(compare_manifest(&truncated).is_err());
}

#[test]
#[ignore = "requires the external T-0013/S05 live oracle driver"]
fn live_output_commit_differential() {
    let path =
        std::env::var("T0013_S06_MANIFEST").expect("T0013_S06_MANIFEST must name driver output");
    let manifest = std::fs::read_to_string(path).expect("read driver manifest");
    assert_eq!(compare_manifest(&manifest), Ok(2));
}
