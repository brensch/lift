//! Schlift's domain, with no IO: one implementation of every rule, linked by
//! the server and the app alike. See `docs/plans/local-first.md`.

/// The proto messages (`workout.v1`).
pub mod pb {
    include!(concat!(env!("OUT_DIR"), "/workout.v1.rs"));
}

pub mod account;
pub mod api;
pub mod exercise_catalog;
pub mod exercise_progress;
pub mod history;
pub mod ids;
pub mod messages;
pub mod onboarding;
pub mod progress;
pub mod projection;
pub mod recovery;
pub mod sync;
pub mod template_library;
pub mod time;
pub mod volume;
pub mod weight_units;
pub mod workout;
