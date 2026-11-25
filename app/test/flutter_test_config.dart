import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs once before every test file under app/test/ (Flutter's test bootstrap).
///
/// google_fonts loads a font the first time it is used, which registers it with
/// a [FontLoader]; the engine then posts a "fonts changed" message on the
/// system channel, and text render objects respond by scheduling a relayout
/// frame callback. When that callback is still pending as a widget test tears
/// down, the test framework throws "An animation is still running even after
/// the widget tree was disposed" and flakes the test (and others in the run).
///
/// Tests don't need to re-layout on a font change, so swallow that system
/// message: no notification, no leaked callback. Runtime fetching stays off —
/// the fonts ship in the app's assets.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  ServicesBinding.instance.defaultBinaryMessenger.setMessageHandler(
    SystemChannels.system.name,
    (ByteData? message) async => null,
  );
  await testMain();
}
