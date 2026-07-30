# Plan: recovery- & frequency-aware "what to do next"

Status: proposal (2026-07-30). Owner: brensch. Scope: how Schlift decides *when*
a user should train, and a not-in-a-workout home screen that makes the next
action obvious.

---

## 1. The problem, and the design bet

Today the home screen answers "what workout is queued" but not the question a
lifter actually has standing in their kitchen: **"should I train today, and if so
which one — or is today a rest day?"**

**A calendar is the wrong metaphor.** Fixed Mon/Wed/Fri days generate guilt the
moment life gets in the way, and they don't reflect what actually governs training
— *recovery* and *frequency*, not the date. A missed Monday shouldn't cascade; the
app should just know your legs are recovered and it's been two days, so today's a
good day to squat.

The bet: model **per-muscle recovery clocks** + a **program's prescribed frequency**,
combine them with the user's **actual cadence**, and surface one clear readiness
state on the home screen. Adaptive, not a grid.

---

## 2. The science (what the model must encode)

- **Frequency:** hitting a muscle **~2×/week beats 1×/week**; past that, once weekly
  *volume* is equated the frequency effect is small. So frequency is a tool to
  *distribute volume* and manage fatigue, not an end in itself. Level guides:
  novice **3×/week full-body**, intermediate **4×/week upper-lower**, advanced 4–6×.
- **Recovery:** muscle protein synthesis stays elevated **~48–72h**. Rough per-group
  clocks: large muscles (legs, back) **48–72h**; small (arms, delts) **24–48h**;
  heavy axial compounds (squat, deadlift) **72–96h**. Younger recover faster, older
  slower.
- **Volume:** ~**10–20 sets/week per muscle** is the productive band (the app's
  weekly set target already gestures at this).
- The app's own programs already encode all of this *implicitly*: StrongLifts/GZCLP
  are **3×/week on non-consecutive days** — "~48h between sessions" is baked into the
  M/W/F cadence. We're making the implicit rule explicit and adaptive.

Sources: Stronger By Science (frequency), PMC strength-frequency & volume
meta-analyses, Bodybuilding.com / CyVigor recovery reviews, StrongLifts & Liftosaur
program guides. (Full links in the session notes.)

---

## 3. Where the app is today

(from a full read of `src/regimes/`, `src/schplanner.rs`, `src/server/workout.rs`,
`app/lib/screens/home/`.)

- **Rotation only, no time model.** Each regime is "next in the rotation," advanced
  when a workout completes: Linear5x5 toggles an A/B key; Wendler increments
  cycle/week/session; GZCLP does `idx = (idx+1) % n`. No day-of-week, no rest day.
- **"Next session" is naive.** `next_session_at = last_session_at + fixed offset`
  (24h for Linear5x5/GZCLP; 24/48/72h by 5/3/1 week). `shouldTrainNow = now >=
  next_session_at` is the *only* train/rest signal.
- **The recovery inputs are dead-plumbed.** `propose_from_state(state,
  last_session_at, now, insights)` already receives history and timing — but all
  three regimes name those params `_last_session_at` / `_insights` and ignore them.
  Lighting them up is additive, not a signature change.
- **No muscle-group model on the backend.** Muscle mapping exists *only* in Flutter:
  `BodyPart {chest, back, shoulders, arms, legs, ass, core}` + `ExerciseInfo.bodyParts`
  in `app/lib/logic/exercises.dart` (first entry = primary mover).
- **No inter-workout cadence anywhere.** `summarize_recent_insights` computes
  *intra-workout* timing (set duration, rest between sets) but never days-between-
  sessions or sessions/week actuals. `summarize_history_window` counts this-week
  sessions only for the progress meter.
- **The home hero** (`readiness_banner.dart`) is a green "train now" vs blue
  "scheduled" card + weekly session/set chips. `TrainingStatus` already carries
  `next_session_at`, `should_train_now`, and per-slot `last_trained_at` /
  `days_since_last_trained` — but **`slotStatuses` is shipped and never rendered**.
  No rest-day advice, no streak, no last-trained on screen.

**Upshot:** the plumbing (regime seam, `TrainingStatus` proto, history timestamps,
Flutter muscle map) is mostly here. Three things are genuinely missing: a
*backend muscle→recovery mapping*, a *cadence/recovery computation over history*, and
a *real train-vs-rest decision* to replace `last + fixed offset`.

---

## 4. The proposed model

Three pieces, all server-side, surfaced through `TrainingStatus`.

### 4a. Muscle-group recovery clocks
- Port the Flutter `bodyParts` map into Rust as `exercise → &[MuscleGroup]`, primary
  mover first. Keep it beside the regime exercise metadata; pin it to the Flutter
  map with a parity test so the two can't drift (the repo already uses Rust↔Dart
  parity fixtures for warmups/reducer).
- Each `MuscleGroup` has a **recovery window** by size + typical intensity:
  legs/back 60h, chest 48h, shoulders/arms 36h, core 24h — with a **+bump for heavy
  axial compounds** (squat/deadlift push their groups toward 72h). Start as a fixed
  table (a const), tunable later.
- From history, for each muscle group compute `last_trained_at` = end time of the
  most recent workout that included an exercise hitting it, and
  `recovered_at = last_trained_at + window`. Recovery fraction = clamp(elapsed/window).

### 4b. Program prescription (make the implicit explicit)
- Extend each regime with a small prescription it already half-has:
  `target_sessions_per_week` (exists), `min_hours_between_sessions` (new; StrongLifts/
  GZCLP ≈ 24–48, Wendler by week), and the **muscle coverage of the next session**
  (derivable from the proposed exercises via 4a).
- This gives the "when is the *next* workout ready?" answer: it's ready when the
  muscles *that workout will hit* are recovered — i.e. `next_ready_at =
  max(recovered_at for each muscle in the next session)`, floored by
  `last_session_at + min_hours_between_sessions`. This replaces the flat +24h.

### 4c. Readiness state (the one decision)
Combine recovery + frequency + learned cadence into a single enum on `TrainingStatus`:
- **READY** — the next workout's muscles are recovered (and min-rest elapsed). "Train."
- **RECOVERING** — not yet; show *what's* recovering and hours remaining. "Rest."
- **OVERDUE** — well past ready (e.g. > 2× the expected gap) and behind the weekly
  target. Gentle "let's get back," never guilt.
- **AHEAD / OPTIONAL** — recovered but you've already met the weekly target; training
  is fine but framed as a bonus.

Learned **cadence** (avg days between sessions over recent history, sessions in the
last 7 days) personalizes thresholds — a 4×/week user and a 2×/week user get
different "overdue" points — and feeds a soft streak/consistency read.

Keep **what** to propose (the rotation) separate from **when** (readiness). The
rotation stays as-is; readiness is new and lives in `derive_training_status` / a new
`recovery` module — so we light up the dead `last_session_at`/`insights` inputs
without touching progression logic.

---

## 5. The home screen: "what to do next"

One hero that resolves the standing question, driven by 4c. States:

- **Train today** — headline names the session and *why now*: "Squat · Bench · Row —
  recovered, 2 days since your last lift." Big **Start**. Predicted time chip stays.
- **Rest day** — "Recovering. Legs need ~14h more." A **per-muscle recovery strip**
  (legs 🟡 14h · back 🟢 ready · chest 🟢 ready) and "Next up: Workout B, ready ~tomorrow 9am."
- **Overdue** — "It's been 5 days — pick up where you left off," no shaming, one tap in.
- **Ahead** — "You've hit 3/3 this week. Another's fine, or rest easy."

Supporting, below the hero:
- **Per-muscle recovery strip** (the visual heart of it) — a row of muscle chips with
  a ready/recovering state and a small clock, so "am I recovered?" is answerable at a
  glance. This is the thing a calendar can't show.
- **Last trained / cadence** — "Last lift: Tue · ~3×/week, on pace" (soft, factual).
- Render the already-shipped **`slotStatuses`** (per-lift "up next / N sets left").
- Recovery-aware **notification**: the "time to lift" reminder fires at the real
  `next_ready_at`, not last + 24h.

A mockup of these states ships alongside this doc.

---

## 6. Phased build

**Phase 1 — backend recovery model (no UI change)**
- Rust `Exercise → &[MuscleGroup]` map + recovery-window table, ported from
  `exercises.dart`, pinned by a parity test.
- Compute per-muscle `last_trained_at` / `recovered_at` and inter-workout cadence
  from history — a new field on `SchplannerInsights` or a sibling `RecoveryState`.
- Files: new `src/recovery.rs` (or extend `src/schplanner.rs`); `summarize_recent_insights`
  (`src/schplanner.rs:437`); `load_recent_schplanner_history` (mind the 24-workout cap
  — cadence needs a few weeks, so widen for timestamps or add a light "recent session
  times" query).

**Phase 2 — readiness decision + proto**
- Add to `TrainingStatus`: `readiness_state` enum, repeated `MuscleRecovery
  {group, last_trained_at, recovered_at, fraction}`, `avg_days_between_sessions`,
  `sessions_last_7d`. Regenerate Dart/Rust proto.
- Replace `next_session_at` computation in each regime's `derive_training_status`
  with `next_ready_at` from 4b; set `readiness_state`. Central helper in the new
  recovery module so the three regimes share it.
- Files: `workout.proto`; `src/regimes/mod.rs` (`build_training_status:345`,
  `format_time_until`); `linear_5x5.rs` / `wendler_531.rs` / `gzclp.rs`
  (`derive_training_status`, `recovery_seconds_for_week`).

**Phase 3 — home UI**
- Rework `readiness_banner.dart` into the state-driven hero; add the per-muscle
  recovery strip + last-trained/cadence; render `slotStatuses`.
- Point `scheduleNextWorkout` (`notification_service.dart:163`) at `next_ready_at`.
- Files: `app/lib/screens/home/readiness_banner.dart`, `home_screen.dart`,
  `completed_workout_screen.dart:148`.

**Phase 4 — later / optional**
- Dynamic session pick: if the next rotation workout's muscles aren't recovered but
  another session's are, suggest that instead. (Powerful, but changes progression
  ordering — defer until the read-only model is trusted.)
- Personalize recovery windows by age/experience (onboarding already has experience
  level) and by recent AMRAP/RPE fatigue signals.

---

## 7. Decisions to make (need your call)

1. **Prescriptive vs permissive.** Recommend **permissive** — never block a workout;
   "Rest day" is advice, Start is always one tap. Agree?
2. **Recovery windows** — fixed table to start (legs/back 60h, chest 48h, arms/delts
   36h, core 24h, +heavy-compound bump), refine with data later? Or tie to
   experience level from onboarding now?
3. **How much home real estate** for the per-muscle strip vs keeping the hero minimal
   — full strip always, or only on rest/recovering states?
4. **Overdue tone** — how gentle, and at what multiple of the expected gap does it
   trigger?
5. Do we want the **dynamic session pick** (Phase 4) at all, or is "fixed rotation,
   smart timing" the whole product?

Once you've weighed in on 1–5 I can turn Phase 1–2 into a concrete implementation.
