# UX review — confusion points & simplifications

A living audit of where a user might be confused, not given the info they need
when they need it, or shown functionality that isn't logical. Bias toward
*removing* and *simplifying*. Each item: observation → decision → status.

Method: reviewing captured e2e screenshots + the screen code, screen by screen.
The app has a deliberate irreverent voice ("Yapping", "Schplanner", "gains_goblin")
— that's personality, not a bug; this review leaves the voice alone and targets
actual confusion, missing info, illogical flows, and complexity.

## Legend
- **FIX** — changed on this branch.
- **PROPOSE** — recommended, not yet done (needs a product call).
- **KEEP** — considered, deliberately left as-is (with reason).

---

## U1. Set info is written three different ways on the workout screen — PROPOSE

On the live workout screen the same "weight & reps" idea appears in three
notations at once:
- pending set chip: `weight · reps` → **"45 · 5"** (`current_exercise_card.dart`)
- completed set chip: `doneReps / targetReps` → **"5 / 5"**
- next-up / rest bar: `reps × weight` → **"5×45 lb"** (`active_boxes.dart:71`)

The next-up bar's `reps×weight` ("5×45") reads as *sets×reps* by analogy with the
program name **"5×5 Workout A"** — genuinely ambiguous. Recommend standardising
the *pending/next-up* weight-and-reps on one order+separator (e.g. `weight × reps`
= "45 lb × 5" everywhere), while keeping the completed chip's `done/target` (it
conveys performance). Left as PROPOSE because it's a visible design change and
worth a deliberate call, not a unilateral edit.

## U2. "Records TBD" / "Record tracking soon" placeholders on the summary — FIX

The workout summary showed "Records TBD" (section header) and "Record tracking
soon" (per exercise) *next to* real stats including an estimated "Best 1RM".
Promising an unbuilt PR feature next to real numbers is contradictory. Removed
the placeholder labels and the dead `recordNote` plumbing; the real stats (sets,
reps, volume, best 1RM, heaviest set) stay.

## U3. "Best 1RM" is an estimate, not labelled as one — FIX

The summary's "Best 1RM" is the Epley estimate `w·(1+reps/30)`, shown as e.g.
"Best 1RM 20.4 lb" for a 17.5 lb × 5 set. Standard metric, but consider labelling
it "Est. 1RM" so it isn't read as a real one-rep max.

## U4. Re-pair with a partner is now request → approve — FIX

Iterated twice here. First pass made the partner "Join" button always pair
(create a session and pull the friend in). But pulling someone in without their
say-so is the wrong consent model, so the final design is a **request/approve
handshake**:
- The partners list button is now **"Ask"** — it sends a request (gated on a
  prior pairing), not an instant join.
- The recipient's app shows a top **banner**: "*name* wants to train with you"
  with Approve / Decline (polled ~1 Hz, independent of session state).
- Approving pairs both into a session (the responder's current one, or a fresh
  one); declining consumes the request. Requests expire after 2 min.
- The QR scan stays the instant path (scanning is explicit consent by the sharer).

Backend: replaced `JoinPartnerSession` with `RequestJoinPartner` /
`GetJoinRequests` / `RespondJoinRequest` + a `join_requests` table. Covered by
`request_then_approve_pairs_both` and `decline_request_does_not_pair` tests and
the `join_request` e2e scenario.

## U5. Debug tiles shown in every user's Settings — PROPOSE

Settings lists "Notification debugging" (→ /debug-notifications) and "Diagnostic
logs" (→ /debug-logs) to all users, ungated. "Diagnostic logs" is defensible as
self-service support; "Notification debugging" reads as a developer tool. Consider
gating behind `kDebugMode` or a hidden gesture to declutter user settings.

## Backend B2. Past group workouts were about to show as "solo" — FIX

The bug-#1 fix (prune the live participant cache when a member leaves) had a
side effect: the workout summary's "Friends worked out with" reads the *same*
`GetSessionParticipants` RPC, which read that pruned cache. So once everyone left
a session, a past workout's summary would show "None (solo session)" — silently
erasing exactly the training-together history we're building. Fixed by sourcing
the historical `GetSessionParticipants` from the durable `session_members` roster
(identity only) while the live view keeps using the pruned cache. Covered by the
extended `leave_prunes_live_view_but_keeps_history` test.

## Backend B1. Dropped the redundant `sessions` table — FIX

The session model had four tables: `user_current_session` (live), 
`session_participants_current` (live blob cache), the new `session_members`
(durable roster), and `sessions` (session_id, created_by, created_at). The
`sessions` table only supplied a date and an unused `created_by`. The date is
derivable from `session_members.first_joined_at`, so the table + its write +
`create_session()` were removed — 4 session tables → 3. Tests still green.

---

## U6. Progress & History screens redesigned — FIX

Both were bare: Progress drew flat monochrome lines with no dates/stats and
plotted *prescribed* weight; History was a plain list showing only name + date +
duration.
- **Progress**: now per-exercise cards with a coloured gradient trend chart (dates
  on the axis, emphasised current point, touch tooltips), the current weight,
  the gain since you started, and start/best/sessions stats — plus a summary
  header. Plots the **actual heaviest working-set weight lifted**, not the
  prescription. Most-improved lift first.
- **History**: rich cards with a date badge, the lifts you actually did
  ("Squat · Bench · Row"), relative day, duration, and volume/sets chips, plus a
  workouts/this-week header. A "👥 group" chip marks sessions trained with others.
Both are frontend-only (no backend change). Captured by the `history_graphs` e2e.

## Note N1. Skip-warmup investigation — feature works (getWorkout hides cancelled sets)

A skip_warmup e2e initially "failed" asserting the backend showed a cancelled
set. Investigation (direct SQLite query) confirmed the skip DOES persist —
`proposed_sets.cancelled = 1` for the skipped warmup — and the UI drops it. The
subtlety: `GetWorkout` excludes cancelled sets from the returned plan, so a client
sees the warmup *count decrease* (12 → 11), not a `cancelled=true` flag. The test
now asserts the reduction. No product bug; worth knowing when reading getWorkout.
