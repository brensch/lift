import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/audio.dart';
import '../gen/sounds.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app_logger.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _restNotificationId = 1;
  static const _nextWorkoutNotificationId = 2;

  /// Sets up timezones and the plugin. Asks for nothing: the prompts are
  /// [requestPermissions] and [requestExactAlarms], which only
  /// PermissionsService calls.
  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // The plugin's iOS defaults prompt at initialize(); turn them all off.
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      linux: linuxSettings,
    );
    await _plugin.initialize(settings: initSettings);
  }

  /// The notification permission prompt (iOS alert, Android 13+ dialog).
  static Future<void> requestPermissions() =>
      _bestEffort('requestPermissions', () async {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true);
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      });

  /// Android 14+ denies exact alarms by default, and without them the rest
  /// notification can land minutes late while the phone sleeps. Granting
  /// is a settings page, not a dialog, so this skips it when already held.
  static Future<void> requestExactAlarms() =>
      _bestEffort('requestExactAlarms', () async {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (android == null) return;
        if (await android.canScheduleExactNotifications() ?? false) return;
        await android.requestExactAlarmsPermission();
      });

  /// Schedules a rest-complete notification for the future.
  /// Used when the app might go into the background.
  static Future<void> scheduleRest({
    required int restUntilUnix,
    required String soundPresetId,
    required String body,
  }) => _bestEffort('scheduleRest', () async {
    // Clear any existing rest notifications first
    await cancelRest();

    final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      restUntilUnix * 1000,
    );

    // Don't schedule if already in the past
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    // Android fixes a channel's sound when the channel is created, so the
    // id carries the preset and the bundled sounds' revision: a changed
    // file gets a fresh channel, and the stale ones are removed.
    final channelId = 'rest_timer_${soundPresetId}_$soundsRevision';
    await _dropStaleRestChannels();
    final androidSound = RawResourceAndroidNotificationSound(
      'sound_$soundPresetId',
    );

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Rest Timer',
      channelDescription: 'Rest timer completion alert',
      importance: Importance.high,
      priority: Priority.high,
      sound: androidSound,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );

    final darwinDetails = DarwinNotificationDetails(
      sound: 'sounds/sound_$soundPresetId.wav',
      presentSound: true,
      presentAlert: true,
    );

    const linuxDetails = LinuxNotificationDetails(defaultActionName: 'Open');

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      linux: linuxDetails,
    );
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: _restNotificationId,
      title: 'Rest Complete',
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: details,
      androidScheduleMode: mode,
      matchDateTimeComponents: null,
      payload: '$restUntilUnix',
    );
    // Exact alarms need a permission the user may not have granted
    // (common on Android 14+); fall back to inexact. Any other failure —
    // including the fallback's — is _bestEffort's to swallow.
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  });

  /// Notifications are best-effort everywhere: a plugin failure (revoked
  /// permission, missing platform implementation, OEM quirks) must never
  /// abort the workout flow that triggered it. scheduleRest carries its
  /// own two-step fallback; everything else funnels through here.
  static Future<void> _bestEffort(
    String operation,
    Future<void> Function() run,
  ) async {
    try {
      await run();
    } catch (e) {
      AppLogger.instance.warn('Notification', '$operation failed', {
        'error': e.toString(),
      });
    }
  }

  /// Cancels any pending or active rest notifications.
  static const _channelRevisionKey = 'rest_channel_revision';

  /// Deletes rest channels made for an older sounds revision (and the
  /// unversioned ones from before revisions existed), once per revision.
  static Future<void> _dropStaleRestChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_channelRevisionKey);
    if (previous == soundsRevision) return;
    for (final id in soundPresets.keys) {
      await android.deleteNotificationChannel(channelId: 'rest_timer_$id');
      if (previous != null) {
        await android.deleteNotificationChannel(
          channelId: 'rest_timer_${id}_$previous',
        );
      }
    }
    // The synthesised presets from before the recordings.
    for (final id in const [
      'chord_strum',
      'bell_high',
      'classic_beep',
      'success_rise',
      'boxing_bell',
      'elevator_ding',
      'dojo_gong',
      'retro_arcade',
      'crystal_shine',
      'morning_dew',
    ]) {
      await android.deleteNotificationChannel(channelId: 'rest_timer_$id');
    }
    await prefs.setString(_channelRevisionKey, soundsRevision);
  }

  static Future<void> cancelRest() =>
      _bestEffort('cancelRest', () => _plugin.cancel(id: _restNotificationId));

  /// Plays an in-app haptic when rest finishes while the app is active.
  /// Background delivery is still handled by the scheduled OS notification.
  static Future<void> playRestCompletionHaptic() =>
      _bestEffort('haptic', () async {
        for (var i = 0; i < 5; i++) {
          await HapticFeedback.vibrate();
          if (i < 4) {
            await Future<void>.delayed(const Duration(milliseconds: 220));
          }
        }
      });

  /// Schedules a next-workout reminder notification.
  /// Cancels any pending next-workout notification.
  static Future<void> cancelNextWorkout() => _bestEffort(
    'cancelNextWorkout',
    () => _plugin.cancel(id: _nextWorkoutNotificationId),
  );

  /// Comprehensive cleanup of all notifications.
  static Future<void> cancelAll() =>
      _bestEffort('cancelAll', () => _plugin.cancelAll());

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  static Future<List<ActiveNotification>> getActiveNotifications() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return android.getActiveNotifications();
    }
    // On iOS/Darwin, this is also available via the general plugin in newer versions,
    // but getActiveNotifications is specifically an Android-heavy API in some versions.
    // However, the latest flutter_local_notifications supports it.
    return _plugin.getActiveNotifications();
  }
}
