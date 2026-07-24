# Historised Program State Machine Refactor Plan

> ## ⚠️ Historical design plan — not a description of the system
>
> This was written *before* the adaptive regime work, in future tense. It is kept
> for context on why things are shaped the way they are. For how program state
> actually works today, read
> [`docs/architecture/regimes.md`](../architecture/regimes.md).
>
> Much of this plan shipped: the `WorkoutRegime` trait, typed `StatePayload`
> state, schema-driven settings and onboarding, per-regime state machines, and
> progression on `EndWorkout`.
>
> **The "historised" part did not.** The plan called for an append-only event log
> with replay; what was built keeps a single current snapshot per user.
>
> | Planned below | Actual |
> |---|---|
> | `training_program_state_events` table | Does not exist |
> | `append_program_state_event` | Does not exist |
> | `get_program_state_history` | Does not exist |
> | Replay events → latest snapshot | No replay; `training_program_state_latest` written directly |
> | `GetTrainingProgramStateHistory` RPC | In the proto, returns `Status::unimplemented` |
> | `ApplyPendingStateUpdate` RPC | Never added to the proto |
>
> Idempotency — a motivation for the event log — is instead handled by the
> `program_progression_applied` ledger, which claims a `workout_id` in the same
> transaction that writes the new state.
>
> Consequences of the snapshot-only design: program state changes are not
> auditable, a bad progression cannot be rolled back by replaying, and there is
> no data to power a "how did my training max get here?" view.
>
> Whether to build the event log is still open. If you do, re-derive this against
> the current code rather than assuming the surrounding details still hold.

## Goal

Replace the current `UserWorkoutConfig + regime_state_json + history-derived progression` approach with a single backend-owned, historised, editable program state machine per user/program.

This is a prototype. Backwards compatibility is explicitly not required.

## User Decisions (Locked)

1. Use one `program state` object (not separate config + state).
   - It must be historised: never update in place, append state snapshots/changes with timestamps.

2. Progression timing / temporal factors:
   - The system should be able to recommend weight drops after long breaks.
   - On workout completion, persist the state representing the just-completed session.
   - On app load / `GetProposed`, compute the next workout from the latest persisted state and current time (so temporal effects can apply then).

3. “History” clarification:
   - Prioritize historised state-machine history for auditing/visualization.
   - Set-by-set workout logs may still exist, but progression should not depend on reconstructing from them.

4. Wendler:
   - Agree to move `1RM/TM` into editable state (not config).

5. GZCLP:
   - `tier` is intrinsic regime metadata, not config/state.
   - Encode tier via group/exercise tags in backend proposals.
   - No read-only config fields in the editable state UI.

6. Linear 5x5:
   - Expose next workout enum (`A/B`) in state.
   - Exercise weights live in state and progress there.

7. Frontend schema contract:
   - Regime implementation provides typed editable fields, including enum options.
   - Frontend renders from backend-provided schema/options.

8. UI reuse:
   - Use a single shared program editor widget/flow for onboarding and settings (consistent UI, minimal duplication).

9. Backwards compatibility:
   - Not required. Delete/replace existing proto/messages as needed.
   - Single program state object is preferred.

10. Scope:
   - Do all regimes in one pass (`linear_5x5`, `gzclp`, `wendler_531_3day`, `wendler_531_4day`).

## Current Architecture (Context)

### Current problems

- Progression is derived from:
  - workout set history (DB)
  - `regime_state_json`
  - partial config values (`one_rep_maxes`, etc.)
- Users cannot reliably correct phases/stages/weights manually.
- State shape is opaque JSON, not typed/schema-driven.
- Frontend now renders program metadata/config dynamically, but editable progression state is still not exposed.
- `days_per_week` is currently mostly UI/readiness metadata and should not be user-editable for current regimes.

### Current key files (relevant)

- Backend regime trait/registry:
  - `src/regimes/mod.rs`
- Regimes:
  - `src/regimes/linear_5x5.rs`
  - `src/regimes/gzclp.rs`
  - `src/regimes/wendler_531_3day.rs`
  - `src/regimes/wendler_531_4day.rs`
- Scheduler:
  - `src/scheduler.rs`
- Workout service (end/start/complete flows):
  - `src/service_workout.rs`
- Settings service:
  - `src/service_settings.rs`
- Proto:
  - `proto/workout/v1/settings.proto`
  - `proto/workout/v1/workout.proto`
- Frontend dynamic program UI:
  - `app/lib/providers/settings_provider.dart`
  - `app/lib/screens/onboarding_screen.dart`
  - `app/lib/screens/regime_settings_screen.dart`
  - `app/lib/screens/regime_info_screen.dart`

## Target Architecture

## 1. Single Historised Program State

Replace current user workout config storage with a single typed program state object (per user).

### Conceptual model

- `TrainingProgramStateEnvelope`
  - `regime_type`
  - `active_state` (latest state payload)
  - `revision` / `version`
  - `updated_at`

- `TrainingProgramStateEvent` (append-only)
  - `user_id`
  - `effective_at`
  - `recorded_at`
  - `source` (`onboarding_init`, `manual_edit`, `workout_completed`, `system_recompute`, etc.)
  - `regime_type`
  - `full_state_payload` (snapshot preferred for simplicity)
  - optional `diff_payload` (future optimization)

### Why snapshot events, not diffs only

- Simpler implementation
- Easier auditing and visualization
- Easier rollback / timeline inspection
- No merge/replay complexity for MVP

## 2. Progression Lifecycle (Temporal-safe)

### On workout completion

Persist the state for the just-completed session result.

- Input:
  - latest active state (before session)
  - actual completed workout results
  - workout started_at/ended_at
- Regime computes:
  - post-session state snapshot (state after applying success/failure/stage transitions/TM changes/etc.)
- Append event:
  - source = `workout_completed`
  - `effective_at = workout_end_time`

### On app load / get proposed schedule

Compute next recommendation from latest persisted state + current time.

- Regime can apply temporal transforms (e.g. long-break deload recommendation)
- This should not mutate persisted state automatically unless explicitly chosen
  - recommended approach: compute an ephemeral proposed-next state + proposal
  - only persist changes on completion or manual edit

This satisfies the requirement to recommend weight drops after time away.

## 3. Progression Source of Truth

### New rule

- Progression source of truth = historised program state
- Workout set history remains for:
  - audit
  - UI/history pages
  - detailed analytics
- Regimes should not reconstruct progression from set history for normal operation

## 4. Regime-owned Typed Editable State Schema

Each regime must define:

- metadata (already present)
- editable state schema
- default initial state
- validation
- proposal calculation from state + now
- state transition on workout completion

### Trait additions (backend)

Add methods to `WorkoutRegime` (names are suggestions):

- `fn state_schema(&self) -> TrainingProgramStateSchema`
- `fn default_state(&self) -> TrainingProgramStateValue`
- `fn normalize_state(&self, state: TrainingProgramStateValue) -> Result<...>`
- `fn propose_from_state(&self, state: &TrainingProgramStateValue, now_ts: i64) -> ProposalResult`
- `fn transition_state_on_workout_complete(&self, state: &TrainingProgramStateValue, workout_result: ..., ended_at: i64) -> TrainingProgramStateValue`
- `fn state_editor_sections(&self, state: &TrainingProgramStateValue) -> ...` (optional UI grouping hints)

Important: enum options must come from backend schema for frontend pickers.

## 5. Typed State Field Schema (Extensible)

Implement a general typed schema/value system so any regime field can be editable.

### Required field types

- `int`
- `float`
- `bool`
- `string` (optional, but cheap to support)
- `enum`
- `group/object`
- `list` (optional for MVP; can be avoided by flattening per-lift keys)

### Field schema shape (proto concept)

- `key`
- `label`
- `help_text`
- `kind`
- `required`
- `editor_kind` (`number`, `enum_picker`, `toggle`, etc.)
- `enum_options[]` (`value`, `label`)
- `constraints` (`min`, `max`, `step`)
- `section`
- `order`
- maybe `visibility_rule` (future)

### Field value shape

Map-like structure keyed by field key:
- `map<string, StateFieldValue>`
or
- repeated `StateFieldEntry { key, value }`

Use a proto `oneof` for typed values.

## 6. Regime-specific State Contents (MVP)

These are the editable fields that “make sense” based on user direction.

### Linear 5x5 (`linear_5x5`)

Editable state fields:
- `next_workout_variant` (enum: `A`, `B`)
- per-lift working weights:
  - `squat_weight`
  - `bench_press_weight`
  - `barbell_row_weight`
  - `overhead_press_weight`
  - `deadlift_weight`
- stall counters (recommended to expose for correction/debugging):
  - `squat_stall_count`
  - etc.
- optionally `last_session_at` if used internally (may keep internal-only)

Backend derives exercises shown in the workout from `next_workout_variant`.

### GZCLP (`gzclp`)

Editable state fields (per-lift):
- current working weight
- stage (enum for T1/T2 lifts)
  - T1 enum: `stage_1_5x3`, `stage_2_6x2`, `stage_3_10x1`
  - T2 enum: `stage_1_3x10`, `stage_2_3x8`, `stage_3_3x6`
- for T3:
  - current weight (simple linear)
  - no stage if not meaningful (or fixed stage omitted)

Do not expose `tier` as a state field.
- Tier should be attached by backend as metadata/tags on proposals/exercises/groups.

Internal-only fields (can remain hidden):
- last-applied timestamps / idempotency guards

### Wendler 5/3/1 4-day (`wendler_531_4day`)

Editable state fields:
- `cycle`
- `week` (enum/string or int 1-4)
- `session_in_week` (enum/int 0-3)
- main-lift `training_max` values (preferred over raw 1RM)
  - `squat_tm`
  - `bench_press_tm`
  - `deadlift_tm`
  - `overhead_press_tm`

Optional:
- `estimated_1rm` fields as convenience inputs if you still want them
  - but avoid duplicate sources of truth unless you define precedence clearly

### Wendler 5/3/1 3-day (`wendler_531_3day`)

Same as 4-day, but:
- `session_in_week` enum/int range 0-2
- proposal logic for paired lifts

## 7. Remove `days_per_week` User Input

Per user decision and current regime behavior:
- No workouts should expose `days_per_week` as an editable state field
- Remove from UI/editor schema
- If needed for display/readiness copy, derive from regime metadata/static definition

## 8. Frontend: Shared Program Editor (Onboarding + Settings)

Create one shared widget/flow and use it in both:
- onboarding
- settings/edit training program

### Requirements

- Same backend-driven schema rendering
- Same enum picker support
- Same validation display
- Different mode only for shell actions:
  - onboarding: `Start`
  - settings: `Save`

### Recommended shape

- `TrainingProgramEditorFlow` widget
  - mode: `onboarding` | `edit`
  - loads catalog + current state
  - step 1: program selection
  - step 2: state editor (dynamic from schema)
  - step 3 optional confirm (can omit for simplicity)

Re-use existing onboarding visual style; wrap settings route around the same component.

## 9. API / Proto Refactor (Breaking, Clean)

Replace/retire current `UserWorkoutConfig` usage for training program progression.

### Proposed new settings/service API (suggested)

In `settings.proto` (or dedicated `training_program.proto` if preferred):

- `GetTrainingProgramsCatalog` (already exists, keep and extend)
- `GetActiveTrainingProgramState`
  - returns current regime type + editable state schema + current values + metadata
- `SetActiveTrainingProgramState`
  - replaces active state (manual edit / onboarding initialization)
  - appends historised state event
- `GetTrainingProgramStateHistory`
  - returns appended snapshots for timeline/auditing (future UI/visualizer)

### Suggested messages

- `TrainingProgramStateSchema`
- `TrainingProgramStateFieldSchema`
- `TrainingProgramStateValue`
- `TrainingProgramStateSnapshot`
- `TrainingProgramStateEvent`

### Delete / replace

- `UserWorkoutConfig` in settings for progression usage
- old `one_rep_maxes`
- old `regime_state_json`
- old `days_per_week` input (from editable UI contract)

## 10. Backend Persistence (Prototype-first)

Since DB reset is acceptable, choose the cleanest schema.

### Suggested tables (or equivalent)

- `training_program_state_events`
  - `user_id`
  - `event_id` (uuid)
  - `regime_type`
  - `effective_at`
  - `recorded_at`
  - `source`
  - `state_payload_json` (typed proto JSON or binary blob)

- `training_program_state_latest` (optional denormalized cache)
  - `user_id`
  - `regime_type`
  - `latest_event_id`
  - `state_payload_json`
  - `updated_at`

For prototype speed:
- append to events
- update latest cache row

## 11. Scheduler / Workout Service Changes

### `GetProposedWorkoutSchedule`

Current behavior (history-derived) must be replaced.

New behavior:
1. Load active program state snapshot
2. Load regime impl
3. Compute proposal from state + `now`
4. Return:
   - proposed groups
   - editable state preview if useful (optional)
   - suggested name, readiness, regime context

No progression mutation occurs here.

### `EndWorkout` / completion path

New behavior:
1. Load active program state snapshot used for the workout (or latest + verify)
2. Extract workout result summary (success/failure/actual reps by working set)
3. Regime computes next persisted state snapshot for completed session
4. Append historised state event
5. Update latest state pointer/cache

Important:
- Ensure idempotency if completion is retried.
- Tie transitions to workout ID / completion event ID.

## 12. Regime Proposal Metadata: Tier Tags

Per user decision:
- Tier is intrinsic to regime and should be backend metadata/tags, not config/state.

For GZCLP:
- Ensure groups/exercises include stable tags like:
  - `tier:t1`, `tier:t2`, `tier:t3`
  - maybe `phase:stage1`, etc., if useful

This helps frontend display and future visualizations without exposing fake config fields.

## 13. Testing Strategy (Must Update)

Existing strict harness is good and should be retained, but needs adaptation to state-source changes.

### Update harness

- Scenario setup should initialize program state snapshot (not `UserWorkoutConfig.one_rep_maxes + regime_state_json`)
- Harness should validate:
  - proposal output (already strict)
  - state snapshot after workout completion
  - cycle/stage transitions persisted in historised state

### Add/retain scenarios

- `linear_5x5`: strict A/B alternation + persisted state transitions
- `gzclp`: strict full-rotation + divergent stages + persisted per-lift stages
- `wendler_531_4day`: full cycle + next cycle restart (already modeled conceptually)
- `wendler_531_3day`: full cycle + next cycle restart (already modeled conceptually)

### New tests to add

- Manual state edit validation
  - invalid enum values rejected
  - invalid week/session combinations rejected
- Temporal deload recommendation after long break
  - proposal changes due to `now`
  - persisted state unchanged until workout completion/manual save (if following ephemeral proposal rule)
- Historised state audit trail append semantics
  - no in-place mutation

## 14. Frontend Implementation Details

### Dynamic enum picker support

Backend schema must provide enum options for state fields.
Frontend should render:
- enum dropdown/segmented control/chips depending on option count

### No read-only “config” rows

Per user decision:
- If a field is intrinsic/static (e.g., GZCLP tier), it should not appear in editor fields.
- Surface it in proposal metadata/UI badges instead.

### Program switching UX

Using shared editor widget:
- switching program initializes default state for selected regime
- editing existing program loads current latest state snapshot
- save/start writes full state snapshot event (`source = onboarding_init` or `manual_edit`)

## 15. Suggested Implementation Sequence (for another LLM)

### Phase 1: Proto + data model (breaking)
1. Introduce typed program state schema/value/event messages
2. Remove/retire `UserWorkoutConfig` progression fields
3. Regenerate Rust + Dart protobufs

### Phase 2: Persistence + settings service
1. Add `training_program_state_events` + latest cache storage
2. Implement:
   - get active state
   - set active state
   - get state history (optional in same pass but recommended)
3. Update catalog endpoint to include state schema hooks if needed

### Phase 3: Regime trait refactor
1. Extend `WorkoutRegime` with state schema/default/validate/propose/transition methods
2. Implement all regimes:
   - linear 5x5
   - gzclp
   - wendler 3-day
   - wendler 4-day

### Phase 4: Scheduler / workout completion integration
1. `GetProposed` reads latest state and computes from state + now
2. `EndWorkout` appends new state snapshot from transition function
3. Remove history-derived progression dependencies

### Phase 5: Frontend shared editor
1. Build reusable `TrainingProgramEditorFlow`
2. Replace onboarding/settings screens with shared widget wrapper
3. Add enum picker rendering from backend schema

### Phase 6: Tests + strict scenarios
1. Port harness setup to new state initialization
2. Add strict state transition assertions
3. Verify both Wendler scenarios still show cycle reset
4. Add temporal break recommendation tests

## 16. Design Notes / Non-goals for MVP

- Do not over-engineer diff-based state history first; snapshot events are enough.
- Do not expose every internal idempotency timestamp field in UI.
- Do not rely on set history to rebuild progression in normal operation.
- Do not keep `days_per_week` editor fields unless a regime truly uses it to alter planning.

## 17. Potential Pitfalls

- Double-applying a workout completion transition (idempotency bug)
- Mixing “proposal-time temporal adjustment” with persisted state mutation unintentionally
- Duplicate sources of truth for Wendler (`1RM` and `TM`) without explicit precedence
- Frontend rendering enum values without backend labels (must provide labels)
- Hidden internal fields leaking into editor schema

## 18. Recommended Final UX Shape

- User picks program
- User edits live program state fields (weights/stages/cycle/etc.)
- Backend computes workouts from current state
- Completing a workout appends a new state snapshot
- Future “State Timeline” UI/visualizer can render the historised state snapshots directly

This aligns with the current test/visualization direction and makes manual correction practical.

