/// What the watch sends the phone (intents, heart-rate batches) and what the
/// phone sends back (a snapshot after every intent, the end command once).
/// Signing out ends the workout on the watch: the last thing the watch hears
/// for it is an ended snapshot (ALL_DONE, no End action), then the end command.
library;

import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/wearable.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/multiplayer_provider.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/services/multiplayer_service.dart';
import 'package:schlift/services/wearable_bridge_service.dart';
import 'package:schlift/services/wearable_sync_coordinator.dart';

import '../support/provider_harness.dart';

/// Records what the phone sends the watch, and plays what the watch sends.
class _FakeBridge extends NoopWearableBridgeService {
  final snapshots = <WearWorkoutSnapshot>[];
  final ended = <String>[];
  final intents = StreamController<WearIntent>.broadcast();
  final sensors = StreamController<WearSensorBatch>.broadcast();

  @override
  Stream<WearIntent> get intentStream => intents.stream;

  @override
  Stream<WearSensorBatch> get sensorBatchStream => sensors.stream;

  @override
  Future<void> publishSnapshot(WearWorkoutSnapshot snapshot) async =>
      snapshots.add(snapshot);

  @override
  Future<void> endWatchWorkout(String workoutId) async => ended.add(workoutId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;
  late _FakeBridge bridge;
  late WearableSyncCoordinator coordinator;

  WearableSyncCoordinator coordinate(WorkoutProvider provider, _FakeBridge b) =>
      WearableSyncCoordinator(
        workoutProvider: provider,
        multiplayerProvider: MultiplayerProvider(
          MultiplayerServiceWrapper(GrpcClient(host: '127.0.0.1', port: 1)),
        ),
        settingsProvider: h.settings,
        bridgeService: b,
        myUserId: () => 'me',
      );

  setUp(() async {
    h = await ProviderHarness.boot();
    await h.seedHistory({Exercise.EXERCISE_SQUAT: (185, 5)});
    bridge = _FakeBridge();
    coordinator = coordinate(h.provider, bridge);
    await coordinator.init();
  });

  tearDown(() async {
    await coordinator.dispose();
    h.dispose();
  });

  bool endsTheWatch(WearWorkoutSnapshot s) =>
      s.state == WorkoutState.WORKOUT_STATE_ALL_DONE &&
      !s.actions.any(
        (a) => a.type == WearActionType.WEAR_ACTION_TYPE_END_WORKOUT,
      );

  test('signing out mid-workout ends it on the watch', () async {
    await h.start([Exercise.EXERCISE_SQUAT]);
    final workoutId = h.provider.workout!.id;
    expect(bridge.snapshots.last.workoutId, workoutId);
    expect(endsTheWatch(bridge.snapshots.last), isFalse);

    // As main.dart does: the coordinator first, then the account is cleared.
    unawaited(coordinator.signOut());
    h.provider.clear();
    await pumpEventQueue();

    expect(bridge.snapshots.last.workoutId, workoutId);
    expect(endsTheWatch(bridge.snapshots.last), isTrue);
    expect(bridge.ended, [workoutId]);
  });

  test('signing out with no workout sends the watch nothing', () async {
    final before = bridge.snapshots.length;
    await coordinator.signOut();
    expect(bridge.snapshots.length, before);
    expect(bridge.ended, isEmpty);
  });

  test('a unit switched mid-workout reaches the watch', () async {
    await h.start([Exercise.EXERCISE_SQUAT]);
    expect(bridge.snapshots.last.youCard.unitText, 'lb');
    final before = bridge.snapshots.length;
    h.settings.applyWeightUnitLocally(WeightUnit.WEIGHT_UNIT_KG);
    await pumpEventQueue();
    expect(bridge.snapshots.length, greaterThan(before));
    expect(bridge.snapshots.last.youCard.unitText, 'kg');
  });

  group('watch intents', () {
    var n = 0;
    String nextId() => 'intent-${n++}';

    /// Waits until [cond] holds: the core answers on another thread.
    Future<void> until(bool Function() cond) async {
      for (var i = 0; i < 500 && !cond(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(cond(), isTrue, reason: 'timed out');
    }

    /// Sends [intent] and waits for the snapshot that acks it.
    Future<void> send(WearIntent intent, [_FakeBridge? to]) async {
      final b = to ?? bridge;
      final before = b.snapshots.length;
      b.intents.add(intent);
      await until(() => b.snapshots.length > before);
    }

    WearIntent complete(String setId, {String? workoutId, String? id}) =>
        WearIntent(
          intentId: id ?? nextId(),
          completeSet: CompleteSetIntent(
            workoutId: workoutId ?? h.provider.workout!.id,
            setId: setId,
            reps: 5,
            actualWeight: 185,
          ),
        );

    WearIntent tap(String setId) => WearIntent(
      intentId: nextId(),
      tapSet: TapSetIntent(workoutId: h.provider.workout!.id, setId: setId),
    );

    setUp(() => h.start([Exercise.EXERCISE_SQUAT]));

    String firstSet() => h.working(Exercise.EXERCISE_SQUAT).first.id;

    test('a complete from the watch completes the set and is acked', () async {
      final setId = firstSet();
      await send(complete(setId));
      expect(h.provider.isSetDone(setId), isTrue);
      expect(bridge.snapshots.last.workoutId, h.provider.workout!.id);
    });

    test('the same intent twice is acted on once', () async {
      final setId = firstSet();
      final intent = tap(setId);
      await send(intent);
      expect(h.provider.workout!.liftingSetId, setId);
      // A second start-tap would complete the set; a repeat does nothing
      // (and is not acked: the no-op after it shows it was handled).
      bridge.intents.add(tap(setId)..intentId = intent.intentId);
      await send(tap('no-such-set'));
      expect(h.provider.isSetDone(setId), isFalse);
    });

    test(
      'an intent for another workout changes nothing but is acked',
      () async {
        final setId = firstSet();
        await send(complete(setId, workoutId: 'another'));
        expect(h.provider.isSetDone(setId), isFalse);
      },
    );

    test('an intent with no id is dropped without an ack', () async {
      final setId = firstSet();
      final before = bridge.snapshots.length;
      bridge.intents.add(complete(setId, id: ''));
      // A no-op intent after it: its ack shows the first was handled.
      await send(tap('no-such-set'));
      expect(h.provider.isSetDone(setId), isFalse);
      expect(bridge.snapshots.length, before + 1);
    });

    test('the ack is sent even when nothing changed', () async {
      await send(tap('no-such-set'));
      final last = bridge.snapshots.last;
      await send(tap('no-such-set'));
      expect(bridge.snapshots.last.state, last.state);
    });

    test('a tap cycles start, done, then one rep off', () async {
      final set = h.working(Exercise.EXERCISE_SQUAT).first;
      await send(tap(set.id));
      expect(h.provider.workout!.liftingSetId, set.id);
      await send(tap(set.id));
      expect(h.provider.isSetDone(set.id), isTrue);
      await send(tap(set.id));
      final done = h.provider.completedSets.firstWhere(
        (c) => c.proposedSetId == set.id,
      );
      expect(done.actualReps, set.targetReps - 1);
    });

    test(
      'an end from the watch ends the workout; the watch is told once',
      () async {
        final workoutId = h.provider.workout!.id;
        await send(
          WearIntent(
            intentId: nextId(),
            endWorkout: EndWorkoutIntent(workoutId: workoutId),
          ),
        );
        await until(() => h.provider.isWorkoutEnded);
        // The end notifies listeners several times; the command goes once.
        await pumpEventQueue();
        expect(bridge.ended, [workoutId]);
      },
    );

    test('a heart-rate batch for another workout is not taken', () async {
      bridge.sensors.add(
        WearSensorBatch(
          batchId: 'b',
          workoutId: 'another',
          heartRateSamples: [HeartRateSample(sampledAt: Int64(1), bpm: 120)],
        ),
      );
      await pumpEventQueue();
      expect(h.provider.wearHeartRateSamples, isEmpty);
    });

    group('arriving before the workout loads (a cold start)', () {
      late WorkoutProvider cold;
      late _FakeBridge coldBridge;
      late WearableSyncCoordinator coldCoordinator;

      setUp(() async {
        cold = WorkoutProvider(h.service, h.settings, sandbox: true);
        coldBridge = _FakeBridge();
        coldCoordinator = coordinate(cold, coldBridge);
        await coldCoordinator.init();
      });

      tearDown(() async {
        await coldCoordinator.dispose();
        cold.dispose();
      });

      test('queued intents are replayed in order once it loads', () async {
        final setId = firstSet();
        final workoutId = h.provider.workout!.id;
        coldBridge.intents.add(
          WearIntent(
            intentId: nextId(),
            startSet: StartSetIntent(workoutId: workoutId, setId: setId),
          ),
        );
        coldBridge.intents.add(complete(setId));
        await pumpEventQueue();
        expect(coldBridge.snapshots, isEmpty);

        await cold.loadActiveWorkout('test');
        await until(() => cold.isSetDone(setId));
        // The start ran first: the done set is no longer the one lifting.
        expect(cold.workout!.liftingSetId, isEmpty);
      });

      test('heart rate heard before is taken once it loads', () async {
        final workout = h.provider.workout!;
        final at = workout.startTime.toInt() * 1000 + 500;
        coldBridge.sensors.add(
          WearSensorBatch(
            batchId: 'early',
            workoutId: workout.id,
            heartRateSamples: [HeartRateSample(sampledAt: Int64(at), bpm: 120)],
          ),
        );
        await pumpEventQueue();

        await cold.loadActiveWorkout('test');
        expect(cold.wearHeartRateSamples.map((s) => s.sampledAt.toInt()), [at]);
      });
    });
  });
}
