import '../gen/workout/v1/workout.pbenum.dart';

const Map<Exercise, String> exerciseNames = {
  Exercise.EXERCISE_UNSPECIFIED: '?',
  Exercise.EXERCISE_SQUAT: 'Squat',
  Exercise.EXERCISE_BENCH_PRESS: 'Bench Press',
  Exercise.EXERCISE_DEADLIFT: 'Deadlift',
  Exercise.EXERCISE_OVERHEAD_PRESS: 'Overhead Press',
  Exercise.EXERCISE_BARBELL_ROW: 'Barbell Row',
  Exercise.EXERCISE_HIP_THRUST: 'Hip Thrust',
  Exercise.EXERCISE_BULGARIAN_SPLIT_SQUAT: 'Bulgarian Split Squat',
  Exercise.EXERCISE_ROMANIAN_DEADLIFT: 'Romanian Deadlift',
  Exercise.EXERCISE_GLUTE_BRIDGE: 'Glute Bridge',
  Exercise.EXERCISE_LUNGE: 'Lunge',
  Exercise.EXERCISE_LEG_CURL: 'Leg Curl',
};

const Map<Exercise, String> exerciseEmojis = {
  Exercise.EXERCISE_UNSPECIFIED: '?',
  Exercise.EXERCISE_SQUAT: '\u{1F9B5}',
  Exercise.EXERCISE_BENCH_PRESS: '\u{1F3CB}\u{FE0F}',
  Exercise.EXERCISE_DEADLIFT: '\u{26A1}',
  Exercise.EXERCISE_OVERHEAD_PRESS: '\u{1F64C}',
  Exercise.EXERCISE_BARBELL_ROW: '\u{1F6A3}',
  Exercise.EXERCISE_HIP_THRUST: '\u{1F351}',
  Exercise.EXERCISE_BULGARIAN_SPLIT_SQUAT: '\u{1F975}',
  Exercise.EXERCISE_ROMANIAN_DEADLIFT: '\u{1FAB5}',
  Exercise.EXERCISE_GLUTE_BRIDGE: '\u{1F309}',
  Exercise.EXERCISE_LUNGE: '\u{1F6B6}',
  Exercise.EXERCISE_LEG_CURL: '\u{1F9B5}',
};

const Map<Exercise, String> shortNames = {
  Exercise.EXERCISE_UNSPECIFIED: '?',
  Exercise.EXERCISE_SQUAT: 'Squat',
  Exercise.EXERCISE_BENCH_PRESS: 'Bench',
  Exercise.EXERCISE_DEADLIFT: 'Deadlift',
  Exercise.EXERCISE_OVERHEAD_PRESS: 'OHP',
  Exercise.EXERCISE_BARBELL_ROW: 'Row',
  Exercise.EXERCISE_HIP_THRUST: 'Hip Thr',
  Exercise.EXERCISE_BULGARIAN_SPLIT_SQUAT: 'BSS',
  Exercise.EXERCISE_ROMANIAN_DEADLIFT: 'RDL',
  Exercise.EXERCISE_GLUTE_BRIDGE: 'Bridge',
  Exercise.EXERCISE_LUNGE: 'Lunge',
  Exercise.EXERCISE_LEG_CURL: 'Curl',
};
