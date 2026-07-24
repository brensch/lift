# Android Development

Everything for running Schlift on Android — emulator and physical device, phone
and Wear OS. Written so an automated agent starting from a fresh shell can
follow it end to end.

- [Quick start (emulator)](#quick-start-emulator)
- [Physical phone](#physical-phone)
- [Wear OS](#wear-os)
- [Screenshots and input automation](#screenshots-and-input-automation)
- [Backend](#backend)
- [Java toolchain](#java-toolchain)
- [Troubleshooting](#troubleshooting)

## Why `adb reverse` is always needed

An Android device or emulator cannot reach the host's `localhost`. The Flutter
debug app points at `localhost:50051`, which on the device means *the device*.
`adb reverse` maps the device's `localhost:50051` back to the host:

```bash
~/android-sdk/platform-tools/adb reverse tcp:50051 tcp:50051
```

`make run-android`, `make run-app` and `make android-agent-start` all do this
automatically. Nearly every "connection refused" is this mapping missing.

```bash
adb reverse --list              # verify
adb reverse --remove tcp:50051  # remove
```

## Quick start (emulator)

One target does everything:

```bash
make android-agent-start
```

This starts the Rust backend on `127.0.0.1:50051` (SQLite under
`.tmp/agent-android/data`), creates the `lift_api34` phone AVD if missing, boots
it headlessly, waits for boot, runs `adb reverse`, installs and launches the
Flutter debug app with `--no-resident`, and captures
`.tmp/screenshots/android-agent-start.png`.

```bash
make android-agent-stop           # stop backend + emulator
tail -f .tmp/agent-android/backend.log
```

### Visible emulator window

Headless is the default because screenshot automation is more reliable under
WSL. For a visible window through WSLg, stop the existing emulator first — only
one instance of an AVD may run at a time:

```bash
make android-emulator-stop
make android-emulator-start ANDROID_EMULATOR_WINDOW=1
make android-emulator-wait
```

## Physical phone

Enable USB debugging: **Settings → About phone**, tap **Build number** seven
times, then **Settings → Developer options → USB debugging**. Connect over USB
and accept the prompt on the device.

```bash
make run-backend      # terminal 1
make run-android      # terminal 2 — sets up adb reverse automatically
```

With several devices attached, target one explicitly:

```bash
flutter devices
~/android-sdk/platform-tools/adb -s <serial> reverse tcp:50051 tcp:50051
cd app && flutter run -d <device-id>
```

### Release APK

```bash
cd app && flutter build apk --release
adb install app/build/app/outputs/flutter-apk/app-release.apk
```

Output lands at `app/build/app/outputs/flutter-apk/app-release.apk`. For signed
store builds see [`releasing.md`](releasing.md).

## Wear OS

### Emulator

```bash
make android-wear-run-emulator
```

Creates and boots a Wear AVD, builds the Wear module, installs and launches it.
This proves the watch app runs and can be screenshotted and tapped over adb. It
does **not** pair the watch emulator to a phone emulator.

### Pairing a Wear emulator to a phone emulator

Supported by Android, but the pairing assistant requires a phone running
Android 11+ **with the Google Play Store**, and Android Studio's Device Manager.

```bash
make android-phone-play-avd-create
make android-wear-avd-create
make android-phone-play-emulator-start ANDROID_EMULATOR_WINDOW=1
make android-emulator-wait
make android-wear-emulator-start ANDROID_EMULATOR_WINDOW=1
```

Then in Android Studio: **Device Manager → Pair Wearable**.

> Android Studio is not installed in this WSL environment, so there is no fully
> headless pairing flow here. Command-line automation can boot both emulators,
> install both apps, screenshot and drive input — the missing piece is the Google
> Play Services Wear node pairing between emulated phone and emulated watch.
> Reference: <https://developer.android.com/training/wearables/get-started/connect-phone>

### Physical watch (wireless debugging)

Modern Wear OS debugging is wireless, and `adb pair` alone is **not** enough —
you must also `adb connect`. The pair port and debug port differ.

On the watch: enable **Developer options**, **ADB debugging**, then open
**Wireless debugging → Pair new device** and note the pairing endpoint, pairing
code, and (back on the main Wireless debugging screen) the debug endpoint.

In the same shell you use for `make` — this matters under WSL2:

```bash
~/android-sdk/platform-tools/adb kill-server
~/android-sdk/platform-tools/adb start-server
~/android-sdk/platform-tools/adb pair <watch_ip>:<pair_port>
~/android-sdk/platform-tools/adb connect <watch_ip>:<debug_port>
~/android-sdk/platform-tools/adb devices
```

Then run the Wear app:

```bash
make run-wear                                          # first connected device
WEAR_SERIAL=<watch_ip>:<debug_port> make run-wear      # explicit target
make run-wear-logs                                     # tail logs
```

If a phone is attached over USB (e.g. via `usbipd`), auto-detect may pick the
phone. Pass `WEAR_SERIAL` explicitly in that case.

## Screenshots and input automation

```bash
make android-screenshot ANDROID_SCREENSHOT_OUT=.tmp/screenshots/current.png
make android-tap X=540 Y=1300
make android-text TEXT=codex
```

Useful raw adb:

```bash
ADB=~/android-sdk/platform-tools/adb
$ADB -s emulator-5554 shell input keyevent 111    # hide soft keyboard
$ADB -s emulator-5554 shell input keyevent 4      # back
$ADB -s emulator-5554 shell dumpsys window | rg 'mCurrentFocus|mFocusedApp'
```

Hide the keyboard with `keyevent 111` before tapping buttons it covers —
otherwise taps land on the keyboard.

## Backend

The backend is the Rust binary `schlift`, listening on `0.0.0.0:50051`:

```bash
curl http://127.0.0.1:50051/api/health
```

```bash
make run-backend           # foreground
make agent-backend-start   # background (agent use)
make agent-backend-stop
```

Dev targets build with `--features test-auth`, which enables the `TestLogin` RPC
used for dev login without a passkey. Production builds do not enable it and
`TestLogin` returns `permission_denied` — see
[`architecture/auth.md`](architecture/auth.md#test-login).

## Java toolchain

Use a full JDK, not a JRE. Java 17 lives at
`/usr/lib/jvm/java-17-openjdk-amd64`. The Android Make targets derive
`JAVA_HOME` from `javac`, avoiding the broken Java 21 JRE-only path.

```bash
make android-sdk-check
make check-android-java
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Connection refused ... localhost ... 50051` | Backend not running, or `adb reverse tcp:50051 tcp:50051` missing |
| Device not detected | `adb devices`; if `unauthorized`, re-accept the USB prompt on the device |
| Multiple devices | `adb -s <serial> reverse tcp:50051 tcp:50051` |
| Gradle: Java lacks `JAVA_COMPILER` | `JAVA_HOME` points at a JRE — run `make check-android-java` |
| No visible emulator | Expected when started with `-no-window`; use `ANDROID_EMULATOR_WINDOW=1` |
| Watch not listed under WSL2 | Re-run `adb pair …` **then** `adb connect …` in the WSL shell |
| Watch app installs but phone can't see it | Wear emulator is not paired via the Wear OS pairing assistant |
