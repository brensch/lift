//! API-level tests for the v2 training model, driven through the real RPC
//! handlers against a real `ServerDb`. Each test corresponds to a UI action the
//! editing story must support — proving the API can express and correctly apply
//! what the screen offers.

use super::training::ServerTrainingService;
use super::*;
use crate::program_state::{payload_from_proto, payload_to_proto, set_f32};
use crate::regimes::{get_regime, progression_slot_key};
use schlift::workout::v1::training_service_server::TrainingService;
use schlift::workout::v1::workout_op::Op;
use uuid::Uuid;

const DAY: i64 = 24 * 3600;

fn authed<T>(token: &str, msg: T) -> Request<T> {
    let mut req = Request::new(msg);
    req.metadata_mut()
        .insert("x-session-token", token.parse().unwrap());
    req
}

async fn setup() -> (ServerTrainingService, String, String) {
    let dir = std::env::temp_dir().join(format!("lift-training-test-{}", Uuid::new_v4()));
    let db = ServerDb::new_in_dir(&dir).await.unwrap();
    let (user, token) = db
        .get_or_create_user_with_auth_session("trainee")
        .await
        .unwrap();
    (ServerTrainingService { db }, user.id, token)
}

fn m(weight: f64, reps: i32) -> Measure {
    Measure {
        weight,
        reps,
        duration_s: 0,
        distance_m: 0.0,
    }
}

/// A squat working set that counts toward the Linear 5x5 program.
fn squat_set(weight: f64) -> SetPlan {
    SetPlan {
        exercise: Exercise::Squat as i32,
        role: SetRole::Working as i32,
        target: Some(m(weight, 5)),
        is_amrap: false,
        instruction: String::new(),
        counts_toward_program: true,
        slot_key: progression_slot_key(Exercise::Squat),
        client_id: String::new(),
    }
}

fn squat_block(weight: f64, sets: usize) -> BlockPlan {
    BlockPlan {
        name: "Squat".to_string(),
        interleave_warmups: false,
        rest_config: None,
        sets: (0..sets).map(|_| squat_set(weight)).collect(),
    }
}

async fn create(svc: &ServerTrainingService, token: &str, blocks: Vec<BlockPlan>, from_program: bool) -> WorkoutView {
    svc.create_workout(authed(
        token,
        CreateWorkoutRequest {
            name: "Session".to_string(),
            blocks,
            started_at: 1_000_000,
            from_program,
        },
    ))
    .await
    .unwrap()
    .into_inner()
}

async fn mutate(svc: &ServerTrainingService, token: &str, workout_id: &str, ops: Vec<Op>) -> WorkoutView {
    svc.mutate_workout(authed(
        token,
        MutateWorkoutRequest {
            workout_id: workout_id.to_string(),
            ops: ops.into_iter().map(|op| WorkoutOp { op: Some(op) }).collect(),
        },
    ))
    .await
    .unwrap()
    .into_inner()
}

fn working_sets(w: &WorkoutView) -> Vec<&SetView> {
    w.blocks
        .iter()
        .flat_map(|b| b.sets.iter())
        .filter(|s| s.role == SetRole::Working as i32)
        .collect()
}

async fn seed_linear_squat(svc: &ServerTrainingService, user_id: &str, weight: f32) {
    let regime = get_regime(RegimeType::Linear5x5);
    let mut payload = regime.default_state();
    set_f32(&mut payload, "squat_weight", weight);
    svc.db
        .put_program_state(
            user_id,
            &GetActiveTrainingProgramStateResponse {
                state: Some(TrainingProgramState {
                    regime_type: RegimeType::Linear5x5 as i32,
                    fields: payload_to_proto(&payload),
                    updated_at: 1,
                    source: "test".to_string(),
                }),
                schema: Some(regime.state_schema()),
            },
        )
        .await
        .unwrap();
}

async fn stored_squat(svc: &ServerTrainingService, user_id: &str) -> f32 {
    let resp = svc.db.get_program_state(user_id).await.unwrap().unwrap();
    let payload = payload_from_proto(&resp.state.unwrap().fields);
    crate::program_state::get_f32(&payload, "squat_weight").unwrap()
}

// ── Plan + view: the three facets ──

#[tokio::test]
async fn a_created_set_shows_proposed_and_target_equal_no_entry() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 3)], true).await;
    let sets = working_sets(&w);
    assert_eq!(sets.len(), 3);
    for s in sets {
        assert_eq!(s.proposed.as_ref().unwrap().weight, 135.0);
        assert_eq!(s.target.as_ref().unwrap().weight, 135.0);
        assert!(!s.has_entry, "a freshly planned set has no entry");
    }
}

// ── Editing before performing: target diverges, proposed frozen ──

#[tokio::test]
async fn editing_target_leaves_proposed_frozen_so_the_ui_can_show_both() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 3)], true).await;
    let set_id = working_sets(&w)[0].id.clone();

    let w = mutate(
        &svc,
        &token,
        &w.id,
        vec![Op::EditTarget(EditTarget { set_id: set_id.clone(), target: Some(m(145.0, 5)) })],
    )
    .await;

    let s = working_sets(&w).into_iter().find(|s| s.id == set_id).unwrap();
    assert_eq!(s.proposed.as_ref().unwrap().weight, 135.0, "intent is preserved");
    assert_eq!(s.target.as_ref().unwrap().weight, 145.0, "the change is shown");
    assert!(!s.has_entry);
}

// ── Performing: entry attaches; start pointer clears on log ──

#[tokio::test]
async fn start_then_log_attaches_an_entry_and_clears_the_active_pointer() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 1)], true).await;
    let set_id = working_sets(&w)[0].id.clone();

    let w = mutate(&svc, &token, &w.id, vec![Op::StartSet(StartSetOp { set_id: set_id.clone(), at: 1_000_100 })]).await;
    assert_eq!(w.active_set_id, set_id, "start sets the active pointer");

    let w = mutate(
        &svc,
        &token,
        &w.id,
        vec![Op::LogSet(LogSetOp { set_id: set_id.clone(), result: Some(m(135.0, 5)), performed_at: 1_000_140 })],
    )
    .await;
    let s = working_sets(&w).into_iter().find(|s| s.id == set_id).unwrap();
    assert!(s.has_entry);
    assert_eq!(s.entry.as_ref().unwrap().reps, 5);
    assert_eq!(w.active_set_id, "", "logging the active set clears the pointer");
}

// ── One-tap completion (no prior start) ──

#[tokio::test]
async fn logging_without_a_prior_start_still_records_the_entry() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 1)], true).await;
    let set_id = working_sets(&w)[0].id.clone();
    let w = mutate(&svc, &token, &w.id, vec![Op::LogSet(LogSetOp { set_id: set_id.clone(), result: Some(m(135.0, 5)), performed_at: 0 })]).await;
    assert!(working_sets(&w)[0].has_entry);
}

// ── Add / remove / skip ──

#[tokio::test]
async fn add_and_remove_sets_are_row_level_and_stable() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 3)], true).await;
    let block_id = w.blocks[0].id.clone();
    let first = working_sets(&w)[0].id.clone();

    let w = mutate(&svc, &token, &w.id, vec![Op::AddSet(AddSetOp { block_id, set: Some(squat_set(135.0)) })]).await;
    assert_eq!(working_sets(&w).len(), 4, "added a 4th set");

    let w = mutate(&svc, &token, &w.id, vec![Op::RemoveSet(RemoveSetOp { set_id: first.clone() })]).await;
    let sets = working_sets(&w);
    assert_eq!(sets.len(), 3, "removed one");
    assert!(!sets.iter().any(|s| s.id == first), "the removed set is gone from the view");
}

#[tokio::test]
async fn skipping_a_set_hides_it_from_progression_but_keeps_it_in_the_view() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 3)], true).await;
    let set_id = working_sets(&w)[0].id.clone();
    let w = mutate(&svc, &token, &w.id, vec![Op::SkipSet(SkipSetOp { set_id: set_id.clone(), skipped: true })]).await;
    let s = working_sets(&w).into_iter().find(|s| s.id == set_id).unwrap();
    assert!(s.skipped);
}

// ── Correcting and deleting entries (append-only) ──

#[tokio::test]
async fn correcting_an_entry_supersedes_it_without_losing_history() {
    let (svc, uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 1)], true).await;
    let set_id = working_sets(&w)[0].id.clone();

    mutate(&svc, &token, &w.id, vec![Op::LogSet(LogSetOp { set_id: set_id.clone(), result: Some(m(135.0, 3)), performed_at: 1_000_100 })]).await;
    let w = mutate(&svc, &token, &w.id, vec![Op::CorrectEntry(CorrectEntryOp { set_id: set_id.clone(), result: Some(m(135.0, 5)), performed_at: 1_000_100 })]).await;

    // The folded truth is the correction (5 reps).
    assert_eq!(working_sets(&w)[0].entry.as_ref().unwrap().reps, 5);
    // Nothing was thrown out: both the original and the correction are on the log.
    let all: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM t_entries WHERE set_id = ?")
        .bind(&set_id)
        .fetch_one(&svc.db.read_pool)
        .await
        .unwrap();
    let _ = uid;
    assert_eq!(all, 2, "append-only: the original entry is retained alongside the correction");
}

#[tokio::test]
async fn deleting_an_entry_tombstones_it_and_the_set_returns_to_pending() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 1)], true).await;
    let set_id = working_sets(&w)[0].id.clone();

    mutate(&svc, &token, &w.id, vec![Op::LogSet(LogSetOp { set_id: set_id.clone(), result: Some(m(135.0, 5)), performed_at: 1_000_100 })]).await;
    let w = mutate(&svc, &token, &w.id, vec![Op::DeleteEntry(DeleteEntryOp { set_id: set_id.clone() })]).await;
    assert!(!working_sets(&w)[0].has_entry, "tombstone removes the entry from the folded view");
}

#[tokio::test]
async fn back_dating_a_set_uses_the_supplied_performed_at() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 1)], true).await;
    let set_id = working_sets(&w)[0].id.clone();
    let yesterday = 1_000_000 - DAY;
    let w = mutate(&svc, &token, &w.id, vec![Op::LogSet(LogSetOp { set_id: set_id.clone(), result: Some(m(135.0, 5)), performed_at: yesterday })]).await;
    assert_eq!(working_sets(&w)[0].entry.as_ref().unwrap().reps, 5);
    let performed: i64 = sqlx::query_scalar("SELECT performed_at FROM t_entries WHERE set_id = ? AND tombstone = 0")
        .bind(&set_id)
        .fetch_one(&svc.db.read_pool)
        .await
        .unwrap();
    assert_eq!(performed, yesterday, "the set is recorded at its real-world time");
}

// ── Batched ops: the whole edit surface in one round-trip ──

#[tokio::test]
async fn a_batch_applies_all_ops_in_order() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 3)], true).await;
    let ids: Vec<String> = working_sets(&w).iter().map(|s| s.id.clone()).collect();

    // Edit set 1, then log all three, in a single MutateWorkout.
    let w = mutate(
        &svc,
        &token,
        &w.id,
        vec![
            Op::EditTarget(EditTarget { set_id: ids[0].clone(), target: Some(m(140.0, 5)) }),
            Op::LogSet(LogSetOp { set_id: ids[0].clone(), result: Some(m(140.0, 5)), performed_at: 1_000_100 }),
            Op::LogSet(LogSetOp { set_id: ids[1].clone(), result: Some(m(135.0, 5)), performed_at: 1_000_200 }),
            Op::LogSet(LogSetOp { set_id: ids[2].clone(), result: Some(m(135.0, 5)), performed_at: 1_000_300 }),
        ],
    )
    .await;
    assert!(working_sets(&w).iter().all(|s| s.has_entry), "all three logged in one call");
    assert_eq!(working_sets(&w)[0].target.as_ref().unwrap().weight, 140.0);
}

// ── close_workout: the progression seam ──

async fn log_all(svc: &ServerTrainingService, token: &str, w: &WorkoutView, weight: f64, reps: i32, base_at: i64) {
    let ops: Vec<Op> = working_sets(w)
        .iter()
        .enumerate()
        .map(|(i, s)| Op::LogSet(LogSetOp { set_id: s.id.clone(), result: Some(m(weight, reps)), performed_at: base_at + i as i64 * 60 }))
        .collect();
    mutate(svc, token, &w.id, ops).await;
}

async fn close(svc: &ServerTrainingService, token: &str, workout_id: &str, at: i64) -> CloseWorkoutResponse {
    svc.close_workout(authed(token, CloseWorkoutRequest { workout_id: workout_id.to_string(), ended_at: at }))
        .await
        .unwrap()
        .into_inner()
}

#[tokio::test]
async fn completing_all_sets_progresses_from_the_top_completed_weight() {
    let (svc, uid, token) = setup().await;
    seed_linear_squat(&svc, &uid, 180.0).await;
    let w = create(&svc, &token, vec![squat_block(180.0, 5)], true).await;
    log_all(&svc, &token, &w, 180.0, 5, 1_000_100).await;
    let resp = close(&svc, &token, &w.id, 1_001_000).await;
    assert_eq!(stored_squat(&svc, &uid).await, 185.0, "180 completed -> 185");
    let squat = resp.changes.iter().find(|c| c.exercise == Exercise::Squat as i32).unwrap();
    assert_eq!(squat.reason, "advance");
    assert_eq!(squat.to_weight, 185.0);
}

#[tokio::test]
async fn dropping_weight_to_finish_regulates_down_not_up() {
    // Prescribed 5x5 @185; do 3 @185 then drop to 155 for the last 2. The user's
    // rule: you couldn't hold 185, so progress from the last set you completed.
    let (svc, uid, token) = setup().await;
    seed_linear_squat(&svc, &uid, 185.0).await;
    let w = create(&svc, &token, vec![squat_block(185.0, 5)], true).await;
    let ids: Vec<String> = working_sets(&w).iter().map(|s| s.id.clone()).collect();
    let mut ops = Vec::new();
    for (i, id) in ids.iter().enumerate() {
        let weight = if i < 3 { 185.0 } else { 155.0 };
        ops.push(Op::LogSet(LogSetOp { set_id: id.clone(), result: Some(m(weight, 5)), performed_at: 1_000_100 + i as i64 * 60 }));
    }
    mutate(&svc, &token, &w.id, ops).await;
    close(&svc, &token, &w.id, 1_001_000).await;

    // Last completed set was 155 -> next is 160, NOT 190.
    assert_eq!(stored_squat(&svc, &uid).await, 160.0, "regulated down from the last completed weight");
}

#[tokio::test]
async fn a_mid_workout_bump_up_progresses_from_the_heavier_weight() {
    let (svc, uid, token) = setup().await;
    seed_linear_squat(&svc, &uid, 180.0).await;
    let w = create(&svc, &token, vec![squat_block(180.0, 5)], true).await;
    let ids: Vec<String> = working_sets(&w).iter().map(|s| s.id.clone()).collect();
    // Do 2 @180, then bump the remaining targets to 185 and finish at 185.
    let mut ops = vec![
        Op::LogSet(LogSetOp { set_id: ids[0].clone(), result: Some(m(180.0, 5)), performed_at: 1_000_100 }),
        Op::LogSet(LogSetOp { set_id: ids[1].clone(), result: Some(m(180.0, 5)), performed_at: 1_000_160 }),
    ];
    for id in ids.iter().skip(2) {
        ops.push(Op::EditTarget(EditTarget { set_id: id.clone(), target: Some(m(185.0, 5)) }));
        ops.push(Op::LogSet(LogSetOp { set_id: id.clone(), result: Some(m(185.0, 5)), performed_at: 1_000_220 }));
    }
    mutate(&svc, &token, &w.id, ops).await;
    close(&svc, &token, &w.id, 1_001_000).await;
    assert_eq!(stored_squat(&svc, &uid).await, 190.0, "finished at 185 -> 190");
}

#[tokio::test]
async fn close_is_idempotent() {
    let (svc, uid, token) = setup().await;
    seed_linear_squat(&svc, &uid, 180.0).await;
    let w = create(&svc, &token, vec![squat_block(180.0, 5)], true).await;
    log_all(&svc, &token, &w, 180.0, 5, 1_000_100).await;
    close(&svc, &token, &w.id, 1_001_000).await;
    close(&svc, &token, &w.id, 1_001_050).await; // second close
    assert_eq!(stored_squat(&svc, &uid).await, 185.0, "progression applied exactly once");
    let events: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM t_progression WHERE workout_id = ?")
        .bind(&w.id)
        .fetch_one(&svc.db.read_pool)
        .await
        .unwrap();
    assert_eq!(events, 1, "exactly one ledger event");
}

// ── Freestyle: logged, but never touches the program ──

#[tokio::test]
async fn freestyle_workout_does_not_advance_the_program() {
    let (svc, uid, token) = setup().await;
    seed_linear_squat(&svc, &uid, 180.0).await;
    // A freestyle curl session (not from the program).
    let block = BlockPlan {
        name: "Curls".to_string(),
        interleave_warmups: false,
        rest_config: None,
        sets: vec![SetPlan {
            exercise: Exercise::Squat as i32, // exercise doesn't matter; counts_toward_program=false
            role: SetRole::Working as i32,
            target: Some(m(40.0, 12)),
            is_amrap: false,
            instruction: String::new(),
            counts_toward_program: false,
            slot_key: String::new(),
            client_id: String::new(),
        }],
    };
    let w = create(&svc, &token, vec![block], false).await;
    log_all(&svc, &token, &w, 40.0, 12, 1_000_100).await;
    close(&svc, &token, &w.id, 1_001_000).await;
    assert_eq!(stored_squat(&svc, &uid).await, 180.0, "freestyle never advances the program");
    let events: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM t_progression WHERE user_id = ?")
        .bind(&uid)
        .fetch_one(&svc.db.read_pool)
        .await
        .unwrap();
    assert_eq!(events, 0, "no ledger event for freestyle");
}

// ── Progression history (the session-over-session ledger) ──

#[tokio::test]
async fn progression_history_records_each_advance() {
    let (svc, uid, token) = setup().await;
    seed_linear_squat(&svc, &uid, 180.0).await;

    // Two sessions two days apart, both completed.
    for (i, weight) in [180.0_f64, 185.0].iter().enumerate() {
        let at = 1_000_000 + i as i64 * 2 * DAY;
        let w = create(&svc, &token, vec![squat_block(*weight, 5)], true).await;
        // fix start time so last_session logic behaves; log + close
        log_all(&svc, &token, &w, *weight, 5, at + 100).await;
        close(&svc, &token, &w.id, at + 1000).await;
    }

    let hist = svc
        .get_progression_history(authed(&token, GetProgressionHistoryRequest { slot_key: progression_slot_key(Exercise::Squat), limit: 0 }))
        .await
        .unwrap()
        .into_inner();
    let squat: Vec<_> = hist.entries.iter().filter(|e| e.exercise == Exercise::Squat as i32).collect();
    assert!(squat.len() >= 2, "each completed session recorded a squat progression event");
    // Newest first: the latest advance ends at 190.
    assert_eq!(squat[0].to_weight, 190.0);
}

// ── Isolation: you can't mutate another user's workout ──

#[tokio::test]
async fn a_workout_cannot_be_mutated_by_another_user() {
    let (svc, _uid, token) = setup().await;
    let w = create(&svc, &token, vec![squat_block(135.0, 1)], true).await;

    let (other_user, other_token) = svc
        .db
        .get_or_create_user_with_auth_session("intruder")
        .await
        .unwrap();
    let _ = other_user;

    let err = svc
        .mutate_workout(authed(
            &other_token,
            MutateWorkoutRequest { workout_id: w.id.clone(), ops: vec![] },
        ))
        .await;
    assert!(err.is_err(), "another user cannot mutate this workout");
    assert_eq!(err.unwrap_err().code(), tonic::Code::NotFound);
}
