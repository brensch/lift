import '../gen/workout/v1/workout.pb.dart';

class Round {
  final int index; // 1-based
  final List<ProposedSet> sets;
  final bool isWarmup;

  Round({required this.index, required this.sets, required this.isWarmup});
}

class ExerciseGroupData {
  final Exercise exercise;
  final List<Exercise> exercises; // all exercises in group
  final List<ProposedSet> sets;
  final ExerciseGroup? group;

  ExerciseGroupData({
    required this.exercise,
    required this.sets,
    this.group,
    this.exercises = const [],
  });

  List<Round> get rounds {
    final List<Round> rounds = [];
    
    // Split into warmup and working sets
    final warmupSets = sets.where((s) => s.warmup).toList();
    final workingSets = sets.where((s) => !s.warmup).toList();

    // Group warmups into rounds
    if (warmupSets.isNotEmpty) {
      _groupIntoRounds(warmupSets, rounds, true);
    }

    // Group working sets into rounds
    if (workingSets.isNotEmpty) {
      _groupIntoRounds(workingSets, rounds, false);
    }

    return rounds;
  }

  void _groupIntoRounds(List<ProposedSet> sourceSets, List<Round> targetRounds, bool isWarmup) {
    // We assume sets are already in correct workout order from the backend.
    // For interleaved groups, the order is E1-S1, E2-S1, E1-S2, E2-S2...
    // We group by "occurrence index" of each exercise.
    
    final Map<Exercise, int> exerciseCounts = {};
    final Map<int, List<ProposedSet>> roundMap = {};
    int maxRound = 0;

    for (final set in sourceSets) {
      final count = (exerciseCounts[set.exercise] ?? 0) + 1;
      exerciseCounts[set.exercise] = count;
      
      roundMap.putIfAbsent(count, () => []).add(set);
      if (count > maxRound) maxRound = count;
    }

    for (int i = 1; i <= maxRound; i++) {
      if (roundMap.containsKey(i)) {
        targetRounds.add(Round(
          index: i,
          sets: roundMap[i]!,
          isWarmup: isWarmup,
        ));
      }
    }
  }
}

List<ExerciseGroupData> groupSetsByExercise(List<ProposedSet> sets) {
  // Group by exerciseGroupId if available
  final Map<String, List<ProposedSet>> byGroup = {};
  final ungrouped = <ProposedSet>[];

  for (final set in sets) {
    if (set.exerciseGroupId.isNotEmpty) {
      byGroup.putIfAbsent(set.exerciseGroupId, () => []).add(set);
    } else {
      ungrouped.add(set);
    }
  }

  final groups = <ExerciseGroupData>[];

  for (final entry in byGroup.entries) {
    final groupSets = entry.value;
    final exercise = groupSets.isNotEmpty
        ? groupSets.first.exercise
        : Exercise.EXERCISE_UNSPECIFIED;
    final exercises = <Exercise>[];
    for (final s in groupSets) {
      if (!exercises.contains(s.exercise)) exercises.add(s.exercise);
    }
    groups.add(ExerciseGroupData(
      exercise: exercise,
      sets: groupSets,
      exercises: exercises,
    ));
  }

  // Fallback: group ungrouped by consecutive exercise runs
  Exercise? currentExercise;
  var currentGroup = <ProposedSet>[];

  for (final set in ungrouped) {
    if (set.exercise != currentExercise) {
      if (currentGroup.isNotEmpty && currentExercise != null) {
        groups.add(
          ExerciseGroupData(exercise: currentExercise, sets: currentGroup),
        );
      }
      currentExercise = set.exercise;
      currentGroup = [set];
    } else {
      currentGroup.add(set);
    }
  }

  if (currentGroup.isNotEmpty && currentExercise != null) {
    groups.add(
      ExerciseGroupData(exercise: currentExercise, sets: currentGroup),
    );
  }

  return groups;
}
