# Schlift — Flutter app

The phone app for Schlift. The Wear OS and Apple Watch apps are native and sit
beside it in `android/wear` and `ios/SchliftWatch`. See the
[root README](../README.md) for the project overview,
[`docs/makefile.md`](../docs/makefile.md) for running and building, and the
[release guide](../docs/releasing.md) for shipping builds.

## Layout

```
lib/
  screens/    Full-screen UI (workout, home, onboarding, settings…)
  widgets/    Reusable UI components
  providers/  App state (WorkoutProvider, MultiplayerProvider, SettingsProvider…)
  services/   Transport / gRPC clients
  logic/      Pure logic helpers
  theme/      Theming
  tutorial/   The in-app tutorial
  gen/        Generated code (do not edit by hand)
android/      Phone + Wear OS native modules
ios/          iOS app + Apple Watch (SchliftWatch) targets
```

## Develop

From the repo root:

```bash
make dev         # local backend + debug app, hot reload
make test-app    # Dart tests against the host build of the core
make proto-dart  # regenerate the Dart bindings after editing ../proto
```
