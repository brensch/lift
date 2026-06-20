# Schlift — Flutter app

The phone, Wear OS, and Apple Watch client for Schlift. See the
[root README](../README.md) for the full project overview and the
[release guide](../docs/releasing.md) for shipping builds.

## Layout

```
lib/
  screens/    Full-screen UI (workout, home, onboarding, regime settings…)
  widgets/    Reusable UI components
  providers/  App state (WorkoutProvider, MultiplayerProvider, SettingsProvider)
  services/   Transport / gRPC clients
  logic/      Pure logic helpers
  theme/      Theming
  gen/        Generated protobuf bindings (do not edit by hand)
android/      Phone + Wear OS native modules
ios/          iOS app + Apple Watch (SchliftWatch) targets
```

## Develop

```bash
flutter pub get
flutter run
flutter test
```

Regenerate protobuf bindings after editing `../proto`:

```bash
PATH="$PATH:$HOME/.pub-cache/bin" \
  protoc --dart_out=grpc:lib/gen --proto_path=../proto ../proto/workout/v1/*.proto
```
