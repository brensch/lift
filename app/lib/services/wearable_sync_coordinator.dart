import 'dart:async';

import 'package:fixnum/fixnum.dart';

import '../gen/workout/v1/wearable.pb.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/workout_provider.dart';
import 'wearable_bridge_service.dart';
import 'wearable_snapshot_builder.dart';

class WearableSyncCoordinator {
  final WorkoutProvider _workoutProvider;
  final MultiplayerProvider _multiplayerProvider;
  final WearableBridgeService _bridgeService;
  final String Function() _myUserId;
  final String Function() _myProfileEmoji;

  StreamSubscription? _intentSub;
  StreamSubscription? _sensorSub;

  /// Intents that arrived before the workout was loaded.
  final List<WearIntent> _pendingIntents = [];
  final Set<String> _handledIntentIds = <String>{};
  bool _workoutEverLoaded = false;
  String? _lastPublishedSnapshotKey;
  String? _lastWorkoutId;
  // Suppresses dedupe-skips and unsolicited publishes (e.g. 1s multiplayer poll
  // ticks) while an intent is mid-flight. Otherwise a stale poll-driven publish
  // can clear the watch's pending state on pre-mutation data, and a dedupe hit
  // against a previously-published identical snapshot can drop the post-mutation
  // reply entirely — leaving the watch to wait out its safety timeout.
  int _inFlightIntents = 0;

  WearableSyncCoordinator({
    required WorkoutProvider workoutProvider,
    required MultiplayerProvider multiplayerProvider,
    required WearableBridgeService bridgeService,
    required String Function() myUserId,
    required String Function() myProfileEmoji,
  }) : _workoutProvider = workoutProvider,
       _multiplayerProvider = multiplayerProvider,
       _bridgeService = bridgeService,
       _myUserId = myUserId,
       _myProfileEmoji = myProfileEmoji;

  Future<void> init() async {
    await _bridgeService.init();

    _intentSub = _bridgeService.intentStream.listen((intent) async {
      await _handleIntent(intent);
    });

    _sensorSub = _bridgeService.sensorBatchStream.listen((batch) {
      if (!_workoutProvider.hasActiveWorkout) return;
      final workoutId = _workoutProvider.activeWorkout?.id;
      if (workoutId == null || batch.workoutId != workoutId) return;
      _workoutProvider.ingestWearHeartRateBatch(batch);
    });

    _workoutProvider.addListener(_onWorkoutChanged);
    _multiplayerProvider.addListener(_publishSnapshot);
    _publishSnapshot();
  }

  void _onWorkoutChanged() {
    final workoutId = _workoutProvider.activeWorkout?.id;
    if (_lastWorkoutId != workoutId) {
      _handledIntentIds.clear();
      _lastWorkoutId = workoutId;
    }
    if (!_workoutEverLoaded && _workoutProvider.hasActiveWorkout) {
      _workoutEverLoaded = true;
      _replayPendingIntents();
    }
    _publishSnapshot();
  }

  Future<void> _handleIntent(WearIntent intent) async {
    if (!_workoutProvider.hasActiveWorkout) {
      // Workout not loaded yet — queue for replay.
      _pendingIntents.add(intent);
      return;
    }
    await _executeIntent(intent);
  }

  void _replayPendingIntents() {
    if (_pendingIntents.isEmpty) return;
    final intents = List<WearIntent>.from(_pendingIntents);
    _pendingIntents.clear();
    for (final intent in intents) {
      _executeIntent(intent);
    }
  }

  Future<void> _executeIntent(WearIntent intent) async {
    final workoutId = _workoutProvider.activeWorkout?.id;
    if (workoutId == null) return;
    if (intent.intentId.isEmpty) return;
    if (!_handledIntentIds.add(intent.intentId)) return;

    _inFlightIntents++;
    try {
      if (intent.hasStartSet() && intent.startSet.workoutId == workoutId) {
        await _workoutProvider.startSet(intent.startSet.setId);
      } else if (intent.hasCompleteSet() &&
          intent.completeSet.workoutId == workoutId) {
        await _workoutProvider.completeSet(
          intent.completeSet.setId,
          intent.completeSet.reps,
          intent.completeSet.actualWeight,
          completedAt: intent.completeSet.completedAt.toInt(),
        );
      } else if (intent.hasSkipWarmup() &&
          intent.skipWarmup.workoutId == workoutId) {
        await _workoutProvider.skipWarmup(intent.skipWarmup.setId);
      } else if (intent.hasEndWorkout() &&
          intent.endWorkout.workoutId == workoutId) {
        await _workoutProvider.endWorkout();
        _multiplayerProvider.markLocalWorkoutFinished();
      }
    } finally {
      _inFlightIntents--;
      // Force-publish the post-mutation snapshot as the reply, bypassing the
      // content-dedupe guard. This is the watch's "ack" — it MUST land even if
      // the serialized content happens to equal a previously-published snapshot.
      _publishSnapshot(force: true);
    }
  }

  Future<void> dispose() async {
    _workoutProvider.removeListener(_onWorkoutChanged);
    _multiplayerProvider.removeListener(_publishSnapshot);
    await _intentSub?.cancel();
    await _sensorSub?.cancel();
    await _bridgeService.dispose();
  }

  void _publishSnapshot({bool force = false}) {
    // Suppress unsolicited (non-forced) publishes while an intent is mid-flight.
    // Otherwise a 1s multiplayer-poll tick that fires between "intent received"
    // and "mutation committed" would publish a pre-mutation snapshot, which the
    // watch would treat as the reply and clear its pending state on stale data.
    if (!force && _inFlightIntents > 0) return;

    if (!_workoutProvider.hasActiveWorkout &&
        !_workoutProvider.isWorkoutEnded) {
      return;
    }

    final userId = _myUserId();
    if (userId.isEmpty) return;

    final snapshot = WearableSnapshotBuilder.build(
      workoutProvider: _workoutProvider,
      multiplayerProvider: _multiplayerProvider,
      myUserId: userId,
      myProfileEmoji: _myProfileEmoji(),
    );

    if (snapshot == null) return;
    final snapshotKey = _snapshotPublishKey(snapshot);
    if (!force && _lastPublishedSnapshotKey == snapshotKey) return;
    _lastPublishedSnapshotKey = snapshotKey;
    unawaited(_bridgeService.publishSnapshot(snapshot));
  }

  String _snapshotPublishKey(WearWorkoutSnapshot snapshot) {
    final normalized = snapshot.deepCopy()
      ..emittedAt = Int64.ZERO
      ..elapsedText = '';
    if (normalized.hasYouCard()) {
      normalized.youCard = normalized.youCard.deepCopy()..timerText = '';
    }
    if (normalized.hasGroupCard()) {
      normalized.groupCard = normalized.groupCard.deepCopy()..timerText = '';
    }
    return normalized.writeToBuffer().join(',');
  }
}
