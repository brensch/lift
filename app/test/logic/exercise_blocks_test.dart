import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/exercise_blocks.dart';

ProposedSet set(
  String id,
  Exercise exercise, {
  bool warmup = false,
  bool cancelled = false,
}) => ProposedSet()
  ..id = id
  ..exercise = exercise
  ..warmup = warmup
  ..cancelled = cancelled;

void main() {
  group('blocksFromSets', () {
    test('groups by exercise in first-appearance order', () {
      final blocks = blocksFromSets([
        set('s1', Exercise.EXERCISE_SQUAT, warmup: true),
        set('s2', Exercise.EXERCISE_SQUAT),
        set('b1', Exercise.EXERCISE_BENCH_PRESS),
        set('b2', Exercise.EXERCISE_BENCH_PRESS),
      ]);
      expect(blocks.length, 2);
      expect(blocks[0].exercise, Exercise.EXERCISE_SQUAT);
      expect(blocks[0].warmupSets.length, 1);
      expect(blocks[0].workingSets.length, 1);
      expect(blocks[1].exercise, Exercise.EXERCISE_BENCH_PRESS);
      expect(blocks[1].sets.length, 2);
    });

    test('excludes cancelled sets, dropping empty blocks entirely', () {
      final blocks = blocksFromSets([
        set('s1', Exercise.EXERCISE_SQUAT, cancelled: true),
        set('b1', Exercise.EXERCISE_BENCH_PRESS),
        set('b2', Exercise.EXERCISE_BENCH_PRESS, cancelled: true),
      ]);
      expect(blocks.length, 1);
      expect(blocks[0].exercise, Exercise.EXERCISE_BENCH_PRESS);
      expect(blocks[0].sets.map((s) => s.id), ['b1']);
    });

    test('collapses legacy interleaved supersets into one block each', () {
      // Old superset data: A B A B. Each exercise gets one block, keyed to
      // where it first appeared, with its sets in encounter order.
      final blocks = blocksFromSets([
        set('a1', Exercise.EXERCISE_SQUAT),
        set('b1', Exercise.EXERCISE_BENCH_PRESS),
        set('a2', Exercise.EXERCISE_SQUAT),
        set('b2', Exercise.EXERCISE_BENCH_PRESS),
      ]);
      expect(blocks.length, 2);
      expect(blocks[0].exercise, Exercise.EXERCISE_SQUAT);
      expect(blocks[0].sets.map((s) => s.id), ['a1', 'a2']);
      expect(blocks[1].sets.map((s) => s.id), ['b1', 'b2']);
    });

    test('a re-added exercise merges with its earlier sets', () {
      // Remove-then-re-add leaves completed squat sets early in the list
      // and fresh ones at the end; the derived view shows one squat block.
      final blocks = blocksFromSets([
        set('s1', Exercise.EXERCISE_SQUAT),
        set('b1', Exercise.EXERCISE_BENCH_PRESS),
        set('s2', Exercise.EXERCISE_SQUAT),
      ]);
      expect(blocks.length, 2);
      expect(blocks[0].sets.map((s) => s.id), ['s1', 's2']);
    });

    test('stableId is keyed by exercise', () {
      final blocks = blocksFromSets([set('s1', Exercise.EXERCISE_SQUAT)]);
      expect(blocks.single.stableId, 'exercise-${Exercise.EXERCISE_SQUAT.value}');
    });
  });
}
