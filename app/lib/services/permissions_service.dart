import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'health_service.dart';
import 'notification_service.dart';

/// The app's one permission moment. Right after sign-in, once per install,
/// the router shows PermissionsScreen; its button asks the OS for everything
/// the app uses, back to back: notifications, then every Health type in a
/// single sheet, then (Android 14+) exact alarms. Nothing else in the app
/// prompts. A permission declined here stays declined until the user changes
/// it in the system settings.
///
/// Neither OS can merge these into one dialog: iOS shows the notification
/// alert and then the Health sheet; Android shows the notification dialog,
/// the Health Connect screen, and the "Alarms & reminders" settings page.
class PermissionsService extends ChangeNotifier {
  PermissionsService._();
  static final instance = PermissionsService._();

  static const _requestedKey = 'permissions_requested_v1';

  // Until load() runs nothing is pending, so a caller that skips main() —
  // the e2e harness pumps the app directly — never sees the screen and its
  // native dialogs, which would hang an integration_test.
  bool _requested = true;

  /// Whether the router should show PermissionsScreen.
  bool get needsRequest => !_requested;

  /// Reads whether this install has been through the request yet. Phones
  /// only; desktop has neither Health nor these prompts.
  Future<void> load() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _requested = prefs.getBool(_requestedKey) ?? false;
    } catch (e) {
      AppLogger.instance.warn('Permissions', 'load failed', {
        'error': e.toString(),
      });
    }
    notifyListeners();
  }

  /// Asks for every permission, one system UI after the other. Each step is
  /// best-effort: a decline or a failure moves on to the next.
  Future<void> requestAll() async {
    AppLogger.instance.info('Permissions', 'requestAll');
    await NotificationService.requestPermissions();
    await HealthService.requestWorkoutHealthPermissions();
    // Last, because on Android 14+ it leaves the app for a settings page.
    await NotificationService.requestExactAlarms();
    _requested = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requestedKey, true);
    } catch (e) {
      AppLogger.instance.warn('Permissions', 'save failed', {
        'error': e.toString(),
      });
    }
    notifyListeners();
  }
}
