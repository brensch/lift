import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _notificationId = 1;

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Request notification permission (Android 13+)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleRestNotification({
    required int restUntilUnix,
    required String soundPresetId,
  }) async {
    await cancelRestNotification();

    final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      restUntilUnix * 1000,
    );

    // Don't schedule if already in the past
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    // Use per-preset channel ID to avoid Android's channel sound caching
    final channelId = 'rest_timer_$soundPresetId';
    final sound = RawResourceAndroidNotificationSound('sound_$soundPresetId');

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Rest Timer',
      channelDescription: 'Rest timer completion alert',
      importance: Importance.high,
      priority: Priority.high,
      sound: sound,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );

    await _plugin.zonedSchedule(
      _notificationId,
      'Rest Complete',
      'Time to start your next set!',
      scheduledTime,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  static Future<void> cancelRestNotification() async {
    await _plugin.cancel(_notificationId);
  }
}
