import '../gen/workout/v1/workout.pb.dart';

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
