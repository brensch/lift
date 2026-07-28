/// Builds a workout plan from exercise configs: working sets, warmups,
/// interleaving, rest resolution, and conversion to proposed sets.
///
/// This is the client-side mirror of the server's set generation in
/// `src/workout/planning.rs` — the app builds sets locally for instant
/// feedback while the server generates the authoritative ones. Warmup parity
/// between the two is pinned by `test/logic/warmup_golden_test.dart`.
library;

import 'package:uuid/uuid.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'warmup.dart';

const _uuid = Uuid();

/// Mirrors DEFAULT_*_REST_SECONDS in `src/workout/planning.rs`.
const int defaultSuccessRestSeconds = 180;
const int defaultFailureRestSeconds = 300;
const int defaultWarmupRestSeconds = 30;

int effectiveRestSuccess({
  required ExerciseTypeConfig config,
  RestConfig? groupRest,
  required bool warmup,
  required bool lastWarmup,
}) {
  final rc = config.hasRestConfig()
      ? config.restConfig
      : (groupRest != null && groupRestHasValues(groupRest)
            ? groupRest
            : null);
  final success = (rc != null && rc.restAfterSuccess > 0)
      ? rc.restAfterSuccess
      : defaultSuccessRestSeconds;
  if (!warmup) return success;
  if (lastWarmup) return success;
  return (rc != null && rc.restAfterWarmup > 0)
      ? rc.restAfterWarmup
      : defaultWarmupRestSeconds;
}

int effectiveRestFailure({
  required ExerciseTypeConfig config,
  RestConfig? groupRest,
  required bool warmup,
  required bool lastWarmup,
}) {
  final rc = config.hasRestConfig()
      ? config.restConfig
      : (groupRest != null && groupRestHasValues(groupRest)
            ? groupRest
            : null);
  final failure = (rc != null && rc.restAfterFailure > 0)
      ? rc.restAfterFailure
      : defaultFailureRestSeconds;
  if (!warmup) return failure;
  if (lastWarmup) {
    final success = (rc != null && rc.restAfterSuccess > 0)
        ? rc.restAfterSuccess
        : defaultSuccessRestSeconds;
    return success;
  }
  return (rc != null && rc.restAfterWarmup > 0)
      ? rc.restAfterWarmup
      : defaultWarmupRestSeconds;
}

/// The concrete working sets for one config: explicit `workingSets` win;
/// otherwise interpolate start→end weight across `groupSets` sets, rounded to
/// 5, marking the last set AMRAP when the config asks for it.
List<WorkingSetSpec> materializeWorkingSetsForConfig(
  ExerciseTypeConfig config,
  int groupSets,
) {
  if (config.workingSets.isNotEmpty) return config.workingSets.toList();
  final count = groupSets <= 0 ? 1 : groupSets;
  final out = <WorkingSetSpec>[];
  for (var i = 0; i < count; i++) {
    final isLast = i == count - 1;
    final weight = count <= 1
        ? config.startWeight
        : config.startWeight +
              (i / (count - 1)) * (config.endWeight - config.startWeight);
    final rounded = (weight / 5.0).round() * 5.0;
    out.add(
      WorkingSetSpec()
        ..targetWeight = rounded.toDouble()
        ..targetReps = config.reps
        ..isAmrap = config.lastSetAmrap && isLast
        ..instruction = config.lastSetAmrap && isLast
            ? 'AMRAP - push for max reps'
            : '',
    );
  }
  return out;
}

/// Expand a group's configs into the flat planned-set list: warmups first
/// (interleaved round-robin for supersets when asked), then working sets
/// interleaved by round.
List<PlannedGroupSet> buildPlannedGroupSetsFromConfigs({
  required int sets,
  required bool interleaveWarmups,
  required List<ExerciseTypeConfig> exerciseConfigs,
  required WeightUnit unit,
  RestConfig? restConfig,
}) {
  if (exerciseConfigs.isEmpty) return const [];

  final workingByConfig = exerciseConfigs
      .map((c) => materializeWorkingSetsForConfig(c, sets))
      .toList();
  final warmupByConfig = <List<WarmupDef>>[];
  for (var i = 0; i < exerciseConfigs.length; i++) {
    final c = exerciseConfigs[i];
    if (!c.includeWarmup) {
      warmupByConfig.add(const []);
      continue;
    }
    final warmupWeight = workingByConfig[i].isNotEmpty
        ? workingByConfig[i].first.targetWeight
        : c.startWeight;
    warmupByConfig.add(generateWarmupDefs(warmupWeight, unit));
  }

  final out = <PlannedGroupSet>[];

  void addWarmupSet(int cfgIdx, int warmIdx) {
    final c = exerciseConfigs[cfgIdx];
    final warm = warmupByConfig[cfgIdx][warmIdx];
    final isLastWarmup = warmIdx == warmupByConfig[cfgIdx].length - 1;
    final planned = PlannedGroupSet()
      ..exercise = c.exercise
      ..targetReps = warm.reps
      ..targetWeight = warm.weight
      ..warmup = true
      ..restAfterSuccess = effectiveRestSuccess(
        config: c,
        groupRest: restConfig,
        warmup: true,
        lastWarmup: isLastWarmup,
      )
      ..restAfterFailure = effectiveRestFailure(
        config: c,
        groupRest: restConfig,
        warmup: true,
        lastWarmup: isLastWarmup,
      )
      ..clientSetId = _uuid.v4();
    out.add(planned);
  }

  if (interleaveWarmups && exerciseConfigs.length > 1) {
    final maxWarmups = warmupByConfig.fold<int>(
      0,
      (m, w) => w.length > m ? w.length : m,
    );
    for (var round = 0; round < maxWarmups; round++) {
      for (var cfgIdx = 0; cfgIdx < exerciseConfigs.length; cfgIdx++) {
        if (round < warmupByConfig[cfgIdx].length) {
          addWarmupSet(cfgIdx, round);
        }
      }
    }
  } else {
    for (var cfgIdx = 0; cfgIdx < exerciseConfigs.length; cfgIdx++) {
      for (
        var warmIdx = 0;
        warmIdx < warmupByConfig[cfgIdx].length;
        warmIdx++
      ) {
        addWarmupSet(cfgIdx, warmIdx);
      }
    }
  }

  final maxWorking = workingByConfig.fold<int>(
    0,
    (m, w) => w.length > m ? w.length : m,
  );
  for (var round = 0; round < maxWorking; round++) {
    for (var cfgIdx = 0; cfgIdx < exerciseConfigs.length; cfgIdx++) {
      if (round >= workingByConfig[cfgIdx].length) continue;
      final c = exerciseConfigs[cfgIdx];
      final ws = workingByConfig[cfgIdx][round];
      final planned = PlannedGroupSet()
        ..exercise = c.exercise
        ..targetReps = ws.targetReps
        ..targetWeight = ws.targetWeight
        ..warmup = false
        ..restAfterSuccess = effectiveRestSuccess(
          config: c,
          groupRest: restConfig,
          warmup: false,
          lastWarmup: false,
        )
        ..restAfterFailure = effectiveRestFailure(
          config: c,
          groupRest: restConfig,
          warmup: false,
          lastWarmup: false,
        )
        ..isAmrap = ws.isAmrap
        ..instruction = ws.instruction
        ..progressionHint = ws.progressionHint.deepCopy()
        ..clientSetId = _uuid.v4();
      out.add(planned);
    }
  }

  return out;
}

/// The group's working "rounds": the largest per-exercise working-set count.
int computeGroupWorkingRoundsFromSets(List<PlannedGroupSet> sets) {
  final counts = <int, int>{};
  for (final set in sets) {
    if (set.warmup) continue;
    counts[set.exercise.value] = (counts[set.exercise.value] ?? 0) + 1;
  }
  var maxCount = 0;
  for (final count in counts.values) {
    if (count > maxCount) maxCount = count;
  }
  return maxCount;
}

/// Convert planned sets to proposed sets, assigning order and ids. Planned
/// sets must carry explicit rest values by this point.
List<ProposedSet> proposedSetsFromPlannedGroupSets({
  required String workoutId,
  required String groupId,
  required List<PlannedGroupSet> sets,
  required int startOrder,
}) {
  final out = <ProposedSet>[];
  var order = startOrder;
  for (final set in sets) {
    if (set.restAfterSuccess <= 0 || set.restAfterFailure <= 0) {
      throw StateError(
        'Workout plan sets must include explicit rest values.',
      );
    }
    out.add(
      ProposedSet()
        ..id = set.clientSetId.isNotEmpty ? set.clientSetId : _uuid.v4()
        ..workoutId = workoutId
        ..workoutOrder = order++
        ..exercise = set.exercise
        ..targetReps = set.targetReps
        ..targetWeight = set.targetWeight
        ..warmup = set.warmup
        ..exerciseGroupId = groupId
        ..restAfterSuccess = set.restAfterSuccess
        ..restAfterFailure = set.restAfterFailure
        ..cancelled = false
        ..isAmrap = set.isAmrap
        ..instruction = set.instruction
        ..progressionHint = set.progressionHint.deepCopy(),
    );
  }
  return out;
}
