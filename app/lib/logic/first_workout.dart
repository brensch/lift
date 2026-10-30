/// Whether an account has finished a workout on this device. Until it has,
/// the workout banner explains each step as it comes up; after the first
/// workout ends it never does again.
///
/// Keyed per account, like the tutorial's flag, so a second person signing
/// up on the same phone gets the hints too.
library;

import 'package:shared_preferences/shared_preferences.dart';

class FirstWorkout {
  static String _key(String userId) => 'first_workout_done_v1.$userId';

  /// Whether [userId] has finished a workout here.
  static Future<bool> isDone(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  /// Record that [userId] has finished one.
  static Future<void> markDone(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }
}
