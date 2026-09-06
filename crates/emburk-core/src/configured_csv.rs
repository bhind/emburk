//! Private single-file configured CSV execution profile.
use crate::{
    bounded_parallel, csv_stream,
    logical_record::{LogicalRecord, LogicalValue},
    logical_schema::{LogicalColumn, LogicalSchema, LogicalType},
    native_formats::{self, Codec, Encoder},
    publication,
    record_handoff::{RecordSource, SourceError},
    yaml_profile::{self, Node},
};
use std::{
    fs::{self, File},
    io::{BufRead, Write},
    path::{Path, PathBuf},
    sync::atomic::{AtomicBool, Ordering},
};

#[derive(Clone)]
struct Column {
    name: String,
    long: bool,
}
struct Profile {
    input: PathBuf,
    output: PathBuf,
    skip: usize,
    schema: LogicalSchema,
    json: bool,
    decoder: Codec,
    encoder: Codec,
    projection: Vec<(usize, String)>,
    workers: usize,
}
pub fn run_config(path: &Path) -> Result<usize, String> {
    run_config_with_cancel(path, &AtomicBool::new(false))
}
pub fn run_config_with_cancel(path: &Path, cancel: &AtomicBool) -> Result<usize, String> {
    let p = compile(yaml_profile::load(path)?.compile_node()?)?;
    execute(p, cancel)
}
fn scalar(n: &Node) -> Result<&str, String> {
    match n {
        Node::Scalar(s) => Ok(s),
        _ => Err("expected scalar configuration value".into()),
    }
}
fn map(n: &Node) -> Result<&Vec<(String, Node)>, String> {
    match n {
        Node::Map(m) => Ok(m),
        _ => Err("expected mapping configuration value".into()),
    }
}
fn values<'a>(m: &'a [(String, Node)], key: &str) -> Vec<&'a Node> {
    m.iter()
        .filter_map(|(k, v)| (k == key).then_some(v))
        .collect()
}
fn one<'a>(m: &'a [(String, Node)], key: &str) -> Result<&'a Node, String> {
    let v = values(m, key);
    if v.len() != 1 {
        Err(format!("required exactly one {key}"))
    } else {
        Ok(v[0])
    }
}
fn exact(m: &[(String, Node)], allowed: &[&str]) -> Result<(), String> {
    for (k, _) in m {
        if !allowed.contains(&k.as_str()) {
            return Err(format!("unsupported option {k}"));
        }
    }
    Ok(())
}
fn require(m: &[(String, Node)], key: &str, value: &str) -> Result<(), String> {
    if scalar(one(m, key)?)? == value {
        Ok(())
    } else {
        Err(format!("unsupported {key}"))
    }
}
fn compile(root: Node) -> Result<Profile, String> {
    let top = map(&root)?;
    exact(top, &["in", "out", "exec", "filters"])?;
    let input = map(one(top, "in")?)?;
    exact(input, &["type", "path_prefix", "parser", "decoders"])?;
    require(input, "type", "file")?;
    let parser = map(one(input, "parser")?)?;
    let json = match scalar(one(parser, "type")?)? {
        "csv" => false,
        "json" => true,
        _ => return Err("unsupported parser type".into()),
    };
    let skip = if json {
        exact(parser, &["type", "columns"])?;
        0
    } else {
        exact(
            parser,
            &[
                "type",
                "charset",
                "newline",
                "delimiter",
                "quote",
                "escape",
                "skip_header_lines",
                "columns",
            ],
        )?;
        for (k, v) in [
            ("type", "csv"),
            ("charset", "UTF-8"),
            ("newline", "LF"),
            ("delimiter", ","),
            ("quote", "\""),
            ("escape", "\""),
        ] {
            require(parser, k, v)?
        }
        let skips = values(parser, "skip_header_lines");
        if skips.is_empty() {
            return Err("required skip_header_lines".into());
        };
        scalar(skips.last().unwrap())?
            .parse()
            .map_err(|_| "invalid skip_header_lines")?
    };
    let Node::Seq(cols) = one(parser, "columns")? else {
        return Err("columns must be sequence".into());
    };
    if cols.is_empty() || cols.len() > csv_stream::MAX_COLUMNS {
        return Err("unsupported column count".into());
    };
    let mut columns = Vec::new();
    for item in cols {
        let c = map(item)?;
        exact(c, &["name", "type"])?;
        let t = scalar(one(c, "type")?)?;
        if !matches!(t, "long" | "string") {
            return Err("unsupported column type".into());
        };
        columns.push(Column {
            name: scalar(one(c, "name")?)?.to_owned(),
            long: t == "long",
        });
    }
    let output = map(one(top, "out")?)?;
    exact(
        output,
        &["type", "path_prefix", "file_ext", "formatter", "encoders"],
    )?;
    require(output, "type", "file")?;
    require(output, "file_ext", "csv")?;
    let formatter = map(one(output, "formatter")?)?;
    exact(
        formatter,
        &[
            "type",
            "charset",
            "newline",
            "delimiter",
            "quote",
            "escape",
            "header_line",
            "quote_policy",
        ],
    )?;
    for (k, v) in [
        ("type", "csv"),
        ("charset", "UTF-8"),
        ("newline", "LF"),
        ("delimiter", ","),
        ("quote", "\""),
        ("escape", "\""),
        ("header_line", "true"),
        ("quote_policy", "MINIMAL"),
    ] {
        require(formatter, k, v)?
    }
    let exec = map(one(top, "exec")?)?;
    exact(exec, &["max_threads", "min_output_tasks"])?;
    let workers = scalar(one(exec, "max_threads")?)?
        .parse::<usize>()
        .map_err(|_| "invalid max_threads")?;
    if !(1..=8).contains(&workers) {
        return Err("max_threads must be 1 through 8".into());
    }
    require(exec, "min_output_tasks", "1")?;
    let mut projection: Vec<_> = columns
        .iter()
        .enumerate()
        .map(|(index, column)| (index, column.name.clone()))
        .collect();
    if let Some(filters) = optional(top, "filters")? {
        let Node::Seq(filters) = filters else {
            return Err("filters must be sequence".into());
        };
        for filter in filters {
            let filter = map(filter)?;
            match scalar(one(filter, "type")?)? {
                "rename" => {
                    exact(filter, &["type", "columns"])?;
                    let renames = map(one(filter, "columns")?)?;
                    for (name, _) in renames {
                        one(renames, name)?;
                        if !projection.iter().any(|(_, current)| current == name) {
                            return Err(format!("rename column not found: {name}"));
                        }
                    }
                    for (_, name) in &mut projection {
                        if let Some(new) = optional(renames, name)? {
                            *name = scalar(new)?.to_owned();
                        }
                    }
                }
                "remove_columns" => {
                    exact(filter, &["type", "remove"])?;
                    let Node::Seq(remove) = one(filter, "remove")? else {
                        return Err("remove must be sequence".into());
                    };
                    let names = remove.iter().map(scalar).collect::<Result<Vec<_>, _>>()?;
                    for name in &names {
                        if !projection.iter().any(|(_, current)| current == name) {
                            return Err(format!("remove column not found: {name}"));
                        }
                    }
                    projection.retain(|(_, name)| !names.contains(&name.as_str()));
                }
                _ => return Err("unsupported filter type".into()),
            }
        }
    }
    Ok(Profile {
        input: PathBuf::from(scalar(one(input, "path_prefix")?)?),
        output: PathBuf::from(format!(
            "{}000.00.csv",
            scalar(one(output, "path_prefix")?)?
        )),
        skip,
        json,
        decoder: codec(input, "decoders", false)?,
        encoder: codec(output, "encoders", true)?,
        projection,
        workers,
        schema: LogicalSchema::new(
            columns
                .iter()
                .map(|column| {
                    LogicalColumn::new(
                        column.name.clone(),
                        if column.long {
                            LogicalType::Signed64
                        } else {
                            LogicalType::Text
                        },
                    )
                })
                .collect(),
        ),
    })
}
fn optional<'a>(mapping: &'a [(String, Node)], key: &str) -> Result<Option<&'a Node>, String> {
    match values(mapping, key).as_slice() {
        [] => Ok(None),
        [value] => Ok(Some(*value)),
        _ => Err(format!("duplicate option {key}")),
    }
}
fn codec(mapping: &[(String, Node)], key: &str, encoder: bool) -> Result<Codec, String> {
    let Some(value) = optional(mapping, key)? else {
        return Ok(Codec::Plain);
    };
    let Node::Seq(items) = value else {
        return Err(format!("{key} must be sequence"));
    };
    let [item] = items.as_slice() else {
        return Err("only one codec is supported".into());
    };
    let item = map(item)?;
    exact(
        item,
        if encoder {
            &["type", "level"]
        } else {
            &["type"]
        },
    )?;
    let (codec, level) = match scalar(one(item, "type")?)? {
        "gzip" => (Codec::Gzip, "6"),
        "bzip2" => (Codec::Bzip2, "9"),
        _ => return Err("unsupported codec type".into()),
    };
    if encoder {
        require(item, "level", level)?;
    }
    Ok(codec)
}
fn execute(profile: Profile, cancel: &AtomicBool) -> Result<usize, String> {
    if cancel.load(Ordering::Acquire) {
        return Err("cancelled".into());
    }
    let Some(input_path) = select_input(&profile)? else {
        return Ok(0);
    };
    execute_input(profile, cancel, input_path)
}
fn select_input(profile: &Profile) -> Result<Option<PathBuf>, String> {
    let parent = profile
        .input
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let prefix = profile
        .input
        .file_name()
        .ok_or("input path has no file prefix")?;
    let mut matches = Vec::new();
    for entry in fs::read_dir(parent).map_err(|error| format!("cannot inspect input: {error}"))? {
        let entry = entry.map_err(|error| format!("cannot inspect input entry: {error}"))?;
        if entry
            .file_name()
            .as_encoded_bytes()
            .starts_with(prefix.as_encoded_bytes())
            && entry
                .metadata()
                .map_err(|error| format!("cannot inspect input entry: {error}"))?
                .is_file()
        {
            matches.push(entry.path());
            if matches.len() == 2 {
                return Err("multiple input files matched".into());
            }
        }
    }
    Ok(matches.pop())
}
fn execute_input(
    profile: Profile,
    cancel: &AtomicBool,
    input_path: PathBuf,
) -> Result<usize, String> {
    let file = File::open(&input_path).map_err(|e| format!("cannot open input: {e}"))?;
    let mut source = Source {
        input: native_formats::reader(file, profile.decoder),
        profile: &profile,
        skipped: 0,
    };
    publication::write_atomic(&profile.output, cancel, |output| {
        let mut encoded = Encoder::new(output, profile.encoder);
        csv_stream::write_row(
            &mut encoded,
            &profile
                .projection
                .iter()
                .map(|(_, name)| Some(name.clone()))
                .collect::<Vec<_>>(),
        )
        .map_err(|error| format!("CSV header failed: {error}"))?;
        let count = bounded_parallel::run(
            profile.workers,
            cancel,
            || source.next_record().map_err(|error| error.0),
            |record| format_record(record, &profile.projection),
            |bytes| encoded.write_all(&bytes).map_err(|error| error.to_string()),
        )?;
        if cancel.load(Ordering::Acquire) {
            return Err("cancelled".into());
        }
        encoded
            .finish()
            .map_err(|error| format!("codec finalization failed: {error}"))?;
        Ok(count)
    })
    .map_err(|error| error.to_string())
}
#[cfg(unix)]
pub fn run_config_resumable(
    config: &Path,
    directory: &Path,
    cancel: &AtomicBool,
    resume: bool,
) -> Result<usize, String> {
    use crate::checkpoint::{self, State};
    use serde_json::{Value, json};
    use std::io::{Read, Seek, SeekFrom};
    let cancelled = || {
        if cancel.load(Ordering::Acquire) {
            Err("cancelled".to_owned())
        } else {
            Ok(())
        }
    };
    cancelled()?;
    let raw = yaml_profile::load(config)?;
    let config_hash = checkpoint::hash(&raw.bytes);
    let profile = compile(raw.compile_node()?)?;
    let input = select_input(&profile)?.ok_or("stateful run requires one matched input")?;
    let input_identity = checkpoint::identity(&input)?;
    let input = fs::canonicalize(input).map_err(|e| e.to_string())?;
    let parent = profile
        .output
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let output = fs::canonicalize(parent).map_err(|e| e.to_string())?.join(
        profile
            .output
            .file_name()
            .ok_or("missing output filename")?,
    );
    let context = json!({"profile":"configured-spool-v1", "config_sha256":config_hash,"input_path":input.to_str().ok_or("stateful input path must be UTF-8")?,"input":input_identity,"output":output.to_str().ok_or("stateful output path must be UTF-8")?});
    let revalidate = || -> Result<(), String> {
        cancelled()?;
        if checkpoint::hash(&yaml_profile::load(config)?.bytes) != config_hash
            || checkpoint::identity(&input)? != input_identity
            || select_input(&profile)?
                .map(fs::canonicalize)
                .transpose()
                .map_err(|e| e.to_string())?
                != Some(input.clone())
        {
            return Err("configuration or input changed".into());
        }
        Ok(())
    };
    if !resume && fs::symlink_metadata(&output).is_ok() {
        return Err("output already exists".into());
    }
    let mut state = State::open(directory, context, resume)?;
    let mut source = Source {
        input: native_formats::reader(
            File::open(&input).map_err(|e| e.to_string())?,
            profile.decoder,
        ),
        profile: &profile,
        skipped: 0,
    };
    let mut header = Vec::new();
    csv_stream::write_row(
        &mut header,
        &profile
            .projection
            .iter()
            .map(|(_, name)| Some(name.clone()))
            .collect::<Vec<_>>(),
    )
    .map_err(|e| e.to_string())?;
    let mut already_published = false;
    if resume {
        state.compare(&header)?;
        for _ in 0..state.records() {
            cancelled()?;
            let record = source
                .next_record()
                .map_err(|e| e.0)?
                .ok_or("input ended before checkpoint")?;
            state.compare(&format_record(record, &profile.projection)?)?;
        }
        if state.phase() != "Writing" && source.next_record().map_err(|e| e.0)?.is_some() {
            return Err("completed spool omits input records".into());
        }
        match fs::symlink_metadata(&output) {
            Ok(_) => {
                if !matches!(state.phase(), "Publishing" | "Published")
                    || checkpoint::identity(&output)? != state.latest["prepared"]
                {
                    return Err("existing output conflicts with prepared identity".into());
                }
                already_published = true;
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound && state.phase() != "Published" => {}
            Err(e) => return Err(format!("cannot recover published output: {e}")),
        }
        revalidate()?;
        state.finish_validation()?;
    } else {
        state.append(&header, false)?;
        state.save("Writing", Value::Null)?;
    }
    if already_published {
        File::open(&output)
            .and_then(|f| f.sync_all())
            .map_err(|e| e.to_string())?;
        File::open(output.parent().unwrap())
            .and_then(|f| f.sync_all())
            .map_err(|e| e.to_string())?;
        if state.phase() != "Published" {
            let prepared = state.latest["prepared"].clone();
            state.save("Published", prepared)?;
        }
        return usize::try_from(state.records()).map_err(|e| e.to_string());
    }
    if state.phase() == "Writing" {
        bounded_parallel::run(
            profile.workers,
            cancel,
            || source.next_record().map_err(|e| e.0),
            |record| format_record(record, &profile.projection),
            |bytes| state.append(&bytes, true),
        )?;
        state.save("Ready", Value::Null)?;
    }
    revalidate()?;
    state
        .spool
        .seek(SeekFrom::Start(0))
        .map_err(|e| e.to_string())?;
    let mut spool = state.spool.try_clone().map_err(|e| e.to_string())?;
    publication::write_prepared(
        &output,
        cancel,
        |output| {
            let mut encoder = Encoder::new(output, profile.encoder);
            let mut bytes = [0; 65536];
            loop {
                cancelled()?;
                let n = spool.read(&mut bytes).map_err(|e| e.to_string())?;
                if n == 0 {
                    break;
                }
                encoder.write_all(&bytes[..n]).map_err(|e| e.to_string())?;
            }
            encoder.finish().map_err(|e| e.to_string())?;
            Ok(())
        },
        |temporary, _| {
            revalidate()?;
            state.save("Publishing", checkpoint::identity(temporary)?)
        },
    )
    .map_err(|e| e.to_string())?;
    let prepared = state.latest["prepared"].clone();
    state.save("Published", prepared)?;
    usize::try_from(state.records()).map_err(|e| e.to_string())
}

struct Source<'a> {
    input: Box<dyn BufRead>,
    profile: &'a Profile,
    skipped: usize,
}
impl RecordSource for Source<'_> {
    fn next_record(&mut self) -> Result<Option<LogicalRecord>, SourceError> {
        if self.profile.json {
            let Some(object) = native_formats::read_json(&mut self.input)
                .map_err(|error| SourceError(error.to_string()))?
            else {
                return Ok(None);
            };
            let mut cells = Vec::new();
            let mut selected_bytes = 0usize;
            for column in self.profile.schema.columns() {
                let value = &object[column.name()];
                selected_bytes = selected_bytes
                    .checked_add(value.as_str().map_or(8, str::len))
                    .ok_or_else(|| SourceError("JSON selected record size overflow".into()))?;
                if selected_bytes > 1024 * 1024 {
                    return Err(SourceError(
                        "JSON selected record exceeds 1048576 bytes".into(),
                    ));
                }
                cells.push(if value.is_null() {
                    LogicalValue::Null
                } else if column.logical_type() == LogicalType::Signed64 {
                    LogicalValue::Signed64(
                        value
                            .as_i64()
                            .ok_or_else(|| SourceError("JSON field is not signed64".into()))?,
                    )
                } else {
                    LogicalValue::Text(
                        value
                            .as_str()
                            .ok_or_else(|| SourceError("JSON field is not string".into()))?
                            .to_owned(),
                    )
                });
            }
            return Ok(Some(LogicalRecord::new(cells)));
        }
        loop {
            let Some(row) =
                csv_stream::read_record(&mut self.input).map_err(|e| SourceError(e.to_string()))?
            else {
                return Ok(None);
            };
            if self.skipped < self.profile.skip {
                self.skipped += 1;
                continue;
            }
            if row.len() != self.profile.schema.columns().len() {
                return Err(SourceError("CSV row width differs from columns".into()));
            }
            let mut cells = Vec::new();
            let mut bad = false;
            for ((text, q), c) in row.into_iter().zip(self.profile.schema.columns()) {
                if text.is_empty() && !q {
                    cells.push(LogicalValue::Null)
                } else if c.logical_type() == LogicalType::Signed64 {
                    match text.parse::<i64>() {
                        Ok(v) => cells.push(LogicalValue::Signed64(v)),
                        _ => {
                            bad = true;
                            break;
                        }
                    }
                } else {
                    cells.push(LogicalValue::Text(text))
                }
            }
            if !bad {
                return Ok(Some(LogicalRecord::new(cells)));
            }
        }
    }
}
fn format_record(r: LogicalRecord, projection: &[(usize, String)]) -> Result<Vec<u8>, String> {
    let cells = r.cells().collect::<Vec<_>>();
    let row = projection
        .iter()
        .map(|(index, _)| match cells[*index] {
            LogicalValue::Null => None,
            LogicalValue::Signed64(v) => Some(v.to_string()),
            LogicalValue::Text(v) => Some(v.clone()),
            _ => None,
        })
        .collect::<Vec<_>>();
    let mut output = Vec::new();
    csv_stream::write_row(&mut output, &row).map_err(|e| e.to_string())?;
    Ok(output)
}
