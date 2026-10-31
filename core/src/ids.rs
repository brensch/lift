//! Ids made while applying an event. Each is derived from the event's own
//! id, so replaying the event anywhere makes the same ones.

use uuid::Uuid;

pub struct Ids {
    base: String,
    next: usize,
}

impl Ids {
    pub fn new(event_id: &str) -> Self {
        Self {
            base: event_id.to_string(),
            next: 0,
        }
    }

    /// The next id: `uuid5(NAMESPACE_OID, "{event_id}:{n}")`.
    pub fn new_id(&mut self) -> String {
        let id = derived_id(&self.base, self.next);
        self.next += 1;
        id
    }
}

/// An id derived from another: `uuid5(NAMESPACE_OID, "{base}:{n}")`.
pub fn derived_id(base: &str, n: usize) -> String {
    Uuid::new_v5(&Uuid::NAMESPACE_OID, format!("{base}:{n}").as_bytes()).to_string()
}
