//! The app's log file, for Dart: one per install, opened once at start.

use std::path::PathBuf;
use std::sync::Mutex;

use crate::logs::{LogRecord, LogStore, StoredLog};
use crate::store::StoreResult;

static LOGS: Mutex<Option<LogStore>> = Mutex::new(None);

fn with_logs<T>(f: impl FnOnce(&mut LogStore) -> StoreResult<T>) -> StoreResult<T> {
    let mut logs = LOGS
        .lock()
        .map_err(|_| "storage: log lock poisoned".to_string())?;
    let logs = logs
        .as_mut()
        .ok_or_else(|| "failed_precondition: the log isn't open".to_string())?;
    f(logs)
}

/// One entry, as the app logged it: when (unix ms), its level (debug 0,
/// info 1, warn 2, error 3), tag, message and fields (a JSON object, or
/// empty).
pub struct LogLine {
    pub at_ms: i64,
    pub level: i32,
    pub tag: String,
    pub message: String,
    pub fields: String,
}

/// One entry as kept, `id` its place in the log.
pub struct KeptLogLine {
    pub id: i64,
    pub at_ms: i64,
    pub level: i32,
    pub tag: String,
    pub message: String,
    pub fields: String,
}

/// Open (or make) the log file at `path`.
pub fn open_logs(path: String) -> StoreResult<()> {
    let store = LogStore::open(&PathBuf::from(path))?;
    *LOGS
        .lock()
        .map_err(|_| "storage: log lock poisoned".to_string())? = Some(store);
    Ok(())
}

pub fn append_logs(lines: Vec<LogLine>) -> StoreResult<()> {
    with_logs(|logs| {
        logs.append(
            lines
                .into_iter()
                .map(|l| LogRecord {
                    at_ms: l.at_ms,
                    level: l.level,
                    tag: l.tag,
                    message: l.message,
                    fields: l.fields,
                })
                .collect(),
        )
    })
}

/// Up to `limit` entries at `min_level` or above, newest first, older than
/// the one numbered `before` (0 for the newest), with `tag` and containing
/// `text` when those aren't empty.
pub fn read_logs(
    min_level: i32,
    tag: String,
    text: String,
    before: i64,
    limit: u32,
) -> StoreResult<Vec<KeptLogLine>> {
    with_logs(|logs| {
        Ok(logs
            .read(min_level, &tag, &text, before, limit)?
            .into_iter()
            .map(|l: StoredLog| KeptLogLine {
                id: l.id,
                at_ms: l.at_ms,
                level: l.level,
                tag: l.tag,
                message: l.message,
                fields: l.fields,
            })
            .collect())
    })
}

pub fn clear_logs() -> StoreResult<()> {
    with_logs(|logs| logs.clear())
}
