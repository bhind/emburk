//! Private, bounded Unix formatted-spool checkpoints. Not an Embulk state format.
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Seek, SeekFrom, Write},
    os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt},
    path::{Path, PathBuf},
    sync::atomic::{AtomicU64, Ordering},
};
const MAX_MANIFEST: u64 = 64 * 1024;
const MAX_SPOOL: u64 = 8 * 1024 * 1024 * 1024;
const MAX_GENERATIONS: u64 = 65536;
static NEXT: AtomicU64 = AtomicU64::new(0);
type Result<T> = std::result::Result<T, String>;
fn error(e: impl std::fmt::Display) -> String {
    e.to_string()
}
pub(crate) fn hash(bytes: &[u8]) -> String {
    hex(Sha256::digest(bytes).as_slice())
}
fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
fn digest_file(file: &mut File, length: u64) -> Result<Sha256> {
    file.seek(SeekFrom::Start(0)).map_err(error)?;
    let mut remaining = length;
    let mut digest = Sha256::new();
    let mut bytes = [0; 65536];
    while remaining != 0 {
        let size = bytes.len().min(remaining as usize);
        let count = file.read(&mut bytes[..size]).map_err(error)?;
        if count == 0 {
            return Err("truncated checkpoint content".into());
        }
        digest.update(&bytes[..count]);
        remaining -= count as u64;
    }
    Ok(digest)
}
pub(crate) fn identity(path: &Path) -> Result<Value> {
    let metadata = fs::symlink_metadata(path).map_err(error)?;
    if !metadata.is_file() {
        return Err("identity requires a regular non-symlink file".into());
    }
    let mut file = File::open(path).map_err(error)?;
    let digest = digest_file(&mut file, metadata.len())?;
    if file.metadata().map_err(error)?.len() != metadata.len() {
        return Err("file changed while hashing".into());
    }
    Ok(
        json!({"dev":metadata.dev(),"ino":metadata.ino(),"len":metadata.len(),"sha256":hex(&digest.finalize())}),
    )
}
fn private(path: &Path, directory: bool) -> Result<()> {
    let m = fs::symlink_metadata(path).map_err(error)?;
    if (directory && !m.is_dir())
        || (!directory && !m.is_file())
        || m.mode() & 0o777 != if directory { 0o700 } else { 0o600 }
    {
        return Err(format!(
            "unsafe state type or permissions: {}",
            path.display()
        ));
    }
    Ok(())
}
fn fields(value: &Value, keys: &[&str]) -> Result<()> {
    let object = value.as_object().ok_or("checkpoint object required")?;
    if object.len() != keys.len() || keys.iter().any(|key| !object.contains_key(*key)) {
        return Err("checkpoint fields differ".into());
    }
    Ok(())
}
fn number(value: &Value, key: &str) -> Result<u64> {
    value[key]
        .as_u64()
        .ok_or_else(|| format!("invalid checkpoint {key}"))
}
fn validate_identity(value: &Value) -> Result<()> {
    fields(value, &["dev", "ino", "len", "sha256"])?;
    for key in ["dev", "ino", "len"] {
        number(value, key)?;
    }
    let digest = value["sha256"].as_str().ok_or("invalid content hash")?;
    if digest.len() != 64
        || !digest
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err("invalid content hash".into());
    }
    Ok(())
}
pub(crate) struct State {
    root: PathBuf,
    _lock: File,
    pub(crate) spool: File,
    pub(crate) latest: Value,
    digest: Sha256,
    length: u64,
    records: u64,
    saved_length: u64,
    saved_records: u64,
    previous: Value,
    next: u64,
}
impl State {
    pub(crate) fn open(root: &Path, context: Value, resume: bool) -> Result<Self> {
        if !resume {
            fs::DirBuilder::new()
                .mode(0o700)
                .create(root)
                .map_err(error)?;
            OpenOptions::new()
                .read(true)
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(root.join("lock"))
                .map_err(error)?;
            OpenOptions::new()
                .read(true)
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(root.join("spool"))
                .map_err(error)?;
            File::open(root).and_then(|f| f.sync_all()).map_err(error)?;
        }
        private(root, true)?;
        private(&root.join("lock"), false)?;
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .open(root.join("lock"))
            .map_err(error)?;
        lock.try_lock()
            .map_err(|e| format!("state lock unavailable: {e}"))?;
        private(&root.join("spool"), false)?;
        let spool = OpenOptions::new()
            .read(true)
            .write(true)
            .open(root.join("spool"))
            .map_err(error)?;
        let metadata = spool.metadata().map_err(error)?;
        if metadata.nlink() != 1 || metadata.len() > MAX_SPOOL {
            return Err("unsafe spool identity or size".into());
        }
        let run = format!(
            "{}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_err(error)?
                .as_nanos(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        );
        let mut state = Self {
            root: root.to_owned(),
            _lock: lock,
            spool,
            latest: json!({"version":1,"sequence":0,"previous":null,"run_id":run,"context":context,"phase":"Writing","spool":{"dev":metadata.dev(),"ino":metadata.ino(),"len":0,"sha256":hash(b"")},"records":0,"prepared":null}),
            digest: Sha256::new(),
            length: 0,
            records: 0,
            saved_length: 0,
            saved_records: 0,
            previous: Value::Null,
            next: 0,
        };
        if resume {
            state.load()?;
        }
        Ok(state)
    }
    fn load(&mut self) -> Result<()> {
        let context = self.latest["context"].clone();
        let mut generations = Vec::new();
        let mut entries = 0;
        for entry in fs::read_dir(&self.root).map_err(error)? {
            entries += 1;
            if entries > MAX_GENERATIONS * 2 + 2 {
                return Err("state entry limit exceeded".into());
            }
            let entry = entry.map_err(error)?;
            let name = entry
                .file_name()
                .into_string()
                .map_err(|_| "invalid state filename")?;
            if name == "spool" || name == "lock" {
                continue;
            }
            private(&entry.path(), false)?;
            if let Some(digits) = name.strip_suffix(".json") {
                if digits.len() != 20 || !digits.bytes().all(|b| b.is_ascii_digit()) {
                    return Err("invalid generation filename".into());
                }
                generations.push((digits.parse::<u64>().map_err(error)?, entry.path()));
            } else if let Some(digits) = name
                .strip_prefix(".checkpoint-")
                .and_then(|s| s.strip_suffix(".tmp"))
            {
                if digits.is_empty() || !digits.bytes().all(|b| b.is_ascii_digit() || b == b'-') {
                    return Err("unknown checkpoint residue".into());
                }
            } else {
                return Err("unknown state entry".into());
            }
        }
        generations.sort_by_key(|item| item.0);
        if generations.is_empty() || generations.len() as u64 > MAX_GENERATIONS {
            return Err("missing or excessive generations".into());
        }
        let mut run = None;
        let mut prior_length = 0;
        let mut prior_records = 0;
        let mut prior_phase = "Writing".to_owned();
        for (expected, (sequence, path)) in generations.into_iter().enumerate() {
            if sequence != expected as u64 {
                return Err("checkpoint chain gap".into());
            }
            let mut bytes = Vec::new();
            File::open(path)
                .map_err(error)?
                .take(MAX_MANIFEST + 1)
                .read_to_end(&mut bytes)
                .map_err(error)?;
            if bytes.len() as u64 > MAX_MANIFEST {
                return Err("manifest too large".into());
            }
            let value: Value = serde_json::from_slice(&bytes).map_err(error)?;
            if serde_json::to_vec(&value).map_err(error)? != bytes {
                return Err("noncanonical or duplicate checkpoint fields".into());
            }
            fields(
                &value,
                &[
                    "version", "sequence", "previous", "run_id", "context", "phase", "spool",
                    "records", "prepared",
                ],
            )?;
            validate_identity(&value["spool"])?;
            if !value["prepared"].is_null() {
                validate_identity(&value["prepared"])?;
            }
            let phase = value["phase"].as_str().ok_or("invalid phase")?;
            if phase == "Published"
                && (!matches!(prior_phase.as_str(), "Publishing" | "Published")
                    || value["prepared"] != self.latest["prepared"])
            {
                return Err("published identity differs from prepared generation".into());
            }
            if !matches!(phase, "Writing" | "Ready" | "Publishing" | "Published")
                || (prior_phase != "Writing" && phase == "Writing")
                || (prior_phase == "Published" && phase != "Published")
            {
                return Err("invalid checkpoint phase transition".into());
            }
            let length = number(&value["spool"], "len")?;
            let records = number(&value, "records")?;
            if value["version"] != 1
                || number(&value, "sequence")? != sequence
                || value["previous"] != self.previous
                || value["context"] != context
                || length > MAX_SPOOL
                || length < prior_length
                || records < prior_records
                || records > MAX_SPOOL
                || value["spool"]["dev"] != self.latest["spool"]["dev"]
                || value["spool"]["ino"] != self.latest["spool"]["ino"]
            {
                return Err("checkpoint identity or chain mismatch".into());
            }
            if prior_phase != "Writing" && (length != prior_length || records != prior_records) {
                return Err("completed spool changed".into());
            }
            if matches!(phase, "Publishing" | "Published") == value["prepared"].is_null() {
                return Err("prepared identity/phase mismatch".into());
            }
            let id = value["run_id"].as_str().ok_or("invalid run id")?;
            if id.is_empty() || id.len() > 128 || run.as_ref().is_some_and(|r| r != id) {
                return Err("run identity mismatch".into());
            }
            run = Some(id.to_owned());
            prior_length = length;
            prior_records = records;
            prior_phase = phase.to_owned();
            self.previous = Value::String(hash(&bytes));
            self.next = sequence + 1;
            self.latest = value;
        }
        self.length = prior_length;
        self.records = prior_records;
        self.saved_length = prior_length;
        self.saved_records = prior_records;
        self.digest = digest_file(&mut self.spool, self.length)?;
        if self.latest["spool"]["sha256"] != hex(&self.digest.clone().finalize()) {
            return Err("spool content mismatch".into());
        }
        self.spool.seek(SeekFrom::Start(0)).map_err(error)?;
        Ok(())
    }
    pub(crate) fn records(&self) -> u64 {
        self.records
    }
    pub(crate) fn phase(&self) -> &str {
        self.latest["phase"].as_str().unwrap_or("")
    }
    pub(crate) fn compare(&mut self, bytes: &[u8]) -> Result<()> {
        let position = self.spool.stream_position().map_err(error)?;
        if position + bytes.len() as u64 > self.length {
            return Err("replayed prefix exceeds checkpoint".into());
        }
        let mut actual = vec![0; bytes.len()];
        self.spool.read_exact(&mut actual).map_err(error)?;
        if actual != bytes {
            return Err("replayed prefix differs from spool".into());
        }
        Ok(())
    }
    pub(crate) fn finish_validation(&mut self) -> Result<()> {
        if self.spool.stream_position().map_err(error)? != self.length {
            return Err("checkpoint record count differs from prefix".into());
        }
        self.spool.set_len(self.length).map_err(error)?;
        self.spool
            .seek(SeekFrom::Start(self.length))
            .map_err(error)?;
        Ok(())
    }
    pub(crate) fn append(&mut self, bytes: &[u8], record: bool) -> Result<()> {
        if bytes.len() > 3 * 1024 * 1024 || self.length + bytes.len() as u64 > MAX_SPOOL {
            return Err("spool bounds exceeded".into());
        }
        self.spool.write_all(bytes).map_err(error)?;
        self.digest.update(bytes);
        self.length += bytes.len() as u64;
        self.records += u64::from(record);
        if self.records - self.saved_records >= 1024
            || self.length - self.saved_length >= 4 * 1024 * 1024
        {
            self.save("Writing", Value::Null)?;
        }
        Ok(())
    }
    pub(crate) fn save(&mut self, phase: &str, prepared: Value) -> Result<()> {
        self.save_with(phase, prepared, |_| Ok(()))
    }
    // Original fault seam for unit tests; production always supplies a no-op.
    fn save_with(
        &mut self,
        phase: &str,
        prepared: Value,
        mut before: impl FnMut(&str) -> Result<()>,
    ) -> Result<()> {
        if self.next >= MAX_GENERATIONS {
            return Err("checkpoint generation limit exceeded".into());
        }
        before("spool-sync")?;
        self.spool.sync_all().map_err(error)?;
        let mut value = self.latest.clone();
        value["sequence"] = json!(self.next);
        value["previous"] = self.previous.clone();
        value["phase"] = json!(phase);
        value["prepared"] = prepared;
        value["spool"]["len"] = json!(self.length);
        value["spool"]["sha256"] = json!(hex(&self.digest.clone().finalize()));
        value["records"] = json!(self.records);
        let bytes = serde_json::to_vec(&value).map_err(error)?;
        if bytes.len() as u64 > MAX_MANIFEST {
            return Err("manifest too large".into());
        }
        let nonce = NEXT.fetch_add(1, Ordering::Relaxed);
        let temp = self.root.join(format!(
            ".checkpoint-{}-{}-{nonce}.tmp",
            self.next,
            std::process::id()
        ));
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&temp)
            .map_err(error)?;
        before("manifest-write")?;
        file.write_all(&bytes)
            .and_then(|()| file.sync_all())
            .map_err(error)?;
        before("manifest-link")?;
        fs::hard_link(&temp, self.root.join(format!("{:020}.json", self.next))).map_err(error)?;
        before("directory-sync")?;
        File::open(&self.root)
            .and_then(|f| f.sync_all())
            .map_err(error)?;
        before("temporary-remove")?;
        fs::remove_file(temp).map_err(error)?;
        File::open(&self.root)
            .and_then(|f| f.sync_all())
            .map_err(error)?;
        self.previous = json!(hash(&bytes));
        self.next += 1;
        self.saved_length = self.length;
        self.saved_records = self.records;
        self.latest = value;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn root() -> PathBuf {
        let p = std::env::temp_dir().join(format!(
            "emburk-checkpoint-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&p).unwrap();
        p.join("state")
    }
    fn staged() -> (PathBuf, State) {
        let p = root();
        let mut s = State::open(&p, json!({"test":1}), false).unwrap();
        s.append(b"header\n", false).unwrap();
        s.save("Writing", Value::Null).unwrap();
        (p, s)
    }
    #[test]
    fn chain_rejects_changed_published_identity() {
        let (p, mut s) = staged();
        s.save("Ready", Value::Null).unwrap();
        let a = json!({"dev":1,"ino":2,"len":3,"sha256":hash(b"one")});
        let b = json!({"dev":1,"ino":9,"len":3,"sha256":hash(b"two")});
        s.save("Publishing", a).unwrap();
        s.save("Published", b).unwrap();
        drop(s);
        assert!(
            State::open(&p, json!({"test":1}), true)
                .err()
                .unwrap()
                .contains("published identity")
        );
    }
    #[test]
    fn interrupted_generation_operations_recover_only_complete_visible_generations() {
        for phase in [
            "spool-sync",
            "manifest-write",
            "manifest-link",
            "directory-sync",
            "temporary-remove",
        ] {
            let (p, mut s) = staged();
            s.append(b"row\n", true).unwrap();
            assert!(
                s.save_with("Writing", Value::Null, |at| if at == phase {
                    Err("injected".into())
                } else {
                    Ok(())
                })
                .is_err()
            );
            drop(s);
            let mut s = State::open(&p, json!({"test":1}), true).unwrap();
            s.compare(b"header\n").unwrap();
            let visible = matches!(phase, "directory-sync" | "temporary-remove");
            assert_eq!(s.records(), u64::from(visible));
            if visible {
                s.compare(b"row\n").unwrap();
            }
            s.finish_validation().unwrap();
        }
    }
    #[test]
    fn uncheckpointed_tail_is_untouched_until_exact_prefix_validates() {
        let (p, mut s) = staged();
        s.spool.write_all(b"tail").unwrap();
        drop(s);
        let mut s = State::open(&p, json!({"test":1}), true).unwrap();
        assert!(s.compare(b"wrong\n").is_err());
        assert_eq!(fs::read(p.join("spool")).unwrap(), b"header\ntail");
        drop(s);
        let mut s = State::open(&p, json!({"test":1}), true).unwrap();
        s.compare(b"header\n").unwrap();
        s.finish_validation().unwrap();
        assert_eq!(fs::read(p.join("spool")).unwrap(), b"header\n");
    }
    #[test]
    fn bounds_are_checked_before_writing_and_previous_generation_survives() {
        let (p, mut s) = staged();
        let original = fs::read(p.join("spool")).unwrap();
        s.length = MAX_SPOOL;
        assert!(s.append(b"x", true).is_err());
        assert_eq!(fs::read(p.join("spool")).unwrap(), original);
        s.length = original.len() as u64;
        s.next = MAX_GENERATIONS;
        assert!(s.save("Writing", Value::Null).is_err());
        drop(s);
        assert!(State::open(&p, json!({"test":1}), true).is_ok());
    }
    #[test]
    fn generation_collision_does_not_overwrite_and_incomplete_temp_is_not_adopted() {
        let (p, mut s) = staged();
        let residue = p.join(".checkpoint-99-999-1.tmp");
        OpenOptions::new()
            .write(true)
            .create_new(true)
            .mode(0o600)
            .open(&residue)
            .unwrap()
            .write_all(b"torn")
            .unwrap();
        s.next = 0;
        assert!(s.save("Writing", Value::Null).is_err());
        drop(s);
        let s = State::open(&p, json!({"test":1}), true).unwrap();
        assert_eq!(s.records(), 0);
        assert_eq!(fs::read(residue).unwrap(), b"torn");
    }
    #[test]
    fn duplicate_manifest_fields_and_unsafe_links_are_rejected() {
        let (p, s) = staged();
        drop(s);
        let path = p.join("00000000000000000000.json");
        let bytes = fs::read(&path).unwrap();
        let mut duplicate = b"{\"version\":1,".to_vec();
        duplicate.extend_from_slice(&bytes[1..]);
        fs::write(&path, duplicate).unwrap();
        assert!(State::open(&p, json!({"test":1}), true).is_err());
        fs::write(&path, bytes).unwrap();
        let saved = p.join("saved");
        fs::rename(p.join("spool"), &saved).unwrap();
        std::os::unix::fs::symlink(&saved, p.join("spool")).unwrap();
        assert!(State::open(&p, json!({"test":1}), true).is_err());
    }
}
