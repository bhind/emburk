//! Private bounded guess profile, based on observed behavior, not upstream code.
use crate::{
    csv_stream, native_formats,
    yaml_profile::{self, Node},
};
use serde_json::{Map, Value};
use std::{
    collections::BTreeSet,
    fs::{self, File},
    io::{BufReader, Cursor, Read, Write},
    path::Path,
};
const RAW: usize = 1024 * 1024;
const DECODED: usize = 32768;
type Result<T> = std::result::Result<T, String>;
pub fn guess_config_to_file(seed: &Path, output: &Path) -> Result<()> {
    let bytes = guess_config(seed)?;
    crate::publication::write_atomic(output, &std::sync::atomic::AtomicBool::new(false), |file| {
        file.write_all(&bytes).map_err(|e| e.to_string())
    })
    .map_err(|e| e.to_string())
}
pub fn guess_config(path: &Path) -> Result<Vec<u8>> {
    let mut root = object(yaml_profile::load(path)?.compile_node()?)?;
    let mut input = root
        .get("in")
        .and_then(Value::as_object)
        .ok_or("seed needs input mapping")?
        .clone();
    if input.get("type").and_then(Value::as_str) != Some("file") {
        return Err("input type must be file".into());
    }
    if input
        .keys()
        .any(|k| !matches!(k.as_str(), "type" | "path_prefix" | "parser" | "decoders"))
    {
        return Err("unsupported input option".into());
    }
    let explicit = match input.get("parser") {
        None => Map::new(),
        Some(Value::Object(m)) => m.clone(),
        _ => return Err("parser must be mapping".into()),
    };
    if explicit
        .keys()
        .any(|k| !matches!(k.as_str(), "charset" | "columns"))
    {
        return Err("explicit parser option not supported by guess".into());
    }
    if explicit.get("charset").is_some_and(|v| v != "UTF-8") {
        return Err("only explicit UTF-8 is supported".into());
    }
    let prefix = Path::new(
        input
            .get("path_prefix")
            .and_then(Value::as_str)
            .ok_or("missing path_prefix")?,
    );
    let parent = prefix
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let name = prefix.file_name().ok_or("missing input filename")?;
    let mut selected = None;
    for entry in fs::read_dir(parent).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        if entry
            .file_name()
            .as_encoded_bytes()
            .starts_with(name.as_encoded_bytes())
        {
            let kind = entry.file_type().map_err(|e| e.to_string())?;
            if kind.is_symlink() {
                return Err("input symlink unsupported".into());
            }
            if kind.is_file() && selected.replace(entry.path()).is_some() {
                return Err("multiple input files matched".into());
            }
        }
    }
    let mut raw = Vec::new();
    File::open(selected.ok_or("no input matched")?)
        .map_err(|e| e.to_string())?
        .take((RAW + 1) as u64)
        .read_to_end(&mut raw)
        .map_err(|e| e.to_string())?;
    if raw.len() > RAW {
        return Err("raw sample exceeds 1 MiB".into());
    }
    let codec = if raw.starts_with(&[0x1f, 0x8b]) {
        Some("gzip")
    } else if raw.starts_with(b"BZh") {
        Some("bzip2")
    } else {
        None
    };
    if let Some(decoders) = input.get("decoders") {
        let expected = codec.map(|c| {
            Value::Array(vec![Value::Object(Map::from_iter([(
                "type".into(),
                Value::String(c.into()),
            )]))])
        });
        if expected.as_ref() != Some(decoders) {
            return Err("explicit decoder does not match supported input".into());
        }
    } else if let Some(codec) = codec {
        input.insert("decoders".into(), serde_json::json!([{"type":codec}]));
    }
    let cursor = Cursor::new(raw);
    let reader: Box<dyn Read> = match codec {
        Some("gzip") => Box::new(flate2::read::MultiGzDecoder::new(cursor)),
        Some("bzip2") => Box::new(bzip2::read::MultiBzDecoder::new(cursor)),
        _ => Box::new(cursor),
    };
    let mut data = Vec::new();
    reader
        .take((DECODED + 1) as u64)
        .read_to_end(&mut data)
        .map_err(|e| e.to_string())?;
    if data.len() > DECODED {
        return Err("decoded whole-file sample exceeds 32768 bytes".into());
    }
    let text = std::str::from_utf8(&data).map_err(|_| "only UTF-8 samples are supported")?;
    if text.is_empty() {
        return Err("cannot guess empty input".into());
    }
    if text.contains('\r') {
        return Err("only LF samples are supported".into());
    }
    let mut parser = if text.trim_start().starts_with('{') {
        let mut reader = BufReader::new(data.as_slice());
        let mut count = 0;
        while native_formats::read_json(&mut reader)
            .map_err(|e| e.to_string())?
            .is_some()
        {
            count += 1;
        }
        if count == 0 {
            return Err("no JSON objects".into());
        }
        Map::from_iter([
            ("type".into(), Value::String("json".into())),
            ("charset".into(), Value::String("UTF-8".into())),
            ("newline".into(), Value::String("LF".into())),
        ])
    } else {
        csv_schema(
            text,
            explicit.contains_key("charset"),
            explicit.get("columns"),
        )?
    };
    // Explicit schema/charset remains authoritative, even when the resulting
    // configuration requires further validation by the transfer consumer.
    parser.extend(explicit);
    input.insert("parser".into(), Value::Object(parser));
    root.insert("in".into(), Value::Object(input));
    let mut output = serde_json::to_vec_pretty(&Value::Object(root)).map_err(|e| e.to_string())?;
    output.push(b'\n');
    if output.len() > 65536 {
        return Err("guessed config exceeds 64 KiB".into());
    }
    Ok(output)
}
fn object(node: Node) -> Result<Map<String, Value>> {
    let Node::Map(items) = node else {
        return Err("expected mapping".into());
    };
    let mut map = Map::new();
    for (key, value) in items {
        if map.insert(key, convert(value)?).is_some() {
            return Err("duplicate seed key".into());
        }
    }
    Ok(map)
}
fn convert(node: Node) -> Result<Value> {
    Ok(match node {
        Node::Scalar(s) => Value::String(s),
        Node::Map(_) => Value::Object(object(node)?),
        Node::Seq(items) => Value::Array(items.into_iter().map(convert).collect::<Result<_>>()?),
    })
}
#[cfg(test)]
fn csv(text: &str, explicit_utf8: bool) -> Result<Map<String, Value>> {
    csv_schema(text, explicit_utf8, None)
}
fn csv_schema(
    text: &str,
    explicit_utf8: bool,
    explicit_columns: Option<&Value>,
) -> Result<Map<String, Value>> {
    if text.contains('\t') || text.contains(';') || text.contains('|') {
        return Err("unsupported possible delimiter".into());
    }
    let mut reader = BufReader::new(text.as_bytes());
    let mut rows = Vec::new();
    while let Some(row) = csv_stream::read_record(&mut reader).map_err(|e| e.to_string())? {
        rows.push(row);
    }
    if rows.is_empty() {
        return Err("no CSV rows".into());
    }
    let width = rows[0].len();
    if width == 0 || width > 256 || rows.iter().any(|r| r.len() != width) {
        return Err("inconsistent CSV rows".into());
    }
    let unique = rows[0]
        .iter()
        .map(|(v, _)| v)
        .collect::<BTreeSet<_>>()
        .len()
        == width;
    let header = rows.len() > 1
        && unique
        && rows[0].iter().all(|(v, _)| ident(v))
        && rows[1..]
            .iter()
            .flatten()
            .any(|(v, _)| v.parse::<i64>().is_ok());
    let numeric = rows.iter().flatten().any(|(v, _)| v.parse::<i64>().is_ok());
    if !header && numeric && !explicit_utf8 {
        return Err("headerless numeric input requires explicit charset: UTF-8; automatic charset inference is unverified".into());
    }
    let names: Vec<String> = if header {
        rows[0].iter().map(|(v, _)| v.clone()).collect()
    } else {
        (0..width).map(|i| format!("c{i}")).collect()
    };
    let mut columns = Vec::new();
    for (index, name) in names.into_iter().enumerate() {
        if explicit_columns.is_some() {
            break;
        }
        let values = rows[usize::from(header)..]
            .iter()
            .map(|r| r[index].0.as_str())
            .collect::<Vec<_>>();
        if values.iter().any(|v| v.is_empty()) {
            return Err("empty-field type inference is unsupported".into());
        }
        let longs = values.iter().filter(|v| v.parse::<i64>().is_ok()).count();
        if longs != 0 && longs != values.len() {
            return Err("mixed numeric type inference is unsupported".into());
        }
        if longs == 0
            && values
                .iter()
                .any(|v| v.parse::<f64>().is_ok() || matches!(*v, "true" | "false"))
        {
            return Err("non-long scalar inference is unsupported".into());
        }
        columns.push(
            serde_json::json!({"name":name,"type":if longs==values.len(){"long"}else{"string"}}),
        );
    }
    let mut parser = Map::new();
    for (key, value) in [
        ("type", "csv"),
        ("charset", "UTF-8"),
        ("newline", "LF"),
        ("delimiter", ","),
        ("quote", "\""),
        ("escape", "\""),
        ("trim_if_not_quoted", "false"),
        ("allow_extra_columns", "false"),
        ("allow_optional_columns", "false"),
    ] {
        parser.insert(key.into(), Value::String(value.into()));
    }
    parser.insert(
        "skip_header_lines".into(),
        Value::String(usize::from(header).to_string()),
    );
    parser.insert(
        "columns".into(),
        explicit_columns.cloned().unwrap_or(Value::Array(columns)),
    );
    Ok(parser)
}
fn ident(s: &str) -> bool {
    let mut chars = s.chars();
    matches!(chars.next(),Some(c)if c.is_ascii_alphabetic()||c=='_')
        && chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}
#[cfg(test)]
mod tests {
    use super::*;
    fn file_guess(bytes: &[u8]) -> Result<Value> {
        static NEXT: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
        let root = std::env::temp_dir().join(format!(
            "emburk-guess-unit-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
        ));
        fs::create_dir(&root).unwrap();
        fs::write(root.join("input"), bytes).unwrap();
        fs::write(root.join("seed.yml"),serde_json::to_vec(&serde_json::json!({"in":{"type":"file","path_prefix":root.join("input").to_str().unwrap()}})).unwrap()).unwrap();
        serde_json::from_slice(&guess_config(&root.join("seed.yml"))?).map_err(|e| e.to_string())
    }
    #[test]
    fn compressed_samples_and_expansion_limits() {
        let plain = b"account,label\n71,Delta\n-3,Echo\n";
        let mut gzip = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::default());
        gzip.write_all(plain).unwrap();
        let bytes = gzip.finish().unwrap();
        assert_eq!(
            file_guess(&bytes).unwrap()["in"]["decoders"][0]["type"],
            "gzip"
        );
        let mut bzip = bzip2::write::BzEncoder::new(Vec::new(), bzip2::Compression::best());
        bzip.write_all(plain).unwrap();
        assert_eq!(
            file_guess(&bzip.finish().unwrap()).unwrap()["in"]["decoders"][0]["type"],
            "bzip2"
        );
        let mut gzip = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::default());
        gzip.write_all(&vec![b'x'; DECODED + 1]).unwrap();
        assert!(file_guess(&gzip.finish().unwrap()).is_err());
        assert!(file_guess(&vec![b'x'; RAW + 1]).is_err());
        assert!(file_guess(&bytes[..bytes.len() - 2]).is_err());
    }
    #[test]
    fn arbitrary_names_and_values() {
        let p = csv("account,label\n71,Delta\n-3,Echo\n", false).unwrap();
        assert_eq!(p["columns"][0]["name"], "account");
        assert_eq!(p["columns"][0]["type"], "long");
        assert_eq!(p["skip_header_lines"], "1");
    }
    #[test]
    fn headerless_needs_explicit_charset() {
        assert!(csv("1,Delta\n2,Echo\n", false).is_err());
        assert_eq!(
            csv("1,Delta\n2,Echo\n", true).unwrap()["columns"][0]["name"],
            "c0"
        );
    }
    #[test]
    fn unsupported_inference_is_explicit() {
        for input in [
            "",
            "a\tb\n1\tx\n",
            "a,b\n1,x\n2\n",
            "a,b\n1,x\ny,z\n",
            "a,b\n1,\n",
            "a,b\n1,3.2\n",
        ] {
            assert!(csv(input, false).is_err(), "{input:?}");
        }
    }
}
