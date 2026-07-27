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

## U3. "Best 1RM" is an estimate, not labelled as one — PROPOSE

The summary's "Best 1RM" is the Epley estimate `w·(1+reps/30)`, shown as e.g.
"Best 1RM 20.4 lb" for a 17.5 lb × 5 set. Standard metric, but consider labelling
it "Est. 1RM" so it isn't read as a real one-rep max.

## U4. One-tap re-pair now works even if the friend isn't lifting yet — FIX

`JoinPartnerSession` used to require the partner to already be in a session, so
two established partners who both just arrived (neither in a session) had to fall
back to the QR — not "easy pairing". Now tapping a partner joins their session if
they have one, or mints a fresh shared session and pulls them in if they don't.
Still gated on a prior pairing (you must have trained together at least once), and
it never yanks a partner out of an existing group. Trust note: this places a prior
partner into a session without a real-time accept (same implied-consent model as
scanning someone's QR) — dial back if that's unwanted.

## U5. Debug tiles shown in every user's Settings — PROPOSE

Settings lists "Notification debugging" (→ /debug-notifications) and "Diagnostic
logs" (→ /debug-logs) to all users, ungated. "Diagnostic logs" is defensible as
self-service support; "Notification debugging" reads as a developer tool. Consider
gating behind `kDebugMode` or a hidden gesture to declutter user settings.

## Backend B1. Dropped the redundant `sessions` table — FIX

The session model had four tables: `user_current_session` (live), 
`session_participants_current` (live blob cache), the new `session_members`
(durable roster), and `sessions` (session_id, created_by, created_at). The
`sessions` table only supplied a date and an unused `created_by`. The date is
derivable from `session_members.first_joined_at`, so the table + its write +
`create_session()` were removed — 4 session tables → 3. Tests still green.

---
