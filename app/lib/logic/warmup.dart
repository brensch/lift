import 'package:uuid/uuid.dart';
import '../gen/workout/v1/workout.pb.dart';

const _uuid = Uuid();

const List<double> plateStops = [45, 95, 135, 185, 225, 275, 315, 365, 405, 455, 495, 545, 585, 635];

const Map<int, List<int>> _repSchemes = {
  1: [5],
  2: [5, 5],
  3: [5, 5, 3],
  4: [5, 5, 3, 2],
};

class WarmupDef {
  final double weight;
  final int reps;
  WarmupDef(this.weight, this.reps);
}

List<WarmupDef> generateWarmupDefs(double workingWeight) {
  if (workingWeight <= 45) return [];

  final candidates = plateStops.where((w) => w < workingWeight).toList();
  if (candidates.isEmpty) return [];

  List<double> selected;
  if (candidates.length <= 4) {
    selected = candidates;
  } else {
    final n = candidates.length;
    final step = (n - 1) / 3;
    selected = [
      candidates[0],
      candidates[step.round()],
      candidates[(step * 2).round()],
      candidates[n - 1],
    ];
  }

  final reps = _repSchemes[selected.length]!;
  return List.generate(selected.length, (i) => WarmupDef(selected[i], reps[i]));
}

/// Rebuild an exercise group's sets. Handles weight changes, warmup toggle, and set count.
/// Completed sets are always preserved; only pending sets get replaced.
List<ProposedSet> rebuildExerciseSets(
  List<ProposedSet> existingSets, {
  required double targetWeight,
  bool? warmups,
  int? setCount,
  required bool Function(String setId) isSetDone,
}) {
  if (existingSets.isEmpty) return [];
  final exercise = existingSets[0].exercise;
  final wantWarmups = warmups ?? existingSets.any((s) => s.warmup);
  final wantSetCount = setCount ?? existingSets.where((s) => !s.warmup).length;
  final targetReps = existingSets.firstWhere(
    (s) => !s.warmup,
    orElse: () => existingSets.first,
  ).targetReps;

  // --- warmup sets ---
  final completedWarmups = existingSets.where((s) => s.warmup && isSetDone(s.id)).toList();
  final pendingWarmups = existingSets.where((s) => s.warmup && !isSetDone(s.id)).toList();

  List<ProposedSet> warmupSets;
  if (!wantWarmups) {
    warmupSets = completedWarmups;
  } else {
    final defs = generateWarmupDefs(targetWeight);
    final pendingNeeded = (defs.length - completedWarmups.length).clamp(0, defs.length);
    final newPending = <ProposedSet>[];
    for (int i = 0; i < pendingNeeded; i++) {
      final def = defs[completedWarmups.length + i];
      if (i < pendingWarmups.length) {
        newPending.add(ProposedSet()
          ..mergeFromMessage(pendingWarmups[i])
          ..targetWeight = def.weight
          ..targetReps = def.reps);
      } else {
        newPending.add(ProposedSet()
          ..id = _uuid.v4()
          ..exercise = exercise
          ..targetReps = def.reps
          ..targetWeight = def.weight
          ..warmup = true);
      }
    }
    warmupSets = [...completedWarmups, ...newPending];
  }

  // --- working sets ---
  final completedWorking = existingSets.where((s) => !s.warmup && isSetDone(s.id)).toList();
  final pendingWorking = existingSets.where((s) => !s.warmup && !isSetDone(s.id)).toList();
  final pendingNeeded = (wantSetCount - completedWorking.length).clamp(0, wantSetCount);

  final newPendingWorking = <ProposedSet>[];
  for (int i = 0; i < pendingNeeded; i++) {
    if (i < pendingWorking.length) {
      newPendingWorking.add(ProposedSet()
        ..mergeFromMessage(pendingWorking[i])
        ..targetWeight = targetWeight
        ..targetReps = targetReps);
    } else {
      newPendingWorking.add(ProposedSet()
        ..id = _uuid.v4()
        ..exercise = exercise
        ..targetReps = targetReps
        ..targetWeight = targetWeight
        ..warmup = false);
    }
  }

  return [...warmupSets, ...completedWorking, ...newPendingWorking];
}
