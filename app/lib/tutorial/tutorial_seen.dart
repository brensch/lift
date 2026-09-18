/// Whether an account has been shown the walkthrough on this device.
///
/// Keyed per account. It used to be one flag for the whole install, so the
/// second person to sign up on a phone — or the same person making a second
/// account — never got the tutorial.
library;

import 'package:shared_preferences/shared_preferences.dart';

class TutorialSeen {
  static const _legacyKey = 'tutorial_seen_v1';
  static String _key(String userId) => 'tutorial_seen_v1.$userId';

  static Future<void>? _migration;

  /// Call once at startup, after the saved session is known. The old
  /// install-wide flag can only have belonged to whoever is signed in right
  /// now, so it is handed to them and then removed; anyone who signs up
  /// later starts unseen. With nobody signed in it is simply removed.
  static Future<void> migrateLegacy(String? signedInUserId) {
    return _migration ??= _migrate(signedInUserId);
  }

  static Future<void> _migrate(String? signedInUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getBool(_legacyKey);
    if (legacy == null) return;
    if (legacy && signedInUserId != null && signedInUserId.isNotEmpty) {
      await prefs.setBool(_key(signedInUserId), true);
    }
    await prefs.remove(_legacyKey);
  }

  /// Marks [userId] as seen and reports whether they already were — one step,
  /// so two home screens racing cannot both decide to show it.
  static Future<bool> checkAndMark(String userId) async {
    // A check must never beat the migration to the legacy flag.
    await _migration;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_key(userId)) ?? false;
    if (!seen) await prefs.setBool(_key(userId), true);
    return seen;
  }

  static void resetForTest() => _migration = null;
}
