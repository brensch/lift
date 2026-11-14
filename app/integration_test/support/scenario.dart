// The scenario orchestrator: drives the real app with expressive actions,
// captures a screenshot per step, and records a structured step log (titles,
// notes, and API-state assertions) that scripts/build_e2e_report.py turns into
// an auditable HTML report.
//
// Runs on integration_test's live binding, so real gRPC round-trips and real
// timers resolve naturally — no fake-async workarounds. scripts/run_e2e.sh
// builds every scenario into one Linux binary and runs many at once.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/main.dart';
import 'package:schlift/providers/sound_provider.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:schlift/screens/workout/set_circle.dart';
import 'package:schlift/services/account_sync.dart';
import 'package:schlift/services/notification_service.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/widgets/dialogs/rung_question_dialog.dart';

import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'api.dart';

/// The rest-over sound, muted: a headless run has no audio device, and sound
/// is not under test here. The scenario swaps this in after each pump.
class _SilentSoundProvider extends SoundProvider {
  @override
  Future<void> playCurrentSound() async {}

  @override
  Future<void> playPreview(String preset) async {}
}

/// The phone every scenario runs as: a Pixel's app surface, 1080 × 2337 at
/// 420 dpi, its status bar 128 pixels deep, so layouts and screenshots (store
/// slides included) match it.
const _phonePixels = Size(1080, 2337);
const _phonePixelRatio = 2.625;
const _statusBarPixels = 128.0;

/// Where screenshots are written: `E2E_OUT`, else app/test_screenshots.
final _shotsDir = Platform.environment['E2E_OUT'] ?? 'test_screenshots';

/// The app, inside a boundary a screenshot is taken from.
final _app = GlobalKey();

/// Pump the real app at the phone's size, ready to be screenshot.
Future<void> pumpApp(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  await binding.setSurfaceSize(_phonePixels / _phonePixelRatio);
  // In the view's own pixels, which on the desktop are not the phone's.
  final statusBar = FakeViewPadding(
    top: _statusBarPixels / _phonePixelRatio * tester.view.devicePixelRatio,
  );
  tester.view
    ..padding = statusBar
    ..viewPadding = statusBar;
  await tester.pumpWidget(
    RepaintBoundary(key: _app, child: const SchliftApp()),
  );
}

/// The app as it is on screen now, written to `<base>.png`.
Future<void> screenshot(String base) async {
  final boundary =
      _app.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: _phonePixelRatio);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File('$_shotsDir/$base.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
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

  /// Pump the real app. It reaches the backend at localhost:50051.
  Future<void> launch() async {
    // Mirror main()'s pre-runApp setup that pumpWidget bypasses: tz + plugin
    // init, without which scheduling a rest notification (on set completion)
    // throws a timezone LateInitializationError. init() asks for nothing, and
    // PermissionsService.load() is deliberately not called, so the
    // permissions screen and its native dialogs never appear.
    await NotificationService.init();
    await pumpApp(binding, tester);
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
    await tester.pumpWidget(const SizedBox());
    await pumpApp(binding, tester);
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
      await screenshot(base);
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
    await screenshot(base);
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

  /// One line in the log per action, so it says how far a scenario got even
  /// when the app dies before the step log is printed.
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

  void expectVisible(String text) => expect(
    find.text(text),
    findsWidgets,
    reason: 'expected "$text" on screen',
  );

  bool isVisible(String text) => find.text(text).evaluate().isNotEmpty;

  /// The header's multiplayer badge reads [people]: that many in the
  /// session, you included. No badge when you're alone or not in one.
  bool showsSessionOf(int people) => find
      .descendant(of: find.byType(Badge), matching: find.text('$people'))
      .evaluate()
      .isNotEmpty;

  /// Poll until the badge reads [people] (it arrives on the Sync stream).
  Future<bool> waitForSessionOf(int people, {int seconds = 15}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (showsSessionOf(people)) return true;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// The header's multiplayer button carries no count: nobody else is in
  /// a session with you.
  bool get showsSolo => find
      .descendant(of: find.byType(Badge), matching: find.byType(Text))
      .evaluate()
      .isEmpty;

  /// Poll until the badge's count is gone (the leave arrives on the Sync
  /// stream).
  Future<bool> waitForSolo({int seconds = 15}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (showsSolo) return true;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Open the menu. It lives on home (and the live workout) only: from a
  /// page pushed over it, go back until home is on show.
  Future<void> openMenu() async {
    for (
      var i = 0;
      i < 5 && find.byIcon(AppIcons.menu).evaluate().isEmpty;
      i++
    ) {
      await tap(find.byIcon(AppIcons.back));
      await settle(seconds: 1);
    }
    await tap(find.byIcon(AppIcons.menu));
  }

  /// Log out from the open menu: the corner button, then its prompt.
  Future<void> logout() async {
    await tap(find.byTooltip(copy.menu.logout));
    await settle(seconds: 1);
    await tap(find.widgetWithText(FilledButton, copy.menu.logout));
  }

  /// Open the live workout's Heart page, from its box over the status box.
  Future<void> openHeart() => tap(heartBox);

  /// Open the edit sheet of the exercise in hand, from the workout (back
  /// to it first from a page pushed over it).
  Future<void> openEdit() async {
    final edit = find.byTooltip(copy.workoutPage.weightAndReps);
    for (var i = 0; i < 3 && edit.evaluate().isEmpty; i++) {
      await tap(find.byIcon(AppIcons.back));
      await settle(seconds: 1);
    }
    await tap(edit.first);
  }

  /// The Heart box: on show only while a workout is live.
  Finder get heartBox => find.byTooltip(copy.workoutPage.tabHeart);

  /// Open the multiplayer sheet from the top row (home or the workout).
  Future<void> openMultiplayer() => tap(find.byTooltip(copy.menu.multiplayer));

  /// Poll until [finder] finds something.
  Future<bool> waitFor(Finder finder, {int seconds = 8}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (finder.evaluate().isNotEmpty) return true;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Poll until [text] appears (backend round-trips resolve asynchronously).
  Future<bool> waitForText(String text, {int seconds = 8}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (isVisible(text)) return true;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Poll until a text containing [text] appears.
  Future<bool> waitForTextContaining(String text, {int seconds = 8}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (find.textContaining(text).evaluate().isNotEmpty) return true;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Dev-login (test-auth) as [username] via the login screen's dev field. A
  /// brand-new account lands on onboarding; a returning one on home (or
  /// straight into its live workout).
  Future<void> devLogin(String username) async {
    // Every scenario starts on a fresh home directory: signed out.
    await mustSee(copy.login.devLogin, seconds: 15);
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
  /// Squat, Barbell Row, Bench Press. StrongLifts B (Squat, Overhead Press,
  /// Deadlift) is the other; home suggests whichever covers more unworked
  /// muscle, so a scenario that seeds history should seed all five lifts.
  static const defaultTemplateName = 'StrongLifts A';

  /// Every lift the default templates can prescribe.
  static const defaultTemplateLifts = [
    Exercise.EXERCISE_SQUAT,
    Exercise.EXERCISE_BARBELL_ROW,
    Exercise.EXERCISE_BENCH_PRESS,
    Exercise.EXERCISE_OVERHEAD_PRESS,
    Exercise.EXERCISE_DEADLIFT,
  ];

  /// The home card's start button.
  static const homeStart = 'Start';

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

  /// The set whose circle is up next, when one can be started now.
  ProposedSet? get nextSet => workout.doneTargetSet;

  /// Whether a set is ready to lift: the workout has one up next. Its
  /// circle may be further down the list (`revealNextSet`).
  bool get setOffered => nextSet != null;

  /// Scroll the workout list until the next set's circle is built and on
  /// screen: the list builds lazily, so a lift further down has no circle
  /// to find until it scrolls in.
  Future<void> revealNextSet() async {
    final set = nextSet;
    if (set == null) return;
    final circle = circleFor(set.id);
    if (circle.evaluate().isNotEmpty) return _reveal(circle);
    await tester.scrollUntilVisible(
      circle,
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

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

  /// Every working set of the live workout done at its target through the
  /// app's own account — a fast-forward past tapping each circle. Full
  /// calibration rungs climb until the sixth settles the working sets.
  Future<int> completeAllWorkingSetsInApp() async {
    var done = 0;
    for (var i = 0; i < 50; i++) {
      final pending = workout.proposedSets.where(
        (p) => !p.warmup && !p.cancelled && !workout.isSetDone(p.id),
      );
      if (pending.isEmpty) break;
      final set = pending.first;
      await tester.runAsync(
        () => workout.completeSet(set.id, set.targetReps, set.targetWeight),
      );
      done++;
    }
    await settle(seconds: 1);
    return done;
  }

  /// Start a workout of [lifts] through the app's own account, each lift
  /// at its weight (an override, so it skips the calibration ramp).
  Future<void> startWorkoutInApp(
    String name,
    List<MapEntry<Exercise, double>> lifts, {
    int sets = 5,
    int reps = 5,
  }) async {
    await tester.runAsync(() async {
      for (final lift in lifts) {
        await workout.setOverride(
          exercise: lift.key,
          weightLb: lift.value,
          reps: reps,
          sets: sets,
        );
      }
      await workout.startWorkout(
        name,
        exercises: [for (final lift in lifts) lift.key],
      );
    });
    await settle(seconds: 1);
  }

  /// Every working set of the live workout done, then the workout ended,
  /// through the app's own account.
  Future<void> finishWorkoutInApp() async {
    await completeAllWorkingSetsInApp();
    await tester.runAsync(() => workout.endWorkout(fireEndedCallback: false));
    await settle(seconds: 1);
  }

  /// A whole session through the app's own account, for history: [lifts]
  /// at their weights, every working set done, ended.
  Future<void> doWorkoutInApp(
    String name,
    List<MapEntry<Exercise, double>> lifts, {
    int sets = 5,
    int reps = 5,
  }) async {
    await startWorkoutInApp(name, lifts, sets: sets, reps: reps);
    await finishWorkoutInApp();
  }

  /// The app's sync stream, read straight from its provider.
  AccountSync get accountSync => Provider.of<AccountSync>(
    tester.element(find.byType(MaterialApp).first),
    listen: false,
  );

  /// Wait until the app's copy of the account holds everything the server
  /// does — after [peer], signed in as the app's own user, seeded history
  /// for it. The server streams it to the app as it is placed, and the app
  /// reloads. Until then a screen can show the account mid-seed.
  Future<void> waitForAppToCatchUp(Peer peer, {int seconds = 30}) async {
    final head = await peer.serverSeq();
    for (var i = 0; i < seconds * 2; i++) {
      final core = accountSync.core;
      final seq = core == null ? 0 : await core.confirmed();
      if (seq >= head) {
        // The reload that follows lands a beat later.
        await settle(seconds: 2);
        return;
      }
      await tester.pump(const Duration(milliseconds: 500));
    }
    throw StateError('the app never caught up to the server (seq $head)');
  }

  /// A first-ever exercise asks where its ramp starts: test me from the
  /// planned weight, and the calibration sets find it.
  Future<void> testMeIfAsked() async {
    final button = find.textContaining(testMe);
    if (button.evaluate().isEmpty) return;
    await tap(button);
    await settle(seconds: 1);
  }

  /// The first-time dialog's one button, up to the weight it names.
  static String get testMe =>
      copy.workout.firstTimeTest.split('{weight}').first;

  /// The "how many more could you have done?" dialog a full calibration
  /// rung opens.
  bool get rungDialogShowing =>
      find.byType(RungQuestionDialog).evaluate().isNotEmpty;

  /// The rung's own circle in that dialog: a tap takes a rep off.
  Finder get rungDialogCircle => find.descendant(
    of: find.byType(RungQuestionDialog),
    matching: find.byType(SetCircle),
  );

  /// Wait for the rung question on [setId] when the core has opened one.
  Future<bool> _waitForRungDialog(String setId, {int seconds = 6}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (rungDialogShowing) return true;
      if (workout.rungQuestionSetId != setId) return false;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return rungDialogShowing;
  }

  /// The answer to the rung question, by its button's label.
  static String rungAnswerLabel(RepsLeft answer) =>
      RungQuestionDialog.answers.firstWhere((a) => a.$1 == answer).$2;

  /// Lift the next set on its circle: tap to start it, tap again when it is
  /// done, then once more per [missed] rep. A calibration rung done in full
  /// asks how many more could have been done, over the list: its dialog
  /// holds the rung's circle, so missed reps are tapped there and then
  /// acknowledged (OK); a rung with every rep is answered [rungAnswer]
  /// (0–1 by default: the ramp ends and the working sets follow).
  Future<void> liftSet({
    int missed = 0,
    RepsLeft rungAnswer = RepsLeft.REPS_LEFT_ZERO_TO_ONE,
    Future<void> Function()? whileLifting,
  }) async {
    for (var i = 0; i < 16 && !setOffered; i++) {
      await settle(seconds: 1);
    }
    final set = nextSet;
    expect(set, isNotNull, reason: 'no set to lift');
    await revealNextSet();
    await tap(circleFor(set!.id));
    // The core answers asynchronously; give it a beat.
    await settle(seconds: 1);
    await testMeIfAsked();
    expect(
      workout.workout?.liftingSetId,
      set.id,
      reason: 'the first tap starts the set',
    );
    if (whileLifting != null) await whileLifting();
    await tap(circleFor(set.id));
    if (!set.calibration || !await _waitForRungDialog(set.id)) {
      for (var i = 0; i < missed; i++) {
        await tap(circleFor(set.id));
      }
      return;
    }
    if (missed == 0) {
      await tap(find.text(rungAnswerLabel(rungAnswer)));
      return;
    }
    for (var i = 0; i < missed; i++) {
      await tap(rungDialogCircle);
    }
    await tap(find.text(copy.workout.rungOk));
  }

  /// End the live workout through the confirm dialog and wait for the
  /// summary. "End workout" is the quiet link under the exercise list and,
  /// once every set is done, the bar's big button; either opens the dialog.
  /// A session that didn't match its template opens the summary under the
  /// offer to save it as one; that is turned down, leaving the summary.
  Future<void> endWorkoutAndWaitForSummary() async {
    await tapText(copy.workout.endWorkout);
    await mustSee(copy.endWorkoutDialog.body, seconds: 6);
    // The dialog's confirm button.
    await tap(find.text(copy.endWorkoutDialog.confirm).last);
    // The summary's first section.
    await mustSee(copy.summary.session, seconds: 15);
    await declineTemplateOffer();
  }

  /// Turn down the "save / update the template?" offer if it is up.
  Future<void> declineTemplateOffer() async {
    await settle(seconds: 1);
    for (final decline in [
      copy.templateUpdate.updateDecline,
      copy.templateUpdate.newDecline,
    ]) {
      if (isVisible(decline)) {
        await shot('Template offer', note: 'Turned down.');
        await tapText(decline);
        await settle(seconds: 1);
        return;
      }
    }
  }
}
