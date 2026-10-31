# Schlift Architecture

Reference documentation for how Schlift actually works today. These documents
describe **current behaviour**, not plans. Where something is designed but not
built, it is called out explicitly under "Not implemented".

| Document | Covers |
|---|---|
| [overview.md](overview.md) | System map, components, a write end to end, deployment |
| [local-first.md](local-first.md) | The account on the phone: events, the fold, the core's API, sync |
| [backend.md](backend.md) | Rust module layout, the event store, DB access model, RPC surface |
| [data-model.md](data-model.md) | The event log, the projected tables, the server schema |
| [workout-lifecycle.md](workout-lifecycle.md) | Template → active → completed, the set state machine, progression |
| [multiplayer.md](multiplayer.md) | Sessions, invites, participant status over the Sync stream |
| [app.md](app.md) | Flutter layer boundaries, providers, the core on the phone |
| [wearable.md](wearable.md) | Watch ↔ phone protocol for Wear OS and watchOS |
| [auth.md](auth.md) | Passkey registration and login, session tokens, the account without a server |
| [analytics.md](analytics.md) | Page-view tracking, sign-in attempt tracking, admins and the `/admin` stats page |
| [testing.md](testing.md) | The test layers, the core's invariant fuzzer, known gaps |

Progression, templates and volume are specified in
[`docs/plans/composable-workouts.md`](../plans/composable-workouts.md), which
this refactor implemented; the code lives in `core/src/exercise_catalog.rs`,
`core/src/exercise_progress.rs` and `core/src/volume.rs`.

## Conventions used here

- Diagrams are [Mermaid](https://mermaid.js.org/); they render on GitHub.
- File references are repo-relative, e.g. `core/src/account.rs`.

## Reading order

If you are new to the codebase, read [overview.md](overview.md), then
[local-first.md](local-first.md) — where the account lives and how it moves —
then [workout-lifecycle.md](workout-lifecycle.md): the workout lifecycle is
where most of the complexity lives, and everything else is in service of it.
