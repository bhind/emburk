//! Bounded JSON-object framing and streaming selected codecs.
use std::{
    fs::File,
    io::{self, BufRead, BufReader, BufWriter, Write},
};

#[derive(Clone, Copy)]
pub(crate) enum Codec {
    Plain,
    Gzip,
    Bzip2,
}
pub(crate) fn reader(file: File, codec: Codec) -> Box<dyn BufRead> {
    match codec {
        Codec::Plain => Box::new(BufReader::new(file)),
        Codec::Gzip => Box::new(BufReader::new(flate2::read::MultiGzDecoder::new(file))),
        Codec::Bzip2 => Box::new(BufReader::new(bzip2::read::MultiBzDecoder::new(file))),
    }
}
pub(crate) enum Encoder<'a> {
    Plain(&'a mut BufWriter<File>),
    Gzip(flate2::write::GzEncoder<&'a mut BufWriter<File>>),
    Bzip2(bzip2::write::BzEncoder<&'a mut BufWriter<File>>),
}
impl<'a> Encoder<'a> {
    pub(crate) fn new(output: &'a mut BufWriter<File>, codec: Codec) -> Self {
        match codec {
            Codec::Plain => Self::Plain(output),
            Codec::Gzip => Self::Gzip(flate2::write::GzEncoder::new(
                output,
                flate2::Compression::new(6),
            )),
            Codec::Bzip2 => Self::Bzip2(bzip2::write::BzEncoder::new(
                output,
                bzip2::Compression::new(9),
            )),
        }
    }
    pub(crate) fn finish(self) -> io::Result<()> {
        match self {
            Self::Plain(out) => out.flush(),
            Self::Gzip(out) => {
                out.finish()?;
                Ok(())
            }
            Self::Bzip2(out) => {
                out.finish()?;
                Ok(())
            }
        }
    }
}
impl Write for Encoder<'_> {
    fn write(&mut self, b: &[u8]) -> io::Result<usize> {
        match self {
            Self::Plain(w) => w.write(b),
            Self::Gzip(w) => w.write(b),
            Self::Bzip2(w) => w.write(b),
        }
    }
    fn flush(&mut self) -> io::Result<()> {
        match self {
            Self::Plain(w) => w.flush(),
            Self::Gzip(w) => w.flush(),
            Self::Bzip2(w) => w.flush(),
        }
    }
}
const MAX: usize = 1024 * 1024;
const DEPTH: usize = 64;
pub(crate) fn read_json(input: &mut impl BufRead) -> io::Result<Option<serde_json::Value>> {
    let mut data = Vec::new();
    let mut started = false;
    let mut depth = 0usize;
    let mut quote = false;
    let mut escaped = false;
    loop {
        let mut b = [0];
        let n = input.read(&mut b)?;
        if n == 0 {
            if !started {
                return Ok(None);
            };
            return Err(io::Error::other("truncated JSON object"));
        }
        let c = b[0];
        if !started {
            if matches!(c, b' ' | b'\t' | b'\r' | b'\n') {
                continue;
            }
            if c != b'{' {
                return Err(io::Error::other("JSON value must be object"));
            }
            started = true;
            depth = 1;
            data.push(c);
            continue;
        }
        if data.len() == MAX {
            return Err(io::Error::other("JSON object exceeds 1048576 bytes"));
        }
        data.push(c);
        if quote {
            if escaped {
                escaped = false
            } else if c == b'\\' {
                escaped = true
            } else if c == b'"' {
                quote = false
            };
            continue;
        }
        match c {
            b'"' => quote = true,
            b'{' | b'[' => {
                depth += 1;
                if depth > DEPTH {
                    return Err(io::Error::other("JSON depth exceeds 64"));
                }
            }
            b'}' | b']' => {
                depth -= 1;
                if depth == 0 {
                    break;
                }
            }
            _ => {}
        }
    }
    serde_json::from_slice::<serde_json::Value>(&data)
        .map_err(|e| io::Error::other(format!("invalid JSON object: {e}")))
        .and_then(|v| {
            if v.is_object() {
                Ok(Some(v))
            } else {
                Err(io::Error::other("JSON value must be object"))
            }
        })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        fs,
        io::{Cursor, Read},
        sync::atomic::{AtomicUsize, Ordering},
    };
    static NEXT: AtomicUsize = AtomicUsize::new(0);
    #[test]
    fn reads_object_sequence_with_multiline_quotes_and_unicode() {
        let mut input =
            Cursor::new(" \n{\n\"text\":\"brace } [ and \\\" quote ☃\",\"id\":1}\n{\"id\":2}");
        let first = read_json(&mut input).unwrap().unwrap();
        assert_eq!(first["text"], "brace } [ and \" quote ☃");
        assert_eq!(read_json(&mut input).unwrap().unwrap()["id"], 2);
        assert!(read_json(&mut input).unwrap().is_none());
    }
    #[test]
    fn rejects_malformed_nonobjects_and_invalid_utf8() {
        for bytes in [
            b"[]".as_slice(),
            b"{",
            b"{]",
            b"{\"x\":\"\xff\"}",
            b"{\"x\":\"\\q\"}",
            b"\x0b{}",
        ] {
            assert!(read_json(&mut Cursor::new(bytes)).is_err());
        }
    }
    #[test]
    fn exact_json_byte_limit_is_enforced_before_growth() {
        for extra in [0, 1] {
            let input = format!("{{\"x\":\"{}\"}}", "a".repeat(MAX - 8 + extra));
            assert_eq!(input.len(), MAX + extra);
            assert_eq!(read_json(&mut Cursor::new(input)).is_ok(), extra == 0);
        }
    }
    #[test]
    fn arrays_and_objects_both_count_toward_depth() {
        for extra in [0, 1] {
            let input = format!(
                "{{\"x\":{}0{}}}",
                "[".repeat(DEPTH - 1 + extra),
                "]".repeat(DEPTH - 1 + extra)
            );
            assert_eq!(read_json(&mut Cursor::new(input)).is_ok(), extra == 0);
        }
    }
    #[test]
    fn codecs_round_trip_and_reject_truncation() {
        for codec in [Codec::Gzip, Codec::Bzip2] {
            let root = std::env::temp_dir().join(format!(
                "emburk-codec-test-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir(&root).unwrap();
            let path = root.join("stream");
            let mut output = BufWriter::new(File::create_new(&path).unwrap());
            let mut encoder = Encoder::new(&mut output, codec);
            encoder.write_all(b"id,name\n1,Ada\n").unwrap();
            encoder.finish().unwrap();
            output.flush().unwrap();
            drop(output);
            let mut decoded = Vec::new();
            reader(File::open(&path).unwrap(), codec)
                .read_to_end(&mut decoded)
                .unwrap();
            assert_eq!(decoded, b"id,name\n1,Ada\n");
            let size = fs::metadata(&path).unwrap().len();
            fs::OpenOptions::new()
                .write(true)
                .open(&path)
                .unwrap()
                .set_len(size - 3)
                .unwrap();
            assert!(
                reader(File::open(&path).unwrap(), codec)
                    .read_to_end(&mut Vec::new())
                    .is_err()
            );
        }
    }
}
