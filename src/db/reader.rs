//! Reads made on the caller's own thread, over plain SQLite connections.
//!
//! sqlx runs each connection on a thread of its own and sends every query
//! there and back: two wakeups and a pool checkout a query. For the small
//! indexed reads every sync open makes (the login, the account's head, the
//! session it's in) that hop cost as much as the read. Here the read is a
//! function call: SQLite is a library in this process, and each of these
//! is a few B-tree steps through pages it already holds.

use rusqlite::{Connection, OpenFlags};
use std::path::Path;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;
use std::time::Duration;

use super::DbResult;

/// A few read-only connections, one per thread that can be reading at once.
/// In WAL mode they read side by side and see every commit made before
/// each statement starts; none holds a read open between statements, so
/// checkpoints are never held back.
pub struct Reader {
    connections: Vec<Mutex<Connection>>,
    next: AtomicUsize,
}

impl Reader {
    /// `count` connections to the database at `path` (migrated already).
    pub fn open(path: &Path, count: usize) -> DbResult<Self> {
        let connections = (0..count.max(1))
            .map(|_| {
                let connection = Connection::open_with_flags(
                    path,
                    OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
                )?;
                connection.busy_timeout(Duration::from_secs(30))?;
                Ok(Mutex::new(connection))
            })
            .collect::<DbResult<_>>()?;
        Ok(Self {
            connections,
            next: AtomicUsize::new(0),
        })
    }

    /// `read` on a free connection: the first not in use, or (all busy,
    /// for the moment a read takes) the next in turn, once it is free.
    pub fn read<R>(&self, read: impl FnOnce(&Connection) -> rusqlite::Result<R>) -> DbResult<R> {
        let count = self.connections.len();
        let start = self.next.fetch_add(1, Ordering::Relaxed);
        for i in 0..count {
            if let Ok(connection) = self.connections[(start + i) % count].try_lock() {
                return Ok(read(&connection)?);
            }
        }
        let connection = self.connections[start % count]
            .lock()
            .unwrap_or_else(|e| e.into_inner());
        Ok(read(&connection)?)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_db() -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("lift-reader-test-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        dir.join("db.sqlite")
    }

    #[test]
    fn it_reads_what_was_committed_before_each_read() {
        let path = temp_db();
        let writer = Connection::open(&path).unwrap();
        writer
            .execute_batch("PRAGMA journal_mode=WAL; CREATE TABLE t (n INTEGER);")
            .unwrap();
        let reader = Reader::open(&path, 2).unwrap();
        let count = || {
            reader
                .read(|c| c.query_row("SELECT count(*) FROM t", [], |r| r.get::<_, i64>(0)))
                .unwrap()
        };
        assert_eq!(count(), 0);
        writer.execute("INSERT INTO t VALUES (1)", []).unwrap();
        assert_eq!(count(), 1);
    }

    #[test]
    fn it_cannot_write() {
        let path = temp_db();
        Connection::open(&path)
            .unwrap()
            .execute_batch("PRAGMA journal_mode=WAL; CREATE TABLE t (n INTEGER);")
            .unwrap();
        let reader = Reader::open(&path, 1).unwrap();
        assert!(reader
            .read(|c| c.execute("INSERT INTO t VALUES (1)", []))
            .is_err());
    }
}
