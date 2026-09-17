# In-process app harness (no device required)

Two layers under `app/test/support/` let tests drive the real app logic
and real screens on any machine — no emulator, no backend.

## Provider harness

`ProviderHarness.boot()` builds a real `WorkoutProvider` against
`FakeWorkoutService` (an in-memory `WorkoutServiceWrapper`), with the
platform channels the provider touches mocked. Canned responses go in;
every mutation batch the provider flushes is captured; `failMutations`
holds the offline queue open. Used by
`test/providers/workout_provider_ops_test.dart` to pin the optimistic
plan ops, overlay replay dedupe, and the offline queue — the client half
of what `src/server/workout_tests.rs` pins server-side.

Gotchas encoded in the harness:

- `boot()` settles with microtasks only. A `Future.delayed` would hang
  forever under `testWidgets`' fake clock.
- With an active workout the provider ticks every second, so
  `pumpAndSettle` never settles — use bounded `pump`s, and dispose the
  provider inside the test body (swap in a `SizedBox` first) so the
  pending-timer check passes.

## Screen harness + screenshots

`test/screenshots/screens_shot_test.dart` pumps real screens at phone
size inside the app's provider shell and drives them (tutorial pages,
papers, maths, the weight sheet's ± flow). Every run checks layout and
exceptions; pixel goldens are only written/compared under
`flutter test --update-goldens` (rasterization differs across machines,
so plain runs skip the comparison and CI can't go red on fonts).

The PNGs land in `test/screenshots/goldens/` and are meant to be looked
at — that is how the callout-collision and provider-shell bugs were
found. Emoji/icons render as tofu boxes in goldens (no emoji font in the
test environment); devices are unaffected.

## What still needs the emulator

`make e2e` (scenario suite, `scripts/run_e2e.sh`) and everything under
`app/integration_test/` drive the real APK against a real backend and
need the Android SDK + KVM. The in-process harness is the fast inner
loop; the emulator suite is the outer one.
