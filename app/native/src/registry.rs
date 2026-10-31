//! The open accounts, by handle.

use std::collections::HashMap;
use std::sync::Mutex;

use crate::store::{Store, StoreResult};

static STORES: Mutex<Option<Stores>> = Mutex::new(None);

#[derive(Default)]
struct Stores {
    next: u32,
    open: HashMap<u32, Store>,
}

const POISONED: &str = "storage: the store lock is poisoned";

pub fn insert(store: Store) -> StoreResult<u32> {
    let mut guard = STORES.lock().map_err(|_| POISONED)?;
    let stores = guard.get_or_insert_with(Stores::default);
    stores.next += 1;
    stores.open.insert(stores.next, store);
    Ok(stores.next)
}

pub fn remove(handle: u32) {
    if let Ok(mut guard) = STORES.lock() {
        if let Some(stores) = guard.as_mut() {
            stores.open.remove(&handle);
        }
    }
}

pub fn with_store<R>(handle: u32, f: impl FnOnce(&mut Store) -> StoreResult<R>) -> StoreResult<R> {
    let mut guard = STORES.lock().map_err(|_| POISONED)?;
    let store = guard
        .as_mut()
        .and_then(|stores| stores.open.get_mut(&handle))
        .ok_or_else(|| "failed_precondition: that account is closed".to_string())?;
    f(store)
}
