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

  StreamSubscription? _intentSub;
  StreamSubscription? _sensorSub;

  /// Intents that arrived before the workout was loaded.
  final List<WearIntent> _pendingIntents = [];
  bool _workoutEverLoaded = false;
  String? _lastPublishedSnapshotKey;

  WearableSyncCoordinator({
    required WorkoutProvider workoutProvider,
    required MultiplayerProvider multiplayerProvider,
    required WearableBridgeService bridgeService,
    required String Function() myUserId,
  }) : _workoutProvider = workoutProvider,
       _multiplayerProvider = multiplayerProvider,
       _bridgeService = bridgeService,
       _myUserId = myUserId;

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
  }

  Future<void> dispose() async {
    _workoutProvider.removeListener(_onWorkoutChanged);
    _multiplayerProvider.removeListener(_publishSnapshot);
    await _intentSub?.cancel();
    await _sensorSub?.cancel();
    await _bridgeService.dispose();
  }

  void _publishSnapshot() {
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
    );

    if (snapshot == null) return;
    final snapshotKey = _snapshotPublishKey(snapshot);
    if (_lastPublishedSnapshotKey == snapshotKey) return;
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
