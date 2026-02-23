import 'package:uuid/uuid.dart';
import '../gen/workout/v1/workout.pb.dart';

const _uuid = Uuid();

double _roundTo2_5(double weight) => (weight / 2.5).round() * 2.5;
double _roundTo5(double weight) => (weight / 5).round() * 5;

bool _is25_45PlateCombo(double totalWeight) {
  if (totalWeight < 45) return false;
  final rem = (totalWeight - 45).round();
  if (rem < 0 || rem % 10 != 0) return false;
  for (int b = 0; b <= rem ~/ 90; b++) {
    final rest = rem - (90 * b);
    if (rest >= 0 && rest % 50 == 0) return true;
  }
  return false;
}

double _snapWarmupWeight(double weight, double maxWarmupWeight) {
  if (maxWarmupWeight < 45) {
    return _roundTo2_5(weight).clamp(2.5, maxWarmupWeight).toDouble();
  }

  final candidate = _roundTo5(weight).clamp(45, maxWarmupWeight).toDouble();
  if (_is25_45PlateCombo(candidate)) return candidate;

  double best = candidate;
  double bestDiff = double.infinity;
  for (double probe = 45; probe <= maxWarmupWeight; probe += 5) {
    if (!_is25_45PlateCombo(probe)) continue;
    final diff = (probe - candidate).abs();
    if (diff <= 5 && (diff < bestDiff || (diff == bestDiff && probe < best))) {
      best = probe;
      bestDiff = diff;
    }
  }
  return best;
}

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

List<WarmupDef> generateWarmupDefs(double workingWeight) {
  // Always produce 4 warmups (5/5/3/2), even below 45 lbs, rounded to 2.5.
  const reps = [5, 5, 3, 2];
  const pcts = [0.40, 0.55, 0.70, 0.85];
  final out = <WarmupDef>[];
  double prev = 0;
  final maxWarmupWeight = (workingWeight - 2.5).clamp(2.5, double.infinity);

  for (int i = 0; i < pcts.length; i++) {
    final desired = _snapWarmupWeight(workingWeight * pcts[i], maxWarmupWeight);
    var chosen = (i == 0 && maxWarmupWeight >= 45)
        ? 45.0
        : desired.clamp(2.5, maxWarmupWeight).toDouble();
    if (chosen < prev) chosen = prev;
    prev = chosen;
    out.add(WarmupDef(chosen, reps[i]));
  }

  return out;
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
    final defs = generateWarmupDefs(targetWeight);
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
