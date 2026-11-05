/// Heart rate from the watch: batches are taken once, samples kept in time
/// order, and every sample heard while the workout ran reaches the account.
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/wearable.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/workout_provider.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;
  late String workoutId;
  late int startMs;

  setUp(() async {
    h = await ProviderHarness.boot();
    await h.seedHistory({Exercise.EXERCISE_SQUAT: (185, 5)});
    await h.start([Exercise.EXERCISE_SQUAT]);
    workoutId = h.provider.workout!.id;
    startMs = h.provider.workout!.startTime.toInt() * 1000;
  });

  tearDown(() => h.dispose());

  /// A batch of samples at [offsets] ms after the start, bpm 100 + offset.
  WearSensorBatch batch(String id, List<int> offsets, {String? workout}) =>
      WearSensorBatch(
        batchId: id,
        workoutId: workout ?? workoutId,
        heartRateSamples: [
          for (final o in offsets)
            HeartRateSample(sampledAt: Int64(startMs + o), bpm: 100.0 + o),
        ],
      );

  List<int> offsets(WorkoutProvider p) =>
      p.wearHeartRateSamples.map((s) => s.sampledAt.toInt() - startMs).toList();

  Future<List<int>> stored() async => (await h.service.getWorkoutHeartRate(
    workoutId,
  )).map((s) => s.sampledAt.toInt() - startMs).toList()..sort();

  test('samples are kept in time order, a late one slotted in', () async {
    h.provider.ingestWearHeartRateBatch(batch('a', [10, 30]));
    h.provider.ingestWearHeartRateBatch(batch('b', [20, 40]));
    expect(offsets(h.provider), [10, 20, 30, 40]);
  });

  test('a batch or a sample heard twice is taken once', () async {
    h.provider.ingestWearHeartRateBatch(batch('a', [10, 20]));
    h.provider.ingestWearHeartRateBatch(batch('a', [10, 20]));
    h.provider.ingestWearHeartRateBatch(batch('b', [20, 30]));
    expect(offsets(h.provider), [10, 20, 30]);
  });

  test('a batch for another workout, or with no id, is not taken', () async {
    h.provider.ingestWearHeartRateBatch(batch('a', [10], workout: 'another'));
    h.provider.ingestWearHeartRateBatch(batch('', [20]));
    expect(h.provider.wearHeartRateSamples, isEmpty);
  });

  test('every sample reaches the account by the end', () async {
    // The end is in whole seconds; one after the start keeps the samples in.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    // The first batch starts a save; the second lands while it is in
    // flight, the third inside the save throttle. The end writes them all.
    h.provider.ingestWearHeartRateBatch(batch('a', [10]));
    h.provider.ingestWearHeartRateBatch(batch('b', [20]));
    h.provider.ingestWearHeartRateBatch(batch('c', [30]));
    await h.provider.endWorkout(fireEndedCallback: false);
    expect(h.provider.isWorkoutEnded, isTrue);
    expect(await stored(), [10, 20, 30]);
  });

  test('a reload mid-workout restores the samples; resends add none', () async {
    h.provider.ingestWearHeartRateBatch(batch('a', [10, 20]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await stored(), [10, 20]);

    final reloaded = WorkoutProvider(h.service, h.settings, sandbox: true);
    addTearDown(reloaded.dispose);
    await reloaded.loadActiveWorkout('test');
    expect(offsets(reloaded), [10, 20]);
    // The watch resends what it never heard acked, with one new sample.
    reloaded.ingestWearHeartRateBatch(batch('a', [10, 20, 30]));
    expect(offsets(reloaded), [10, 20, 30]);
  });
}
