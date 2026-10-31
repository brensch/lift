//! Events on the wire: a batch, zstd-compressed. Both ends of the Sync
//! stream pack and unpack with these.

use prost::Message;

use crate::account::CoreError;
use crate::pb::{Event, EventBatch};

/// zstd's default: a good ratio at a cost nobody notices for a few events.
const LEVEL: i32 = 3;

pub fn pack(events: Vec<Event>) -> Vec<u8> {
    let bytes = EventBatch { events }.encode_to_vec();
    // Compressing an in-memory buffer can't fail.
    zstd::encode_all(bytes.as_slice(), LEVEL).unwrap_or_default()
}

pub fn unpack(packed: &[u8]) -> Result<Vec<Event>, CoreError> {
    let bad = |e: &dyn std::fmt::Display| CoreError::InvalidArgument(format!("bad batch: {e}"));
    let bytes = zstd::decode_all(packed).map_err(|e| bad(&e))?;
    Ok(EventBatch::decode(bytes.as_slice())
        .map_err(|e| bad(&e))?
        .events)
}
