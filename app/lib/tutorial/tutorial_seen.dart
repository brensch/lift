/// Whether an account has been shown the walkthrough on this device, one
/// flag per account.
library;

import 'package:shared_preferences/shared_preferences.dart';

class TutorialSeen {
  static String _key(String userId) => 'tutorial_seen_v1.$userId';

  /// Marks [userId] as seen and reports whether they already were — one step,
  /// so two home screens racing cannot both decide to show it.
  static Future<bool> checkAndMark(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_key(userId)) ?? false;
    if (!seen) await prefs.setBool(_key(userId), true);
    return seen;
  }
}
