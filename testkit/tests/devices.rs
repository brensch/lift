//! Several devices of one account, each training offline and syncing when it
//! likes: pushes in pieces, resent, the server's events heard late and in
//! pieces, and the server now and then restored from an older backup.
//! Whatever the interleaving, every device must show the account its events
//! fold to (what it holds, then what it waits to have placed), and once all
//! is synced every device and the server hold the same log and the same
//! account, with every event any device recorded in it once.

use prost::Message;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use schlift_core::account::Account;
use schlift_core::api::{self, Call};
use schlift_core::events::Event;
use schlift_core::pb::{GetHomeRequest, GetWorkoutRequest};
use schlift_native::store::{Store, PUSH_EVENTS};
use schlift_testkit::{onboard, workout, Lifter, BUDGET_MINUTES};
use std::collections::HashSet;
use std::path::Path;

const USER: &str = "0b5e0c1e-3c4f-4d8a-9a51-2f6f0b9d7c11";
const DEVICES: usize = 3;
const STEPS: usize = 60;

/// The server's placement, as `push_events` does it: what it doesn't hold,
/// by id, goes after the head in the order it came.
#[derive(Default)]
struct Server {
    log: Vec<Event>,
    held: HashSet<String>,
}

impl Server {
    /// Restored from a backup of the first `kept` events.
    fn restore(&mut self, kept: usize) {
        self.log.truncate(kept);
        self.held = self.log.iter().map(|e| e.id.clone()).collect();
    }

    fn push(&mut self, events: Vec<Event>) {
        for mut event in events {
            if self.held.insert(event.id.clone()) {
                event.seq = self.log.len() as i64 + 1;
                self.log.push(event);
            }
        }
    }
}

struct Device {
    store: Store,
    lifter: Lifter,
    /// Whether it has a stream whose first events it took: only then does
    /// it push, as the app does.
    connected: bool,
    /// The last pending event this connection sent.
    sent: i64,
}

impl Device {
    /// A stream opened as the app opens one, its first message the server's
    /// events after where the store says, up to `upto` of them (a stream
    /// opened past the head is told the head and ended). Whether it stays.
    fn connect(&mut self, server: &Server, upto: usize) -> bool {
        self.sent = 0;
        let after = self.store.opens_after().unwrap() as usize;
        let head = server.log.len();
        let events = server
            .log
            .get(after..upto.clamp((after + 1).min(head), head))
            .map_or(Vec::new(), <[Event]>::to_vec);
        self.connected = self.store.receive(events, head as i64).is_ok() && after <= head;
        self.connected
    }
}

/// What the app reads, through the same dispatch the store answers with.
fn reads(account: &Account, now: i64) -> Vec<Vec<u8>> {
    let mut account = account.clone();
    let mut call = Call::new(&mut account, now, "read");
    let active = call
        .view()
        .get_active_workout()
        .workout
        .map(|w| w.id)
        .unwrap_or_default();
    let mut out: Vec<Vec<u8>> = [
        (
            "GetHome",
            GetHomeRequest {
                budget_minutes: BUDGET_MINUTES,
            }
            .encode_to_vec(),
        ),
        ("ListWorkoutSummaries", Vec::new()),
        ("GetExerciseProgress", Vec::new()),
        ("GetSettings", Vec::new()),
    ]
    .into_iter()
    .map(|(method, request)| api::call(&mut call, method, &request).unwrap())
    .collect();
    if !active.is_empty() {
        let request = GetWorkoutRequest { workout_id: active }.encode_to_vec();
        out.push(api::call(&mut call, "GetWorkout", &request).unwrap());
    }
    out
}

fn store_reads(store: &mut Store, now: i64) -> Vec<Vec<u8>> {
    let mut out: Vec<Vec<u8>> = [
        (
            "GetHome",
            GetHomeRequest {
                budget_minutes: BUDGET_MINUTES,
            }
            .encode_to_vec(),
        ),
        ("ListWorkoutSummaries", Vec::new()),
        ("GetExerciseProgress", Vec::new()),
        ("GetSettings", Vec::new()),
    ]
    .into_iter()
    .map(|(method, request)| store.call(method, &request, now).unwrap())
    .collect();
    let active = schlift_core::pb::GetActiveWorkoutResponse::decode(
        store.call("GetActiveWorkout", &[], now).unwrap().as_slice(),
    )
    .unwrap()
    .workout
    .map(|w| w.id)
    .unwrap_or_default();
    if !active.is_empty() {
        let request = GetWorkoutRequest { workout_id: active }.encode_to_vec();
        out.push(store.call("GetWorkout", &request, now).unwrap());
    }
    out
}

/// The account a device's file folds to: what it holds, then what waits.
fn folded(store: &Store) -> Account {
    let mut account = Account::fold(&store.events().unwrap());
    for event in store.pending().unwrap() {
        account.replay(&event);
    }
    account
}

fn check(device: &mut Device, n: usize, now: i64, step: &str) {
    let expected = reads(&folded(&device.store), now);
    assert!(
        store_reads(&mut device.store, now) == expected,
        "device {n} shows other than its events fold to, after {step}"
    );
}

fn run(seed: u64) {
    let mut rng = StdRng::seed_from_u64(seed);
    let mut server = Server::default();
    let mut now = 1_780_000_000;
    let mut devices: Vec<Device> = (0..DEVICES)
        .map(|n| Device {
            store: Store::open(Path::new(":memory:"), USER, "").unwrap(),
            lifter: Lifter::new(seed * 10 + n as u64),
            connected: false,
            sent: 0,
        })
        .collect();
    // The first device onboards and syncs; the others start from it.
    onboard(&mut devices[0].store, now).unwrap();
    server.push(devices[0].store.pending().unwrap());
    for device in &mut devices {
        assert!(device.connect(&server, server.log.len()));
    }
    // Every event a device recorded: none may be lost.
    let mut recorded: HashSet<String> = HashSet::new();

    for step in 0..STEPS {
        let n = rng.gen_range(0..DEVICES);
        now += rng.gen_range(60..20_000);
        let roll = rng.gen_range(0..20);
        if roll == 0 {
            // The server restored from an older backup: every stream ends.
            server.restore(rng.gen_range(0..=server.log.len()));
            for device in &mut devices {
                device.connected = false;
            }
            continue;
        }
        let device = &mut devices[n];
        let what = match roll {
            // A whole workout, offline. One already under way (another
            // device's, heard) can make the start refuse: nothing recorded.
            1..=6 => {
                if let Ok(end) = workout(&mut device.store, &mut device.lifter, now) {
                    now = end;
                }
                "a workout"
            }
            // A piece of what waits, on this connection.
            7..=11 if device.connected => {
                let (mut events, last) = device.store.pending_after(device.sent).unwrap();
                assert!(events.len() as i64 <= PUSH_EVENTS);
                let keep = rng.gen_range(0..=events.len());
                if keep == events.len() {
                    device.sent = last;
                }
                events.truncate(keep);
                server.push(events);
                "a push"
            }
            // The connection dropped.
            12..=13 => {
                device.connected = false;
                "a drop"
            }
            // Some of the server's events, heard: a piece, or all of them.
            _ if device.connected => {
                let confirmed = device.store.confirmed().unwrap() as usize;
                let upto = rng.gen_range(confirmed..=server.log.len());
                let events = server.log[confirmed..upto].to_vec();
                device
                    .store
                    .receive(events, server.log.len() as i64)
                    .unwrap();
                "a receive"
            }
            // A new stream: its first message, a piece or all of it.
            _ => {
                let upto = rng.gen_range(0..=server.log.len());
                device.connect(&server, upto);
                "a connect"
            }
        };
        recorded.extend(device.store.pending().unwrap().into_iter().map(|e| e.id));
        check(
            device,
            n,
            now,
            &format!("{what} at step {step} (seed {seed})"),
        );
    }

    // Everything synced: each device connects until it takes the server's
    // events, pushes what waits and hears it back, round after round until
    // a round places nothing.
    loop {
        let before = server.log.len();
        for device in &mut devices {
            let mut tries = 0;
            while !device.connect(&server, server.log.len()) {
                tries += 1;
                assert!(tries < 64, "a device never met the server (seed {seed})");
            }
            server.push(device.store.pending().unwrap());
            let confirmed = device.store.confirmed().unwrap() as usize;
            device
                .store
                .receive(server.log[confirmed..].to_vec(), server.log.len() as i64)
                .unwrap();
        }
        if server.log.len() == before {
            break;
        }
    }
    let account = Account::fold(&server.log);
    let expected = reads(&account, now);
    for (n, device) in devices.iter_mut().enumerate() {
        assert_eq!(device.store.pending_count().unwrap(), 0, "device {n}");
        assert_eq!(device.store.events().unwrap(), server.log, "device {n}");
        assert!(
            store_reads(&mut device.store, now) == expected,
            "device {n} differs from the server's account (seed {seed})"
        );
    }
    let placed: HashSet<String> = server.log.iter().map(|e| e.id.clone()).collect();
    assert_eq!(placed.len(), server.log.len(), "each event once");
    assert!(
        recorded.is_subset(&placed),
        "an event a device recorded was lost (seed {seed})"
    );
    assert!(
        account.workouts.len() > 1,
        "the devices trained: {} workouts",
        account.workouts.len()
    );
}

/// `DEVICE_SEEDS=200` runs more interleavings than CI does.
#[test]
fn devices_syncing_in_any_order_agree() {
    let seeds = std::env::var("DEVICE_SEEDS").map_or(3, |n| n.parse().unwrap());
    for seed in 0..seeds {
        run(seed);
    }
}
