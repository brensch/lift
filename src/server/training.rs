//! TrainingService: the v2 workout API.
//!
//! One write endpoint — `MutateWorkout` — carries a list of typed ops, so the
//! entire edit surface of a workout is a single batchable round-trip. Reads fold
//! the append-only entry log into a `WorkoutView`. `CloseWorkout` is the one
//! place performance turns into program change: it reuses the existing regime
//! machinery (prescription from program state, performance from v2 entries) and
//! appends one idempotent progression event.

use super::*;
use crate::db::training::{MeasureVals, NewBlock, NewEntry, NewSet, NewWorkout, ProgressionWrite};
use crate::db::{TrainingBlockRow, TrainingEntryRow, TrainingSetRow};
use crate::program_state::{payload_from_proto, payload_to_proto};
use crate::regimes::{fake_completed_workout, get_regime, progression_slot_key};
use crate::schplanner::{prescribed_slots_from_groups, PrescribedSlot, SchplannerInsights, SchplannerSlotOutcome};
use crate::time::now_unix;
use schlift::workout::v1::training_service_server::TrainingService;
use schlift::workout::v1::workout_op::Op;
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Clone)]
pub struct ServerTrainingService {
    pub db: ServerDb,
}

impl ServerTrainingService {
    fn new_set(block_id: &str, ord: i32, plan: &SetPlan) -> NewSet {
        let m = plan.target.unwrap_or_default();
        NewSet {
            id: if plan.client_id.is_empty() {
                Uuid::new_v4().to_string()
            } else {
                plan.client_id.clone()
            },
            block_id: block_id.to_string(),
            ord,
            exercise: plan.exercise,
            role: plan.role,
            weight: m.weight as f32,
            reps: m.reps,
            duration_s: m.duration_s,
            distance_m: m.distance_m as f32,
            is_amrap: plan.is_amrap,
            instruction: plan.instruction.clone(),
            counts_toward_program: plan.counts_toward_program,
            slot_key: plan.slot_key.clone(),
        }
    }

    fn new_block(ord: i32, plan: &BlockPlan) -> NewBlock {
        let block_id = Uuid::new_v4().to_string();
        let rest = plan.rest_config.unwrap_or_default();
        let sets = plan
            .sets
            .iter()
            .enumerate()
            .map(|(i, s)| Self::new_set(&block_id, i as i32, s))
            .collect();
        NewBlock {
            id: block_id,
            ord,
            name: plan.name.clone(),
            interleave_warmups: plan.interleave_warmups,
            rest_success: rest.rest_after_success,
            rest_failure: rest.rest_after_failure,
            rest_warmup: rest.rest_after_warmup,
            rest_last_warmup: rest.rest_after_last_warmup,
            sets,
        }
    }

    /// Build the folded WorkoutView: sets in order under their blocks, each with
    /// its newest non-tombstoned entry (if any).
    async fn view(&self, user_id: &str, workout_id: &str) -> Result<Option<WorkoutView>, Status> {
        let Some(w) = self
            .db
            .t_get_workout(user_id, workout_id)
            .await
            .map_err(internal_error)?
        else {
            return Ok(None);
        };
        let blocks = self.db.t_get_blocks(workout_id).await.map_err(internal_error)?;
        let sets = self.db.t_get_sets(workout_id).await.map_err(internal_error)?;
        let entries = self.db.t_get_entries(workout_id).await.map_err(internal_error)?;
        let entry_by_set: HashMap<&str, &TrainingEntryRow> =
            entries.iter().map(|e| (e.set_id.as_str(), e)).collect();

        let mut block_views: Vec<BlockView> = blocks
            .iter()
            .map(block_view)
            .collect();
        let block_index: HashMap<String, usize> = block_views
            .iter()
            .enumerate()
            .map(|(i, b)| (b.id.clone(), i))
            .collect();

        for s in &sets {
            if let Some(&idx) = block_index.get(&s.block_id) {
                block_views[idx]
                    .sets
                    .push(set_view(s, entry_by_set.get(s.id.as_str()).copied()));
            }
        }

        Ok(Some(WorkoutView {
            id: w.id,
            name: w.name,
            start_time: w.start_time,
            end_time: w.end_time,
            session_id: w.session_id,
            blocks: block_views,
            active_set_id: w.active_set_id,
            active_started_at: w.active_started_at,
            from_program: w.from_program,
            closed: w.closed_at != 0,
        }))
    }

    async fn apply_op(&self, user_id: &str, workout_id: &str, op: Op) -> Result<(), Status> {
        let now = now_unix();
        match op {
            Op::EditTarget(o) => {
                self.db
                    .t_edit_target(user_id, &o.set_id, vals(&o.target.unwrap_or_default()))
                    .await
                    .map_err(internal_error)?;
            }
            Op::AddSet(o) => {
                let plan = o.set.ok_or_else(|| Status::invalid_argument("add_set missing set"))?;
                // Append after the current max order.
                let ord = self.next_set_ord(workout_id).await?;
                let set = Self::new_set(&o.block_id, ord, &plan);
                self.db.t_add_set(user_id, workout_id, &set).await.map_err(internal_error)?;
            }
            Op::RemoveSet(o) => {
                self.db.t_remove_set(user_id, &o.set_id).await.map_err(internal_error)?;
            }
            Op::SkipSet(o) => {
                self.db.t_skip_set(user_id, &o.set_id, o.skipped).await.map_err(internal_error)?;
            }
            Op::StartSet(o) => {
                let at = if o.at > 0 { o.at } else { now };
                self.db.t_set_active(user_id, workout_id, &o.set_id, at).await.map_err(internal_error)?;
            }
            Op::LogSet(o) => {
                let performed_at = if o.performed_at > 0 { o.performed_at } else { now };
                let e = entry_vals(&o.result.unwrap_or_default(), performed_at, now, false, &o.set_id);
                self.db.t_append_entry(user_id, workout_id, &e).await.map_err(internal_error)?;
            }
            Op::CorrectEntry(o) => {
                let performed_at = if o.performed_at > 0 { o.performed_at } else { now };
                let e = entry_vals(&o.result.unwrap_or_default(), performed_at, now, false, &o.set_id);
                self.db.t_append_entry(user_id, workout_id, &e).await.map_err(internal_error)?;
            }
            Op::DeleteEntry(o) => {
                let e = NewEntry { set_id: o.set_id.clone(), vals: MeasureVals::default(), performed_at: now, recorded_at: now, tombstone: true };
                self.db.t_append_entry(user_id, workout_id, &e).await.map_err(internal_error)?;
            }
            Op::ReorderBlocks(o) => {
                self.db.t_reorder_blocks(user_id, workout_id, &o.block_ids).await.map_err(internal_error)?;
            }
            Op::AddBlock(o) => {
                let plan = o.block.ok_or_else(|| Status::invalid_argument("add_block missing block"))?;
                let ord = self.next_block_ord(workout_id).await?;
                let block = Self::new_block(ord, &plan);
                self.db.t_add_block(user_id, workout_id, &block).await.map_err(internal_error)?;
            }
        }
        Ok(())
    }

    async fn next_set_ord(&self, workout_id: &str) -> Result<i32, Status> {
        let sets = self.db.t_get_sets(workout_id).await.map_err(internal_error)?;
        Ok(sets.iter().map(|s| s.ord).max().map(|m| m + 1).unwrap_or(0))
    }

    async fn next_block_ord(&self, workout_id: &str) -> Result<i32, Status> {
        let blocks = self.db.t_get_blocks(workout_id).await.map_err(internal_error)?;
        Ok(blocks.iter().map(|b| b.ord).max().map(|m| m + 1).unwrap_or(0))
    }
}

fn vals(m: &Measure) -> MeasureVals {
    MeasureVals {
        weight: m.weight as f32,
        reps: m.reps,
        duration_s: m.duration_s,
        distance_m: m.distance_m as f32,
    }
}

fn entry_vals(m: &Measure, performed_at: i64, recorded_at: i64, tombstone: bool, set_id: &str) -> NewEntry {
    NewEntry {
        set_id: set_id.to_string(),
        vals: vals(m),
        performed_at,
        recorded_at,
        tombstone,
    }
}

fn measure(weight: f32, reps: i32, dur: i32, dist: f32) -> Measure {
    Measure {
        weight: weight as f64,
        reps,
        duration_s: dur,
        distance_m: dist as f64,
    }
}

fn block_view(b: &TrainingBlockRow) -> BlockView {
    BlockView {
        id: b.id.clone(),
        order: b.ord,
        name: b.name.clone(),
        interleave_warmups: b.interleave_warmups,
        rest_config: Some(RestConfig {
            rest_after_success: b.rest_success,
            rest_after_failure: b.rest_failure,
            rest_after_warmup: b.rest_warmup,
            rest_after_last_warmup: b.rest_last_warmup,
        }),
        sets: Vec::new(),
    }
}

fn set_view(s: &TrainingSetRow, entry: Option<&TrainingEntryRow>) -> SetView {
    SetView {
        id: s.id.clone(),
        block_id: s.block_id.clone(),
        order: s.ord,
        exercise: s.exercise,
        role: s.role,
        proposed: Some(measure(s.proposed_weight, s.proposed_reps, s.proposed_duration_s, s.proposed_distance_m)),
        target: Some(measure(s.target_weight, s.target_reps, s.target_duration_s, s.target_distance_m)),
        entry: entry.map(|e| measure(e.weight, e.reps, e.duration_s, e.distance_m)),
        has_entry: entry.is_some(),
        skipped: s.skipped,
        is_amrap: s.is_amrap,
        instruction: s.instruction.clone(),
        counts_toward_program: s.counts_toward_program,
        slot_key: s.slot_key.clone(),
    }
}

/// Build slot outcomes from the v2 sets + folded entries, given the regime's
/// prescription for this session. Mirrors `schplanner::summarize_slot_outcomes`,
/// but sources the performance from v2 entries and orders "last set" by the
/// real-world `performed_at` — the "last completed set is your current capacity"
/// rule. Only working sets that count toward the program and match a prescribed
/// slot participate; freestyle and warmup sets are ignored.
fn slot_outcomes_from_v2(
    prescribed: &HashMap<String, PrescribedSlot>,
    sets: &[TrainingSetRow],
    entries: &[TrainingEntryRow],
) -> HashMap<String, SchplannerSlotOutcome> {
    let entry_by_set: HashMap<&str, &TrainingEntryRow> =
        entries.iter().map(|e| (e.set_id.as_str(), e)).collect();

    // slot_key -> the performed working sets in that slot
    let mut by_slot: HashMap<String, Vec<(&TrainingSetRow, &TrainingEntryRow)>> = HashMap::new();
    for set in sets {
        if set.role != SetRole::Working as i32 || !set.counts_toward_program || set.skipped {
            continue;
        }
        let Some(entry) = entry_by_set.get(set.id.as_str()) else {
            continue;
        };
        // Prefer the set's own slot_key; fall back to exercise identity.
        let slot_key = if set.slot_key.is_empty() {
            progression_slot_key(Exercise::try_from(set.exercise).unwrap_or(Exercise::Unspecified))
        } else {
            set.slot_key.clone()
        };
        if !prescribed.contains_key(&slot_key) {
            continue;
        }
        by_slot.entry(slot_key).or_default().push((set, entry));
    }

    let mut outcomes = HashMap::new();
    for (slot_key, mut performed) in by_slot {
        // Order by set position for "top set" (last by workout order).
        performed.sort_by_key(|(s, _)| s.ord);
        let slot = &prescribed[&slot_key];
        let target_reps = slot.target_reps;

        let completed_sets = performed.len();
        let successful_sets = performed.iter().filter(|(_, e)| e.reps >= target_reps).count();
        // "Last completed set is your current capacity" — most recent by real-world time.
        let last_completed_actual_weight = performed
            .iter()
            .max_by_key(|(_, e)| e.performed_at)
            .map(|(_, e)| e.weight);
        let last_successful_actual_weight = performed
            .iter()
            .filter(|(_, e)| e.reps >= target_reps)
            .max_by_key(|(_, e)| e.performed_at)
            .map(|(_, e)| e.weight);
        let top_set_actual_reps = performed.last().map(|(_, e)| e.reps).unwrap_or(0);

        outcomes.insert(
            slot_key.clone(),
            SchplannerSlotOutcome {
                slot_key,
                exercise: slot.exercise,
                tier: slot.tier.clone(),
                rule: slot.rule,
                planned_sets: slot.set_count,
                completed_sets,
                successful_sets,
                last_completed_actual_weight,
                last_successful_actual_weight,
                top_set_target_reps: target_reps,
                top_set_actual_reps,
                amrap_success_threshold: slot.amrap_success_threshold,
                workout_ended: true,
            },
        );
    }
    outcomes
}

/// The top (heaviest) working-set target weight per slot in a proposal. Used to
/// express a progression change as "next prescribed weight vs current."
fn slot_top_weights(proposal: &crate::program_state::ProposeResult) -> HashMap<String, f32> {
    let mut out: HashMap<String, f32> = HashMap::new();
    for group in &proposal.proposed_groups {
        for config in &group.exercise_configs {
            for ws in &config.working_sets {
                let Some(hint) = ws.progression_hint.as_ref() else {
                    continue;
                };
                let e = out.entry(hint.slot_key.clone()).or_insert(0.0);
                if ws.target_weight > *e {
                    *e = ws.target_weight;
                }
            }
        }
    }
    out
}

#[tonic::async_trait]
impl TrainingService for ServerTrainingService {
    async fn create_workout(
        &self,
        request: Request<CreateWorkoutRequest>,
    ) -> Result<Response<WorkoutView>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "CreateWorkout", %user_id, "request");
        let workout_id = Uuid::new_v4().to_string();
        let start = if req.started_at > 0 { req.started_at } else { now_unix() };
        let blocks: Vec<NewBlock> = req
            .blocks
            .iter()
            .enumerate()
            .map(|(i, b)| Self::new_block(i as i32, b))
            .collect();
        let session_id = self
            .db
            .get_user_current_session(&user_id)
            .await
            .map_err(internal_error)?
            .unwrap_or_default();
        let new_workout = NewWorkout {
            id: workout_id.clone(),
            name: req.name.clone(),
            start_time: start,
            session_id,
            from_program: req.from_program,
        };
        self.db
            .t_create_workout(&user_id, &new_workout, &blocks)
            .await
            .map_err(internal_error)?;
        let view = self
            .view(&user_id, &workout_id)
            .await?
            .ok_or_else(|| Status::internal("workout vanished after create"))?;
        Ok(Response::new(view))
    }

    async fn mutate_workout(
        &self,
        request: Request<MutateWorkoutRequest>,
    ) -> Result<Response<WorkoutView>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "MutateWorkout", %user_id, workout_id = %req.workout_id, ops = req.ops.len(), "request");
        // Guard: workout must exist and belong to the caller.
        if self.db.t_get_workout(&user_id, &req.workout_id).await.map_err(internal_error)?.is_none() {
            return Err(Status::not_found("workout not found"));
        }
        for op in req.ops {
            if let Some(op) = op.op {
                self.apply_op(&user_id, &req.workout_id, op).await?;
            }
        }
        let view = self
            .view(&user_id, &req.workout_id)
            .await?
            .ok_or_else(|| Status::not_found("workout not found"))?;
        Ok(Response::new(view))
    }

    async fn get_workout_v2(
        &self,
        request: Request<GetWorkoutV2Request>,
    ) -> Result<Response<WorkoutView>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let view = self
            .view(&user_id, &req.workout_id)
            .await?
            .ok_or_else(|| Status::not_found("workout not found"))?;
        Ok(Response::new(view))
    }

    async fn close_workout(
        &self,
        request: Request<CloseWorkoutRequest>,
    ) -> Result<Response<CloseWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let now = if req.ended_at > 0 { req.ended_at } else { now_unix() };
        info!(rpc = "CloseWorkout", %user_id, workout_id = %req.workout_id, "request");

        let workout = self
            .db
            .t_get_workout(&user_id, &req.workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("workout not found"))?;
        self.db
            .t_end_workout(&user_id, &req.workout_id, now)
            .await
            .map_err(internal_error)?;

        // Load current program state (shared _latest snapshot with v1).
        let state_resp = self
            .db
            .get_program_state(&user_id)
            .await
            .map_err(internal_error)?;
        let (regime_type, prev_payload) = match state_resp {
            Some(resp) => {
                let state = resp.state.unwrap_or_default();
                let rt = RegimeType::try_from(state.regime_type).unwrap_or(RegimeType::Linear5x5);
                (rt, payload_from_proto(&state.fields))
            }
            None => {
                let rt = RegimeType::Linear5x5;
                (rt, get_regime(rt).default_state())
            }
        };
        let regime = get_regime(regime_type);

        // Freestyle workouts never touch the program.
        if !workout.from_program {
            let view = self.view(&user_id, &req.workout_id).await?.unwrap();
            return Ok(Response::new(CloseWorkoutResponse { workout: Some(view), changes: vec![] }));
        }

        // Prescription: derived fresh from program state, temporally adjusted —
        // identical to the v1 reconciliation, so progression semantics match.
        let adjusted_prev = regime.apply_temporal_adjustments_for_proposal(&prev_payload, workout.start_time, now);
        let insights = SchplannerInsights::default();
        let before_proposal = regime.propose_from_state(&adjusted_prev, workout.start_time, now, &insights);
        let prescribed = prescribed_slots_from_groups(&before_proposal.proposed_groups);
        let before_weights = slot_top_weights(&before_proposal);

        // Performance: from v2 sets + entries.
        let sets = self.db.t_get_sets(&req.workout_id).await.map_err(internal_error)?;
        let entries = self.db.t_get_entries(&req.workout_id).await.map_err(internal_error)?;
        let outcomes = slot_outcomes_from_v2(&prescribed, &sets, &entries);

        // Advance.
        let mut payload = adjusted_prev.clone();
        regime.transition_state_on_workout_completed(&mut payload, &fake_completed_workout(now), &outcomes);

        // What changed, expressed as next-prescribed-weight vs current.
        let after_proposal = regime.propose_from_state(&payload, now, now + 1, &insights);
        let after_weights = slot_top_weights(&after_proposal);
        let changes = build_changes(&prescribed, &outcomes, &before_weights, &after_weights);

        // Persist: append ledger event + refresh _latest, idempotent by workout.
        let response = GetActiveTrainingProgramStateResponse {
            state: Some(TrainingProgramState {
                regime_type: regime_type as i32,
                fields: payload_to_proto(&payload),
                updated_at: now,
                source: format!("workout_completed:{}", req.workout_id),
            }),
            schema: Some(regime.state_schema()),
        };
        let changes_blob = encode_changes(&changes);
        let state_before = serde_json::to_vec(&adjusted_prev).unwrap_or_default();
        let state_after = serde_json::to_vec(&payload).unwrap_or_default();
        let latest_blob = prost::Message::encode_to_vec(&response);
        self.db
            .t_apply_progression(
                &user_id,
                &ProgressionWrite {
                    workout_id: &req.workout_id,
                    at: now,
                    reason: &overall_reason(&changes),
                    state_before: &state_before,
                    state_after: &state_after,
                    changes_blob: &changes_blob,
                    latest_response_blob: &latest_blob,
                },
            )
            .await
            .map_err(internal_error)?;

        let view = self.view(&user_id, &req.workout_id).await?.unwrap();
        Ok(Response::new(CloseWorkoutResponse { workout: Some(view), changes }))
    }

    async fn get_progression_history(
        &self,
        request: Request<GetProgressionHistoryRequest>,
    ) -> Result<Response<GetProgressionHistoryResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let limit = if req.limit > 0 { req.limit as i64 } else { 100 };
        let rows = self.db.t_progression_history(&user_id, limit).await.map_err(internal_error)?;
        let mut entries = Vec::new();
        for row in rows {
            let changes: Vec<ProgressionChange> = decode_changes(&row.changes_blob);
            for c in changes {
                if !req.slot_key.is_empty() && c.slot_key != req.slot_key {
                    continue;
                }
                entries.push(ProgressionHistoryEntry {
                    workout_id: row.workout_id.clone(),
                    at: row.at,
                    exercise: c.exercise,
                    slot_key: c.slot_key,
                    reason: c.reason,
                    from_weight: c.from_weight,
                    to_weight: c.to_weight,
                });
            }
        }
        Ok(Response::new(GetProgressionHistoryResponse { entries }))
    }
}

fn build_changes(
    prescribed: &HashMap<String, PrescribedSlot>,
    outcomes: &HashMap<String, SchplannerSlotOutcome>,
    before: &HashMap<String, f32>,
    after: &HashMap<String, f32>,
) -> Vec<ProgressionChange> {
    let mut out = Vec::new();
    for (slot_key, slot) in prescribed {
        let from = before.get(slot_key).copied().unwrap_or(0.0);
        let to = after.get(slot_key).copied().unwrap_or(from);
        if (from - to).abs() < 0.01 && outcomes.get(slot_key).is_none() {
            continue; // untrained, unchanged — nothing to report
        }
        let reason = if to > from + 0.01 {
            "advance"
        } else if to < from - 0.01 {
            "deload"
        } else {
            "hold"
        };
        let headline = headline_for(reason, outcomes.get(slot_key), to);
        out.push(ProgressionChange {
            exercise: slot.exercise as i32,
            slot_key: slot_key.clone(),
            reason: reason.to_string(),
            from_weight: from as f64,
            to_weight: to as f64,
            headline,
        });
    }
    out.sort_by(|a, b| a.slot_key.cmp(&b.slot_key));
    out
}

fn headline_for(reason: &str, outcome: Option<&SchplannerSlotOutcome>, to: f32) -> String {
    match reason {
        "advance" => {
            if let Some(o) = outcome {
                if let Some(w) = o.last_successful_actual_weight {
                    return format!("Best set {}×{} — increasing to {}", trim(w), o.top_set_actual_reps.max(o.top_set_target_reps), trim(to));
                }
            }
            format!("Increasing to {}", trim(to))
        }
        "deload" => {
            if let Some(o) = outcome {
                if let Some(w) = o.last_completed_actual_weight {
                    return format!("Finished at {} — setting {} next", trim(w), trim(to));
                }
            }
            format!("Backing off to {}", trim(to))
        }
        _ => format!("Holding at {}", trim(to)),
    }
}

fn trim(w: f32) -> String {
    if (w - w.round()).abs() < 0.01 {
        format!("{}", w.round() as i64)
    } else {
        format!("{w}")
    }
}

fn overall_reason(changes: &[ProgressionChange]) -> String {
    if changes.iter().any(|c| c.reason == "advance") {
        "advance".to_string()
    } else if changes.iter().any(|c| c.reason == "deload") {
        "deload".to_string()
    } else {
        "hold".to_string()
    }
}

fn encode_changes(changes: &[ProgressionChange]) -> Vec<u8> {
    let wrapped = GetProgressionHistoryResponse {
        entries: changes
            .iter()
            .map(|c| ProgressionHistoryEntry {
                workout_id: String::new(),
                at: 0,
                exercise: c.exercise,
                slot_key: c.slot_key.clone(),
                reason: c.reason.clone(),
                from_weight: c.from_weight,
                to_weight: c.to_weight,
            })
            .collect(),
    };
    prost::Message::encode_to_vec(&wrapped)
}

fn decode_changes(blob: &[u8]) -> Vec<ProgressionChange> {
    let Ok(wrapped) = <GetProgressionHistoryResponse as prost::Message>::decode(blob) else {
        return vec![];
    };
    wrapped
        .entries
        .into_iter()
        .map(|e| ProgressionChange {
            exercise: e.exercise,
            slot_key: e.slot_key,
            reason: e.reason,
            from_weight: e.from_weight,
            to_weight: e.to_weight,
            headline: String::new(),
        })
        .collect()
}
