//! What Dart sees (generated into `lib/gen/native` by flutter_rust_bridge).
//! Accounts are opened by path and used by handle: the signed-in user's
//! file, and in-memory ones (the tutorial's sandbox, tests).

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
/// bytes. Errors read `code: message`.
pub fn call(handle: u32, method: String, request: Vec<u8>) -> StoreResult<Vec<u8>> {
    call_at(handle, method, request, now_unix())
}

/// [call] with the clock set to `now` (unix seconds): for seeding a
/// believable past, and for tests.
pub fn call_at(handle: u32, method: String, request: Vec<u8>, now: i64) -> StoreResult<Vec<u8>> {
    with_store(handle, |store| store.call(&method, &request, now))
}

/// The events the server hasn't acknowledged, packed for the Sync stream,
/// and the seq of the last one (0 when there are none).
pub fn outbox(handle: u32) -> StoreResult<(Vec<u8>, i64)> {
    with_store(handle, |store| {
        let events = store.events_after(store.acked()?)?;
        let last = events.last().map(|e| e.seq).unwrap_or(0);
        Ok((
            if events.is_empty() {
                Vec::new()
            } else {
                pack(events)
            },
            last,
        ))
    })
}

/// The server holds everything up to `head`.
pub fn acked(handle: u32, head: i64) -> StoreResult<()> {
    with_store(handle, |store| store.set_acked(head))
}

/// The account's seq and the last one the server acknowledged.
pub fn sync_state(handle: u32) -> StoreResult<(i64, i64)> {
    with_store(handle, |store| Ok((store.seq(), store.acked()?)))
}

/// Events pulled from the server (packed), appended after this file's own.
pub fn restore(handle: u32, packed: Vec<u8>) -> StoreResult<i64> {
    let events = unpack(&packed).map_err(|e| format!("invalid_argument: {e}"))?;
    with_store(handle, |store| store.restore(events))
}

/// Write the whole account to `dest` (a single SQLite file).
pub fn export_account(handle: u32, dest: String) -> StoreResult<()> {
    with_store(handle, |store| store.export(&PathBuf::from(dest)))
}

/// Whose account the file at `path` holds: the user's id and name.
pub fn account_file_owner(path: String) -> StoreResult<(String, String)> {
    file_owner(&PathBuf::from(path))
}
