# LLM Android Runbook

This file is for an automated coding agent starting from a fresh shell in this
repo. It captures the shortest path to run the backend, boot an Android
emulator, launch the Flutter app, and drive it from screenshots.

## Quick Start: Phone Emulator + Backend

From the repo root:

```bash
make android-agent-start
```

This target does all of the following:

- starts the Rust backend on `127.0.0.1:50051`
- stores its SQLite data under `.tmp/agent-android/data`
- creates the `lift_api34` phone AVD if missing
- boots the emulator headlessly by default
- waits for Android to finish booting
- runs `adb reverse tcp:50051 tcp:50051`
- installs and launches the Flutter debug app with `--no-resident`
- captures `.tmp/screenshots/android-agent-start.png`

Stop the background pieces with:

```bash
make android-agent-stop
```

The backend log is:

```bash
.tmp/agent-android/backend.log
```

## Visible Emulator Window

The default is headless because screenshot automation is more reliable in WSL.
To try a visible emulator window through WSLg, stop the existing emulator first,
then start it with `ANDROID_EMULATOR_WINDOW=1`:

```bash
make android-emulator-stop
make android-emulator-start ANDROID_EMULATOR_WINDOW=1
make android-emulator-wait
```

Only one instance of the same AVD should run at a time.

## Screenshot And Input Automation

Capture a screenshot:

```bash
make android-screenshot ANDROID_SCREENSHOT_OUT=.tmp/screenshots/current.png
```

Tap coordinates:

```bash
make android-tap X=540 Y=1300
```

Type text:

```bash
make android-text TEXT=codex
```

Useful direct adb commands:

```bash
~/android-sdk/platform-tools/adb -s emulator-5554 shell input keyevent 111
~/android-sdk/platform-tools/adb -s emulator-5554 shell input keyevent 4
~/android-sdk/platform-tools/adb -s emulator-5554 shell dumpsys window | rg 'mCurrentFocus|mFocusedApp'
```

Use `keyevent 111` to hide the soft keyboard before tapping covered buttons.

## Backend Details

The backend is the Rust binary `schlift`. It listens on `0.0.0.0:50051` and
exposes a health check at:

```bash
curl http://127.0.0.1:50051/api/health
```

For a foreground backend, use:

```bash
make run-backend
```

For the agent background backend only:

```bash
make agent-backend-start
make agent-backend-stop
```

The Flutter debug app defaults to `localhost:50051`. On an Android emulator,
`localhost` means the emulator, so the Makefile runs:

```bash
adb reverse tcp:50051 tcp:50051
```

That maps emulator `localhost:50051` to host `localhost:50051`.

## Java Toolchain

Use a full JDK, not a JRE. This machine has Java 17 installed at:

```bash
/usr/lib/jvm/java-17-openjdk-amd64
```

The Android Make targets derive `JAVA_HOME` from `javac`, which avoids the
broken Java 21 JRE-only path.

Check the Android toolchain with:

```bash
make android-sdk-check
```

## Wear OS Emulator

Create and boot a Wear OS AVD, build the Wear module, install it, and launch it:

```bash
make android-wear-run-emulator
```

This proves the watch app can run under an emulator and can be screenshot/tapped
through adb like the phone emulator. It does not by itself pair the watch
emulator to the phone emulator.

## Phone Emulator + Wear Emulator Pairing

Yes, Android supports pairing a Wear emulator with a phone device or phone
emulator. The current official Android docs say the phone must be Android 11+
and have the Google Play Store for the Wear OS emulator pairing assistant.

Create the two AVDs needed for that route:

```bash
make android-phone-play-avd-create
make android-wear-avd-create
```

Start the Play Store phone AVD visibly:

```bash
make android-phone-play-emulator-start ANDROID_EMULATOR_WINDOW=1
make android-emulator-wait
```

Start the Wear AVD visibly:

```bash
make android-wear-emulator-start ANDROID_EMULATOR_WINDOW=1
```

Then use Android Studio:

```text
Device Manager -> Pair Wearable
```

Android Studio is not installed in this WSL environment at the time this runbook
was written, so a fully headless command-line pairing flow is not available here.
Command-line automation can still boot both emulators, install both apps, capture
screenshots, and drive UI input. The missing piece is the official Google Play
Services Wear node pairing between the emulated phone and emulated watch.

Official docs:

```text
https://developer.android.com/training/wearables/get-started/connect-phone
```

## Physical Wear OS Watch

For an actual watch, use wireless debugging:

```bash
~/android-sdk/platform-tools/adb pair <watch_ip>:<pair_port>
~/android-sdk/platform-tools/adb connect <watch_ip>:<debug_port>
WEAR_SERIAL=<watch_ip>:<debug_port> make run-wear
```

The pair port and debug port are different. On the watch, use:

```text
Settings -> Developer options -> Wireless debugging -> Pair new device
```

After pairing, return to the Wireless debugging screen and use the main debug
endpoint for `adb connect`.

## Common Failure Modes

- `Connection refused ... localhost ... 50051`: backend is not running or
  `adb reverse tcp:50051 tcp:50051` is missing.
- Gradle says Java lacks `JAVA_COMPILER`: `JAVA_HOME` points at a JRE. Run
  `make check-android-java`.
- No visible emulator: expected when started with `-no-window`.
- Watch app installs but phone cannot see it: the Wear emulator is not paired to
  the phone through the Wear OS pairing assistant.
