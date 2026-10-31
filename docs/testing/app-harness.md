# In-process app harness (no device required)

Two layers let tests drive the real app logic and real screens on any
machine — no emulator, no backend.

## Provider harness

`ProviderHarness.boot()` (`app/test/support/provider_harness.dart`) builds a
real `WorkoutProvider` and `SettingsProvider` against the **real core**: the
host build of `app/native` (`target/debug/libschlift_native.so`, `.dylib` on
macOS), opened on an in-memory account through `FixedCore`. The platform
channels the provider touches (notifications, prefs) are mocked. Build the
library first — `make test-app` runs `cargo build -p schlift_native` and then
`flutter test`.

Nothing is canned: a test makes the same calls the app does and reads the
core's answers. Used by `test/providers/workout_provider_test.dart`. The
rules themselves are tested in Rust (`core/tests/api.rs`).

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
