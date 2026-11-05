/// LocalCore against the real core: `writes` fires for a call that stored
/// events for the server, and only then — a read included, when it is the
/// call that records an ended workout's late heart rate.
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/services/local_core.dart';

import '../support/provider_harness.dart';

void main() {
  late LocalCore core;
  var writes = 0;

  setUp(() async {
    await loadCore();
    core = await LocalCore.memory('test');
    writes = 0;
    core.writes.listen((_) => writes++);
  });

  tearDown(() => core.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> getHome() async {
    await core.call('GetHome', GetHomeRequest(), GetHomeResponse.fromBuffer);
    await settle();
  }

  test('a write fires, a read that stores nothing does not', () async {
    await core.call(
      'StartWorkout',
      StartWorkoutRequest(
        name: 'Test',
        exercises: [Exercise.EXERCISE_SQUAT],
      ),
      StartWorkoutResponse.fromBuffer,
    );
    await settle();
    expect(writes, 1);

    await getHome();
    expect(writes, 1);
  });

  test('a read that records late heart rate fires', () async {
    final started = await core.call(
      'StartWorkout',
      StartWorkoutRequest(
        name: 'Test',
        exercises: [Exercise.EXERCISE_SQUAT],
      ),
      StartWorkoutResponse.fromBuffer,
    );
    await core.call(
      'EndWorkout',
      EndWorkoutRequest(workoutId: started.id),
      EndWorkoutResponse.fromBuffer,
    );
    await settle();
    final pending = await core.pendingCount();
    final before = writes;

    // Late from the watch: gathered, not recorded yet.
    await core.call(
      'AppendWorkoutHeartRate',
      AppendWorkoutHeartRateRequest(
        workoutId: started.id,
        samples: [
          WorkoutHeartRatePoint(
            sampledAt: Int64(DateTime.now().millisecondsSinceEpoch),
            bpm: 120,
          ),
        ],
      ),
      AppendWorkoutHeartRateResponse.fromBuffer,
    );
    await settle();
    expect(writes, before);
    expect(await core.pendingCount(), pending);

    // The next call, a read, records it: the sync has something to push.
    await getHome();
    expect(await core.pendingCount(), pending + 1);
    expect(writes, before + 1);
  });
}
