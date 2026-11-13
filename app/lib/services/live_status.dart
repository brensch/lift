/// The live status: the workout in hand, shown by the phone itself while
/// the app is out of sight. On Android a notification that stays up (a Live
/// Update on 16 and later: the shade, the lock screen, a chip in the status
/// bar); on iPhone a Live Activity (the lock screen and the Dynamic Island).
/// Both say the stage and the set in hand, with the stage's own clock
/// ticking by itself, and both move on from a rest when it runs out with
/// nothing of the app running.
///
/// This is the one place Dart talks to it. Each platform draws it natively,
/// from the same message:
///   android/app/src/main/kotlin/com/brensch/schlift/livestatus/
///   ios/LiveStatus/
/// See docs/architecture/live-status.md.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../gen/copy.dart';
import 'app_logger.dart';

/// The workout at one stage: its words, its colours and its clock.
class LiveStatusPhase {
  /// "Lifting", and the word short enough for the Dynamic Island: "Lift".
  final String stage;
  final String short;

  /// The set in hand: "Squat", and "100 kg × 5 · Set 2 of 5".
  final String exercise;
  final String detail;

  /// The stage's colour, and the ink that reads on it.
  final Color color;
  final Color ink;

  /// The moment (Unix seconds) the clock counts up from, or with
  /// [countDown] down to; null when the stage has no clock.
  final int? clockUnix;
  final bool countDown;

  const LiveStatusPhase({
    required this.stage,
    required this.short,
    required this.exercise,
    required this.detail,
    required this.color,
    required this.ink,
    this.clockUnix,
    this.countDown = false,
  });

  Map<String, Object?> _toMap() => {
    // Android's one-line heading; the iPhone lays the parts out itself.
    'title': copy.workoutStatus.title
        .replaceAll('{stage}', stage)
        .replaceAll('{exercise}', exercise),
    'stage': stage,
    'short': short,
    'exercise': exercise,
    'detail': detail,
    'color': color.toARGB32(),
    'ink': ink.toARGB32(),
    'clockMs': (clockUnix ?? 0) * 1000,
    'countDown': countDown,
  };
}

class LiveStatus {
  static const _channel = MethodChannel('schlift/live_status');

  static bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Show [now]. With [then] and [thenAtUnix] (a rest and its end), the
  /// status moves on to [then] at that moment by itself.
  static Future<void> show({
    required LiveStatusPhase now,
    LiveStatusPhase? then,
    int? thenAtUnix,
  }) => _bestEffort('show', {
    'channel': copy.workoutStatus.channel,
    'now': now._toMap(),
    if (then != null && thenAtUnix != null) ...{
      'then': then._toMap(),
      'thenAtMs': thenAtUnix * 1000,
    },
  });

  /// Take it down: the workout ended, or was thrown away.
  static Future<void> cancel() => _bestEffort('cancel', null);

  /// Like every notification, best effort: a platform that can't show it
  /// must never get in the way of the workout.
  static Future<void> _bestEffort(String method, Object? arguments) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      AppLogger.instance.warn('LiveStatus', '$method failed', {
        'error': e.toString(),
      });
    }
  }
}
