use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// User preferences stored locally
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct UserPreferences {
    pub id: Uuid,
    pub username: String,
    pub age: Option<u32>,
    pub created_at: u64,
}

impl UserPreferences {
    pub fn new(username: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            username,
            age: None,
            created_at: current_time_secs(),
        }
    }
}

#[cfg(target_arch = "wasm32")]
fn current_time_secs() -> u64 {
    (js_sys::Date::now() / 1000.0) as u64
}

#[cfg(not(target_arch = "wasm32"))]
fn current_time_secs() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

/// Messages sent over WebSocket for signaling
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum SignalMessage {
    /// Register with the signaling server
    Register { user_id: Uuid, username: String },

    /// List of online users
    UserList { users: Vec<OnlineUser> },

    /// Request to connect to a peer
    ConnectRequest { from: Uuid, to: Uuid },

    /// WebRTC offer
    Offer { from: Uuid, to: Uuid, sdp: String },

    /// WebRTC answer
    Answer { from: Uuid, to: Uuid, sdp: String },

    /// ICE candidate
    IceCandidate { from: Uuid, to: Uuid, candidate: String },

    /// Direct message over WebRTC (for testing)
    DirectMessage { content: String },
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OnlineUser {
    pub id: Uuid,
    pub username: String,
}
