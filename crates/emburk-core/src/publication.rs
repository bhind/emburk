//! Private Unix single-output publication. Visibility and cleanup are separate.
use std::{
    fs::{self, File, OpenOptions},
    io::{self, BufWriter, Write},
    path::{Path, PathBuf},
    sync::atomic::{AtomicBool, AtomicU64, Ordering},
};

static NEXT: AtomicU64 = AtomicU64::new(0);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Phase {
    Create,
    Write,
    Flush,
    FileSync,
    PreparePublication,
    Link,
    TargetDirectorySync,
    TemporaryRemove,
    CleanupDirectorySync,
    AbortRemove,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum State {
    NotPublished,
    PublishedDurabilityUnknown,
    Published,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Cleanup {
    NoTemporary,
    Removed,
    Retained,
    RemovalDurabilityUnknown,
}
#[derive(Debug)]
pub(crate) struct PublicationError {
    pub(crate) phase: Phase,
    pub(crate) state: State,
    pub(crate) cleanup: Cleanup,
    pub(crate) target: PathBuf,
    pub(crate) temporary: Option<PathBuf>,
    pub(crate) message: String,
}
impl std::fmt::Display for PublicationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{:?} at {:?}; output {}; cleanup {:?}; {}",
            self.state,
            self.phase,
            self.target.display(),
            self.cleanup,
            self.message
        )?;
        if let Some(path) = &self.temporary {
            write!(f, "; temporary {}", path.display())?;
        }
        Ok(())
    }
}

pub(crate) fn write_atomic<T>(
    target: &Path,
    cancel: &AtomicBool,
    write: impl FnOnce(&mut BufWriter<File>) -> Result<T, String>,
) -> Result<T, PublicationError> {
    write_prepared(target, cancel, write, |_, _| Ok(()))
}

pub(crate) fn write_prepared<T>(
    target: &Path,
    cancel: &AtomicBool,
    write: impl FnOnce(&mut BufWriter<File>) -> Result<T, String>,
    prepared: impl FnOnce(&Path, &Path) -> Result<(), String>,
) -> Result<T, PublicationError> {
    write_with_prepared(target, write, prepared, |phase| {
        if matches!(phase, Phase::Write | Phase::Link) && cancel.load(Ordering::Acquire) {
            Err(io::Error::other("cancelled"))
        } else {
            Ok(())
        }
    })
}

// The hook is private and is supplied with faults only by unit tests. It runs
// immediately before the corresponding real operation, never from environment.
#[cfg(test)]
fn write_with<T>(
    target: &Path,
    write: impl FnOnce(&mut BufWriter<File>) -> Result<T, String>,
    before: impl FnMut(Phase) -> io::Result<()>,
) -> Result<T, PublicationError> {
    write_with_prepared(target, write, |_, _| Ok(()), before)
}
fn write_with_prepared<T>(
    target: &Path,
    write: impl FnOnce(&mut BufWriter<File>) -> Result<T, String>,
    prepared: impl FnOnce(&Path, &Path) -> Result<(), String>,
    mut before: impl FnMut(Phase) -> io::Result<()>,
) -> Result<T, PublicationError> {
    let failure = |phase, state, cleanup, temporary, message| PublicationError {
        phase,
        state,
        cleanup,
        target: target.to_owned(),
        temporary,
        message,
    };
    let create_error = |message| {
        failure(
            Phase::Create,
            State::NotPublished,
            Cleanup::NoTemporary,
            None,
            message,
        )
    };
    if !cfg!(unix) {
        return Err(create_error(
            "single-file publication is unsupported on this platform".into(),
        ));
    }
    before(Phase::Create).map_err(|e| create_error(e.to_string()))?;
    if target.file_name().is_none() {
        return Err(create_error("output has no file name".into()));
    }
    let parent = target
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    let mut created = None;
    for _ in 0..1024 {
        let temporary = parent.join(format!(
            ".emburk-output-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        let mut options = OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        match options.open(&temporary) {
            Ok(file) => {
                created = Some((temporary, file));
                break;
            }
            Err(e) if e.kind() == io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(create_error(e.to_string())),
        }
    }
    let (temporary, file) =
        created.ok_or_else(|| create_error("temporary name attempts exhausted".into()))?;
    let mut output = BufWriter::new(file);
    let staged = (|| {
        before(Phase::Write).map_err(|e| (Phase::Write, e.to_string()))?;
        let value = write(&mut output).map_err(|e| (Phase::Write, e))?;
        before(Phase::Flush)
            .and_then(|()| output.flush())
            .map_err(|e| (Phase::Flush, e.to_string()))?;
        before(Phase::FileSync)
            .and_then(|()| output.get_ref().sync_all())
            .map_err(|e| (Phase::FileSync, e.to_string()))?;
        before(Phase::PreparePublication)
            .map_err(|e| (Phase::PreparePublication, e.to_string()))?;
        prepared(&temporary, target).map_err(|e| (Phase::PreparePublication, e))?;
        before(Phase::Link)
            .and_then(|()| fs::hard_link(&temporary, target))
            .map_err(|e| (Phase::Link, e.to_string()))?;
        Ok(value)
    })();
    // Do not let BufWriter::drop retry a failed write/flush. No buffered bytes
    // are written after the staged operation has decided its outcome.
    let (file, _unwritten) = output.into_parts();
    drop(file);
    let value = match staged {
        Ok(value) => value,
        Err((phase, mut message)) => {
            let cleanup =
                match before(Phase::AbortRemove).and_then(|()| fs::remove_file(&temporary)) {
                    Ok(()) => Cleanup::Removed,
                    Err(e) => {
                        message.push_str(&format!("; owned temporary cleanup failed: {e}"));
                        Cleanup::Retained
                    }
                };
            return Err(failure(
                phase,
                State::NotPublished,
                cleanup,
                (cleanup == Cleanup::Retained).then_some(temporary),
                message,
            ));
        }
    };
    // The final path now exists. Nothing below can remove it, even on failure.
    let directory = before(Phase::TargetDirectorySync)
        .and_then(|()| File::open(parent))
        .and_then(|directory| {
            directory.sync_all()?;
            Ok(directory)
        })
        .map_err(|e| {
            failure(
                Phase::TargetDirectorySync,
                State::PublishedDurabilityUnknown,
                Cleanup::Retained,
                Some(temporary.clone()),
                e.to_string(),
            )
        })?;
    before(Phase::TemporaryRemove)
        .and_then(|()| fs::remove_file(&temporary))
        .map_err(|e| {
            failure(
                Phase::TemporaryRemove,
                State::Published,
                Cleanup::Retained,
                Some(temporary.clone()),
                e.to_string(),
            )
        })?;
    before(Phase::CleanupDirectorySync)
        .and_then(|()| directory.sync_all())
        .map_err(|e| {
            failure(
                Phase::CleanupDirectorySync,
                State::Published,
                Cleanup::RemovalDurabilityUnknown,
                Some(temporary),
                e.to_string(),
            )
        })?;
    Ok(value)
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    fn target() -> PathBuf {
        let root = std::env::temp_dir().join(format!(
            "emburk-publication-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&root).unwrap();
        root.join("result")
    }
    fn content(output: &mut BufWriter<File>) -> Result<usize, String> {
        output.write_all(b"complete\n").map_err(|e| e.to_string())?;
        Ok(1)
    }
    fn fault(phase: Phase, requested: Phase) -> io::Result<()> {
        if phase == requested {
            Err(io::Error::other("injected operation failure"))
        } else {
            Ok(())
        }
    }
    #[test]
    fn each_prepublication_failure_leaves_no_output_or_temporary() {
        for phase in [
            Phase::Create,
            Phase::Write,
            Phase::Flush,
            Phase::FileSync,
            Phase::Link,
        ] {
            let target = target();
            let error = write_with(&target, content, |p| fault(p, phase)).unwrap_err();
            assert_eq!(error.state, State::NotPublished);
            assert_eq!(error.phase, phase);
            assert!(!target.exists());
            assert_eq!(fs::read_dir(target.parent().unwrap()).unwrap().count(), 0);
            assert_eq!(
                error.cleanup,
                if phase == Phase::Create {
                    Cleanup::NoTemporary
                } else {
                    Cleanup::Removed
                }
            );
        }
    }
    #[test]
    fn partial_stream_failure_is_unpublished_and_cleanup_failure_is_explicit() {
        for fail_cleanup in [false, true] {
            let target = target();
            let error = write_with(
                &target,
                |out| {
                    out.write_all(&vec![b'x'; 16384]).unwrap();
                    Err::<(), _>("injected input failure after partial write".into())
                },
                |phase| {
                    if fail_cleanup {
                        fault(phase, Phase::AbortRemove)
                    } else {
                        Ok(())
                    }
                },
            )
            .unwrap_err();
            assert_eq!(error.state, State::NotPublished);
            assert!(!target.exists());
            assert_eq!(
                error.cleanup,
                if fail_cleanup {
                    Cleanup::Retained
                } else {
                    Cleanup::Removed
                }
            );
            if fail_cleanup {
                let temporary = error.temporary.as_ref().unwrap();
                assert_eq!(fs::read(temporary).unwrap().len(), 16384);
                assert!(error.to_string().contains(&temporary.display().to_string()));
            }
        }
    }
    #[test]
    fn every_postlink_failure_preserves_complete_final_output_and_state() {
        for phase in [
            Phase::TargetDirectorySync,
            Phase::TemporaryRemove,
            Phase::CleanupDirectorySync,
        ] {
            let target = target();
            let error = write_with(&target, content, |p| fault(p, phase)).unwrap_err();
            assert_eq!(fs::read(&target).unwrap(), b"complete\n");
            assert_eq!(error.phase, phase);
            assert_eq!(
                error.state,
                if phase == Phase::TargetDirectorySync {
                    State::PublishedDurabilityUnknown
                } else {
                    State::Published
                }
            );
            let retained = phase != Phase::CleanupDirectorySync;
            assert_eq!(error.temporary.as_ref().unwrap().exists(), retained);
            assert_eq!(
                error.cleanup,
                if retained {
                    Cleanup::Retained
                } else {
                    Cleanup::RemovalDurabilityUnknown
                }
            );
        }
    }
    #[test]
    fn successful_publication_has_one_owner_only_file_and_preserves_value() {
        use std::os::unix::fs::PermissionsExt;
        let target = target();
        assert_eq!(
            write_atomic(&target, &AtomicBool::new(false), content).unwrap(),
            1
        );
        assert_eq!(fs::read(&target).unwrap(), b"complete\n");
        assert_eq!(
            fs::metadata(&target).unwrap().permissions().mode() & 0o777,
            0o600
        );
        assert_eq!(fs::read_dir(target.parent().unwrap()).unwrap().count(), 1);
    }
    #[test]
    fn cancellation_after_writing_is_checked_again_before_link() {
        let target = target();
        let cancel = AtomicBool::new(false);
        let error = write_atomic(&target, &cancel, |output| {
            content(output)?;
            cancel.store(true, Ordering::Release);
            Ok(())
        })
        .unwrap_err();
        assert_eq!(
            (error.state, error.phase, error.cleanup),
            (State::NotPublished, Phase::Link, Cleanup::Removed)
        );
        assert!(!target.exists());
        assert_eq!(fs::read_dir(target.parent().unwrap()).unwrap().count(), 0);
    }
    #[test]
    fn existing_regular_and_symlink_destinations_are_never_replaced() {
        use std::os::unix::fs::symlink;
        for is_link in [false, true] {
            let target = target();
            let original = target.with_file_name("original");
            if is_link {
                fs::write(&original, b"old").unwrap();
                symlink(&original, &target).unwrap();
            } else {
                fs::write(&target, b"old").unwrap();
            }
            let error = write_atomic(&target, &AtomicBool::new(false), content).unwrap_err();
            assert_eq!(
                (error.state, error.phase, error.cleanup),
                (State::NotPublished, Phase::Link, Cleanup::Removed)
            );
            assert_eq!(fs::read(&target).unwrap(), b"old");
            assert_eq!(
                fs::symlink_metadata(&target)
                    .unwrap()
                    .file_type()
                    .is_symlink(),
                is_link
            );
            assert_eq!(
                fs::read_dir(target.parent().unwrap()).unwrap().count(),
                if is_link { 2 } else { 1 }
            );
        }
    }

    #[test]
    fn prepared_hook_runs_after_sync_before_link_and_can_prevent_publication() {
        let target = target();
        let cancel = AtomicBool::new(false);
        let error = write_prepared(&target, &cancel, content, |temporary, final_path| {
            assert_eq!(fs::read(temporary).unwrap(), b"complete\n");
            assert!(!final_path.exists());
            Err("prepared failure".into())
        })
        .unwrap_err();
        assert_eq!(error.phase, Phase::PreparePublication);
        assert_eq!(error.state, State::NotPublished);
        assert!(!target.exists());
        assert_eq!(fs::read_dir(target.parent().unwrap()).unwrap().count(), 0);
    }

    #[test]
    fn prepared_hook_cancellation_prevents_link() {
        let target = target();
        let cancel = AtomicBool::new(false);
        let error = write_prepared(&target, &cancel, content, |_, _| {
            cancel.store(true, Ordering::Release);
            Ok(())
        })
        .unwrap_err();
        assert_eq!(error.phase, Phase::Link);
        assert_eq!(error.state, State::NotPublished);
        assert!(!target.exists());
    }
}
