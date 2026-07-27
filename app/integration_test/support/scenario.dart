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
import 'package:schlift/main.dart';
import 'package:schlift/services/health_service.dart';
import 'package:schlift/services/notification_service.dart';

import 'api.dart';

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
    // throws a timezone LateInitializationError. Skip the permission prompts —
    // they're native dialogs that would hang the test.
    await NotificationService.init(requestPermissions: false);
    // Convert the surface to an image BEFORE the app renders. Doing it after the
    // login animation starts hangs (it waits for a stable frame that never
    // arrives). Once converted, every takeScreenshot captures the live surface.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(const SchliftApp());
    await settle();
  }

  /// Re-pump a fresh [SchliftApp] — new providers, new gRPC client — to simulate
  /// a cold restart. Crash recovery should re-fetch server state (e.g. an active
  /// workout) on the way back up.
  Future<void> relaunch() async {
    await tester.pumpWidget(const SchliftApp());
    await settle(seconds: 4);
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

  // ── Capture ──

  /// Screenshot the current screen and record a report step. Pumps a couple of
  /// frames first so the captured surface reflects the very latest state (e.g. a
  /// banner that just appeared via an async poll), not a frame behind.
  Future<void> shot(String title, {String? note}) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final base = '${name}_${_n.toString().padLeft(2, '0')}';
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

  Future<void> tap(Finder f, {String? shot}) async {
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
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Scroll [within] (default: the first Scrollable) by [dy] logical pixels
  /// (negative scrolls the content up, revealing what's below).
  Future<void> scroll(double dy, {Finder? within}) async {
    final target = within ?? find.byType(Scrollable).first;
    await tester.drag(target, Offset(0, dy));
    await settle(seconds: 1);
  }

  void expectVisible(String text) => expect(find.text(text), findsWidgets,
      reason: 'expected "$text" on screen');

  bool isVisible(String text) => find.text(text).evaluate().isNotEmpty;

  /// Poll until [text] appears (backend round-trips resolve asynchronously).
  Future<bool> waitForText(String text, {int seconds = 8}) async {
    for (var i = 0; i < seconds * 2; i++) {
      if (isVisible(text)) return true;
      await tester.pump(const Duration(milliseconds: 500));
    }
    return false;
  }

  /// Dev-login (test-auth) as [username] via the login screen's dev field, then
  /// dismiss the one-time passkey notice a brand-new account is shown before it
  /// reaches onboarding.
  Future<void> devLogin(String username) async {
    // Wait for the login screen — a freshly-booted emulator's first app launch
    // can render slower than launch()'s settle window.
    await waitForText('Dev Login', seconds: 15);
    final field = find.widgetWithText(TextField, 'Username');
    final target = field.evaluate().isNotEmpty ? field : find.byType(TextField);
    await typeInto(target, username);
    await tapText('Dev Login');
    await settle(seconds: 5);
    if (await waitForText('I understand', seconds: 6)) {
      await tapText('I understand');
      await settle(seconds: 3);
    }
  }

  /// Walk the whole onboarding flow (marker → units → program → weights →
  /// confirm) accepting the regime defaults, and land on the home screen. Used
  /// by scenarios that need a set-up user but aren't testing onboarding itself.
  Future<void> completeOnboarding() async {
    if (!await waitForText('Choose your colour and creature', seconds: 10)) {
      return; // already past onboarding (e.g. a returning user)
    }
    await tapText('NEXT'); // marker → units
    await waitForText('CHOOSE YOUR UNITS', seconds: 6);
    await tapText('NEXT'); // units → program
    await waitForText('CHOOSE YOUR PROGRAM', seconds: 6);
    await tapText('NEXT'); // program → weights
    await waitForText('Choose starting weights', seconds: 6);
    await tapText('NEXT'); // weights → confirm
    await settle(seconds: 2);
    await tapText('START'); // commit
    await waitForText('START WORKOUT', seconds: 12);
  }
}
