//! Original bounded RFC-4180-style CSV reader and minimal formatter.
use std::io::{self, BufRead, Write};
pub(super) const MAX_RECORD: usize = 1024 * 1024;
pub(super) const MAX_COLUMNS: usize = 256;
#[derive(Clone, Copy)]
enum State {
    Start,
    Plain,
    Quoted,
    AfterQuote,
}

pub(super) fn read_record<R: BufRead>(input: &mut R) -> io::Result<Option<Vec<(String, bool)>>> {
    let mut fields = Vec::new();
    let mut field = Vec::new();
    let mut state = State::Start;
    let mut quoted = false;
    let mut count = 0usize;
    let mut saw = false;
    loop {
        let mut byte = [0];
        if input.read(&mut byte)? == 0 {
            if !saw {
                return Ok(None);
            }
            if matches!(state, State::Quoted) {
                return Err(io::Error::other("unterminated CSV quote"));
            }
            return finish(fields, field, quoted);
        }
        saw = true;
        count += 1;
        if count > MAX_RECORD {
            return Err(io::Error::other("CSV record exceeds 1048576 bytes"));
        }
        match state {
            State::Start => match byte[0] {
                b'"' => {
                    state = State::Quoted;
                    quoted = true
                }
                b',' => push_field(&mut fields, std::mem::take(&mut field), false)?,
                b'\n' => return finish(fields, field, false),
                value => {
                    state = State::Plain;
                    push(&mut field, value)?
                }
            },
            State::Plain => match byte[0] {
                b'"' => return Err(io::Error::other("CSV quote in unquoted field")),
                b',' => {
                    push_field(&mut fields, std::mem::take(&mut field), false)?;
                    state = State::Start
                }
                b'\n' => {
                    if field.last() == Some(&b'\r') {
                        field.pop();
                    }
                    return finish(fields, field, false);
                }
                value => push(&mut field, value)?,
            },
            State::Quoted => match byte[0] {
                b'"' => state = State::AfterQuote,
                value => push(&mut field, value)?,
            },
            State::AfterQuote => match byte[0] {
                b'"' => {
                    push(&mut field, b'"')?;
                    state = State::Quoted
                }
                b',' => {
                    push_field(&mut fields, std::mem::take(&mut field), true)?;
                    quoted = false;
                    state = State::Start
                }
                b'\n' => return finish(fields, field, true),
                _ => return Err(io::Error::other("CSV character after closing quote")),
            },
        }
    }
}
fn push(field: &mut Vec<u8>, byte: u8) -> io::Result<()> {
    if field.len() == MAX_RECORD {
        Err(io::Error::other("CSV record exceeds 1048576 bytes"))
    } else {
        field.push(byte);
        Ok(())
    }
}
fn push_field(fields: &mut Vec<(String, bool)>, field: Vec<u8>, quoted: bool) -> io::Result<()> {
    if fields.len() == MAX_COLUMNS {
        return Err(io::Error::other("CSV row has more than 256 columns"));
    }
    fields.push((
        String::from_utf8(field).map_err(|_| io::Error::other("CSV is not valid UTF-8"))?,
        quoted,
    ));
    Ok(())
}
fn finish(
    mut fields: Vec<(String, bool)>,
    field: Vec<u8>,
    quoted: bool,
) -> io::Result<Option<Vec<(String, bool)>>> {
    push_field(&mut fields, field, quoted)?;
    Ok(Some(fields))
}

pub(super) fn write_row<W: Write>(out: &mut W, row: &[Option<String>]) -> io::Result<()> {
    for (n, value) in row.iter().enumerate() {
        if n > 0 {
            out.write_all(b",")?
        };
        if let Some(value) = value {
            let quote = value.is_empty() || value.contains([',', '"', '\n', '\r']);
            if quote {
                out.write_all(b"\"")?
            };
            for byte in value.bytes() {
                if byte == b'"' {
                    out.write_all(b"\"\"")?
                } else {
                    out.write_all(&[byte])?
                }
            }
            if quote {
                out.write_all(b"\"")?
            };
        }
    }
    out.write_all(b"\n")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn guards_exact_record_and_column_boundaries() {
        assert!(read_record(&mut Cursor::new(vec![b'x'; MAX_RECORD])).is_ok());
        let quoted = [vec![b'"'], vec![b'x'; MAX_RECORD - 2], vec![b'"']].concat();
        assert!(read_record(&mut Cursor::new(quoted)).is_ok());
        assert!(read_record(&mut Cursor::new(vec![b'x'; MAX_RECORD + 1])).is_err());
        assert!(read_record(&mut Cursor::new(vec![b','; MAX_COLUMNS - 1])).is_ok());
        assert!(read_record(&mut Cursor::new(vec![b','; MAX_COLUMNS])).is_err());
    }

    #[test]
    fn rejects_invalid_quote_transitions() {
        for bytes in [b"a\"b".as_slice(), b"\"a\"x", b"\"unterminated"] {
            assert!(read_record(&mut Cursor::new(bytes)).is_err());
        }
    }
}
