// End-to-end harness: drives the REAL Schlift app against a REAL backend in a
// headless `flutter test`, capturing a legible screenshot after every step.
//
// It is the Puppeteer-equivalent for this app:
//  - spawns the Rust backend (built with --features test-auth) on its own port
//    and temp database, so runs are isolated and repeatable;
//  - pumps the real `SchliftApp`, pointed at that backend, so real gRPC traffic
//    flows over a real socket;
//  - exposes expressive actions (login, tap, type, wait-for) that read like a
//    user story;
//  - writes numbered PNGs into test_screenshots/<scenario>/ plus an HTML report
//    so a human can audit exactly what the app did, screen by screen.
//
// Screens render with real fonts (loaded from the Flutter SDK cache), so the
// screenshots look like the app, not tofu boxes.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schlift/main.dart';

/// Stub the platform plugins the app touches at startup so a headless test
/// doesn't throw MissingPluginException. Each returns a benign value; event
/// streams are made empty. Call once before pumping the app.
void installPluginStubs() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  void mockMethod(String channel, [Object? Function(MethodCall)? handler]) {
    messenger.setMockMethodCallHandler(MethodChannel(channel),
        (call) async => handler?.call(call));
  }

  // Deep links: no initial link, empty stream.
  mockMethod('com.llfbandit.app_links/messages', (call) {
    if (call.method == 'getInitialAppLink' || call.method == 'getInitialLink') {
      return null;
    }
    return null;
  });
  // The events EventChannel is backed by a MethodChannel with listen/cancel.
  mockMethod('com.llfbandit.app_links/events');

  // Everything else the app may reach at startup/login — return null (benign).
  for (final c in const [
    'flutter_health',
    'dev.fluttercommunity.plus/package_info',
    'dev.fluttercommunity.plus/device_info',
    'dexterous.com/flutter/local_notifications',
    'plugins.flutter.io/path_provider',
  ]) {
    mockMethod(c);
  }
}

/// Spawns and owns a throwaway backend for a test run.
class TestBackend {
  TestBackend._(this.port, this._process, this._dir);

  final int port;
  final Process _process;
  final Directory _dir;

  static Future<TestBackend> start({int port = 51_090}) async {
    final repoRoot = Directory.current.parent.path; // app/ -> repo root

    // Build once with the dev-login feature. Release for realistic latency.
    final build = await Process.run(
      'cargo',
      ['build', '--bin', 'schlift', '--features', 'test-auth', '--release'],
      workingDirectory: repoRoot,
    );
    if (build.exitCode != 0) {
      throw StateError('backend build failed:\n${build.stderr}');
    }

    final dir = Directory.systemTemp.createTempSync('schlift-e2e-');
    final proc = await Process.start(
      '$repoRoot/target/release/schlift',
      const [],
      environment: {
        'DATA_DIR': '${dir.path}/data',
        'PORT': '$port',
        'RUST_LOG': 'error',
      },
      workingDirectory: repoRoot,
      // Inherit the parent's stdio rather than opening pipes. A piped child's
      // stdout/stderr are live stream subscriptions that keep the test isolate's
      // event loop from ever going idle, so `flutter test` hangs until timeout.
      mode: ProcessStartMode.inheritStdio,
    );

    // Wait until the port accepts connections.
    for (var i = 0; i < 100; i++) {
      try {
        final s = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(milliseconds: 300));
        await s.close();
        return TestBackend._(port, proc, dir);
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    proc.kill();
    throw StateError('backend never became reachable on :$port');
  }

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
    try {
      _dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

/// A single captured step, for the report.
class _Shot {
  _Shot(this.index, this.name, this.file);
  final int index;
  final String name;
  final String file;
}

/// Drives the app and records screenshots for one scenario.
class AppDriver {
  AppDriver(this.tester, this.scenario);

  final WidgetTester tester;
  final String scenario;
  final _boundaryKey = GlobalKey();
  final List<_Shot> _shots = [];
  int _step = 0;

  static bool _fontsLoaded = false;

  /// Load real fonts so screenshots are legible. Idempotent across scenarios.
  static Future<void> loadFonts() async {
    if (_fontsLoaded) return;
    // Manrope + Space Grotesk are bundled under assets/google_fonts/, so force
    // fetching off: google_fonts loads them from assets offline (no network, no
    // throw). MaterialIcons + a Roboto fallback still come from the SDK cache.
    GoogleFonts.config.allowRuntimeFetching = false;

    final home = Platform.environment['HOME'];
    final dir = '$home/flutter-sdk/bin/cache/artifacts/material_fonts';
    Future<void> load(String family, String file) async {
      final path = '$dir/$file';
      if (!File(path).existsSync()) return;
      final bytes = File(path).readAsBytesSync();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }

    // Register Roboto under the names google_fonts asks for, so text renders
    // in a real (if not pixel-exact) face instead of boxes.
    for (final family in [
      'Roboto',
      'Manrope', 'Manrope_regular', 'Manrope_bold',
      'SpaceGrotesk', 'SpaceGrotesk_regular', 'SpaceGrotesk_bold',
    ]) {
      await load(family, 'Roboto-Regular.ttf');
    }
    await load('MaterialIcons', 'MaterialIcons-Regular.otf');
    _fontsLoaded = true;
  }

  /// Pump the real app pointed at [backend], wrapped so we can screenshot it.
  Future<void> launch(TestBackend backend) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: SchliftApp(
          serverHostOverride: '127.0.0.1',
          serverPortOverride: backend.port,
        ),
      ),
    );
    _drainBenignExceptions();
    await settle();
  }

  /// Let animations, timers, and gRPC round-trips resolve. `pumpAndSettle`
  /// times out on the app's periodic polling, so we pump in bounded bursts.
  Future<void> settle({int rounds = 12, int ms = 250}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(Duration(milliseconds: ms));
      _drainBenignExceptions();
    }
  }

  /// google_fonts throws an async exception when it can't fetch/bundle a font in
  /// a headless test. Rendering already falls back to the ambient Roboto, so the
  /// exception is cosmetic — consume it so it doesn't fail the run. Anything that
  /// isn't a font error is re-thrown, so real bugs still surface.
  void _drainBenignExceptions() {
    final ex = tester.takeException();
    if (ex == null) return;
    final s = ex.toString();
    final benign = s.contains('google_fonts') ||
        s.contains('Failed to load font') ||
        s.contains('fonts.gstatic') ||
        s.contains('allowRuntimeFetching');
    if (!benign) {
      throw ex;
    }
  }

  Future<void> shot(String name) async {
    await tester.pump(const Duration(milliseconds: 60));
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();
    final file = '${_step.toString().padLeft(2, '0')}_$safe.png';
    final out = File('test_screenshots/$scenario/$file');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
    _shots.add(_Shot(_step, name, file));
    _step++;
    // Rewrite the report after every shot so the artifacts are always current,
    // even if a later step stalls (a live-gRPC app can wedge the fake-async
    // clock). The report never depends on the run finishing cleanly.
    _writeReportSync('$scenario — ${_shots.length} step(s)');
  }

  /// Give the REAL backend time to respond. Widget tests run in fake-async, so
  /// `pump()` alone never lets a real gRPC socket resolve — we must yield to the
  /// real event loop via `runAsync`, then pump to render the result. Call this
  /// after any action that hits the backend (login, start workout, …).
  Future<void> waitForBackend({int ms = 800}) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await settle(rounds: 6);
  }

  /// Unmount the app so SchliftApp.dispose runs (which shuts down the gRPC
  /// channel and cancels its keepalive timers), then let that settle. Without
  /// this the channel's real timers keep the test isolate alive and the run
  /// hangs at teardown. Always call at the end of a scenario.
  Future<void> finish(String reportTitle) async {
    await writeReport(reportTitle);
    // Unmount the app: SchliftApp.dispose() fires grpcClient.shutdown(), which
    // cancels the channel's keepalive timer. That cancellation runs on the real
    // event loop, so hand it real time via runAsync — otherwise the real timer
    // keeps the test isolate alive and the run only ends at the timeout.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
  }

  // ── Expressive actions ──

  /// Type [text] into the first visible text field, then screenshot.
  Future<void> typeInto(Finder field, String text, {String? capture}) async {
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 100));
    if (capture != null) await shot(capture);
  }

  /// Tap a widget found by [finder]; settle; optionally screenshot.
  Future<void> tap(Finder finder, {String? capture}) async {
    expect(finder, findsWidgets, reason: 'nothing to tap for $finder');
    await tester.tap(finder.first);
    await settle();
    if (capture != null) await shot(capture);
  }

  /// Tap the first widget whose visible text is [label].
  Future<void> tapText(String label, {String? capture}) =>
      tap(find.text(label), capture: capture);

  /// Assert some text is on screen (a scenario checkpoint).
  void expectVisible(String text) =>
      expect(find.text(text), findsWidgets, reason: 'expected "$text" on screen');

  bool isVisible(String text) => find.text(text).evaluate().isNotEmpty;

  /// Log in via the dev (test-auth) path as [username].
  Future<void> devLogin(String username) async {
    // The login screen has a dev username field; enter and submit.
    final field = find.byType(TextField);
    expect(field, findsWidgets, reason: 'no login field found');
    await tester.enterText(field.first, username);
    await tester.pump(const Duration(milliseconds: 100));
    await shot('login — entered "$username"');
    // Submit via the on-field action (Enter) which calls _devLogin.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(rounds: 16);
  }

  /// Emit an HTML report indexing every screenshot for this scenario. Called
  /// automatically after each `shot`, so it never depends on the run finishing.
  Future<void> writeReport(String title) async => _writeReportSync(title);

  void _writeReportSync(String title) {
    final buf = StringBuffer()
      ..writeln('<!doctype html><meta charset="utf-8">')
      ..writeln('<title>$title</title>')
      ..writeln('<style>'
          'body{font:15px/1.5 system-ui;margin:0;background:#0f1115;color:#e6e9ee}'
          'header{padding:20px 24px;border-bottom:1px solid #232833}'
          'h1{margin:0;font-size:18px}'
          '.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:20px;padding:24px}'
          '.card{background:#171a21;border:1px solid #232833;border-radius:10px;overflow:hidden}'
          '.card img{width:100%;display:block;background:#fff}'
          '.cap{padding:10px 12px;font-size:13px}'
          '.n{color:#6b7686;font-variant-numeric:tabular-nums;margin-right:8px}'
          '</style>')
      ..writeln('<header><h1>$title</h1></header><div class="grid">');
    for (final s in _shots) {
      buf.writeln('<div class="card"><img src="${s.file}" alt="${s.name}">'
          '<div class="cap"><span class="n">${s.index.toString().padLeft(2, '0')}</span>'
          '${const HtmlEscape().convert(s.name)}</div></div>');
    }
    buf.writeln('</div>');
    File('test_screenshots/$scenario/report.html')
        .writeAsStringSync(buf.toString());
  }

  int get shotCount => _shots.length;
}
