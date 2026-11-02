/// The watch's snapshot, built from a real provider on the real core.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/multiplayer_provider.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/services/multiplayer_service.dart';
import 'package:schlift/services/wearable_snapshot_builder.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;
  late MultiplayerProvider multiplayer;

  setUp(() async {
    h = await ProviderHarness.boot(sandbox: true);
    multiplayer = MultiplayerProvider(
      MultiplayerServiceWrapper(GrpcClient(host: '127.0.0.1', port: 1)),
    );
  });

  tearDown(() {
    multiplayer.dispose();
    h.dispose();
  });

  test('a first-time set: the usual band, "Open phone!" for the weight, '
      'and the usual card once it is started', () async {
    // Never done: its first set is a calibration set with nothing known.
    await h.start([Exercise.EXERCISE_DEADLIFT]);
    final first = h.provider.doneTargetSet!;
    expect(first.calibration, isTrue);

    final waiting = WearableSnapshotBuilder.build(
      workoutProvider: h.provider,
      multiplayerProvider: multiplayer,
      myUserId: 'me',
    )!.youCard;
    expect(waiting.firstTime, isTrue);
    expect(waiting.firstTimeText, copy.workout.watchFirstTimeStatus);
    expect(waiting.stateLabel, copy.workout.ready);
    expect(waiting.yappingLabel, copy.workout.yapping);
    expect(waiting.weightText, isEmpty);
    expect(waiting.repsText, isEmpty);

    // "Test me" on the phone starts it: the watch finishes it as usual.
    await h.provider.startSet(first.id);
    final lifting = WearableSnapshotBuilder.build(
      workoutProvider: h.provider,
      multiplayerProvider: multiplayer,
      myUserId: 'me',
    )!.youCard;
    expect(lifting.firstTime, isFalse);
    expect(lifting.firstTimeText, isEmpty);
    expect(lifting.stateLabel, copy.workout.lifting);
    expect(lifting.repsText, '${first.targetReps}');
  });
}
