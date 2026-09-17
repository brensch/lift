/// Estimated session length for a template, from the resolved trackers.
///
/// A heuristic, but the single source of it: per exercise, setup time plus
/// working sets with their prescribed rest between them, plus the warmup
/// ladder where one is prescribed. Mirrors the constants the old server
/// estimate used, so the numbers feel familiar.
library;

import '../gen/workout/v1/workout.pb.dart';

const int _setupSeconds = 75; // rack up, adjust bench, load plates
const int _workingSetSeconds = 45;
const int _warmupSetSeconds = 30;
const int _warmupRestSeconds = 30;
const int _warmupCount = 4;

/// Seconds for one exercise: setup + sets + rests-between-sets (+ ladder).
int estimatedExerciseSeconds(ExerciseTracker tracker) {
  final sets = tracker.sets < 1 ? 1 : tracker.sets;
  var total = _setupSeconds + sets * _workingSetSeconds;
  total += (sets - 1) * tracker.restSeconds;
  if (tracker.includeWarmup) {
    // The last warmup's rest rolls into the first working set's rest, so
    // count the ladder as sets plus the short between-warmup rests.
    total += _warmupCount * (_warmupSetSeconds + _warmupRestSeconds);
  }
  return total;
}

/// Seconds for a whole template. Unknown exercises (no tracker — only
/// possible before the first home load) count as zero rather than guessing.
int estimatedSessionSeconds(
  WorkoutTemplate template,
  List<ExerciseTracker> trackers,
) {
  final byExercise = {for (final t in trackers) t.exercise: t};
  var total = 0;
  for (final exercise in template.exercises) {
    final tracker = byExercise[exercise];
    if (tracker == null) continue;
    total += estimatedExerciseSeconds(tracker);
  }
  return total;
}

/// "~52 min" style label; empty when there is nothing to estimate.
String estimatedSessionLabel(
  WorkoutTemplate template,
  List<ExerciseTracker> trackers,
) {
  final seconds = estimatedSessionSeconds(template, trackers);
  if (seconds <= 0) return '';
  final minutes = (seconds / 60).round();
  return '~$minutes min';
}
