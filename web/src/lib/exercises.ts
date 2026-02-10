import { Exercise } from '@/gen/workout/v1/workout_pb'

export const EXERCISE_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench Press',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'Overhead Press',
  [Exercise.BARBELL_ROW]: 'Barbell Row',
  [Exercise.HIP_THRUST]: 'Hip Thrust',
  [Exercise.BULGARIAN_SPLIT_SQUAT]: 'Bulgarian Split Squat',
  [Exercise.ROMANIAN_DEADLIFT]: 'Romanian Deadlift',
  [Exercise.GLUTE_BRIDGE]: 'Glute Bridge',
  [Exercise.LUNGE]: 'Lunge',
  [Exercise.LEG_CURL]: 'Leg Curl',
}

export const EXERCISE_EMOJIS: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '❓',
  [Exercise.SQUAT]: '🦵',
  [Exercise.BENCH_PRESS]: '🏋️',
  [Exercise.DEADLIFT]: '⚡',
  [Exercise.OVERHEAD_PRESS]: '🙌',
  [Exercise.BARBELL_ROW]: '🚣',
  [Exercise.HIP_THRUST]: '🍑',
  [Exercise.BULGARIAN_SPLIT_SQUAT]: '🥵',
  [Exercise.ROMANIAN_DEADLIFT]: '🪵',
  [Exercise.GLUTE_BRIDGE]: '🌉',
  [Exercise.LUNGE]: '🚶',
  [Exercise.LEG_CURL]: '🦵',
}

export const SHORT_NAMES: Record<Exercise, string> = {
  [Exercise.UNSPECIFIED]: '?',
  [Exercise.SQUAT]: 'Squat',
  [Exercise.BENCH_PRESS]: 'Bench',
  [Exercise.DEADLIFT]: 'Deadlift',
  [Exercise.OVERHEAD_PRESS]: 'OHP',
  [Exercise.BARBELL_ROW]: 'Row',
  [Exercise.HIP_THRUST]: 'Hip Thr',
  [Exercise.BULGARIAN_SPLIT_SQUAT]: 'BSS',
  [Exercise.ROMANIAN_DEADLIFT]: 'RDL',
  [Exercise.GLUTE_BRIDGE]: 'Bridge',
  [Exercise.LUNGE]: 'Lunge',
  [Exercise.LEG_CURL]: 'Curl',
}
