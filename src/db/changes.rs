//! Changes a live view may need to redraw for, told only to the streams that
//! watch them: a user's own streams, or the streams of a session's members.
//! A stream wakes for what concerns it and nothing else, however many are
//! connected.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use schlift_core::events::Event;
use tokio::sync::broadcast;

/// Who a change concerns.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum Topic {
    User(String),
    Session(String),
}

#[derive(Clone, Debug, PartialEq)]
pub enum Change {
    /// New events in the user's account, each with its place.
    Account(Arc<[Event]>),
    /// The user's own session membership.
    Membership,
    /// Requests to join the user.
    JoinRequests,
    /// The session's members or their progress.
    Session,
    /// One of the user's logins was signed out, or the account deleted:
    /// each of their streams checks it is still signed in.
    SignedOut,
}

/// Changes a stream may fall behind by before it is told it missed some.
const BACKLOG: usize = 64;

/// A channel per watched topic, made by the first to watch it and dropped
/// once nobody does.
#[derive(Default)]
pub(super) struct Changes(Mutex<HashMap<Topic, broadcast::Sender<Change>>>);

impl Changes {
    pub(super) fn watch(&self, topic: Topic) -> broadcast::Receiver<Change> {
        let mut topics = self.0.lock().unwrap_or_else(|e| e.into_inner());
        topics.retain(|_, tx| tx.receiver_count() > 0);
        topics
            .entry(topic)
            .or_insert_with(|| broadcast::channel(BACKLOG).0)
            .subscribe()
    }

    pub(super) fn notify(&self, topic: Topic, change: Change) {
        let topics = self.0.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(tx) = topics.get(&topic) {
            // Nobody watching any more is fine: the next watch drops it.
            let _ = tx.send(change);
        }
    }
}
