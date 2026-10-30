# One-Tap Sets

Status: proposed. Build it in the order of [9. Work phases](#9-work-phases).
No backwards compatibility: old rows, old fields and old watch builds are
not supported once a phase lands.

This document says what the user has to tell the app during a workout,
what each screen shows and in what order of importance, and how the
numbers respond. It replaces the start/complete set model, the lifting
and yapping states, and the fixed catalog opener for a never-done
exercise.

## 1. Summary

Today a set is started with one tap and completed with a second tap after
scrolling a rep wheel to the reps you did. The app tracks three moods,
lifting (green), resting (blue) and yapping (pink), and the completed
screen reports lifting, resting and yapping time, work density and a
work:rest ratio. A never-done exercise starts at the empty bar and takes
several sessions to reach a real weight.

After this change a set is one tap: **Done**. Reps and weight are assumed
as prescribed; changing them is an exception path. The app has two live
moods, ready and resting. There is no lifting state and no yapping. After
the last set of an exercise the app asks one question, **how was that**,
with three answers. A never-done loaded exercise runs a short calibration
ramp on its first session, with that same question after every ramp set,
and leaves with a real working weight.

| Property | Today | After |
|---|---|---|
| Taps per set | 2 (Start, Complete) plus a rep wheel | 1 (Done) |
| Rep entry | Every set, on a 0–100 wheel | Exception only: a done set can be edited |
| Live states | Lifting, resting, yapping, ready, all done | Ready, resting, all done |
| Time stats | Duration, lifting, resting, yapping, density, ratio | Duration, rest |
| Effort input | None | One tap per exercise: easy / right / hard |
| First session of an exercise | Empty bar, three sets | Calibration ramp to a working weight |
| Watch during a set | Rep picker inside the Complete button | One Done button |
| Watch design | Two-column, two near-identical codebases | One vertical layout, one spec, both platforms |

## 2. Terms

| Term | Meaning |
|---|---|
| Set | A `ProposedSet`. It is *pending*, *done* or *cancelled*. Nothing else. |
| Done | The one tap. It records the set as prescribed and starts rest. |
| Rest | The countdown after Done. `rest_until` on the done set. |
| Ready | No rest is running and a pending set exists. |
| Effort | The answer to "how was that": easy, right, hard. One per exercise per workout, on the final working set. |
| Calibration | The first session of a loaded exercise with no performed history: a ramp of single sets that finds the working weight. |
| Exception | Anything other than Done: fewer reps, different weight, skip rest, skip warmup, remove, reorder. |

Terms that no longer exist in code, copy or UI: start set, lifting,
active set, yapping, chat time, work density, rest ratio, AMRAP. The
reserved proto tags for AMRAP stay reserved.

## 3. Inputs

Per set: **Done**. One tap, either device. Done logs `target_reps` at
`target_weight` and starts rest. Rest is `rest_after_success`; the final
working set of an exercise rests `END_OF_EXERCISE_REST_SECONDS` as today.

Per exercise: **effort**. After Done on the final working set, during
that rest, both devices show the question. Easy, right, hard. Unanswered
when rest ends means right. Answering on either device wins; the phone
is authoritative and the watch renders what it is sent.

Exceptions, in order of how often they happen:

| Exception | Where | How |
|---|---|---|
| Fewer reps than planned | Both | During the rest after that set: "fewer reps" opens a picker 0..target. Rest switches to `rest_after_failure`. |
| Skip rest | Both | One tap on the rest screen. Goes to ready. |
| Skip warmup | Both | Secondary action while a warmup is the next set. |
| Change weight for the exercise | Phone | Existing adjust sheet. Pending sets and pending warmups regenerate. |
| Edit a done set later | Phone | Tap the chip: reps and weight. |
| Remove, reorder, add | Phone | As today. |

Nothing asks for reps up front. Nothing asks how long a set took.

## 4. State model

A set is pending, done or cancelled. Done means a `CompletedSet` row
exists. There is no in-progress row and no `started_at`.

Workout state, derived in the reducer and mirrored in Dart:

| State | Condition | Carries |
|---|---|---|
| RESTING | Last done set has `rest_until > now` | `rest_until`, next pending set, `effort_prompt` if that done set was the final working set of its exercise and it has no effort yet |
| READY | A pending set exists | Next pending set |
| ALL_DONE | No pending set | Completion summary |

`effort_prompt` carries the exercise and the done set id. It is cleared
when an effort is recorded or when the next set is done; rest ending
without an answer records `right` on the server at the next mutation or
at end of workout, whichever is first.

## 5. Data model

Proto, `workout.proto`:

- `CompletedSet`: remove `started_at`. `ended_at` keeps its name (it is
  the one timestamp a set has; renaming it buys nothing). Add
  `Effort effort = 9`.
- `enum Effort { UNSPECIFIED, EASY, RIGHT, HARD }`.
- `ProposedSet`: add `bool calibration = 15`.
- `WorkoutStateSnapshot`: states READY, RESTING, ALL_DONE. Remove
  `active_started_at`, `last_rest_end`. Add `EffortPrompt effort_prompt`
  (`exercise`, `completed_set_id`).
- `WorkoutMutation`: remove `start_set`. Add `rate_exercise`
  (`workout_id`, `exercise`, `effort`), `skip_rest` (`workout_id`),
  `edit_completed_set` (`workout_id`, `completed_set_id`, `actual_reps`,
  `actual_weight`). `complete_set` keeps `completed_at`.
- `WorkoutSummary`: remove lifting, yapping, density and ratio fields.
  Keep duration, rest, volume, sets, per-exercise stats.
- `ExerciseTracker` / `TrackerState`: add `consecutive_hard`.

Proto, `wearable.proto`:

- `WearActionType`: COMPLETE_SET, FEWER_REPS, SKIP_REST, SKIP_WARMUP,
  RATE_EXERCISE, END_WORKOUT. Remove START_SET.
- `WearActionStyle`: PRIMARY, SECONDARY. Remove REP_OPTION.
- `WearWorkoutSnapshot`: remove `active_started_at`, `last_rest_end`,
  `group_card`, `side_label`, `header`, `is_complete` (never read by a
  watch). Add `EffortPromptCard effort_prompt` (`exercise_name`,
  `completed_set_id`).
- `WearStatusCard`: `exercise_name`, `set_line` ("Set 2 of 3",
  "Warmup 1 of 4", "Finding your weight"), `set_text` (the set in the
  user's unit, "60 kg × 5"; the watch never formats a weight), `display_set`.
- Intents: CompleteSet (`set_id`, `completed_at`), FewerReps (`set_id`,
  `reps`), SkipRest, SkipWarmup (`set_id`), RateExercise (`exercise`,
  `effort`), EndWorkout. Remove StartSet.

SQLite, `src/db/mod.rs`: `completed_sets` drops `started_at` from reads
and writes (the column may stay in old files; nothing reads it), gains
`effort INTEGER NOT NULL DEFAULT 0`. `proposed_sets` gains
`calibration INTEGER NOT NULL DEFAULT 0`. `exercise_trackers` gains
`consecutive_hard`. Each is an idempotent `ALTER TABLE` next to
`SERVER_SCHEMA`.

## 6. Progression

Double progression stays the engine. Effort tunes it. Per exercise per
workout, from `session_outcomes`: `cleared`, `min_reps`,
`performed_weight`, and now `effort` (the final working set's effort,
`right` if unset).

| Outcome | Next state |
|---|---|
| Cleared, easy, `min_reps >= top` | weight + two steps, reps to bottom |
| Cleared, easy, below top | weight + one step, reps to bottom |
| Cleared, right, `min_reps >= top` | weight + one step, reps to bottom (today's rule) |
| Cleared, right, below top | reps = `min_reps + 1` (today's rule) |
| Cleared, hard | hold weight and reps; `consecutive_hard + 1` |
| Not cleared | hold; second miss running deloads 10% (today's rule); `consecutive_hard + 1` |
| Bailed | hold (today's rule) |
| Bodyweight | reps only (today's rule); effort moves reps by 2 on easy |

Any outcome that is not hard resets `consecutive_hard`. When
`consecutive_hard` reaches 3 the tracker deloads 10%, reps to bottom,
both counters reset. That is the planned deload: no calendar, no failure
needed.

A miss after a skipped rest counts as a hold, not a miss: the reducer
records `rest_skipped` on the done set when `skip_rest` fires, and
`session_outcomes` excludes those sets from `cleared` without counting
them against it. Keep this simple; it is one boolean.

## 7. Calibration

Triggered when an exercise is loaded (not bodyweight) and its tracker has
`last_performed_at == 0`. The onboarding seed for the five barbell lifts
does not count as performed. The warmup ladder is not generated; the ramp
is the warmup.

Plan at start: one pending set flagged `calibration`, 5 reps, at the
ramp start. Ramp start is the catalog opener, or 60% of the seed when
one exists, snapped. After Done on a calibration set the effort question
appears immediately (the rest is 90 s):

| Answer | Next |
|---|---|
| Easy | Append another calibration set at the next rung |
| Right | This is the working weight. Append the prescribed working sets at it, minus one (the calibration set counts). |
| Hard | The previous rung is the working weight (the opener if this was the first). Append the working sets at it, minus one. |

Rung step: the larger of one equipment step and 10% of the current
weight, snapped to loadable. Cap at 6 ramp sets; the sixth is treated as
right. The tracker is written at EndWorkout as today, from the working
sets, with `last_performed_at` set; a bailed calibration leaves the
tracker unset so it runs again.

Calibration sets are shown with the set line "Finding your weight" and
the effort question is the only thing on the rest screen. They count as
warmups for volume and summary. Both reducers (Rust and Dart) implement
the append rules; add the fixture to the parity harness.

## 8. Screens

Hierarchy rule for every screen: one primary number, one primary action,
everything else small and grey. Type is Inter Tight for display and text,
Geist Mono for button labels. Colours: black background; ready has no accent (white
button, black text); resting is blue `#3B82F6`; the effort question is
amber `#F59E0B`; done is green `#16A34A`. Heart-rate colour bands stay as
they are. The green/blue/pink trio and `workoutYapping*` tokens are
deleted.

### 8.1 Watch, both platforms, one spec

Vertical, full-bleed, three zones. Both apps implement this layout from
the same snapshot with no platform-specific extras: no version line, no
`hk:` diagnostic.

**Status row** (top, 16 pt, grey): elapsed time, heart rate in its band
colour. Present on every screen. Hidden in ambient mode along with the
countdown.

**Ready**

1. Exercise name, 18 medium, white.
2. `set_text`, 34 bold, white. The biggest thing on screen.
3. Set line, 14, grey: "Set 2 of 3", "Warmup 1 of 4", "Finding your
   weight".
4. **Done**, a full-width white button, 56 tall, black 20 bold text.
   Below it, only when the next set is a warmup, a small grey text action
   "Skip warmup".

**Resting**

1. Countdown, 44 bold, blue. The biggest thing on screen. Counts down to
   0:00 and then stays at 0:00 with the haptic; it never counts up.
2. "Next: `set_text`", 16, white, and the exercise name, 14, grey.
3. Two small grey text actions on one row: "Fewer reps", "Skip rest".
   "Fewer reps" shows a 0..target wheel with a confirm button, the only
   picker on the watch, and it is never on the Ready screen.

**Effort question** (replaces Resting when `effort_prompt` is set)

This is the one screen without the status row: three buttons and two
lines do not fit a small round face with it, and its first line already
carries the countdown.

1. Exercise name, 14, grey, and the countdown, 20, grey.
2. "How was that?", 18 medium, white.
3. Three stacked full-width buttons, 44 tall: Easy, Right, Hard, amber
   outline, the middle one filled. A tap answers and the screen returns to
   Resting.

**Done**

1. "Done", 30 bold, green.
2. Time, sets, volume as three label/value rows.
3. **End workout**, full-width white button. After it fires, the watch
   returns to its idle view.

**Idle**: "Open Schlift on your phone", one line, grey.

Rest-end haptic as today. No tap is accepted on a button for 2 s after a
tap or until the next snapshot, as today.

### 8.2 Phone bottom bar

The bar is the live control surface and follows the watch exactly, so a
user looking at either device reads the same hierarchy.

- Status box: exercise name (16 bold) over `weight × reps` (32 bold) and
  the plate pill. Right side: state label and timer, as today, with the
  states Ready (no label, no timer), Resting (blue, countdown) and the
  effort question (amber, "How was that?").
- Action area: Ready shows **Done** (64 tall) with "Skip warmup" outlined
  to its left when applicable. Resting shows "Fewer reps" and "Skip rest"
  as two outlined buttons. The effort question shows the three buttons.
  All done shows **End workout**.
- The elapsed/heart box stays.

### 8.3 Phone workout screen

Keep the two-column layout. Changes:

- The current exercise card has no lifting state. The next pending chip is
  the rainbow chip; done chips are green or yellow. Tapping a done chip
  opens the edit-set sheet (reps, weight). Tapping the pencil opens the
  weight sheet as today.
- Calibration blocks show "Finding your weight" instead of warmup and
  working sections, with the ramp sets as chips.
- `active_boxes.dart` is deleted.

### 8.4 Completed screen

Tiles: Duration, Volume, Sets, Rest. Then heart rate, friends, exercise
totals, set log, as today. The heart-rate chart shades rest windows from
`ended_at` to `rest_until`; nothing else is shaded.

## 9. Work phases

Each phase is one PR, green on `make lint-check` and the parity harness,
with the Swift compile workflow run for any watch change.

1. **Strip.** Remove start set, the lifting state, yapping, `started_at`,
   `last_rest_end`, `active_started_at`, the summary's lifting, yapping,
   density and ratio fields, the three-colour tokens, `active_boxes.dart`,
   and the rep wheel from the phone's action area. Done sends
   `target_reps`. Both watches: remove the picker and START_SET; one Done
   button. Reducer, Dart mirror, snapshot builder, golden fixtures, tests.
   This phase has no new behaviour.
2. **Watch layout.** Implement 8.1 on both platforms from one spec. Bring
   the phone bottom bar to 8.2. Trim `wearable.proto` to the fields a watch
   reads.
3. **Exceptions.** `edit_completed_set`, `skip_rest`, `rest_skipped`;
   "Fewer reps" and "Skip rest" on both devices; the done-chip edit sheet.
4. **Effort.** `Effort`, `rate_exercise`, `effort_prompt`, the question on
   both devices, the timeout to right, `advance_tracker` rules from
   section 6 including the three-hard deload, `consecutive_hard`.
5. **Calibration.** `calibration` on sets, the ramp rules in both
   reducers, the plan at start, the UI treatment, the tracker write.
6. **Docs and copy.** Update `docs/architecture/workout-lifecycle.md`,
   `wearable.md` and `app.md`. Copy strings go in `app/copy.yaml` as
   placeholders for the user to reword.

Phases 1 and 2 remove more than they add and are safe to land on their
own. Phases 3 to 5 each add one input and can be reordered if needed,
but 4 before 5 because calibration reuses the effort question.

## 10. Revisions after first use

- **No "fewer reps" during rest.** It put a rare case on every rest
  screen. A miss is corrected on the phone by tapping the set's chip
  (`edit_completed_set`). An uncorrected miss counts as a hit; the effort
  answer catches most of what that loses.
- **Skip rest is a full-width button** on every device, not a text link.
- **You can type your weight during calibration.** On a calibration set
  the phone offers "I know my weight". Entering a weight with
  `AdjustExerciseWeight` while the exercise has a pending calibration rung
  drops the pending rung, records any unanswered rung of that exercise as
  right without appending, and appends the prescription's full working
  sets at that weight. Their ids are `uuid5(NAMESPACE_OID,
  "{pending_rung_id}:{n}")`, so both reducers agree.

## 11. Revision: effort on every set, one button (supersedes the effort
## parts of sections 3, 4, 6, 8 and the skip-rest parts of section 10)

The experience, one set at a time:

1. **One button, always.** Ready shows **Done**. While rest is running it
   shows **Done early**. Both log the next pending set as prescribed. There
   is no skip rest, on any device, and no `skip_rest` mutation.
2. **Effort on every working set and every calibration rung**, never on a
   warmup. After Done, the rest screen shows "How was that?" with three
   small chips under the timer: Easy, Right, Hard. Answering is optional
   and never blocks. The answer can be changed until the next Done. An
   unanswered set is recorded as Right at the next Done or at EndWorkout.
   Rest ending no longer resolves anything.
3. **The timer says what to do.** While resting: blue countdown, label
   "Resting". When rest ends: pink (`#EC4899`), label "Lift now", counting
   up from the end of rest, until the next Done. Before the first set of a
   workout: no label, no timer.
4. **Calibration uses the same chips.** An answer on a rung appends the next
   rung or the working sets at once, as before. Changing the answer removes
   the pending sets that answer appended (ids derived from this done set)
   and appends for the new answer. Done with no answer resolves the rung as
   Right first, then logs the first appended set. Its id is deterministic
   (`uuid5("{done_id}:0")`), so the phone can show it on the button before
   the server has seen anything. "I know my weight" stays.

Rules behind it:

- `EffortPrompt` describes the latest done set while it is prompt-worthy
  (working set or rung), whatever the rest state, and carries the current
  `effort`. It clears when a newer set is done.
- `CompleteSet` first resolves every unanswered prompt-worthy set as Right,
  extending a ramp. `EndWorkout` resolves without extending. No other
  mutation resolves.
- `RateExercise` may re-rate the latest done set only.
- Session effort per exercise for progression: Hard if any working set was
  rated Hard, otherwise the last working set's effort, Right if unset.
- A set done early (its `ended_at` is before the previous done set's
  `rest_until`) is judged normally when it hits its target. Only a
  done-early miss is softened: it holds the session (no miss counted, no
  advance) instead of making it not-cleared. A miss on a full rest is still
  a miss. `CompletedSet.rest_skipped` and `SkipRest` are removed.

Watch, both platforms: one Rest screen replaces Resting and Effort. Status
row; the timer (40 bold, blue countdown or pink count-up) with its label
(14, same colour); "Next: `set_text`" (14 white); the three chips (30 tall,
amber outline, the selected one filled) when there is a prompt; a
full-width primary button, "Done early" or "Done", 48 tall. Each watch
flips to "Lift now" and "Done" itself when the countdown reaches zero; the
labels come in the snapshot. Ready (the first set), Done and Idle are
unchanged.

## 12. Revision: yapping is back, as a state

Dropping yapping was a mistake. It returns as a first-class
`WorkoutState` (`WORKOUT_STATE_YAPPING`), derived from the same moment as
resting: after a done set the workout is RESTING while that set's prescribed
rest runs and YAPPING once it has run out, until the next Done; READY is only
before the first set. It replaces "Lift now" (same phase, now a state): pink,
counting up from `rest_until`, on the phone, both watches (`yapping_label`)
and the multiplayer ticker. `WorkoutSummary.yapping_seconds` sums it; the
heart-rate chart shades it. Details: `docs/architecture/workout-lifecycle.md`.

## 13. Revision: sets are circles, and Lifting is a state

Logging moved off the bottom bar and onto the sets, StrongLifts style. A set
is a circle with a number in it: tap the up-next circle to start it
(`StartSet`, the new `WORKOUT_STATE_LIFTING`, counting up), tap again when
it is done (`CompleteSet`, every rep), once more per missed rep
(`EditCompletedSet`, reps − 1), and the tap after zero undoes it
(`DeleteCompletedSet`; a rung stops at zero). Each exercise is a full-width
row of circles, warmups first until they are done or skipped. The banner
under the page has no buttons: everyone's status box, yours at the bottom.

Working sets are no longer rated: progression reads the reps, an unanswered
question resolving to right. Only a finding-weight rung asks, worded as reps
left in the tank (0–1 hard, 2–3 right, 4+ easy). Easy / right / hard is our
own coarse proxy for reps in reserve, which beginners judge poorly; a miss
is a fact.

Skipping no longer removes anything (`CancelProposedSet`, the watch's
SKIP_WARMUP action and its intent are gone). Each exercise shows its
warmups and working sets in two rows; "Skip" on the warmup row marks the undone
warmups skipped (`SkipWarmups`, `ProposedSet.skipped`), and doing a working
set moves past them too. Either way they stay in the plan and can still be
done. Any set can be done in any order. On a watch the rung's finish carries the answer. Details:
`docs/architecture/workout-lifecycle.md` and `wearable.md`.
