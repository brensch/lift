//! The app's log, in a SQLite file of its own beside the accounts: what the
//! app did, for the person looking into a problem on this phone. Warnings
//! and errors are kept for good; debug and info share a budget of
//! `CHATTER_BYTES`, the oldest going first.

use std::path::Path;

use rusqlite::{params, Connection, OptionalExtension};

use crate::store::StoreResult;

/// The most the debug and info entries hold between them, in bytes of tag,
/// message and fields.
pub const CHATTER_BYTES: i64 = 1 << 20;

/// Levels as stored: debug 0, info 1, warn 2, error 3.
const WARN: i32 = 2;

const SCHEMA: &str = "
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY,
    at_ms INTEGER NOT NULL,
    level INTEGER NOT NULL,
    tag TEXT NOT NULL,
    message TEXT NOT NULL,
    -- The entry's fields as a JSON object, '' for none.
    fields TEXT NOT NULL,
    size INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS logs_level ON logs(level, id);
";

/// One entry, as the app logged it.
pub struct LogRecord {
    pub at_ms: i64,
    pub level: i32,
    pub tag: String,
    pub message: String,
    pub fields: String,
}

/// One entry as kept, with its place in the log.
pub struct StoredLog {
    pub id: i64,
    pub at_ms: i64,
    pub level: i32,
    pub tag: String,
    pub message: String,
    pub fields: String,
}

pub struct LogStore {
    conn: Connection,
    /// What the debug and info entries hold now.
    chatter: i64,
}

fn storage(e: impl std::fmt::Display) -> String {
    format!("storage: {e}")
}

impl LogStore {
    pub fn open(path: &Path) -> StoreResult<Self> {
        let conn = Connection::open(path).map_err(storage)?;
        conn.execute_batch(&format!("PRAGMA journal_mode = WAL;{SCHEMA}"))
            .map_err(storage)?;
        let chatter = Self::chatter_in(&conn)?;
        Ok(Self { conn, chatter })
    }

    fn chatter_in(conn: &Connection) -> StoreResult<i64> {
        conn.query_row(
            "SELECT COALESCE(SUM(size), 0) FROM logs WHERE level < ?",
            [WARN],
            |r| r.get(0),
        )
        .map_err(storage)
    }

    /// Keep `records`, then drop the oldest debug and info past the budget.
    pub fn append(&mut self, records: Vec<LogRecord>) -> StoreResult<()> {
        let tx = self.conn.transaction().map_err(storage)?;
        for r in &records {
            let size = (r.tag.len() + r.message.len() + r.fields.len()) as i64;
            tx.execute(
                "INSERT INTO logs (at_ms, level, tag, message, fields, size)
                 VALUES (?, ?, ?, ?, ?, ?)",
                params![r.at_ms, r.level, r.tag, r.message, r.fields, size],
            )
            .map_err(storage)?;
            if r.level < WARN {
                self.chatter += size;
            }
        }
        if self.chatter > CHATTER_BYTES {
            // The newest that fit stay; everything older goes.
            let oldest_kept: Option<i64> = tx
                .query_row(
                    "SELECT id FROM (
                         SELECT id, SUM(size) OVER (ORDER BY id DESC) AS held
                         FROM logs WHERE level < ?1
                     ) WHERE held <= ?2 ORDER BY id LIMIT 1",
                    params![WARN, CHATTER_BYTES],
                    |r| r.get(0),
                )
                .optional()
                .map_err(storage)?;
            tx.execute(
                "DELETE FROM logs WHERE level < ?1 AND id < ?2",
                params![WARN, oldest_kept.unwrap_or(i64::MAX)],
            )
            .map_err(storage)?;
            self.chatter = Self::chatter_in(&tx)?;
        }
        tx.commit().map_err(storage)
    }

    /// Up to `limit` entries at `min_level` or above, newest first, older
    /// than the one numbered `before` (0 for the newest), with `tag` when
    /// it isn't empty and containing `text` (in the tag, message or
    /// fields, any case) when that isn't.
    pub fn read(
        &self,
        min_level: i32,
        tag: &str,
        text: &str,
        before: i64,
        limit: u32,
    ) -> StoreResult<Vec<StoredLog>> {
        let before = if before > 0 { before } else { i64::MAX };
        let pattern = format!("%{}%", text.replace('%', "\\%").replace('_', "\\_"));
        let mut query = self
            .conn
            .prepare_cached(
                "SELECT id, at_ms, level, tag, message, fields FROM logs
                 WHERE level >= ?1 AND id < ?2
                   AND (?3 = '' OR tag = ?3)
                   AND (?4 = '' OR tag LIKE ?5 ESCAPE '\\'
                        OR message LIKE ?5 ESCAPE '\\'
                        OR fields LIKE ?5 ESCAPE '\\')
                 ORDER BY id DESC LIMIT ?6",
            )
            .map_err(storage)?;
        let rows = query
            .query_map(params![min_level, before, tag, text, pattern, limit], |r| {
                Ok(StoredLog {
                    id: r.get(0)?,
                    at_ms: r.get(1)?,
                    level: r.get(2)?,
                    tag: r.get(3)?,
                    message: r.get(4)?,
                    fields: r.get(5)?,
                })
            })
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        Ok(rows)
    }

    pub fn clear(&mut self) -> StoreResult<()> {
        self.conn.execute("DELETE FROM logs", []).map_err(storage)?;
        self.chatter = 0;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record(level: i32, message: &str) -> LogRecord {
        LogRecord {
            at_ms: 1,
            level,
            tag: "t".into(),
            message: message.into(),
            fields: String::new(),
        }
    }

    fn open() -> LogStore {
        LogStore::open(Path::new(":memory:")).unwrap()
    }

    #[test]
    fn warnings_and_errors_outlast_the_budget_and_chatter_does_not() {
        let mut logs = open();
        logs.append(vec![record(2, "warned"), record(3, "failed")])
            .unwrap();
        // Ten times the budget of chatter, in pieces.
        let line = "x".repeat(1023);
        for _ in 0..10 {
            logs.append((0..1024).map(|_| record(1, &line)).collect())
                .unwrap();
        }
        let kept = logs.read(0, "", "", 0, u32::MAX).unwrap();
        let chatter: i64 = kept
            .iter()
            .filter(|l| l.level < 2)
            .map(|l| (l.tag.len() + l.message.len()) as i64)
            .sum();
        assert!(chatter <= CHATTER_BYTES, "{chatter}");
        assert!(chatter > CHATTER_BYTES - 2048, "{chatter}");
        let serious: Vec<_> = kept.iter().filter(|l| l.level >= 2).collect();
        assert_eq!(serious.len(), 2);
    }

    #[test]
    fn reads_newest_first_in_pages_by_level_tag_and_text() {
        let mut logs = open();
        logs.append(vec![
            record(0, "one"),
            record(1, "two"),
            LogRecord {
                tag: "gRPC".into(),
                ..record(3, "three 100%")
            },
        ])
        .unwrap();
        let all = logs.read(0, "", "", 0, 2).unwrap();
        assert_eq!(
            all.iter().map(|l| l.message.as_str()).collect::<Vec<_>>(),
            ["three 100%", "two"]
        );
        let older = logs.read(0, "", "", all[1].id, 10).unwrap();
        assert_eq!(older.len(), 1);
        assert_eq!(older[0].message, "one");
        assert_eq!(logs.read(1, "", "", 0, 10).unwrap().len(), 2);
        assert_eq!(logs.read(0, "gRPC", "", 0, 10).unwrap().len(), 1);
        assert_eq!(logs.read(0, "", "TWO", 0, 10).unwrap().len(), 1);
        assert_eq!(logs.read(0, "", "0%", 0, 10).unwrap().len(), 1);
        assert_eq!(logs.read(0, "", "_", 0, 10).unwrap().len(), 0);
    }
}
