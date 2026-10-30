// The scenario orchestrator: drives the real app on the emulator with expressive
// actions, captures a screenshot per step, and records a structured step log
// (titles, notes, and API-state assertions) that the host driver turns into an
// auditable HTML report.
//
// Runs on integration_test's live binding, so real gRPC round-trips and real
// timers resolve naturally — no fake-async workarounds.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/main.dart';
import 'package:schlift/providers/sound_provider.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:schlift/services/health_service.dart';
import 'package:schlift/services/notification_service.dart';

import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'api.dart';
import 'package:schlift/theme/app_icons.dart';

/// The rest-over sound, muted. The emulator has no audio device worth the
/// name, and playing a clip through it (every early Start, every rest end) is
/// one of the things that has brought the WSL2 emulator down mid-run. Sound
/// is not under test here; the scenario swaps this in after each pump.
class _SilentSoundProvider extends SoundProvider {
  @override
  Future<void> playCurrentSound() async {}

  @override
  Future<void> playPreview(String preset) async {}
}

class _Step {
  _Step(this.index, this.title, {this.shot, this.note, this.kind = 'ui'});
  final int index;
  final String title;
  final String? shot; // screenshot base name, if any
  final String? note;
  final String kind; // 'ui' | 'api' | 'assert' | 'peer'
}

/// One end-to-end scenario. Construct with the binding + tester + a name, then
/// script it with the actions below; call [report] at the end.
class Scenario {
  Scenario(this.binding, this.tester, this.name) : api = Api.connect();

  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final String name;
  final Api api;

  final List<_Step> _steps = [];
  int _n = 0;

  // ── Lifecycle ──

  /// Pump the real app. It reaches the backend at localhost:50051 (adb reverse).
  /// Pump the real app. [suppressHealth] keeps the native Health Connect sheet
  /// from appearing (the default — it would hang the test); a health-focused
  /// scenario can pass false when the permissions are pre-granted via adb so the
  /// app can actually exercise the Health Connect write path.
  Future<void> launch({bool suppressHealth = true}) async {
    // Suppress the native Health Connect permission sheet — it would pause the
    // Flutter surface and hang the test. Health isn't under test here.
    HealthService.suppressPermissionPrompts = suppressHealth;
    // Mirror main()'s pre-runApp setup that pumpWidget bypasses: tz + plugin
    // init, without which scheduling a rest notification (on set completion)
    // throws a timezone LateInitializationError. init() asks for nothing, and
    // PermissionsService.load() is deliberately not called, so the
    // permissions screen and its native dialogs never appear.
    await NotificationService.init();
    // Convert the surface to an image BEFORE the app renders. Doing it after the
    // login animation starts hangs (it waits for a stable frame that never
    // arrives). Once converted, every takeScreenshot captures the live surface.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(const SchliftApp());
    await settle();
    _muteRestSound();
  }

  /// Point the workout provider at a sound provider that plays nothing.
  void _muteRestSound() {
    final apps = find.byType(MaterialApp);
    if (apps.evaluate().isEmpty) return;
    Provider.of<WorkoutProvider>(
      tester.element(apps.first),
      listen: false,
    ).setSoundProvider(_SilentSoundProvider());
  }

  /// Re-pump a fresh [SchliftApp] — new providers, new gRPC client — to simulate
  /// a cold restart. Crash recovery should re-fetch server state (e.g. an active
  /// workout) on the way back up.
  Future<void> relaunch() async {
    await tester.pumpWidget(const SchliftApp());
    await settle(seconds: 4);
    _muteRestSound();
  }

  /// Let real gRPC, timers, and animations resolve. `pumpAndSettle` never
  /// completes here (the app polls every second), so pump in real-time bursts.
  Future<void> settle({int seconds = 3}) async {
    // On integration_test's live binding, pump() advances real async (gRPC,
    // timers) — no extra Future.delayed needed, and delays here can revert the
    // converted screenshot surface.
    for (var i = 0; i < seconds * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// Finish: shut the API channel and emit the step log to stdout, one short
  /// line per step. integration_test delivers EITHER screenshots (onScreenshot)
  /// OR reportData — not both — so the log can't ride the driver channel and app
  /// files are wiped when `flutter drive` uninstalls on teardown. Printing to
  /// the test log is the one channel that always survives: the host parses these
  /// `E2E|` lines out of the drive log (see scripts/build_e2e_report.py).
  Future<void> report() async {
    await api.close();
    // One line per record keeps every line well under any log-truncation limit.
    // ignore: avoid_print
    print('E2E|scenario|$name');
    for (final s in _steps) {
      final rec = <String, dynamic>{
        'index': s.index,
        'title': s.title,
        'kind': s.kind,
        if (s.shot != null) 'shot': s.shot,
        if (s.note != null) 'note': s.note,
      };
      // ignore: avoid_print
      print('E2E|step|${jsonEncode(rec)}');
    }
    // ignore: avoid_print
    print('E2E|end|$name');
  }

  /// Run the scenario [body] with explicit failure capture. On ANY error —
  /// a failed expect, a tap that missed, a timeout — this prints a loud,
  /// self-contained failure block (the error, the last step reached, and every
  /// text on screen at the moment of failure) and saves a FAILURE screenshot,
  /// then rethrows. So a red run says exactly what broke and where, instead of
  /// leaving a wall of framework log to reverse-engineer. Always emits the
  /// report. Scenarios that use run() must NOT also call report() themselves.
  Future<void> run(Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      await _captureFailure(error);
      rethrow;
    } finally {
      await report();
    }
  }

  Future<void> _captureFailure(Object error) async {
    final lastStep = _steps.isNotEmpty ? _steps.last.title : '(no steps yet)';
    List<String> onScreen;
    try {
      onScreen = visibleTexts();
    } catch (_) {
      onScreen = const ['<could not read the widget tree>'];
    }
    try {
      final base = '${name}_FAILURE';
      await binding.takeScreenshot(base);
      _steps.add(
        _Step(
          _n,
          'FAILURE: $error',
          shot: '$base.png',
          note: error.toString(),
          kind: 'assert',
        ),
      );
      _n++;
    } catch (_) {
      // Screenshot can fail if the surface is gone; the printed block still lands.
    }
    // A loud, greppable block on the one channel that survives teardown (stdout).
    void say(String line) => debugPrint(line); // ignore: avoid_print
    say('');
    say('════════════════ SCENARIO FAILED: $name ════════════════');
    say('LAST STEP OK : $lastStep');
    say('ERROR        : $error');
    say(
      'ON SCREEN NOW: ${onScreen.isEmpty ? '(nothing)' : onScreen.join(' | ')}',
    );
    say('════════════════════════════════════════════════════════');
    say('');
    // Machine-readable twin for the host report builder.
    // ignore: avoid_print
    print(
      'E2E|failure|${jsonEncode({'scenario': name, 'lastStep': lastStep, 'error': error.toString(), 'onScreen': onScreen})}',
    );
  }

  /// Every non-empty text string currently in the widget tree — the ground truth
  /// for "what screen am I actually on" when an expectation fails.
  List<String> visibleTexts() {
    final out = <String>[];
    for (final element in find.byType(Text).evaluate()) {
      final widget = element.widget;
      if (widget is Text) {
        final text = widget.data ?? widget.textSpan?.toPlainText();
        if (text != null && text.trim().isNotEmpty) out.add(text.trim());
      }
    }
    return out;
  }

  /// Wait for [text] and throw an explicit error if it never appears. Prefer
  /// this over `expect(isVisible(...), isTrue)` at scenario gates: paired with
  /// run(), a miss reports what text WAS on screen instead of a bare `false`.
  Future<void> mustSee(String text, {int seconds = 8}) async {
    if (await waitForText(text, seconds: seconds)) return;
    throw StateError(
      'expected "$text" on screen within ${seconds}s — not found',
    );
  }

  // ── Capture ──

  /// Screenshot the current screen and record a report step. Pumps a couple of
  /// frames first so the captured surface reflects the very latest state (e.g. a
  /// banner that just appeared via an async poll), not a frame behind.
  Future<void> shot(String title, {String? note}) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final base = '${name}_${_n.toString().padLeft(2, '0')}';
    _progress('shot $base: $title');
    await binding.takeScreenshot(base);
    _steps.add(_Step(_n, title, shot: '$base.png', note: note, kind: 'ui'));
    _n++;
  }

  /// Record a note / API-state checkpoint (no screenshot).
  void note(String title, {String? detail, String kind = 'api'}) {
    _steps.add(_Step(_n, title, note: detail, kind: kind));
    _n++;
  }

  // ── Interactions ──

  /// Scroll [f] into view if it lives in a scrollable. Login/onboarding/home are
  /// all scroll views, so a target below the fold would otherwise fail its
  /// hit-test (tapping empty space). Harmless when there's nothing to scroll.
  Future<void> _reveal(Finder f) async {
    try {
      await tester.ensureVisible(f.first);
      await tester.pump(const Duration(milliseconds: 200));
    } catch (_) {
      // Not inside a Scrollable (or already visible) — ensureVisible throws; fine.
    }
  }

  /// One line on logcat per action, so the drive log says how far a scenario
  /// got even when the emulator dies before the step log is printed.
  void _progress(String what) => debugPrint('E2E> $name: $what');

  Future<void> tap(Finder f, {String? shot}) async {
    _progress('tap ${f.describeMatch(Plurality.one)}');
    expect(f, findsWidgets, reason: 'nothing to tap: $f');
    await _reveal(f);
    await tester.tap(f.first);
    await settle();
    if (shot != null) await this.shot(shot);
  }

  Future<void> tapText(String label, {String? shot}) =>
      tap(find.text(label), shot: shot);

  Future<void> typeInto(Finder field, String text) async {
    expect(field, findsWidgets, reason: 'no field: $field');
    await _reveal(field);
    await tester.tap(field.first);
    await tester.enterText(field.first, text);
    // Drop the soft keyboard before we move on — left up, it covers the button
    // below the field (e.g. Dev Login), and the next tap silently misses. Use
    // plain pump, not pumpAndSettle: login/onboarding animate continuously (the
    // creature/marker), so pumpAndSettle would block waiting to settle.
    FocusManager.instance.primaryFocus?.unfocus();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scroll [within] (default: the first Scrollable) by [dy] logical pixels
  /// (negative scrolls the content up, revealing what's below).
  Future<void> scroll(double dy, {Finder? within}) async {
    final target = within ?? find.byType(Scrollable).first;
    await tester.drag(target, Offset(0, dy));
    await settle(seconds: 1);
  }

  void expectVisible(String text) => expect(
    find.text(text),
    findsWidgets,
    reason: 'expected "$text" on screen',
  );

  bool isVisible(String text) => find.text(text).evaluate().isNotEmpty;

  /// Poll until [text] appears (backend round-trips resolve asynchronously).
  Future<bool> waitForText(String text, {int seconds = 8}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (isVisible(text)) return true;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Dev-login (test-auth) as [username] via the login screen's dev field. A
  /// brand-new account lands on onboarding; a returning one on home (or
  /// straight into its live workout).
  Future<void> devLogin(String username) async {
    // Wait for the login screen — a freshly-booted emulator's first app launch
    // can render slower than launch()'s settle window.
    if (!await waitForText(copy.login.devLogin, seconds: 15)) {
      // Not on login: a previous scenario's session survived on the device
      // (flutter drive only uninstalls the app on a clean teardown, and an
      // emulator crash skips that). Sign it out and carry on.
      final menu = find.byIcon(AppIcons.menu);
      if (menu.evaluate().isEmpty) {
        throw StateError(
          'expected the login screen or a signed-in app; on screen: '
          '${visibleTexts().join(" | ")}',
        );
      }
      await tap(menu);
      await tapText('Logout');
      await mustSee(copy.login.devLogin, seconds: 10);
    }
    final field = find.widgetWithText(TextField, copy.login.devUsername);
    final target = field.evaluate().isNotEmpty ? field : find.byType(TextField);
    await typeInto(target, username);
    await tapText(copy.login.devLogin);
    await settle(seconds: 5);
  }

  /// Walk the whole onboarding flow (marker → unit → strength → bodyweight →
  /// templates) accepting the defaults — the library's default templates
  /// (StrongLifts A and B) come pre-ticked — skip the first-run tutorial and
  /// land on the home screen with START showing. Used by scenarios that need a
  /// set-up user but aren't testing onboarding itself. A no-op for a
  /// returning user, who is routed past onboarding.
  Future<void> completeOnboarding() async {
    if (!await waitForText(copy.onboarding.marker.title, seconds: 10)) {
      await skipTutorial();
      return; // already past onboarding (e.g. a returning user)
    }
    await tapText(copy.onboarding.next); // marker → unit
    await mustSee(copy.onboarding.unit.title, seconds: 6);
    await tapText(copy.onboarding.next); // unit → strength
    await mustSee(copy.onboarding.strength.title, seconds: 6);
    await tapText(copy.onboarding.next); // strength → bodyweight
    await mustSee(copy.onboarding.weight.field, seconds: 6);
    await tapText(copy.onboarding.next); // bodyweight → templates
    await mustSee(copy.onboarding.templates.title, seconds: 6);
    await mustSee(defaultTemplateName, seconds: 10); // the library has loaded
    await tapText(copy.onboarding.templates.finish); // commit the defaults
    await skipTutorial();
    await mustSee(homeStart, seconds: 15);
  }

  /// One of the library templates ticked by default (templates/library.yaml):
  /// Squat, Bench Press, Barbell Row. StrongLifts B (Squat, Overhead Press,
  /// Deadlift) is the other; home suggests whichever covers more unworked
  /// muscle, so a scenario that seeds history should seed all five lifts.
  static const defaultTemplateName = 'StrongLifts A';

  /// Every lift the default templates can prescribe.
  static const defaultTemplateLifts = [
    Exercise.EXERCISE_SQUAT,
    Exercise.EXERCISE_BENCH_PRESS,
    Exercise.EXERCISE_BARBELL_ROW,
    Exercise.EXERCISE_OVERHEAD_PRESS,
    Exercise.EXERCISE_DEADLIFT,
  ];

  /// The home card's start button.
  static const homeStart = 'START';

  /// The first arrival at home shows the walkthrough once per account; it is
  /// not under test here, so dismiss it. Plain pumps only — the tutorial
  /// animates continuously, so pumpAndSettle would never return.
  Future<void> skipTutorial() async {
    if (await waitForText(copy.tutorial.skip, seconds: 8)) {
      await tapText(copy.tutorial.skip);
      await settle(seconds: 2);
    }
  }

  /// The app's workout state, read straight from its provider.
  WorkoutProvider get workout => Provider.of<WorkoutProvider>(
    tester.element(find.byType(MaterialApp).first),
    listen: false,
  );

  /// A set's circle on the workout page.
  Finder circleFor(String setId) => find.byKey(ValueKey('set-circle-$setId'));

  /// Whether a rung is asking how many reps were left.
  bool get repsLeftAsked => isVisible(copy.workout.repsLeftQuestion);

  /// The set whose circle is up next, when one can be started now.
  ProposedSet? get nextSet {
    if (repsLeftAsked) return null;
    final set = workout.doneTargetSet;
    if (set == null || circleFor(set.id).evaluate().isEmpty) return null;
    return set;
  }

  /// Whether a set is ready to lift: the up-next circle is on screen.
  bool get setOffered => nextSet != null;

  /// From home, start the expanded template's workout (the suggestion by
  /// default) and wait for its first circle: a calibration rung, a warmup
  /// or a working set.
  Future<void> startWorkoutFromHome() async {
    await mustSee(homeStart, seconds: 10);
    await tapText(homeStart);
    for (var i = 0; i < 12 && !setOffered; i++) {
      await settle(seconds: 1);
    }
    expect(setOffered, isTrue, reason: 'no set circle after Start');
  }

  /// Lift the next set on its circle: tap to start it, tap again when it is
  /// done, then once more per [missed] rep. A finding-weight rung then asks
  /// how many reps were left: [repsLeft] answers (2–3 by default).
  Future<void> liftSet({int missed = 0, String? repsLeft}) async {
    for (var i = 0; i < 16 && !setOffered; i++) {
      if (repsLeftAsked) await tapText(repsLeft ?? copy.workout.repsLeftSome);
      await settle(seconds: 1);
    }
    final set = nextSet;
    expect(set, isNotNull, reason: 'no set to lift');
    await tap(circleFor(set!.id));
    expect(
      workout.activeWorkout?.liftingSetId,
      set.id,
      reason: 'the first tap starts the set',
    );
    for (var i = 0; i <= missed; i++) {
      await tap(circleFor(set.id));
    }
    if (set.calibration) {
      await mustSee(copy.workout.repsLeftQuestion, seconds: 4);
      await tapText(repsLeft ?? copy.workout.repsLeftSome);
    }
  }

  /// End the live workout through the confirm dialog and wait for the
  /// summary. "End workout" is the quiet link under the exercise list and,
  /// once every set is done, the bar's big button; either opens the dialog.
  Future<void> endWorkoutAndWaitForSummary() async {
    await tapText(copy.workout.endWorkout);
    await mustSee('This will end your current workout.', seconds: 6);
    await tap(find.text('End Workout').last); // the dialog's confirm button
    await mustSee('Session snapshot', seconds: 15);
  }
}
