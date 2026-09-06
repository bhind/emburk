#![forbid(unsafe_code)]

use std::{
    env,
    fs::{self, File, OpenOptions},
    io::{self, BufReader},
    path::Path,
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
            "Usage: emburk transfer-lines INPUT OUTPUT\n       emburk transfer-lines-stdout INPUT\n       emburk transfer-lines-null INPUT"
        );
        return;
    }
    let (command, result) = match arguments.as_slice() {
        [_, command, config] if command == "run" => (
            "run",
            emburk_core::run_config(Path::new(config)).map(|_| ()),
        ),
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
        std::process::exit(1);
    }
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
