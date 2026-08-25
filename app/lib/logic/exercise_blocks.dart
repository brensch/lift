/// Derived view of the flat set list: one exercise's sets, in order.
/// Never stored and never on the wire — a workout is just an ordered list
/// of ProposedSets, and blocks are recomputed from it wherever the UI
/// wants a per-exercise card.
library;

import '../gen/workout/v1/workout.pb.dart';

class ExerciseBlock {
  final Exercise exercise;

  /// Visible (non-cancelled) sets, in workout order.
  final List<ProposedSet> sets;

  const ExerciseBlock({required this.exercise, required this.sets});

  String get stableId => 'exercise-${exercise.value}';

  Iterable<ProposedSet> get workingSets => sets.where((s) => !s.warmup);
  Iterable<ProposedSet> get warmupSets => sets.where((s) => s.warmup);
}

/// Group visible sets by exercise, ordered by first appearance. Legacy
/// interleaved supersets collapse into one block per exercise.
List<ExerciseBlock> blocksFromSets(Iterable<ProposedSet> sets) {
  final order = <Exercise>[];
  final byExercise = <Exercise, List<ProposedSet>>{};
  for (final set in sets) {
    if (set.cancelled) continue;
    if (!byExercise.containsKey(set.exercise)) {
      order.add(set.exercise);
      byExercise[set.exercise] = [];
    }
    byExercise[set.exercise]!.add(set);
  }
  return [
    for (final exercise in order)
      ExerciseBlock(exercise: exercise, sets: byExercise[exercise]!),
  ];
}
