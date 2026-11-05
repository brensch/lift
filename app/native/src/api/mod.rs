//! What Dart sees (generated into `lib/gen/native` by flutter_rust_bridge).
//! Accounts are opened by path and used by handle: the signed-in user's
//! file, and in-memory ones (the tutorial's sandbox, tests).

pub mod logs;

use std::path::PathBuf;

use schlift_core::sync::{pack, unpack};

use crate::registry::{insert, remove, with_store};
use crate::store::{file_owner, Store, StoreResult};

fn now_unix() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or_default()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Open the account file at `path` (":memory:" for one that lives only
/// while open) for `user_id`, known as `name`. Returns its handle.
pub fn open_account(path: String, user_id: String, name: String) -> StoreResult<u32> {
    insert(Store::open(&PathBuf::from(path), &user_id, &name)?)
}

pub fn close_account(handle: u32) {
    remove(handle);
}

/// Answer one RPC by its gRPC method name, request and response as proto
/// bytes, and whether it stored events for the server: a write, or a read
/// that recorded an ended workout's heart rate. Errors read `code: message`.
pub fn call(handle: u32, method: String, request: Vec<u8>) -> StoreResult<(Vec<u8>, bool)> {
    with_store(handle, |store| {
        let before = store.pending_count()?;
        let response = store.call(&method, &request, now_unix())?;
        Ok((response, store.pending_count()? > before))
    })
}

/// The last seq the file holds.
pub fn confirmed(handle: u32) -> StoreResult<i64> {
    with_store(handle, |store| store.confirmed())
}

/// What the Sync stream opens with: a seq before the last the file holds,
/// so the server's first event shows whether the histories agree.
pub fn opens_after(handle: u32) -> StoreResult<i64> {
    with_store(handle, |store| store.opens_after())
}

/// Bring in the export at `path`: what in it the file lacks is added, in
/// its places where its history carries on from the file's, otherwise to
/// wait to be placed; nothing is removed. Returns how many events it added.
pub fn import_file(handle: u32, path: String) -> StoreResult<i64> {
    with_store(handle, |store| {
        store.import(&PathBuf::from(path)).map(|added| added as i64)
    })
}

/// What this device recorded that the server hasn't placed, after the
/// pending event numbered `after` (the last one this stream sent): packed
/// for the Sync stream (empty when there's nothing), and the number of the
/// last. Numbers only grow, so a stream sends each event once.
pub fn outbox(handle: u32, after: i64) -> StoreResult<(Vec<u8>, i64)> {
    with_store(handle, |store| {
        let (events, last) = store.pending_after(after)?;
        let packed = if events.is_empty() {
            Vec::new()
        } else {
            pack(&events)
        };
        Ok((packed, last))
    })
}

/// How many events this device recorded that the server hasn't placed.
pub fn pending_count(handle: u32) -> StoreResult<i64> {
    with_store(handle, |store| store.pending_count())
}

/// Events from the server (packed), in its order, and the last seq it
/// holds. Returns whether the account changed under the app.
pub fn receive(handle: u32, packed: Vec<u8>, head: i64) -> StoreResult<bool> {
    let events = if packed.is_empty() {
        Vec::new()
    } else {
        unpack(&packed).map_err(|e| format!("invalid_argument: {e}"))?
    };
    with_store(handle, |store| store.receive(events, head))
}

/// A session partner's workout events (packed) from the server: their
/// workout so far when `whole`, else more of it.
pub fn receive_partner(
    handle: u32,
    partner: String,
    packed: Vec<u8>,
    whole: bool,
) -> StoreResult<()> {
    let events = if packed.is_empty() {
        Vec::new()
    } else {
        unpack(&packed).map_err(|e| format!("invalid_argument: {e}"))?
    };
    with_store(handle, |store| {
        store.receive_partner(&partner, events, whole);
        Ok(())
    })
}

/// Where a partner is up to now (a ParticipantStatus, without who they are),
/// given when they joined and ended from the session; None once they're off
/// show.
pub fn partner_status(
    handle: u32,
    partner: String,
    joined_at: i64,
    ended_at: i64,
) -> StoreResult<Option<Vec<u8>>> {
    with_store(handle, |store| {
        Ok(store.partner_status(&partner, joined_at, ended_at, now_unix()))
    })
}

/// Forget the partners not in `partners`: the session's members now.
pub fn keep_partners(handle: u32, partners: Vec<String>) -> StoreResult<()> {
    with_store(handle, |store| {
        store.keep_partners(&partners);
        Ok(())
    })
}

/// The template library the server sent (a packed
/// ListTemplateLibraryResponse). Returns whether it changed.
pub fn set_library(handle: u32, packed: Vec<u8>) -> StoreResult<bool> {
    with_store(handle, |store| store.set_library(&packed))
}

/// Write the whole account to `dest` (a single SQLite file).
pub fn export_account(handle: u32, dest: String) -> StoreResult<()> {
    with_store(handle, |store| store.export(&PathBuf::from(dest)))
}

/// Whose account the file at `path` holds: the user's id and name.
pub fn account_file_owner(path: String) -> StoreResult<(String, String)> {
    file_owner(&PathBuf::from(path))
}
