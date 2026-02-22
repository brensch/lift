import 'dart:async';

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
      if (!_workoutProvider.hasActiveWorkout) return;
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
    });

    _sensorSub = _bridgeService.sensorBatchStream.listen((batch) {
      if (!_workoutProvider.hasActiveWorkout) return;
      final workoutId = _workoutProvider.activeWorkout?.id;
      if (workoutId == null || batch.workoutId != workoutId) return;
      _workoutProvider.ingestWearHeartRateBatch(batch);
    });

    _workoutProvider.addListener(_publishSnapshot);
    _multiplayerProvider.addListener(_publishSnapshot);
    _publishSnapshot();
  }

  Future<void> dispose() async {
    _workoutProvider.removeListener(_publishSnapshot);
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
    unawaited(_bridgeService.publishSnapshot(snapshot));
  }
}
