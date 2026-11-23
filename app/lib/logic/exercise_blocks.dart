/// Derived view of the flat set list: one exercise's sets, in order.
/// Never stored and never on the wire — a workout is just an ordered list
/// of ProposedSets, and blocks are recomputed from it wherever the UI
/// wants a per-exercise card.
library;

import '../gen/workout/v1/workout.pb.dart';

class ExerciseBlock {
  final String exercise;

  /// Visible (non-cancelled) sets, in workout order.
  final List<ProposedSet> sets;

  const ExerciseBlock({required this.exercise, required this.sets});

  String get stableId => 'exercise-$exercise';

  /// The sets that count: not warmups, not calibration rungs.
  Iterable<ProposedSet> get workingSets => sets.where(isWorkingSet);

  /// The ramp of a first-session exercise, in order.
  Iterable<ProposedSet> get calibrationSets => sets.where((s) => s.calibration);
}

/// A working set: neither a warmup nor a calibration rung. Rungs count as
/// warmups for volume and summaries, like the core's `session_outcomes`.
bool isWorkingSet(ProposedSet set) => !set.warmup && !set.calibration;

extension WorkoutSummarySets on WorkoutSummary {
  /// The working sets done in the workout, every lift together.
  int get workingSets => exercises.fold(0, (n, e) => n + e.totalSets);
}

/// Group visible sets by exercise, ordered by first appearance; a
/// re-added exercise merges into one block.
List<ExerciseBlock> blocksFromSets(Iterable<ProposedSet> sets) {
  final order = <String>[];
  final byExercise = <String, List<ProposedSet>>{};
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

/// The list as it's drawn: lone lifts, and a superset's or circuit's lifts
/// together as one item (one section, dragged as one). Blocks of a group
/// sit side by side; the core keeps them so.
List<List<ExerciseBlock>> sectionsOf(List<ExerciseBlock> blocks) {
  String groupOf(ExerciseBlock b) =>
      b.sets.map((s) => s.group).where((g) => g.isNotEmpty).firstOrNull ?? '';
  final sections = <List<ExerciseBlock>>[];
  for (final block in blocks) {
    final group = groupOf(block);
    final last = sections.lastOrNull;
    if (group.isNotEmpty && last != null && groupOf(last.first) == group) {
      last.add(block);
    } else {
      sections.add([block]);
    }
  }
  return sections;
}

/// A lift's short code under its circles in a group: the initials of a
/// name of more than one word ("LR" for Lateral Raise), the first two
/// letters of one word ("Pl"), longer where two lifts would share one.
Map<String, String> liftCodes(List<String> names) {
  String code(String name, int extra) {
    final words = name.split(RegExp(r'[\s-]+')).where((w) => w.isNotEmpty);
    final base = words.length > 1
        ? words.map((w) => w[0].toUpperCase()).join()
        : name.substring(0, name.length.clamp(0, 2));
    if (extra == 0) return base;
    final tail = words.last;
    return base + tail.substring(1, (1 + extra).clamp(1, tail.length));
  }

  final codes = <String, String>{};
  for (var extra = 0; extra < 4; extra++) {
    codes
      ..clear()
      ..addAll({for (final n in names) n: code(n, extra)});
    if (codes.values.toSet().length == names.toSet().length) break;
  }
  return codes;
}
