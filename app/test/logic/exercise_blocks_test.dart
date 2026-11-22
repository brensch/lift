import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/exercise_blocks.dart';

ProposedSet set(
  String id,
  String exercise, {
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
        set('s1', 'squat', warmup: true),
        set('s2', 'squat'),
        set('b1', 'bench_press'),
        set('b2', 'bench_press'),
      ]);
      expect(blocks.length, 2);
      expect(blocks[0].exercise, 'squat');
      expect(blocks[0].workingSets.length, 1);
      expect(blocks[1].exercise, 'bench_press');
      expect(blocks[1].sets.length, 2);
    });

    test('excludes cancelled sets, dropping empty blocks entirely', () {
      final blocks = blocksFromSets([
        set('s1', 'squat', cancelled: true),
        set('b1', 'bench_press'),
        set('b2', 'bench_press', cancelled: true),
      ]);
      expect(blocks.length, 1);
      expect(blocks[0].exercise, 'bench_press');
      expect(blocks[0].sets.map((s) => s.id), ['b1']);
    });

    test('collapses interleaved exercises into one block each', () {
      // A B A B: each exercise gets one block, keyed to where it first
      // appeared, with its sets in encounter order.
      final blocks = blocksFromSets([
        set('a1', 'squat'),
        set('b1', 'bench_press'),
        set('a2', 'squat'),
        set('b2', 'bench_press'),
      ]);
      expect(blocks.length, 2);
      expect(blocks[0].exercise, 'squat');
      expect(blocks[0].sets.map((s) => s.id), ['a1', 'a2']);
      expect(blocks[1].sets.map((s) => s.id), ['b1', 'b2']);
    });

    test('a re-added exercise merges with its earlier sets', () {
      // Remove-then-re-add leaves completed squat sets early in the list
      // and fresh ones at the end; the derived view shows one squat block.
      final blocks = blocksFromSets([
        set('s1', 'squat'),
        set('b1', 'bench_press'),
        set('s2', 'squat'),
      ]);
      expect(blocks.length, 2);
      expect(blocks[0].sets.map((s) => s.id), ['s1', 's2']);
    });

    test('stableId is keyed by exercise', () {
      final blocks = blocksFromSets([set('s1', 'squat')]);
      expect(blocks.single.stableId, 'exercise-squat');
    });
  });
}
