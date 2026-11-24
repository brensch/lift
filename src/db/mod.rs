use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions, SqliteSynchronous},
    Pool, Row, Sqlite,
};
use std::path::Path;
use std::str::FromStr;
use uuid::Uuid;

use crate::time::now_unix;

mod accounts;
mod analytics;
mod assistants;
mod auth;
mod changes;
mod ledger;
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
        let data_dir = data_dir.as_ref();
        std::fs::create_dir_all(data_dir)?;
        let db_path = format!("{}/server.sqlite", data_dir.display());
        let options = SqliteConnectOptions::from_str(&format!("sqlite://{}", db_path))?
            .create_if_missing(true)
            .synchronous(SqliteSynchronous::Normal)
            .journal_mode(SqliteJournalMode::Wal)
            .busy_timeout(std::time::Duration::from_secs(30));
        let write_pool = SqlitePoolOptions::new()
            .max_connections(1)
            .acquire_slow_threshold(std::time::Duration::from_secs(60))
            .connect_with(options.clone())
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
        )
        .await?;
        ledger.run(ledger::flush_every());
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
