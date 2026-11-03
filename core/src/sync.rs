//! Events on the wire: a JSON array, zstd-compressed. Both ends of the Sync
//! stream pack and unpack with these.

use std::fmt;
use std::io::Read;

use serde::de::{Deserializer, SeqAccess, Visitor};

use crate::account::CoreError;
use crate::events::Event;

/// zstd's default: a good ratio at a cost nobody notices for a few events.
const LEVEL: i32 = 3;

/// The most a batch from the server may decompress to: a whole account's
/// history, years of it.
const MAX_BATCH_BYTES: u64 = 64 << 20;

/// The most a pushed batch may decompress to. The largest real push, a whole
/// imported history, is a few MB; this bounds what a crafted push can make
/// the server hold.
const MAX_PUSH_BYTES: u64 = 16 << 20;

/// The most events one push may hold. Far above anything a phone records (an
/// outbox after weeks offline, an import of years of training); counted
/// while reading, before more are kept.
pub const MAX_EVENTS_PER_PUSH: usize = 100_000;

pub fn pack(events: &[Event]) -> Vec<u8> {
    // Serialising plain data to a buffer can't fail; nor can compressing it.
    let json = serde_json::to_vec(events).unwrap_or_default();
    // In one call, so zstd sizes its window to the input, not to a stream.
    zstd::bulk::compress(&json, LEVEL).unwrap_or_default()
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

fn bad(e: impl fmt::Display) -> CoreError {
    CoreError::InvalidArgument(format!("bad batch: {e}"))
}

fn unpack_at_most(
    packed: &[u8],
    max_bytes: u64,
    max_events: usize,
) -> Result<Vec<Event>, CoreError> {
    let mut json = Vec::new();
    zstd::stream::read::Decoder::new(packed)
        .map_err(bad)?
        .take(max_bytes + 1)
        .read_to_end(&mut json)
        .map_err(bad)?;
    if json.len() as u64 > max_bytes {
        return Err(bad(format!("larger than {max_bytes} bytes")));
    }
    let mut reader = serde_json::Deserializer::from_slice(&json);
    let events = reader.deserialize_seq(AtMost(max_events)).map_err(bad)?;
    reader.end().map_err(bad)?;
    Ok(events)
}

/// A JSON array of events, refused once it holds more than this many.
struct AtMost(usize);

impl<'de> Visitor<'de> for AtMost {
    type Value = Vec<Event>;

    fn expecting(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "an array of at most {} events", self.0)
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> Result<Vec<Event>, A::Error> {
        let mut events = Vec::new();
        while let Some(event) = seq.next_element()? {
            if events.len() == self.0 {
                return Err(serde::de::Error::custom(format!(
                    "more than {} events",
                    self.0
                )));
            }
            events.push(event);
        }
        Ok(events)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::events::{Fact, TemplateDeleted};

    fn event(n: usize) -> Event {
        Event {
            seq: 0,
            id: format!("e{n}"),
            at: 1,
            fact: Fact::TemplateDeleted(TemplateDeleted {
                template_id: "t".into(),
            }),
        }
    }

    #[test]
    fn unpack_reverses_pack() {
        let events: Vec<Event> = (0..3).map(event).collect();
        assert_eq!(unpack(&pack(&events)).unwrap(), events);
    }

    #[test]
    fn unpack_push_takes_a_push_at_the_limit_and_refuses_one_past_it() {
        let events: Vec<Event> = (0..MAX_EVENTS_PER_PUSH).map(event).collect();
        assert_eq!(
            unpack_push(&pack(&events)).unwrap().len(),
            MAX_EVENTS_PER_PUSH
        );
        let more: Vec<Event> = (0..=MAX_EVENTS_PER_PUSH).map(event).collect();
        assert!(matches!(
            unpack_push(&pack(&more)),
            Err(CoreError::InvalidArgument(_))
        ));
        assert_eq!(unpack(&pack(&more)).unwrap().len(), MAX_EVENTS_PER_PUSH + 1);
    }

    #[test]
    fn unpack_refuses_a_batch_that_expands_past_its_limit() {
        let padded = Event {
            id: "x".repeat(MAX_PUSH_BYTES as usize),
            ..event(0)
        };
        let packed = pack(&[padded]);
        assert!(matches!(
            unpack_push(&packed),
            Err(CoreError::InvalidArgument(_))
        ));
        assert_eq!(unpack(&packed).unwrap().len(), 1);
        let zeros = vec![b' '; MAX_BATCH_BYTES as usize + 1];
        let packed = zstd::encode_all(zeros.as_slice(), LEVEL).unwrap();
        assert!(matches!(
            unpack(&packed),
            Err(CoreError::InvalidArgument(_))
        ));
    }

    #[test]
    fn unpack_refuses_what_is_not_an_array_of_events() {
        for json in [&b"[{\"id\":\"e\"}]"[..], b"{}", b"[1]", b"[] extra"] {
            let packed = zstd::encode_all(json, LEVEL).unwrap();
            assert!(
                unpack(&packed).is_err(),
                "{}",
                String::from_utf8_lossy(json)
            );
        }
    }
}
