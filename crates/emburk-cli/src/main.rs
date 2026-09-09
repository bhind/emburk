#![forbid(unsafe_code)]

use std::{
    env,
    fs::{self, File, OpenOptions},
    io::{self, BufReader, Write},
    path::Path,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};

fn main() {
    let arguments: Vec<_> = env::args_os().collect();
    if arguments.len() == 1 {
        println!("{}", emburk_core::DEVELOPMENT_STATUS);
        return;
    }
    if arguments.len() == 2
        && matches!(
            arguments.get(1).and_then(|value| value.to_str()),
            Some("--help" | "-h")
        )
    {
        println!(
            "Usage: emburk guess SEED [-o CONFIG]\n       emburk run CONFIG [--report REPORT.json]\n       emburk run CONFIG [--state STATE_DIR]\n       emburk resume CONFIG STATE_DIR\n       emburk transfer-lines INPUT OUTPUT\n       emburk transfer-lines-stdout INPUT\n       emburk transfer-lines-null INPUT"
        );
        return;
    }
    if let [_, command, config, flag, report] = arguments.as_slice()
        && command == "run"
        && flag == "--report"
    {
        run_with_report(Path::new(config), Path::new(report));
        return;
    }
    let cancelled = Arc::new(AtomicBool::new(false));
    let (command, result) = match arguments.as_slice() {
        [_, command, seed] if command == "guess" => (
            "guess",
            emburk_core::guess_config(Path::new(seed)).and_then(|bytes| {
                io::stdout()
                    .lock()
                    .write_all(&bytes)
                    .map_err(|e| e.to_string())
            }),
        ),
        [_, command, seed, flag, output] if command == "guess" && flag == "-o" => (
            "guess",
            emburk_core::guess_config_to_file(Path::new(seed), Path::new(output)),
        ),
        #[cfg(unix)]
        [_, command, config, flag, directory] if command == "run" && flag == "--state" => (
            "run",
            stateful(Path::new(config), Path::new(directory), &cancelled, false),
        ),
        #[cfg(unix)]
        [_, command, config, directory] if command == "resume" => (
            "resume",
            stateful(Path::new(config), Path::new(directory), &cancelled, true),
        ),
        [_, command, config] if command == "run" => {
            let signal_flag = Arc::clone(&cancelled);
            let result = ctrlc::set_handler(move || signal_flag.store(true, Ordering::Release))
                .map_err(|error| format!("cannot install SIGINT handler: {error}"))
                .and_then(|()| {
                    emburk_core::run_config_with_cancel(Path::new(config), &cancelled).map(|_| ())
                });
            ("run", result)
        }
        [_, command, input, output] if command == "transfer-lines" => (
            "transfer-lines",
            transfer(Path::new(input), Path::new(output)),
        ),
        [_, command, input] if command == "transfer-lines-stdout" => {
            ("transfer-lines-stdout", transfer_stdout(Path::new(input)))
        }
        [_, command, input] if command == "transfer-lines-null" => {
            ("transfer-lines-null", transfer_null(Path::new(input)))
        }
        _ => {
            eprintln!(
                "Usage: emburk run CONFIG [--report REPORT.json]\n       emburk transfer-lines INPUT OUTPUT"
            );
            std::process::exit(2);
        }
    };
    if let Err(error) = result {
        eprintln!("emburk: {command} failed: {error}");
        std::process::exit(if cancelled.load(Ordering::Acquire) {
            130
        } else {
            1
        });
    }
}

fn run_with_report(config: &Path, report_path: &Path) {
    let cancelled = Arc::new(AtomicBool::new(false));
    let signal_flag = Arc::clone(&cancelled);
    if let Err(error) = ctrlc::set_handler(move || signal_flag.store(true, Ordering::Release)) {
        eprintln!("emburk: run failed: cannot install SIGINT handler: {error}");
        std::process::exit(1);
    }

    let mut report = match create_report(report_path) {
        Ok(report) => report,
        Err(error) => {
            eprintln!("emburk: cannot create run report exclusively: {error}");
            std::process::exit(2);
        }
    };

    let result = if cancelled.load(Ordering::Acquire) {
        Err("cancelled".to_owned())
    } else {
        emburk_core::run_config_with_cancel(config, &cancelled)
    };

    let (outcome, exit_code, records, error) = match result {
        Ok(records) => ("succeeded", 0, Some(records), None),
        Err(error) if cancelled.load(Ordering::Acquire) => {
            let diagnostic = format!("emburk: run failed: {error}");
            eprintln!("{diagnostic}");
            ("cancelled", 130, None, Some(diagnostic))
        }
        Err(error) => {
            let diagnostic = format!("emburk: run failed: {error}");
            eprintln!("{diagnostic}");
            ("failed", 1, None, Some(diagnostic))
        }
    };
    let body = run_report_json(outcome, exit_code, records, error.as_deref());
    if let Err(error) = report
        .write_all(body.as_bytes())
        .and_then(|()| report.flush())
    {
        eprintln!("emburk: cannot write run report: {error}");
        std::process::exit(exit_code.max(1));
    }
    if exit_code != 0 {
        std::process::exit(exit_code);
    }
}

fn create_report(path: &Path) -> io::Result<File> {
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(path)
}

fn run_report_json(
    outcome: &str,
    exit_code: i32,
    records: Option<usize>,
    error: Option<&str>,
) -> String {
    let records = records
        .map(|records| records.to_string())
        .unwrap_or_else(|| "null".to_owned());
    let error = error
        .map(|error| serde_json::to_string(error).expect("string JSON serialization cannot fail"))
        .unwrap_or_else(|| "null".to_owned());
    format!(
        "{{\"schema\":\"emburk.run-result/v1\",\"command\":\"run\",\"outcome\":\"{outcome}\",\"exit_code\":{exit_code},\"records\":{records},\"error\":{error}}}\n"
    )
}

#[cfg(unix)]
fn stateful(
    config: &Path,
    directory: &Path,
    cancelled: &Arc<AtomicBool>,
    resume: bool,
) -> Result<(), String> {
    let flag = Arc::clone(cancelled);
    ctrlc::set_handler(move || flag.store(true, Ordering::Release)).map_err(|e| e.to_string())?;
    emburk_core::run_config_resumable(config, directory, cancelled, resume).map(|_| ())
}

fn open_input(input: &Path) -> Result<File, String> {
    let metadata = fs::metadata(input).map_err(|error| format!("cannot inspect input: {error}"))?;
    if !metadata.is_file() {
        return Err("input must be a regular file".into());
    }
    File::open(input).map_err(|error| format!("cannot open input: {error}"))
}

fn transfer(input: &Path, output: &Path) -> Result<(), String> {
    let input_file = open_input(input)?;
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let output_file = options
        .open(output)
        .map_err(|error| format!("cannot create output exclusively: {error}"))?;
    match emburk_core::transfer_lines(BufReader::new(input_file), output_file) {
        Ok(count) => {
            println!("emburk: transfer-lines completed: {count} records");
            Ok(())
        }
        Err(error) => Err(format!(
            "{error}; output may be partially written at {}",
            output.display()
        )),
    }
}

fn transfer_stdout(input: &Path) -> Result<(), String> {
    let input_file = open_input(input)?;
    let stdout = io::stdout();
    let count = emburk_core::transfer_lines(BufReader::new(input_file), stdout.lock())
        .map_err(|error| format!("{error}"))?;
    eprintln!("emburk: transfer-lines-stdout completed: {count} records");
    Ok(())
}

fn transfer_null(input: &Path) -> Result<(), String> {
    let input_file = open_input(input)?;
    let count = emburk_core::transfer_lines(BufReader::new(input_file), io::sink())
        .map_err(|error| format!("{error}"))?;
    eprintln!("emburk: transfer-lines-null completed: {count} records");
    Ok(())
}
