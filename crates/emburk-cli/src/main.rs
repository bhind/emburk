#![forbid(unsafe_code)]

use std::{
    env,
    fs::{self, File, OpenOptions},
    io::{self, BufReader},
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
            "Usage: emburk run CONFIG [--state STATE_DIR]\n       emburk resume CONFIG STATE_DIR\n       emburk transfer-lines INPUT OUTPUT\n       emburk transfer-lines-stdout INPUT\n       emburk transfer-lines-null INPUT"
        );
        return;
    }
    let cancelled = Arc::new(AtomicBool::new(false));
    let (command, result) = match arguments.as_slice() {
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
            eprintln!("Usage: emburk run CONFIG\n       emburk transfer-lines INPUT OUTPUT");
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
