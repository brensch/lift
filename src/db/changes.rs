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
    /// New events in the user's account, each with its place: stored, and
    /// sent to the user's devices.
    Account(Arc<[Event]>),
    /// Events the user just pushed, not yet placed (no seq): for their
    /// session partners at once, before they're stored with the next flush.
    Live(Arc<[Event]>),
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

/// Changes a stream may fall behind by before it is told it missed some
/// (and sends everything again). Each watched topic holds this many slots
/// from the start, so with a million streams it is kept small.
const BACKLOG: usize = 16;

/// A channel per watched topic, made by the first to watch it and dropped
/// once nobody does.
#[derive(Default)]
pub(super) struct Changes(Mutex<Topics>);

#[derive(Default)]
pub(super) struct Topics {
    channels: HashMap<Topic, broadcast::Sender<Change>>,
    /// How many there were after the last sweep for unwatched ones: swept
    /// again once they've doubled, so a watch costs the same with a million
    /// streams open as with ten (not a walk over all of them each time).
    swept_at: usize,
}

impl Changes {
    pub(super) fn watch(&self, topic: Topic) -> broadcast::Receiver<Change> {
        let mut topics = self.0.lock().unwrap_or_else(|e| e.into_inner());
        if topics.channels.len() > 2 * topics.swept_at.max(64) {
            topics.channels.retain(|_, tx| tx.receiver_count() > 0);
            topics.swept_at = topics.channels.len();
        }
        topics
            .channels
            .entry(topic)
            .or_insert_with(|| broadcast::channel(BACKLOG).0)
            .subscribe()
    }

    pub(super) fn notify(&self, topic: Topic, change: Change) {
        let topics = self.0.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(tx) = topics.channels.get(&topic) {
            // Nobody watching any more is fine: the next watch drops it.
            let _ = tx.send(change);
        }
    }
}
