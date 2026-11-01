/// Signing out ends the workout on the watch: the last thing the watch hears
/// for it is an ended snapshot (ALL_DONE, no End action), then the end command.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/wearable.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/multiplayer_provider.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/services/multiplayer_service.dart';
import 'package:schlift/services/wearable_bridge_service.dart';
import 'package:schlift/services/wearable_sync_coordinator.dart';

import '../support/provider_harness.dart';

/// Records what the phone sends the watch.
class _FakeBridge extends NoopWearableBridgeService {
  final snapshots = <WearWorkoutSnapshot>[];
  final ended = <String>[];

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

  setUp(() async {
    h = await ProviderHarness.boot(sandbox: true);
    await h.seedTrackers({Exercise.EXERCISE_SQUAT: 185});
    bridge = _FakeBridge();
    coordinator = WearableSyncCoordinator(
      workoutProvider: h.provider,
      multiplayerProvider: MultiplayerProvider(
        MultiplayerServiceWrapper(GrpcClient(host: '127.0.0.1', port: 1)),
      ),
      bridgeService: bridge,
      myUserId: () => 'me',
    );
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
    final workoutId = h.provider.activeWorkout!.id;
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
}
