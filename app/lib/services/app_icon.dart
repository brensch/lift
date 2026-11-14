/// The "App icon" setting: the launcher icon with its one coloured plate in
/// each stage's colour. The phone itself keeps which is chosen; this asks it
/// and changes it. Each platform does it its own way, behind one channel:
///   android/app/src/main/kotlin/com/brensch/schlift/appicon/AppIcon.kt
///     (a launcher alias per icon, one enabled)
///   ios/Runner/AppIconPlugin.swift
///     (alternate icon sets; iOS tells the user itself when it changes)
/// The icons are made by scripts/app_icon_variants.py. Elsewhere (desktop,
/// tests) there is only the default and nothing changes.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_logger.dart';

/// The icons, by the stage each is coloured for. The names are the ones the
/// native sides know: add one there, in the script and here together.
enum AppIconChoice { ready, lifting, resting, yapping }

class AppIconService {
  static const _channel = MethodChannel('schlift/app_icon');

  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// The icon on show now.
  static Future<AppIconChoice> current() async {
    if (!supported) return AppIconChoice.ready;
    try {
      final name = await _channel.invokeMethod<String>('get');
      return AppIconChoice.values.firstWhere(
        (choice) => choice.name == name,
        orElse: () => AppIconChoice.ready,
      );
    } catch (e) {
      AppLogger.instance.warn('AppIcon', 'get failed', {'error': e.toString()});
      return AppIconChoice.ready;
    }
  }

  /// Show [choice]'s icon. False when the phone wouldn't.
  static Future<bool> set(AppIconChoice choice) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('set', {'name': choice.name}) ??
          false;
    } catch (e) {
      AppLogger.instance.warn('AppIcon', 'set failed', {'error': e.toString()});
      return false;
    }
  }
}
