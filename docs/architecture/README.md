# Schlift Architecture

Reference documentation for how Schlift actually works today. These documents
describe **current behaviour**, not plans. Where something is designed but not
built, it is called out explicitly under "Not implemented".

| Document | Covers |
|---|---|
| [overview.md](overview.md) | System map, components, a write end to end, deployment |
| [local-first.md](local-first.md) | The account on the phone: events, the fold, the core's API, sync |
| [backend.md](backend.md) | Rust module layout, the event store, DB access model, schema changes, RPC surface |
| [data-model.md](data-model.md) | The event log, what an export contains, the server schema and its migrations |
| [workout-lifecycle.md](workout-lifecycle.md) | Template → planned at the start → completed: the estimated max, the time budget, decisions and their reasons, the set state machine, the weight log |
| [multiplayer.md](multiplayer.md) | Sessions, invites, participant status over the Sync stream |
| [app.md](app.md) | Flutter layer boundaries, providers, the core on the phone |
| [wearable.md](wearable.md) | Watch ↔ phone protocol for Wear OS and watchOS |
| [live-status.md](live-status.md) | The workout on the lock screen: Android's Live Update, the iPhone's Live Activity |
| [auth.md](auth.md) | Passkey registration and login, session tokens, the account without a server |
| [analytics.md](analytics.md) | Page-view tracking, sign-in attempt tracking, admins and the `/admin` stats page |
| [testing.md](testing.md) | The test layers, the core's invariant fuzzer, known gaps |

How each lift is planned — the estimated max, the time budget, the
reasons — is specified in
[`docs/plans/planned-at-start.md`](../plans/planned-at-start.md); the code
lives in `core/src/plan.rs`, `core/src/exercise_progress.rs`,
`core/src/exercise_catalog.rs` and `core/src/volume.rs`. The other files in
`docs/plans/` are the history of earlier designs, not descriptions of the
current one.

## Conventions used here

- Diagrams are [Mermaid](https://mermaid.js.org/); they render on GitHub.
- File references are repo-relative, e.g. `core/src/account.rs`.

## Reading order

If you are new to the codebase, read [overview.md](overview.md), then
[local-first.md](local-first.md) — where the account lives and how it moves —
then [workout-lifecycle.md](workout-lifecycle.md): the workout lifecycle is
where most of the complexity lives, and everything else is in service of it.
