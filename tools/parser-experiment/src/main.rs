#![forbid(unsafe_code)]

use saphyr_parser::{Event, Parser, Span};
use std::{env, fs::File, io::Read, path::Path};

const MAX_INPUT_BYTES: usize = 64 * 1024;
const MAX_EVENTS: usize = 4 * 1024;
const MAX_DEPTH: usize = 64;

fn main() {
    let arguments: Vec<_> = env::args_os().collect();
    let [_, input] = arguments.as_slice() else {
        eprintln!("usage: emburk-parser-experiment INPUT");
        std::process::exit(2);
    };
    let source = match read_source(Path::new(input)) {
        Ok(source) => source,
        Err(error) => {
            eprintln!("input-error {error}");
            std::process::exit(1);
        }
    };
    let observation = observe(&source);
    for event in observation.events {
        println!("{event}");
    }
    if let Some(error) = observation.error {
        eprintln!("parse-error {error}");
        std::process::exit(1);
    }
}

fn read_source(path: &Path) -> Result<String, String> {
    let file = File::open(path).map_err(|error| format!("open: {error}"))?;
    read_bounded(file)
}

fn read_bounded(input: impl Read) -> Result<String, String> {
    let mut bytes = Vec::with_capacity(8192);
    input
        .take((MAX_INPUT_BYTES + 1) as u64)
        .read_to_end(&mut bytes)
        .map_err(|error| format!("read: {error}"))?;
    if bytes.len() > MAX_INPUT_BYTES {
        return Err(format!("input exceeds {MAX_INPUT_BYTES} bytes"));
    }
    String::from_utf8(bytes).map_err(|error| format!("raw-invalid-utf8: {error}"))
}

struct Observation {
    events: Vec<String>,
    error: Option<String>,
}

fn observe(source: &str) -> Observation {
    let mut parser = Parser::new_from_str(source);
    let mut events = Vec::new();
    let mut depth = 0usize;
    while let Some(result) = parser.next_event() {
        let (event, span) = match result {
            Ok(event) => event,
            Err(error) => {
                return Observation {
                    events,
                    error: Some(error.to_string()),
                };
            }
        };
        if events.len() == MAX_EVENTS {
            return Observation {
                events,
                error: Some(format!("event limit {MAX_EVENTS} exceeded")),
            };
        }
        match event {
            Event::SequenceStart(..) | Event::MappingStart(..) => {
                depth += 1;
                if depth > MAX_DEPTH {
                    return Observation {
                        events,
                        error: Some(format!("depth limit {MAX_DEPTH} exceeded")),
                    };
                }
            }
            Event::SequenceEnd | Event::MappingEnd => depth = depth.saturating_sub(1),
            _ => {}
        }
        events.push(render_event(events.len(), event, span));
    }
    Observation {
        events,
        error: None,
    }
}

fn render_event(index: usize, event: Event<'_>, span: Span) -> String {
    let location = format!(
        "span={}:{}:{}-{}:{}:{}",
        span.start.index(),
        span.start.line(),
        span.start.col(),
        span.end.index(),
        span.end.line(),
        span.end.col()
    );
    match event {
        Event::Scalar(text, style, anchor, tag) => format!(
            "event={index} scalar text={text:?} style={style:?} anchor={anchor} tag={:?} {location}",
            tag.map(|tag| tag.to_string())
        ),
        Event::Alias(anchor) => format!("event={index} alias anchor={anchor} {location}"),
        Event::SequenceStart(anchor, tag) => format!(
            "event={index} sequence-start anchor={anchor} tag={:?} {location}",
            tag.map(|tag| tag.to_string())
        ),
        Event::MappingStart(anchor, tag) => format!(
            "event={index} mapping-start anchor={anchor} tag={:?} {location}",
            tag.map(|tag| tag.to_string())
        ),
        Event::SequenceEnd => format!("event={index} sequence-end {location}"),
        Event::MappingEnd => format!("event={index} mapping-end {location}"),
        Event::StreamStart => format!("event={index} stream-start {location}"),
        Event::StreamEnd => format!("event={index} stream-end {location}"),
        Event::DocumentStart(explicit) => {
            format!("event={index} document-start explicit={explicit} {location}")
        }
        Event::DocumentEnd => format!("event={index} document-end {location}"),
        Event::Nothing => format!("event={index} nothing {location}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn observes_duplicate_style_tag_anchor_alias_and_spans() {
        let observation = observe(
            "first: plain\nfirst: 'single'\nquoted: \"double\"\ntagged: !kind value\ncore: !!str tagged\nseed: &a value\nuse: *a\n",
        );
        assert!(observation.error.is_none());
        let first = observation
            .events
            .iter()
            .filter(|event| event.contains("text=\"first\""))
            .collect::<Vec<_>>();
        assert_eq!(first.len(), 2);
        assert!(first[0].contains("style=Plain"));
        assert!(first[1].contains("style=Plain"));
        let plain = observation
            .events
            .iter()
            .position(|event| event.contains("text=\"plain\" style=Plain"))
            .unwrap();
        let single = observation
            .events
            .iter()
            .position(|event| event.contains("text=\"single\" style=SingleQuoted"))
            .unwrap();
        let first_positions = observation
            .events
            .iter()
            .enumerate()
            .filter_map(|(index, event)| event.contains("text=\"first\"").then_some(index))
            .collect::<Vec<_>>();
        assert!(
            first_positions[0] < plain && plain < first_positions[1] && first_positions[1] < single
        );
        assert!(
            observation
                .events
                .iter()
                .any(|event| event.contains("style=DoubleQuoted"))
        );
        assert!(
            observation
                .events
                .iter()
                .any(|event| event.contains("tag=Some(\"!kind\")"))
        );
        assert!(
            observation
                .events
                .iter()
                .any(|event| event.contains("tag=Some(\"tag:yaml.org,2002:!str\")"))
        );
        assert!(
            observation
                .events
                .iter()
                .any(|event| event.contains("text=\"value\" style=Plain anchor=1"))
        );
        assert!(
            observation
                .events
                .iter()
                .any(|event| event.contains("alias anchor=1"))
        );
        assert!(first[0].contains("span=0:1:0-5:1:5"));
    }

    #[test]
    fn retains_partial_events_and_error_for_malformed_and_multiple_documents() {
        let malformed = observe("ok: value\nbroken: [\n");
        assert!(!malformed.events.is_empty());
        assert!(malformed.error.is_some());
        let documents = observe("---\na: one\n...\n---\na: two\n");
        assert!(documents.error.is_none());
        assert_eq!(
            documents
                .events
                .iter()
                .filter(|event| event.contains("document-start"))
                .count(),
            2
        );
    }

    #[test]
    fn bounded_reader_distinguishes_raw_invalid_bytes_and_exact_limits() {
        let replacement = read_bounded(std::io::Cursor::new("x: \u{fffd}\n")).unwrap();
        assert!(observe(&replacement).error.is_none());
        assert!(
            read_bounded(std::io::Cursor::new(vec![b'x', b':', b' ', 0xff]))
                .unwrap_err()
                .contains("raw-invalid-utf8")
        );
        assert_eq!(
            read_bounded(std::io::Cursor::new(vec![b'x'; MAX_INPUT_BYTES]))
                .unwrap()
                .len(),
            MAX_INPUT_BYTES
        );
        assert!(read_bounded(std::io::Cursor::new(vec![b'x'; MAX_INPUT_BYTES + 1])).is_err());
    }

    #[test]
    fn file_path_uses_the_common_bounded_reader() {
        use std::{
            fs::{self, OpenOptions},
            io::Write,
            sync::atomic::{AtomicUsize, Ordering},
        };
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let path = std::env::temp_dir().join(format!(
            "emburk-parser-reader-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
            .unwrap();
        file.write_all("x: \u{fffd}\n".as_bytes()).unwrap();
        drop(file);
        assert!(observe(&read_source(&path).unwrap()).error.is_none());
        fs::remove_file(path).unwrap();
    }

    #[test]
    fn s13_authored_shapes_have_expected_order_style_and_error_classification() {
        let prefix = "in:\n  type:\n    source: maven\n    group: org.embulk.t0012\n    name: t0012_syntax\n    version: 0.0.1\n";
        let suffix = "out:\n  type: \"null\"\n";
        let control = observe(&format!("{prefix}  field: syntax-value\n{suffix}"));
        assert!(control.error.is_none());
        assert!(
            control
                .events
                .iter()
                .any(|event| event.contains("text=\"syntax-value\" style=Plain"))
        );
        let quoted = observe(&format!("{prefix}  field: \"syntax-value\"\n{suffix}"));
        assert!(quoted.error.is_none());
        assert!(
            quoted
                .events
                .iter()
                .any(|event| event.contains("text=\"syntax-value\" style=DoubleQuoted"))
        );
        let duplicate = observe(&format!(
            "{prefix}  field: first-value\n  field: second-value\n{suffix}"
        ));
        let values = duplicate
            .events
            .iter()
            .filter(|event| event.contains("text=\"") && event.contains("-value\""))
            .collect::<Vec<_>>();
        assert!(
            values
                .iter()
                .position(|event| event.contains("first-value"))
                .unwrap()
                < values
                    .iter()
                    .position(|event| event.contains("second-value"))
                    .unwrap()
        );
        assert!(
            observe(&format!("{prefix}  field: [unterminated\n{suffix}"))
                .error
                .is_some()
        );
        let alias = observe(&format!(
            "seed: &v syntax-value\n{prefix}  field: *v\n{suffix}"
        ));
        assert!(
            alias
                .events
                .iter()
                .any(|event| event.contains("text=\"syntax-value\" style=Plain anchor=1"))
        );
        assert!(
            alias
                .events
                .iter()
                .any(|event| event.contains("alias anchor=1"))
        );
        assert!(
            read_bounded(std::io::Cursor::new(
                format!("{prefix}  field: bad-")
                    .into_bytes()
                    .into_iter()
                    .chain([0xff])
                    .chain(b"-value\n".iter().copied())
                    .chain(suffix.bytes())
                    .collect::<Vec<_>>()
            ))
            .is_err()
        );
    }

    #[test]
    fn valid_nested_flow_and_many_events_hit_the_named_bounds() {
        let nested = format!(
            "{}x{}",
            "[".repeat(MAX_DEPTH + 1),
            "]".repeat(MAX_DEPTH + 1)
        );
        assert_eq!(
            observe(&nested).error.as_deref(),
            Some("depth limit 64 exceeded")
        );
        assert_eq!(
            observe(&"- x\n".repeat(MAX_EVENTS)).error.as_deref(),
            Some("event limit 4096 exceeded")
        );
    }
}
