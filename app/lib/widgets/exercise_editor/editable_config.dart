/// Mutable working copy of an ExerciseTypeConfig while the user edits a group.
library;

import '../../gen/workout/v1/workout.pb.dart';

class EditableConfig {
  Exercise exercise;
  double startWeight;
  double endWeight;
  bool differentEndWeight;
  int reps;
  bool includeWarmup;
  RestConfig? restConfig;
  // Carried through edits so the last-set AMRAP marker + instruction survive a
  // weight change. (Progression itself is reconciled server-side by exercise, so
  // it does not depend on this round-trip.)
  bool lastSetAmrap;

  EditableConfig({
    required this.exercise,
    required this.startWeight,
    required this.endWeight,
    this.differentEndWeight = false,
    required this.reps,
    required this.includeWarmup,
    this.restConfig,
    this.lastSetAmrap = false,
  });
}
