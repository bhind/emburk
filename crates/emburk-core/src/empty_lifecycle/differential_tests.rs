use super::*;

const HEADER: &str = "T0013-S04\t1";
const OUTPUT_CAP: usize = 1024;

#[derive(Debug)]
struct Case {
    name: String,
    plan: EmptyPlan,
    fail_before_finish: bool,
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
    while let Some(line) = lines.next() {
        let fields: Vec<_> = line.split('\t').collect();
        if fields.len() != 10 || fields[0] != "CASE" {
            return Err("malformed case row".into());
        }
        if !matches!(fields[1], "normal" | "failure") || !seen.insert(fields[1].to_owned()) {
            return Err("unknown or duplicate case".into());
        }
        let input_tasks = parse_count(fields[2], "input task count")?;
        let output_tasks = parse_count(fields[3], "output task count")?;
        let output_task_cap = parse_count(fields[4], "output task cap")?;
        if output_task_cap != OUTPUT_CAP || output_tasks > OUTPUT_CAP {
            return Err("unsupported output plan".into());
        }
        let fail_before_finish = match fields[5] {
            "normal-input" => false,
            "fail-before-finish" => true,
            _ => return Err("unknown scenario input".into()),
        };
        let expected_result = match fields[6] {
            "success" | "selected-input-failure" => fields[6].to_owned(),
            _ => return Err("unknown result category".into()),
        };
        let input_reports = parse_count(fields[7], "input report count")?;
        let output_reports = parse_count(fields[8], "output report count")?;
        let event_count = parse_count(fields[9], "event count")?;
        if input_tasks != 1 || output_tasks == 0 {
            return Err("unsupported selected plan".into());
        }
        match fields[1] {
            "normal" if fail_before_finish || expected_result != "success" => {
                return Err("normal case input/result mismatch".into());
            }
            "failure" if !fail_before_finish || expected_result != "selected-input-failure" => {
                return Err("failure case input/result mismatch".into());
            }
            _ => {}
        }
        if event_count > lines.clone().count() {
            return Err("event count exceeds remaining rows".into());
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
            name: fields[1].to_owned(),
            plan: EmptyPlan {
                input_tasks,
                output_tasks,
                output_task_cap,
            },
            fail_before_finish,
            expected_result,
            input_reports,
            output_reports,
            events,
        });
    }
    if cases.len() != 2 || !seen.contains("normal") || !seen.contains("failure") {
        return Err("case manifest is not exact".into());
    }
    Ok(cases)
}

fn event_name(event: &Event) -> String {
    match event {
        Event::InputJobOpened => "InputJobOpened".into(),
        Event::InputControlOpened => "InputControlOpened".into(),
        Event::InputRan => "InputRan".into(),
        Event::InputFinished => "InputFinished".into(),
        Event::InputFailed => "InputFailed".into(),
        Event::InputControlClosed(outcome) => format!("InputControlClosed:{}", outcome_name(outcome)),
        Event::InputJobClosed(outcome) => format!("InputJobClosed:{}", outcome_name(outcome)),
        Event::OutputJobOpened => "OutputJobOpened".into(),
        Event::OutputControlOpened => "OutputControlOpened".into(),
        Event::OutputTaskOpened(index) => format!("OutputTaskOpened:{index}"),
        Event::OutputTaskFinished(index) => format!("OutputTaskFinished:{index}"),
        Event::OutputTaskCommitted(index) => format!("OutputTaskCommitted:{index}"),
        Event::OutputTaskAborted(index) => format!("OutputTaskAborted:{index}"),
        Event::OutputTaskClosed(index) => format!("OutputTaskClosed:{index}"),
        Event::OutputControlClosed(outcome) => format!("OutputControlClosed:{}", outcome_name(outcome)),
        Event::OutputJobClosed(outcome) => format!("OutputJobClosed:{}", outcome_name(outcome)),
        Event::InputCleaned => "InputCleaned".into(),
        Event::OutputCleaned => "OutputCleaned".into(),
    }
}

fn outcome_name(outcome: &ScopeOutcome) -> &'static str {
    match outcome {
        ScopeOutcome::Normal => "Normal",
        ScopeOutcome::Failed => "Failed",
    }
}

fn compare_manifest(manifest: &str) -> Result<usize, String> {
    let cases = parse_manifest(manifest)?;
    for case in &cases {
        let (result, input_cleanup, output_cleanup, trace) =
            run(case.plan.clone(), case.fail_before_finish);
        let actual_result = match result {
            Ok(()) => "success",
            Err(CoordinatorError::InputFailed(InputFailure(ref message)))
                if message == "selected input failure" =>
            {
                "selected-input-failure"
            }
            Err(other) => return Err(format!("unexpected Rust result for {}: {other:?}", case.name)),
        };
        if actual_result != case.expected_result {
            return Err(format!("result differs for {}", case.name));
        }
        let actual_input_reports = input_cleanup
            .contexts
            .first()
            .ok_or_else(|| format!("missing input cleanup for {}", case.name))?
            .reports
            .len();
        let actual_output_reports = output_cleanup
            .contexts
            .first()
            .ok_or_else(|| format!("missing output cleanup for {}", case.name))?
            .reports
            .len();
        if input_cleanup.contexts.len() != 1
            || output_cleanup.contexts.len() != 1
            || actual_input_reports != case.input_reports
            || actual_output_reports != case.output_reports
        {
            return Err(format!("cleanup report counts differ for {}", case.name));
        }
        let mut actual_events: Vec<_> = trace.iter().map(event_name).collect();
        if case.fail_before_finish {
            let input_failed_controls = trace
                .iter()
                .filter(|event| matches!(event, Event::InputControlClosed(ScopeOutcome::Failed)))
                .count();
            let output_failed_controls = trace
                .iter()
                .filter(|event| matches!(event, Event::OutputControlClosed(ScopeOutcome::Failed)))
                .count();
            if input_failed_controls != 1 || output_failed_controls != 1 {
                return Err(format!("failed control outcomes differ for {}", case.name));
            }
            actual_events.retain(|event| {
                event != "InputControlClosed:Failed" && event != "OutputControlClosed:Failed"
            });
        }
        if actual_events != case.events {
            return Err(format!("event projection differs for {}", case.name));
        }
    }
    Ok(cases.len())
}

fn valid_manifest() -> String {
    let normal_events = [
        "InputJobOpened", "InputControlOpened", "OutputJobOpened", "OutputControlOpened",
        "OutputTaskOpened:0", "InputRan", "OutputTaskFinished:0", "InputFinished",
        "OutputTaskCommitted:0", "OutputTaskClosed:0", "OutputControlClosed:Normal",
        "OutputJobClosed:Normal", "InputControlClosed:Normal", "InputJobClosed:Normal",
        "InputCleaned", "OutputCleaned",
    ];
    let failure_events = [
        "InputJobOpened", "InputControlOpened", "OutputJobOpened", "OutputControlOpened",
        "OutputTaskOpened:0", "InputRan", "InputFailed", "OutputTaskAborted:0",
        "OutputTaskClosed:0", "OutputJobClosed:Failed", "InputJobClosed:Failed",
        "InputCleaned", "OutputCleaned",
    ];
    let mut rows = vec![HEADER.to_owned()];
    rows.push(format!("CASE\tnormal\t1\t1\t1024\tnormal-input\tsuccess\t1\t1\t{}", normal_events.len()));
    rows.extend(normal_events.map(|event| format!("EVENT\t{event}")));
    rows.push(format!("CASE\tfailure\t1\t1\t1024\tfail-before-finish\tselected-input-failure\t0\t0\t{}", failure_events.len()));
    rows.extend(failure_events.map(|event| format!("EVENT\t{event}")));
    rows.join("\n") + "\n"
}

#[test]
fn differential_manifest_rejects_invalid_or_mutated_outcomes() {
    let valid = valid_manifest();
    assert_eq!(compare_manifest(&valid), Ok(2));
    for bad in [
        valid.replacen(HEADER, "T0013-S04\t2", 1),
        valid.replacen("CASE\tnormal", "CASE\tunknown", 1),
        valid.replacen("CASE\tfailure", "CASE\tnormal", 1),
        valid.replacen("\t1024\tnormal-input", "\t1025\tnormal-input", 1),
        valid.replacen("\tnormal-input\t", "\tunknown-input\t", 1),
        valid.replacen("\tsuccess\t1\t1\t", "\tselected-input-failure\t1\t1\t", 1),
        valid.replacen("\tsuccess\t1\t1\t", "\tsuccess\t0\t1\t", 1),
        valid.replacen("\tsuccess\t1\t1\t", "\tsuccess\t1\t0\t", 1),
        valid.replacen("OutputTaskOpened:0", "OutputTaskOpened:1", 1),
        valid.replacen("InputRan\nEVENT\tOutputTaskFinished:0", "OutputTaskFinished:0\nEVENT\tInputRan", 1),
        valid.replacen("CASE\tnormal\t1\t1\t1024", "CASE\tnormal\t1\t0\t1024", 1),
        format!("{valid}CASE\tnormal\t1\t1\t1024\tnormal-input\tsuccess\t1\t1\t0\n"),
        valid.replacen("EVENT\tInputJobOpened", "EVENT", 1),
    ] {
        assert!(compare_manifest(&bad).is_err(), "accepted bad manifest:\n{bad}");
    }
    let truncated = valid.lines().take(valid.lines().count() - 1).collect::<Vec<_>>().join("\n");
    assert!(compare_manifest(&truncated).is_err());
}

#[test]
#[ignore = "requires the external T-0013/S03 live oracle driver"]
fn live_empty_lifecycle_differential() {
    let path = std::env::var("T0013_S04_MANIFEST")
        .expect("T0013_S04_MANIFEST must name driver output");
    let manifest = std::fs::read_to_string(path).expect("read driver manifest");
    assert_eq!(compare_manifest(&manifest), Ok(2));
}
