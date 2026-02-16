import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _notificationId = 1;
  static const _buzzNotificationId = 2;
  static const _startSetActionId = 'start_next_set';

  /// Callback for when the "Start Set" notification action is tapped.
  static void Function()? onStartNextSet;

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request notification permission (Android 13+)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId == _startSetActionId) {
      onStartNextSet?.call();
    }
  }

  static Future<void> scheduleRestNotification({
    required int restUntilUnix,
    required String soundPresetId,
    String body = 'Time to start your next set!',
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
    final androidSound = RawResourceAndroidNotificationSound('sound_$soundPresetId');

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

    await _plugin.zonedSchedule(
      _notificationId,
      'Rest Complete',
      body,
      scheduledTime,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
      payload: '$restUntilUnix',
    );
  }

  static Future<void> cancelRestNotification() async {
    await _plugin.cancel(_notificationId);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Show a silent notification with vibration only (no sound).
  /// Used when rest ends while app is in foreground — the in-app ding handles
  /// sound, but we still want watches to buzz.
  static Future<void> showBuzzNotification({String body = 'Time to start your next set!'}) async {
    const androidDetails = AndroidNotificationDetails(
      'rest_timer_buzz',
      'Rest Timer Buzz',
      channelDescription: 'Vibration-only alert when rest ends',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      actions: [
        AndroidNotificationAction(
          _startSetActionId,
          'Start Set',
          showsUserInterface: true,
        ),
      ],
    );

    const darwinDetails = DarwinNotificationDetails(
      presentSound: false,
      presentAlert: true,
    );

    await _plugin.show(
      _buzzNotificationId,
      'Rest Complete',
      body,
      const NotificationDetails(android: androidDetails, iOS: darwinDetails),
    );
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }
}
