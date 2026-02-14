import '../gen/workout/v1/workout.pb.dart';

class ExerciseGroupData {
  final Exercise exercise;
  final List<ProposedSet> sets;

  ExerciseGroupData({required this.exercise, required this.sets});
}

List<ExerciseGroupData> groupSetsByExercise(List<ProposedSet> sets) {
  final groups = <ExerciseGroupData>[];
  Exercise? currentExercise;
  var currentGroup = <ProposedSet>[];

  for (final set in sets) {
    if (set.exercise != currentExercise) {
      if (currentGroup.isNotEmpty && currentExercise != null) {
        groups.add(ExerciseGroupData(exercise: currentExercise, sets: currentGroup));
      }
      currentExercise = set.exercise;
      currentGroup = [set];
    } else {
      currentGroup.add(set);
    }
  }

  if (currentGroup.isNotEmpty && currentExercise != null) {
    groups.add(ExerciseGroupData(exercise: currentExercise, sets: currentGroup));
  }

  return groups;
}
