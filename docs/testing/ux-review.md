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

## Backend B1. Dropped the redundant `sessions` table — FIX

The session model had four tables: `user_current_session` (live), 
`session_participants_current` (live blob cache), the new `session_members`
(durable roster), and `sessions` (session_id, created_by, created_at). The
`sessions` table only supplied a date and an unused `created_by`. The date is
derivable from `session_members.first_joined_at`, so the table + its write +
`create_session()` were removed — 4 session tables → 3. Tests still green.

---
