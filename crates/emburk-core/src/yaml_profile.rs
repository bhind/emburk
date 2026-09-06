//! A deliberately narrow YAML event adapter for the configured CSV profile.

use saphyr_parser::{Event, Parser};
use std::{
    fs::File,
    io::{BufReader, Read},
    path::Path,
};

const MAX_BYTES: usize = 64 * 1024;
const MAX_EVENTS: usize = 4096;
const MAX_DEPTH: usize = 64;

#[derive(Debug, Clone)]
pub(super) enum Node {
    Scalar(String),
    Map(Vec<(String, Node)>),
    Seq(Vec<Node>),
}
#[derive(Debug, Clone)]
#[allow(
    dead_code,
    reason = "raw provenance is retained for profile admission and tests"
)]
pub(super) struct RawConfig {
    pub(super) bytes: Vec<u8>,
    pub(super) events: Vec<String>,
    node: Node,
    unsupported: bool,
}
impl RawConfig {
    pub(super) fn compile_node(self) -> Result<Node, String> {
        if self.unsupported {
            Err("YAML aliases, tags, anchors, or unsupported scalar styles are unsupported".into())
        } else {
            Ok(self.node)
        }
    }
}

pub(super) fn load(path: &Path) -> Result<RawConfig, String> {
    let mut bytes = Vec::new();
    BufReader::new(File::open(path).map_err(|e| format!("cannot open config: {e}"))?)
        .take((MAX_BYTES + 1) as u64)
        .read_to_end(&mut bytes)
        .map_err(|e| format!("cannot read config: {e}"))?;
    if bytes.len() > MAX_BYTES {
        return Err(format!("config exceeds {MAX_BYTES} bytes"));
    }
    let text =
        String::from_utf8(bytes.clone()).map_err(|_| "config is not valid UTF-8".to_owned())?;
    let mut tokens = Vec::new();
    let mut depth = 0usize;
    let mut raw_events = Vec::new();
    let mut unsupported = false;
    let mut documents = 0usize;
    for item in Parser::new_from_str(&text) {
        let (event, span) = item.map_err(|e| format!("invalid YAML: {e}"))?;
        if raw_events.len() == MAX_EVENTS {
            return Err(format!("config event limit {MAX_EVENTS} exceeded"));
        }
        raw_events.push(format!(
            "{event:?}@{}:{}:{}-{}:{}:{}",
            span.start.index(),
            span.start.line(),
            span.start.col(),
            span.end.index(),
            span.end.line(),
            span.end.col()
        ));
        match event {
            Event::Scalar(v, style, anchor, tag) => {
                if !matches!(
                    style,
                    saphyr_parser::ScalarStyle::Plain
                        | saphyr_parser::ScalarStyle::SingleQuoted
                        | saphyr_parser::ScalarStyle::DoubleQuoted
                ) || anchor != 0
                    || tag.is_some()
                {
                    unsupported = true;
                }
                tokens.push(Token::Scalar(v.into_owned()));
            }
            Event::MappingStart(anchor, tag) => {
                if anchor != 0 || tag.is_some() {
                    unsupported = true;
                }
                depth += 1;
                if depth > MAX_DEPTH {
                    return Err(format!("config depth limit {MAX_DEPTH} exceeded"));
                }
                tokens.push(Token::Map);
            }
            Event::SequenceStart(anchor, tag) => {
                if anchor != 0 || tag.is_some() {
                    unsupported = true;
                }
                depth += 1;
                if depth > MAX_DEPTH {
                    return Err(format!("config depth limit {MAX_DEPTH} exceeded"));
                }
                tokens.push(Token::Seq);
            }
            Event::MappingEnd | Event::SequenceEnd => {
                depth = depth.saturating_sub(1);
                tokens.push(Token::End);
            }
            Event::Alias(_) => {
                unsupported = true;
                tokens.push(Token::Alias);
            }
            Event::DocumentStart(_) => {
                documents += 1;
            }
            Event::StreamStart | Event::StreamEnd | Event::DocumentEnd | Event::Nothing => {}
        }
    }
    if documents != 1 {
        return Err("multiple YAML documents are unsupported".into());
    }
    let node = if unsupported {
        Node::Scalar(String::new())
    } else {
        let mut index = 0;
        let node = parse(&tokens, &mut index)?;
        if index != tokens.len() {
            return Err("multiple YAML documents are unsupported".into());
        }
        node
    };
    Ok(RawConfig {
        bytes,
        events: raw_events,
        node,
        unsupported,
    })
}

#[derive(Debug)]
enum Token {
    Scalar(String),
    Map,
    Seq,
    End,
    Alias,
}
fn parse(tokens: &[Token], i: &mut usize) -> Result<Node, String> {
    match tokens.get(*i) {
        Some(Token::Scalar(v)) => {
            *i += 1;
            Ok(Node::Scalar(v.clone()))
        }
        Some(Token::Map) => {
            *i += 1;
            let mut entries = Vec::new();
            while !matches!(tokens.get(*i), Some(Token::End)) {
                let Some(Token::Scalar(key)) = tokens.get(*i) else {
                    return Err("YAML mapping keys must be scalars".into());
                };
                let key = key.clone();
                *i += 1;
                entries.push((key, parse(tokens, i)?));
            }
            *i += 1;
            Ok(Node::Map(entries))
        }
        Some(Token::Seq) => {
            *i += 1;
            let mut entries = Vec::new();
            while !matches!(tokens.get(*i), Some(Token::End)) {
                entries.push(parse(tokens, i)?);
            }
            *i += 1;
            Ok(Node::Seq(entries))
        }
        _ => Err("YAML document has no supported root".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        fs,
        sync::atomic::{AtomicUsize, Ordering},
    };
    static NEXT: AtomicUsize = AtomicUsize::new(0);
    fn fixture(bytes: &[u8]) -> std::path::PathBuf {
        let directory = loop {
            let candidate = std::env::temp_dir().join(format!(
                "emburk-yaml-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            match fs::create_dir(&candidate) {
                Ok(()) => break candidate,
                Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
                Err(error) => panic!("cannot create fixture directory: {error}"),
            }
        };
        let path = directory.join("config.yml");
        fs::write(&path, bytes).unwrap();
        path
    }
    fn cleanup(path: std::path::PathBuf) {
        fs::remove_file(&path).unwrap();
        fs::remove_dir(path.parent().unwrap()).unwrap();
    }
    #[test]
    fn normal_and_duplicate_mapping_compile() {
        let path = fixture(b"a: one\na: 'two'\n");
        let raw = load(&path).unwrap();
        assert_eq!(raw.bytes, b"a: one\na: 'two'\n");
        assert!(
            raw.events
                .iter()
                .any(|event| event.contains("SingleQuoted"))
        );
        let Node::Map(entries) = raw.compile_node().unwrap() else {
            panic!()
        };
        assert_eq!(entries.len(), 2);
        assert!(matches!(&entries[0], (key, Node::Scalar(value)) if key == "a" && value == "one"));
        assert!(matches!(&entries[1], (key, Node::Scalar(value)) if key == "a" && value == "two"));
        cleanup(path);
    }
    #[test]
    fn metadata_is_retained_before_rejection() {
        let path = fixture(b"seed: &a tagged\nuse: *a\ntag: !kind value\n");
        let raw = load(&path).unwrap();
        assert!(raw.events.iter().any(|event| event.contains("Alias(1)")));
        assert!(raw.bytes.windows(5).any(|window| window == b"!kind"));
        assert!(
            raw.events
                .iter()
                .any(|event| event.contains("Tag") && event.contains("kind"))
        );
        assert!(
            raw.events
                .iter()
                .any(|event| event.contains("\"tagged\", Plain, 1"))
        );
        assert!(raw.events.iter().all(|event| event.contains('@')));
        assert!(
            raw.events
                .iter()
                .any(|event| event.contains("@0:1:0-4:1:4"))
        );
        assert!(raw.compile_node().is_err());
        cleanup(path);
    }
    #[test]
    fn rejects_two_documents_and_byte_cap() {
        let path = fixture(b"---\na: one\n---\na: two\n");
        assert!(load(&path).is_err());
        cleanup(path);
        let path = fixture(&vec![b'x'; MAX_BYTES + 1]);
        assert!(load(&path).is_err());
        cleanup(path);
    }
    #[test]
    fn enforces_named_event_and_depth_limits() {
        let path = fixture("- x\n".repeat(MAX_EVENTS).as_bytes());
        assert!(load(&path).unwrap_err().contains("event limit 4096"));
        cleanup(path);
        let nested = format!(
            "{}x{}",
            "[".repeat(MAX_DEPTH + 1),
            "]".repeat(MAX_DEPTH + 1)
        );
        let path = fixture(nested.as_bytes());
        assert!(load(&path).unwrap_err().contains("depth limit 64"));
        cleanup(path);
        let path = fixture(&vec![b'x'; MAX_BYTES]);
        assert_eq!(load(&path).unwrap().bytes.len(), MAX_BYTES);
        cleanup(path);
    }
}
