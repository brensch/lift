//! Schlift's domain, with no IO: one implementation of every rule, linked by
//! the server and the app alike. See `docs/architecture/local-first.md`.

/// The proto messages (`workout.v1`).
/// The rules accounts fold by: a hash of this crate's sources, the protos
/// and every dependency's version (build.rs). A snapshot folded by other
/// rules is not used.
pub const FOLD: &str = env!("SCHLIFT_FOLD");

pub mod pb {
    include!(concat!(env!("OUT_DIR"), "/workout.v1.rs"));
}

pub mod account;
pub mod api;
pub mod events;
pub mod exercise_progress;
pub mod history;
pub mod ids;
pub mod migrate;
pub mod onboarding;
pub mod plan;
pub mod program;
pub mod progress;
pub mod projection;
pub mod recovery;
pub mod rotation;
pub mod session;
pub mod simulate;
pub mod snapshot;
pub mod sync;
pub mod template_library;
pub mod volume;
pub mod weight_units;
pub mod workout;
