#![forbid(unsafe_code)]

use std::{
    env,
    fs::{self, File, OpenOptions},
    io::BufReader,
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
        println!("Usage: emburk transfer-lines INPUT OUTPUT");
        return;
    }
    if arguments.len() != 4 || arguments[1] != "transfer-lines" {
        eprintln!("Usage: emburk transfer-lines INPUT OUTPUT");
        std::process::exit(2);
    }
    let input = Path::new(&arguments[2]);
    let output = Path::new(&arguments[3]);
    if let Err(error) = transfer(input, output) {
        eprintln!("emburk: transfer-lines failed: {error}");
        std::process::exit(1);
    }
}

fn transfer(input: &Path, output: &Path) -> Result<(), String> {
    let metadata = fs::metadata(input).map_err(|error| format!("cannot inspect input: {error}"))?;
    if !metadata.is_file() {
        return Err("input must be a regular file".into());
    }
    let input_file = File::open(input).map_err(|error| format!("cannot open input: {error}"))?;
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
