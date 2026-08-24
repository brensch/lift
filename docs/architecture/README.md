# Schlift Architecture

Reference documentation for how Schlift actually works today. These documents
describe **current behaviour**, not plans. Where something is designed but not
built, it is called out explicitly under "Not implemented".

| Document | Covers |
|---|---|
| [overview.md](overview.md) | System map, components, a request end to end, deployment |
| [backend.md](backend.md) | Rust module layout, DB access model, RPC surface |
| [data-model.md](data-model.md) | SQLite schema, entity relationships, blob columns |
| [workout-lifecycle.md](workout-lifecycle.md) | Template → active → completed, the set state machine, optimistic mutations |
| [multiplayer.md](multiplayer.md) | Sessions, invites, participant fan-out |
| [app.md](app.md) | Flutter layer boundaries, providers, polling and refresh |
| [wearable.md](wearable.md) | Watch ↔ phone ↔ server protocol for Wear OS and watchOS |
| [auth.md](auth.md) | Passkey registration and login, session tokens |
| [testing.md](testing.md) | The test layers, the API invariant harness, known gaps |

Progression, templates and volume are specified in
[`docs/plans/composable-workouts.md`](../plans/composable-workouts.md), which
this refactor implemented; the code lives in `src/exercise_catalog.rs`,
`src/exercise_progress.rs` and `src/volume.rs`.

## Conventions used here

- Diagrams are [Mermaid](https://mermaid.js.org/); they render on GitHub.
- File references are repo-relative, e.g. `src/server/workout.rs:850`.

## Reading order

If you are new to the codebase, read [overview.md](overview.md), then
[workout-lifecycle.md](workout-lifecycle.md) — the workout lifecycle is where
most of the complexity lives, and everything else is in service of it.
