//! Events on the wire: a batch, zstd-compressed. Both ends of the Sync
//! stream pack and unpack with these.

use std::io::Read;

use prost::Message;

use crate::account::CoreError;
use crate::pb::{Event, EventBatch};

/// zstd's default: a good ratio at a cost nobody notices for a few events.
const LEVEL: i32 = 3;

/// The most a batch may decompress to. A whole account's history is a few
/// MB; this stops a small crafted batch from expanding until memory runs out.
const MAX_BATCH_BYTES: u64 = 64 << 20;

pub fn pack(events: Vec<Event>) -> Vec<u8> {
    let bytes = EventBatch { events }.encode_to_vec();
    // Compressing an in-memory buffer can't fail.
    zstd::encode_all(bytes.as_slice(), LEVEL).unwrap_or_default()
}

pub fn unpack(packed: &[u8]) -> Result<Vec<Event>, CoreError> {
    let bad = |e: &dyn std::fmt::Display| CoreError::InvalidArgument(format!("bad batch: {e}"));
    let mut bytes = Vec::new();
    zstd::stream::read::Decoder::new(packed)
        .map_err(|e| bad(&e))?
        .take(MAX_BATCH_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(|e| bad(&e))?;
    if bytes.len() as u64 > MAX_BATCH_BYTES {
        return Err(bad(&format!("larger than {MAX_BATCH_BYTES} bytes")));
    }
    Ok(EventBatch::decode(bytes.as_slice())
        .map_err(|e| bad(&e))?
        .events)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unpack_refuses_a_batch_that_expands_past_the_limit() {
        let zeros = vec![0u8; MAX_BATCH_BYTES as usize + 1];
        let packed = zstd::encode_all(zeros.as_slice(), LEVEL).unwrap();
        assert!(matches!(
            unpack(&packed),
            Err(CoreError::InvalidArgument(_))
        ));
    }

    #[test]
    fn unpack_reverses_pack() {
        let events = vec![Event {
            seq: 1,
            ..Default::default()
        }];
        assert_eq!(unpack(&pack(events.clone())).unwrap(), events);
    }
}
