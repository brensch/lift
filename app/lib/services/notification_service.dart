import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _restNotificationId = 1;
  static const _nextWorkoutNotificationId = 2;
  static const _startSetActionId = 'start_next_set';

  /// Callback for when the "Start Set" notification action is tapped.
  static void Function()? onStartNextSet;

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
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
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request notification permission (Android 13+)
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId == _startSetActionId) {
      onStartNextSet?.call();
    }
  }

  /// Schedules a rest-complete notification for the future.
  /// Used when the app might go into the background.
  static Future<void> scheduleRest({
    required int restUntilUnix,
    required String soundPresetId,
    required String body,
  }) async {
    // Clear any existing rest notifications first
    await cancelRest();

    final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      restUntilUnix * 1000,
    );

    // Don't schedule if already in the past
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    // Use per-preset channel ID to avoid Android's channel sound caching
    final channelId = 'rest_timer_$soundPresetId';
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
      actions: const [
        AndroidNotificationAction(
          _startSetActionId,
          'Start Set',
          showsUserInterface: true,
        ),
      ],
    );

    final darwinDetails = DarwinNotificationDetails(
      sound: 'sounds/sound_$soundPresetId.wav',
      presentSound: true,
      presentAlert: true,
    );

    const linuxDetails = LinuxNotificationDetails(
      defaultActionName: 'Start Set',
    );

    await _plugin.zonedSchedule(
      _restNotificationId,
      'Rest Complete',
      body,
      scheduledTime,
      NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        linux: linuxDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
      payload: '$restUntilUnix',
    );
  }

  /// Cancels any pending or active rest notifications.
  static Future<void> cancelRest() async {
    await _plugin.cancel(_restNotificationId);
  }

  /// Plays an in-app haptic when rest finishes while the app is active.
  /// Background delivery is still handled by the scheduled OS notification.
  static Future<void> playRestCompletionHaptic() async {
    for (var i = 0; i < 5; i++) {
      await HapticFeedback.vibrate();
      if (i < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
    }
  }

  /// Schedules a next-workout reminder notification.
  static Future<void> scheduleNextWorkout({
    required int nextSessionAtUnix,
    required String regimeName,
  }) async {
    await cancelNextWorkout();

    final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      nextSessionAtUnix * 1000,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      'next_workout',
      'Next Workout',
      channelDescription: 'Reminder when your next workout session is ready',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      _nextWorkoutNotificationId,
      'Time to lift!',
      'Your $regimeName session is ready.',
      scheduledTime,
      const NotificationDetails(android: androidDetails, iOS: darwinDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  /// Cancels any pending next-workout notification.
  static Future<void> cancelNextWorkout() async {
    await _plugin.cancel(_nextWorkoutNotificationId);
  }

  /// Comprehensive cleanup of all notifications.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

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
