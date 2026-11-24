use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions, SqliteSynchronous},
    Pool, Row, Sqlite,
};
use std::path::{Path, PathBuf};
use std::str::FromStr;
use uuid::Uuid;

use crate::time::now_unix;

mod accounts;
mod analytics;
mod assistants;
mod auth;
mod changes;
pub mod ledger;
mod migrate;
mod recovery;
mod training;
pub use changes::{Change, Topic};
mod session;
pub use session::JOIN_REQUEST_TTL_SECONDS;

pub use analytics::MAX_STATS_WINDOW_DAYS;
pub use assistants::{Client, Consent, MAX_FEEDBACK_CHARS};
pub use recovery::{shown_code, Approval, Held, Recovery, RECOVERY_TTL_SECONDS};
pub use training::AccountRow;

pub type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

#[derive(Clone)]
pub struct ServerDb {
    pub read_pool: Pool<Sqlite>,
    write_pool: Pool<Sqlite>,
    join_requests: std::sync::Arc<session::JoinRequests>,
    changes: std::sync::Arc<changes::Changes>,
    /// Every account's events and each account folded (`ledger`).
    ledger: std::sync::Arc<ledger::Ledger>,
}

impl ServerDb {
    pub async fn new_in_dir(data_dir: impl AsRef<Path>) -> DbResult<Self> {
        Self::new_with_timing(data_dir, ledger::Timing::from_env()).await
    }

    /// The same, with the ledger's timings given (tests of holding events).
    pub async fn new_with_timing(
        data_dir: impl AsRef<Path>,
        timing: ledger::Timing,
    ) -> DbResult<Self> {
        let data_dir = data_dir.as_ref();
        std::fs::create_dir_all(data_dir)?;
        let db_path = format!("{}/server.sqlite", data_dir.display());
        let options = SqliteConnectOptions::from_str(&format!("sqlite://{}", db_path))?
            .create_if_missing(true)
            .synchronous(SqliteSynchronous::Normal)
            .journal_mode(SqliteJournalMode::Wal)
            .busy_timeout(std::time::Duration::from_secs(30));
        // The writer never checkpoints: a commit that did would copy the WAL
        // into the database (random writes) before it returned, and a
        // batch of snapshots is megabytes. `checkpoint_in_background` does.
        let write_pool = SqlitePoolOptions::new()
            .max_connections(1)
            .acquire_slow_threshold(std::time::Duration::from_secs(60))
            .connect_with(
                options
                    .clone()
                    .pragma("wal_autocheckpoint", "0")
                    // Cut back to this once checkpointed: a burst of writes
                    // leaves the WAL long otherwise (568 MB after one).
                    .pragma("journal_size_limit", (64 << 20).to_string()),
            )
            .await?;
        let read_pool = SqlitePoolOptions::new()
            .max_connections(16)
            .connect_with(options)
            .await?;
        migrate::migrate(&write_pool).await?;
        let changes = std::sync::Arc::<changes::Changes>::default();
        let ledger = ledger::Ledger::open(
            data_dir,
            read_pool.clone(),
            write_pool.clone(),
            changes.clone(),
            timing,
        )
        .await?;
        ledger.run();
        checkpoint_in_background(
            &read_pool,
            &write_pool,
            PathBuf::from(format!("{db_path}-wal")),
        );
        Ok(Self {
            read_pool,
            write_pool,
            join_requests: Default::default(),
            changes,
            ledger,
        })
    }

    /// Hear about the topic's changes from now on.
    pub fn watch(&self, topic: Topic) -> tokio::sync::broadcast::Receiver<Change> {
        self.changes.watch(topic)
    }

    fn notify(&self, topic: Topic, change: Change) {
        self.changes.notify(topic, change);
    }
}

/// Copy the WAL into the database every few seconds, from a reader: a
/// passive checkpoint waits for no one and blocks no one, so the writer's
/// commits stay appends. It can't copy past what readers still use, so
/// under steady reads it falls behind; once the WAL passes
/// `WAL_TRUNCATE_AT`, a truncating checkpoint on the writer's connection
/// (between its writes) waits for the readers and starts the WAL again.
fn checkpoint_in_background(read_pool: &Pool<Sqlite>, write_pool: &Pool<Sqlite>, wal: PathBuf) {
    let (read_pool, write_pool) = (read_pool.clone(), write_pool.clone());
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(std::time::Duration::from_secs(if cfg!(test) {
                1
            } else {
                5
            }))
            .await;
            if read_pool.is_closed() {
                return;
            }
            let long = std::fs::metadata(&wal).is_ok_and(|m| m.len() > WAL_TRUNCATE_AT);
            let (pool, checkpoint) = if long {
                (&write_pool, "PRAGMA wal_checkpoint(TRUNCATE)")
            } else {
                (&read_pool, "PRAGMA wal_checkpoint(PASSIVE)")
            };
            if let Err(error) = sqlx::query(checkpoint).execute(pool).await {
                tracing::warn!(%error, "checkpointing the WAL");
            }
        }
    });
}

/// A WAL longer than this is checkpointed whole and truncated.
const WAL_TRUNCATE_AT: u64 = 256 << 20;
