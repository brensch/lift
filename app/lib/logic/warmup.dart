import 'package:uuid/uuid.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'weight_units.dart';

const _uuid = Uuid();

class WarmupDef {
  final double weight;
  final int reps;
  WarmupDef(this.weight, this.reps);
}

bool groupRestHasValues(RestConfig rc) =>
    rc.restAfterSuccess > 0 ||
    rc.restAfterFailure > 0 ||
    rc.restAfterWarmup > 0 ||
    rc.restAfterLastWarmup > 0;

/// Four warmups (5/5/3/2) climbing to the working weight, each the simplest
/// plate step-up in [unit] — empty bar first, then loads that prefer one big
/// plate over several small. Working weight is in pounds (storage); warmups
/// snap in the display unit and are returned in pounds. A direct port of
/// `generate_warmup_defs` in src/workout/planning.rs; parity is pinned by
/// `test/logic/warmup_golden_test.dart`.
List<WarmupDef> generateWarmupDefs(double workingWeightLb, WeightUnit unit) {
  const reps = [5, 5, 3, 2];
  const pcts = [0.40, 0.55, 0.70, 0.85];
  final bar = standardBarWeight(unit);
  final plates = standardPlates(unit);
  final smallest = plates.last;

  final working = displayWeightFromPounds(workingWeightLb, unit);
  // Warmups sit below the working weight by at least one small plate.
  final rawMax = working - smallest;
  final max = rawMax < smallest ? smallest : rawMax;

  final out = <WarmupDef>[];
  double prev = 0; // display units
  for (int i = 0; i < pcts.length; i++) {
    final target = working * pcts[i];
    var chosen = (i == 0 && max >= bar)
        ? bar // empty bar first
        : simplestLoadableNear(target, bar, plates, smallest, max);
    if (chosen < prev) chosen = prev;
    prev = chosen;
    out.add(WarmupDef(poundsFromDisplayWeight(chosen, unit), reps[i]));
  }

  return out;
}

/// Rebuild an exercise group's sets. Handles weight changes, warmup toggle, and set count.
/// Completed sets are always preserved; only pending sets get replaced.
List<ProposedSet> rebuildExerciseSets(
  List<ProposedSet> existingSets, {
  required double targetWeight,
  required WeightUnit unit,
  bool? warmups,
  int? setCount,
  required bool Function(String setId) isSetDone,
}) {
  if (existingSets.isEmpty) return [];
  final exercise = existingSets[0].exercise;
  final wantWarmups = warmups ?? existingSets.any((s) => s.warmup);
  final wantSetCount = setCount ?? existingSets.where((s) => !s.warmup).length;
  final targetReps = existingSets
      .firstWhere((s) => !s.warmup, orElse: () => existingSets.first)
      .targetReps;

  // --- warmup sets ---
  final completedWarmups = existingSets
      .where((s) => s.warmup && isSetDone(s.id))
      .toList();
  final pendingWarmups = existingSets
      .where((s) => s.warmup && !isSetDone(s.id))
      .toList();

  List<ProposedSet> warmupSets;
  if (!wantWarmups) {
    warmupSets = completedWarmups;
  } else {
    final defs = generateWarmupDefs(targetWeight, unit);
    final pendingNeeded = (defs.length - completedWarmups.length).clamp(
      0,
      defs.length,
    );
    final newPending = <ProposedSet>[];
    for (int i = 0; i < pendingNeeded; i++) {
      final def = defs[completedWarmups.length + i];
      if (i < pendingWarmups.length) {
        newPending.add(
          ProposedSet()
            ..mergeFromMessage(pendingWarmups[i])
            ..targetWeight = def.weight
            ..targetReps = def.reps,
        );
      } else {
        newPending.add(
          ProposedSet()
            ..id = _uuid.v4()
            ..exercise = exercise
            ..targetReps = def.reps
            ..targetWeight = def.weight
            ..warmup = true,
        );
      }
    }
    warmupSets = [...completedWarmups, ...newPending];
  }

  // --- working sets ---
  final completedWorking = existingSets
      .where((s) => !s.warmup && isSetDone(s.id))
      .toList();
  final pendingWorking = existingSets
      .where((s) => !s.warmup && !isSetDone(s.id))
      .toList();
  final pendingNeeded = (wantSetCount - completedWorking.length).clamp(
    0,
    wantSetCount,
  );

  final newPendingWorking = <ProposedSet>[];
  for (int i = 0; i < pendingNeeded; i++) {
    if (i < pendingWorking.length) {
      newPendingWorking.add(
        ProposedSet()
          ..mergeFromMessage(pendingWorking[i])
          ..targetWeight = targetWeight
          ..targetReps = targetReps,
      );
    } else {
      newPendingWorking.add(
        ProposedSet()
          ..id = _uuid.v4()
          ..exercise = exercise
          ..targetReps = targetReps
          ..targetWeight = targetWeight
          ..warmup = false,
      );
    }
  }

  return [...warmupSets, ...completedWorking, ...newPendingWorking];
}
