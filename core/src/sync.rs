//! Events on the wire: a batch, zstd-compressed. Both ends of the Sync
//! stream pack and unpack with these.

use std::io::Read;

use prost::encoding::{decode_key, decode_varint, skip_field, DecodeContext, WireType};
use prost::Message;

use crate::account::CoreError;
use crate::pb::{Event, EventBatch};

/// zstd's default: a good ratio at a cost nobody notices for a few events.
const LEVEL: i32 = 3;

/// The most a batch from the server may decompress to: a whole account's
/// history, years of it.
const MAX_BATCH_BYTES: u64 = 64 << 20;

/// The most a pushed batch may decompress to. The largest real push, a whole
/// imported history, is about 1 MB. An empty nested message is two bytes on
/// the wire and up to a few hundred in memory, so this also bounds what a
/// crafted push can make the server allocate (under 2 GB).
const MAX_PUSH_BYTES: u64 = 16 << 20;

/// The most events one push may hold. Far above anything a phone records (an
/// outbox after weeks offline, an import of years of training); an empty
/// event is two bytes on the wire but nearly two hundred in memory, so this
/// is counted while decoding, before any are kept.
pub const MAX_EVENTS_PER_PUSH: usize = 100_000;

/// `EventBatch.events`.
const EVENTS_FIELD: u32 = 1;

pub fn pack(events: Vec<Event>) -> Vec<u8> {
    let bytes = EventBatch { events }.encode_to_vec();
    // Compressing an in-memory buffer can't fail.
    zstd::encode_all(bytes.as_slice(), LEVEL).unwrap_or_default()
}

/// A batch the server sent: the account's events, however many.
pub fn unpack(packed: &[u8]) -> Result<Vec<Event>, CoreError> {
    unpack_at_most(packed, MAX_BATCH_BYTES, usize::MAX)
}

/// A batch a phone pushed, refused past `MAX_PUSH_BYTES` or
/// `MAX_EVENTS_PER_PUSH` events.
pub fn unpack_push(packed: &[u8]) -> Result<Vec<Event>, CoreError> {
    unpack_at_most(packed, MAX_PUSH_BYTES, MAX_EVENTS_PER_PUSH)
}

fn unpack_at_most(
    packed: &[u8],
    max_bytes: u64,
    max_events: usize,
) -> Result<Vec<Event>, CoreError> {
    let bad = |e: &dyn std::fmt::Display| CoreError::InvalidArgument(format!("bad batch: {e}"));
    let mut bytes = Vec::new();
    zstd::stream::read::Decoder::new(packed)
        .map_err(|e| bad(&e))?
        .take(max_bytes + 1)
        .read_to_end(&mut bytes)
        .map_err(|e| bad(&e))?;
    if bytes.len() as u64 > max_bytes {
        return Err(bad(&format!("larger than {max_bytes} bytes")));
    }
    // An EventBatch field by field, so the count is checked before each
    // event is decoded rather than after all of them are.
    let mut buf = bytes.as_slice();
    let mut events = Vec::new();
    while !buf.is_empty() {
        let (tag, wire_type) = decode_key(&mut buf).map_err(|e| bad(&e))?;
        if tag != EVENTS_FIELD || wire_type != WireType::LengthDelimited {
            skip_field(wire_type, tag, &mut buf, DecodeContext::default()).map_err(|e| bad(&e))?;
            continue;
        }
        if events.len() == max_events {
            return Err(bad(&format!("more than {max_events} events")));
        }
        let len = decode_varint(&mut buf).map_err(|e| bad(&e))?;
        if len > buf.len() as u64 {
            return Err(bad(&"truncated event"));
        }
        let (event, rest) = buf.split_at(len as usize);
        events.push(Event::decode(event).map_err(|e| bad(&e))?);
        buf = rest;
    }
    Ok(events)
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
    fn unpack_push_refuses_too_many_events_before_decoding_them() {
        // Each `0a 00` is one empty event: two bytes on the wire.
        let bytes = [0x0a, 0x00].repeat(MAX_EVENTS_PER_PUSH + 1);
        let packed = zstd::encode_all(bytes.as_slice(), LEVEL).unwrap();
        assert!(packed.len() < 1024);
        assert!(matches!(
            unpack_push(&packed),
            Err(CoreError::InvalidArgument(_))
        ));
        assert_eq!(unpack(&packed).unwrap().len(), MAX_EVENTS_PER_PUSH + 1);
    }

    #[test]
    fn unpack_push_refuses_a_push_that_expands_past_its_own_limit() {
        // One event padded past the push limit (but not the server's).
        let event = Event {
            id: "x".repeat(MAX_PUSH_BYTES as usize),
            ..Default::default()
        };
        let packed = pack(vec![event]);
        assert!(matches!(
            unpack_push(&packed),
            Err(CoreError::InvalidArgument(_))
        ));
        assert_eq!(unpack(&packed).unwrap().len(), 1);
    }

    #[test]
    fn unpack_push_takes_a_push_at_the_limit() {
        let events = vec![Event::default(); MAX_EVENTS_PER_PUSH];
        assert_eq!(
            unpack_push(&pack(events)).unwrap().len(),
            MAX_EVENTS_PER_PUSH
        );
    }

    #[test]
    fn unpack_reverses_pack() {
        let events = vec![
            Event {
                seq: 1,
                ..Default::default()
            },
            Event {
                seq: 2,
                id: "b".into(),
                ..Default::default()
            },
        ];
        assert_eq!(unpack(&pack(events.clone())).unwrap(), events);
    }

    #[test]
    fn unpack_refuses_a_truncated_event() {
        let packed = zstd::encode_all([0x0a, 0x05, 0x08].as_slice(), LEVEL).unwrap();
        assert!(unpack(&packed).is_err());
    }
}
