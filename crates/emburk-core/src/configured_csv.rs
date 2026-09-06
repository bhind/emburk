//! Private single-file configured CSV execution profile.
use crate::{
    csv_stream,
    logical_record::{LogicalRecord, LogicalValue},
    logical_schema::{LogicalColumn, LogicalSchema, LogicalType},
    publication,
    record_handoff::{RecordSink, RecordSource, SinkError, SourceError, handoff_owned_records},
    yaml_profile::{self, Node},
};
use std::{
    fs::{self, File},
    io::{BufReader, BufWriter},
    path::{Path, PathBuf},
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
}
pub fn run_config(path: &Path) -> Result<usize, String> {
    let p = compile(yaml_profile::load(path)?.compile_node()?)?;
    execute(p)
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
    exact(top, &["in", "out", "exec"])?;
    let input = map(one(top, "in")?)?;
    exact(input, &["type", "path_prefix", "parser"])?;
    require(input, "type", "file")?;
    let parser = map(one(input, "parser")?)?;
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
    let skip = scalar(skips.last().unwrap())?
        .parse()
        .map_err(|_| "invalid skip_header_lines")?;
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
    exact(output, &["type", "path_prefix", "file_ext", "formatter"])?;
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
    require(exec, "max_threads", "1")?;
    require(exec, "min_output_tasks", "1")?;
    Ok(Profile {
        input: PathBuf::from(scalar(one(input, "path_prefix")?)?),
        output: PathBuf::from(format!(
            "{}000.00.csv",
            scalar(one(output, "path_prefix")?)?
        )),
        skip,
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
fn execute(profile: Profile) -> Result<usize, String> {
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
    let Some(input_path) = matches.pop() else {
        return Ok(0);
    };
    let file = File::open(&input_path).map_err(|e| format!("cannot open input: {e}"))?;
    let mut source = Source {
        input: BufReader::new(file),
        profile: &profile,
        skipped: 0,
    };
    publication::write_atomic(&profile.output, |output| {
        csv_stream::write_row(
            output,
            &profile
                .schema
                .columns()
                .map(|column| Some(column.name().to_owned()))
                .collect::<Vec<_>>(),
        )
        .map_err(|error| format!("CSV header failed: {error}"))?;
        let mut sink = Sink { output };
        handoff_owned_records(&mut source, &mut sink)
            .map_err(|error| format!("CSV transfer failed: {error:?}"))
    })
    .map_err(|error| error.to_string())
}
struct Source<'a> {
    input: BufReader<File>,
    profile: &'a Profile,
    skipped: usize,
}
impl RecordSource for Source<'_> {
    fn next_record(&mut self) -> Result<Option<LogicalRecord>, SourceError> {
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
struct Sink<'a> {
    output: &'a mut BufWriter<File>,
}
impl RecordSink for Sink<'_> {
    fn accept(&mut self, r: LogicalRecord) -> Result<(), SinkError> {
        let row = r
            .cells()
            .map(|v| match v {
                LogicalValue::Null => None,
                LogicalValue::Signed64(v) => Some(v.to_string()),
                LogicalValue::Text(v) => Some(v.clone()),
                _ => None,
            })
            .collect::<Vec<_>>();
        csv_stream::write_row(&mut self.output, &row).map_err(|e| SinkError(e.to_string()))
    }
}
