use prost::Message;
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
mod auth;
mod migrate;
pub use accounts::{Diverged, Pushed};
mod session;
pub use session::JOIN_REQUEST_TTL_SECONDS;
#[cfg(test)]
pub use session::SESSION_IDLE_SECONDS;

pub use analytics::MAX_STATS_WINDOW_DAYS;

pub type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Something a live view may need to redraw for. The Sync stream of every
/// connected device listens and re-sends what concerns it.
#[derive(Clone, Debug, PartialEq)]
pub enum Change {
    /// A session's members or their progress.
    Session(String),
    /// A user's own session membership.
    Membership(String),
    /// Requests to join this user.
    JoinRequests(String),
}

#[derive(Clone)]
pub struct ServerDb {
    pub read_pool: Pool<Sqlite>,
    write_pool: Pool<Sqlite>,
    accounts: std::sync::Arc<accounts::AccountCache>,
    join_requests: std::sync::Arc<session::JoinRequests>,
    changes: tokio::sync::broadcast::Sender<Change>,
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
        Ok(Self {
            read_pool,
            write_pool,
            accounts: Default::default(),
            join_requests: Default::default(),
            changes: tokio::sync::broadcast::channel(1024).0,
        })
    }

    /// Hear about changes from now on.
    pub fn subscribe(&self) -> tokio::sync::broadcast::Receiver<Change> {
        self.changes.subscribe()
    }

    fn notify(&self, change: Change) {
        // No receivers is fine: nobody is watching.
        let _ = self.changes.send(change);
    }
}
