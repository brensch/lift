# End-to-end screenshot harness

A headless way to drive the **real** Schlift app against a **real** backend and
capture a legible screenshot of each screen for audit — the Flutter equivalent
of a Puppeteer run, with no emulator required.

```bash
make e2e-screens
# then open: app/test_screenshots/onboarding/report.html
```

## What it does

`harness.dart` provides:

- **`TestBackend.start()`** — builds the Rust backend (`--features test-auth`)
  and spawns it on its own port with a throwaway database. Isolated and
  repeatable.
- **`AppDriver`** — pumps the real `SchliftApp` pointed at that backend (real
  gRPC over a real socket), and exposes expressive actions:
  - `launch`, `shot('name')`, `tap`, `tapText`, `typeInto`, `devLogin`,
    `expectVisible`, `waitForBackend`, `finish`.
  - every `shot` writes a numbered PNG into `test_screenshots/<scenario>/` and
    adds it to an HTML `report.html` you can open and scroll.

Screens render with **real fonts** — Manrope + Space Grotesk are bundled under
`assets/google_fonts/` (which also removes the app's first-run font fetch in
production), and Roboto + MaterialIcons come from the SDK cache. Screenshots look
like the app, not tofu boxes.

## Writing a scenario

```dart
testWidgets('my flow', (tester) async {
  final app = AppDriver(tester, 'my_flow');   // -> test_screenshots/my_flow/
  await app.launch(backend);
  await app.shot('start');
  await app.typeInto(find.byType(TextField).first, 'squats');
  await app.tapText('Add', capture: 'after adding');
  await app.finish('My flow');
}, timeout: const Timeout(Duration(seconds: 30)));
```

Read it like a user story; each `capture:`/`shot` is a frame in the report.

## The one caveat, and the path past it

`flutter test` runs on a **fake-async** clock. That is fine for rendering and for
capturing screenshots — which is why this harness works — but it has two limits
with a live-networked app:

1. **Clean exit.** A live gRPC channel keeps a real keepalive timer, so the test
   isolate never goes fully idle and the run ends via its `timeout` rather than a
   green check. **The screenshots and `report.html` are always produced before
   that** — they are the deliverable, so `make e2e-screens` treats a produced
   report as success, not the exit code.
2. **Driving past a real backend round-trip.** Actions that need the backend to
   respond (login, start workout) require yielding to the real event loop
   (`waitForBackend`, which uses `tester.runAsync`). That conflicts with the
   app's periodic timers (the 1 Hz multiplayer poll) once you're logged in, so
   multi-step *post-login* flows are not reliable here.

For **fully interactive, post-login flows**, use the emulator path, which runs on
a real event loop where real gRPC, real timers, and screenshots all just work:

```bash
make android-agent-start     # boots emulator + backend + app
make android-screenshot ANDROID_SCREENSHOT_OUT=.tmp/shot.png
make android-tap X=540 Y=1300
make android-text TEXT=squats
```

See [`docs/android_dev.md`](../../../docs/android_dev.md). A future step is to
port these scenarios to `integration_test` running on that emulator, which would
give clean, scripted, end-to-end runs with screenshots for every step.

## What's proven today

The harness reliably captures real, legible screenshots of the real app's
pre-login screens (login, and anything reachable without a backend round-trip),
against a real backend, with no emulator. That is the fast visual-audit loop;
the emulator path is the heavy but complete one.
