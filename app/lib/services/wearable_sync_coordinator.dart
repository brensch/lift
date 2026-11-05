import 'dart:async';

import 'package:fixnum/fixnum.dart';

import '../gen/workout/v1/wearable.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../screens/workout/live_set_circle.dart';
import '../screens/workout/section_workout.dart';
import 'wearable_bridge_service.dart';
import 'wearable_snapshot_builder.dart';

class WearableSyncCoordinator {
  final WorkoutProvider _workoutProvider;
  final MultiplayerProvider _multiplayerProvider;
  // The unit and plate colours every weight on the watch is drawn in.
  final SettingsProvider _settingsProvider;
  final WearableBridgeService _bridgeService;
  final String Function() _myUserId;

  StreamSubscription? _intentSub;
  StreamSubscription? _sensorSub;

  /// Intents that arrived before the workout was loaded.
  final List<WearIntent> _pendingIntents = [];

  /// Heart-rate batches that arrived before the workout first loaded (a cold
  /// start mid-workout), by batch id: the bridge has already acked them, so
  /// the watch will not send them again.
  final Map<String, WearSensorBatch> _pendingSensorBatches = {};
  final Set<String> _handledIntentIds = <String>{};
  bool _workoutEverLoaded = false;
  String? _lastPublishedSnapshotKey;
  String? _lastWorkoutId;
  // Workout id we've already told the watch to end, so we send the dedicated end command
  // exactly once when a workout finishes (phone- or watch-initiated).
  String? _endCommandSentForWorkoutId;
  // Suppresses dedupe-skips and unsolicited publishes (e.g. a session update
  // arriving) while an intent is mid-flight. Otherwise a stale unsolicited publish
  // can clear the watch's pending state on pre-mutation data, and a dedupe hit
  // against a previously-published identical snapshot can drop the post-mutation
  // reply entirely — leaving the watch to wait out its safety timeout.
  int _inFlightIntents = 0;

  WearableSyncCoordinator({
    required WorkoutProvider workoutProvider,
    required MultiplayerProvider multiplayerProvider,
    required SettingsProvider settingsProvider,
    required WearableBridgeService bridgeService,
    required String Function() myUserId,
  }) : _workoutProvider = workoutProvider,
       _multiplayerProvider = multiplayerProvider,
       _settingsProvider = settingsProvider,
       _bridgeService = bridgeService,
       _myUserId = myUserId;

  Future<void> init() async {
    _intentSub = _bridgeService.intentStream.listen((intent) async {
      await _handleIntent(intent);
    });

    _sensorSub = _bridgeService.sensorBatchStream.listen((batch) {
      if (!_workoutProvider.hasActiveWorkout) {
        if (!_workoutEverLoaded) _pendingSensorBatches[batch.batchId] = batch;
        return;
      }
      final workoutId = _workoutProvider.workout?.id;
      if (workoutId == null || batch.workoutId != workoutId) return;
      _workoutProvider.ingestWearHeartRateBatch(batch);
    });

    _workoutProvider.addListener(_onWorkoutChanged);
    _multiplayerProvider.addListener(_publishSnapshot);
    _settingsProvider.addListener(_publishSnapshot);
    _publishSnapshot();
  }

  void _onWorkoutChanged() {
    final workoutId = _workoutProvider.workout?.id;
    if (_lastWorkoutId != workoutId) {
      _handledIntentIds.clear();
      _lastWorkoutId = workoutId;
    }
    if (!_workoutEverLoaded && _workoutProvider.hasActiveWorkout) {
      _workoutEverLoaded = true;
      _replayPendingSensorBatches();
      unawaited(_replayPendingIntents());
    }
    // When the workout becomes ended, tell the watch to stop its HK session (exactly once).
    // The phone cannot end the watch's session directly — this dedicated, guaranteed-delivery
    // command is the reliable way to stop it, independent of the snapshot pipeline.
    if (_workoutProvider.isWorkoutEnded &&
        workoutId != null &&
        _endCommandSentForWorkoutId != workoutId) {
      _endCommandSentForWorkoutId = workoutId;
      unawaited(_bridgeService.endWatchWorkout(workoutId));
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

  /// One at a time, in the order the watch sent them: a set's start must
  /// land before its completion.
  Future<void> _replayPendingIntents() async {
    final intents = List<WearIntent>.from(_pendingIntents);
    _pendingIntents.clear();
    for (final intent in intents) {
      await _executeIntent(intent);
    }
  }

  void _replayPendingSensorBatches() {
    final batches = _pendingSensorBatches.values.toList();
    _pendingSensorBatches.clear();
    final workoutId = _workoutProvider.workout?.id;
    for (final batch in batches) {
      if (batch.workoutId == workoutId) {
        _workoutProvider.ingestWearHeartRateBatch(batch);
      }
    }
  }

  Future<void> _executeIntent(WearIntent intent) async {
    final workoutId = _workoutProvider.workout?.id;
    if (workoutId == null) return;
    if (intent.intentId.isEmpty) return;
    if (!_handledIntentIds.add(intent.intentId)) return;

    _inFlightIntents++;
    try {
      if (intent.hasStartSet() && intent.startSet.workoutId == workoutId) {
        await _workoutProvider.startSet(
          intent.startSet.setId,
          startedAt: intent.startSet.startedAt.toInt(),
        );
      } else if (intent.hasCompleteSet() &&
          intent.completeSet.workoutId == workoutId) {
        await _workoutProvider.completeSet(
          intent.completeSet.setId,
          intent.completeSet.reps,
          intent.completeSet.actualWeight,
          completedAt: intent.completeSet.completedAt.toInt(),
        );
      } else if (intent.hasTapSet() && intent.tapSet.workoutId == workoutId) {
        // A circle tapped on the watch: what a tap on the phone's does.
        final set = _workoutProvider.proposedSets
            .where((s) => s.id == intent.tapSet.setId)
            .firstOrNull;
        if (set != null) {
          await LiveSetCircle.tapSet(
            _workoutProvider,
            SectionWorkout.mine(_workoutProvider),
            set,
          );
        }
      } else if (intent.hasEndWorkout() &&
          intent.endWorkout.workoutId == workoutId) {
        await _workoutProvider.endWorkout();
      }
    } finally {
      _inFlightIntents--;
      // Force-publish the post-mutation snapshot as the reply, bypassing the
      // content-dedupe guard. This is the watch's "ack" — it MUST land even if
      // the serialized content happens to equal a previously-published snapshot.
      _publishSnapshot(force: true);
    }
  }

  /// Signing out ends what the watch is tracking: the workout belongs to the
  /// account that is leaving. Call before the workout is cleared. An ALL_DONE
  /// snapshot with no End action is what both watches read as ended; iOS also
  /// gets its dedicated end command for the HealthKit session.
  Future<void> signOut() async {
    final workoutId = _workoutProvider.workout?.id;
    _pendingIntents.clear();
    _pendingSensorBatches.clear();
    if (workoutId == null) return;
    _endCommandSentForWorkoutId = workoutId;
    _lastPublishedSnapshotKey = null;
    await _bridgeService.publishSnapshot(
      WearWorkoutSnapshot(
        workoutId: workoutId,
        state: WorkoutState.WORKOUT_STATE_ALL_DONE,
        emittedAt: Int64(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await _bridgeService.endWatchWorkout(workoutId);
  }

  Future<void> dispose() async {
    _workoutProvider.removeListener(_onWorkoutChanged);
    _multiplayerProvider.removeListener(_publishSnapshot);
    _settingsProvider.removeListener(_publishSnapshot);
    await _intentSub?.cancel();
    await _sensorSub?.cancel();
  }

  void _publishSnapshot({bool force = false}) {
    // Suppress unsolicited (non-forced) publishes while an intent is mid-flight.
    // Otherwise a session update that lands between "intent received"
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
    return normalized.writeToBuffer().join(',');
  }
}
