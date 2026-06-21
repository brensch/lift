import '../gen/workout/v1/workout.pbenum.dart';

/// Body-part groupings used for tags + the exercise-picker filters.
/// `ass` is its own first-class group (glutes are a focus, not an afterthought).
enum BodyPart { chest, back, shoulders, arms, legs, ass, core }

const Map<BodyPart, String> bodyPartLabels = {
  BodyPart.chest: 'Chest',
  BodyPart.back: 'Back',
  BodyPart.shoulders: 'Shoulders',
  BodyPart.arms: 'Arms',
  BodyPart.legs: 'Legs',
  BodyPart.ass: 'Ass',
  BodyPart.core: 'Core',
};

/// Single source of truth for everything we know about an exercise.
/// The legacy lookup maps below are derived from this list.
class ExerciseInfo {
  final Exercise exercise;
  final String name;
  final String shortName;
  final String emoji;

  /// Muscle groups this move trains. First entry is the primary mover.
  final List<BodyPart> bodyParts;

  const ExerciseInfo(
    this.exercise,
    this.name,
    this.shortName,
    this.emoji,
    this.bodyParts,
  );
}

/// The full exercise catalogue. Order here is the order shown in the picker.
const List<ExerciseInfo> exerciseCatalog = [
  // ── The big lifts (regime-driven) ──
  ExerciseInfo(Exercise.EXERCISE_SQUAT, 'Squat', 'Squat', '🦵', [
    BodyPart.legs,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_BENCH_PRESS, 'Bench Press', 'Bench', '🏋️', [
    BodyPart.chest,
  ]),
  ExerciseInfo(Exercise.EXERCISE_DEADLIFT, 'Deadlift', 'Deads', '⚡', [
    BodyPart.back,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_OVERHEAD_PRESS, 'Overhead Press', 'OHP', '🙌', [
    BodyPart.shoulders,
  ]),
  ExerciseInfo(Exercise.EXERCISE_BARBELL_ROW, 'Barbell Row', 'Row', '🚣', [
    BodyPart.back,
  ]),
  ExerciseInfo(Exercise.EXERCISE_HIP_THRUST, 'Hip Thrust', 'Hip Thr', '🍑', [
    BodyPart.ass,
    BodyPart.legs,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_BULGARIAN_SPLIT_SQUAT,
    'Bulgarian Split Squat',
    'BSS',
    '🥵',
    [BodyPart.legs, BodyPart.ass],
  ),
  ExerciseInfo(
    Exercise.EXERCISE_ROMANIAN_DEADLIFT,
    'Romanian Deadlift',
    'RDL',
    '🪵',
    [BodyPart.ass, BodyPart.legs],
  ),
  ExerciseInfo(Exercise.EXERCISE_GLUTE_BRIDGE, 'Glute Bridge', 'Bridge', '🌉', [
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_LUNGE, 'Lunge', 'Lunge', '🚶', [
    BodyPart.legs,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_LEG_CURL, 'Leg Curl', 'Curl', '🦵', [
    BodyPart.legs,
  ]),

  // ── Chest ──
  ExerciseInfo(
    Exercise.EXERCISE_INCLINE_BENCH_PRESS,
    'Incline Bench Press',
    'Inc Bench',
    '🏋️',
    [BodyPart.chest, BodyPart.shoulders],
  ),
  ExerciseInfo(
    Exercise.EXERCISE_DUMBBELL_BENCH_PRESS,
    'Dumbbell Bench Press',
    'DB Bench',
    '🏋️',
    [BodyPart.chest],
  ),
  ExerciseInfo(
    Exercise.EXERCISE_INCLINE_DUMBBELL_PRESS,
    'Incline Dumbbell Press',
    'Inc DB',
    '🏋️',
    [BodyPart.chest, BodyPart.shoulders],
  ),
  ExerciseInfo(Exercise.EXERCISE_DUMBBELL_FLY, 'Dumbbell Fly', 'DB Fly', '🦋', [
    BodyPart.chest,
  ]),
  ExerciseInfo(Exercise.EXERCISE_CABLE_FLY, 'Cable Fly', 'Cbl Fly', '🦋', [
    BodyPart.chest,
  ]),
  ExerciseInfo(Exercise.EXERCISE_PUSH_UP, 'Push-Up', 'Push-Up', '🤸', [
    BodyPart.chest,
    BodyPart.arms,
  ]),
  ExerciseInfo(Exercise.EXERCISE_CHEST_DIP, 'Chest Dip', 'Dip', '🔻', [
    BodyPart.chest,
    BodyPart.arms,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_MACHINE_CHEST_PRESS,
    'Machine Chest Press',
    'Mch Press',
    '🦾',
    [BodyPart.chest],
  ),
  ExerciseInfo(Exercise.EXERCISE_PEC_DECK, 'Pec Deck', 'Pec Deck', '🦋', [
    BodyPart.chest,
  ]),

  // ── Back ──
  ExerciseInfo(Exercise.EXERCISE_PULL_UP, 'Pull-Up', 'Pull-Up', '🧗', [
    BodyPart.back,
    BodyPart.arms,
  ]),
  ExerciseInfo(Exercise.EXERCISE_CHIN_UP, 'Chin-Up', 'Chin-Up', '🧗', [
    BodyPart.back,
    BodyPart.arms,
  ]),
  ExerciseInfo(Exercise.EXERCISE_LAT_PULLDOWN, 'Lat Pulldown', 'Pulldown', '🔽', [
    BodyPart.back,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_SEATED_CABLE_ROW,
    'Seated Cable Row',
    'Cable Row',
    '🚣',
    [BodyPart.back],
  ),
  ExerciseInfo(Exercise.EXERCISE_DUMBBELL_ROW, 'Dumbbell Row', 'DB Row', '🚣', [
    BodyPart.back,
  ]),
  ExerciseInfo(Exercise.EXERCISE_T_BAR_ROW, 'T-Bar Row', 'T-Bar', '🚣', [
    BodyPart.back,
  ]),
  ExerciseInfo(Exercise.EXERCISE_PENDLAY_ROW, 'Pendlay Row', 'Pendlay', '🚣', [
    BodyPart.back,
  ]),
  ExerciseInfo(Exercise.EXERCISE_FACE_PULL, 'Face Pull', 'Face Pull', '😤', [
    BodyPart.shoulders,
    BodyPart.back,
  ]),
  ExerciseInfo(Exercise.EXERCISE_SHRUG, 'Shrug', 'Shrug', '🤷', [
    BodyPart.back,
    BodyPart.shoulders,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_BACK_EXTENSION,
    'Back Extension',
    'Back Ext',
    '🔙',
    [BodyPart.back, BodyPart.ass],
  ),

  // ── Shoulders ──
  ExerciseInfo(
    Exercise.EXERCISE_DUMBBELL_SHOULDER_PRESS,
    'Dumbbell Shoulder Press',
    'DB Press',
    '🙆',
    [BodyPart.shoulders],
  ),
  ExerciseInfo(Exercise.EXERCISE_ARNOLD_PRESS, 'Arnold Press', 'Arnold', '💪', [
    BodyPart.shoulders,
  ]),
  ExerciseInfo(Exercise.EXERCISE_LATERAL_RAISE, 'Lateral Raise', 'Lat Raise', '🔺', [
    BodyPart.shoulders,
  ]),
  ExerciseInfo(Exercise.EXERCISE_FRONT_RAISE, 'Front Raise', 'Frnt Raise', '⬆️', [
    BodyPart.shoulders,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_REAR_DELT_FLY,
    'Rear Delt Fly',
    'Rear Delt',
    '🦋',
    [BodyPart.shoulders, BodyPart.back],
  ),
  ExerciseInfo(Exercise.EXERCISE_UPRIGHT_ROW, 'Upright Row', 'Up Row', '⬆️', [
    BodyPart.shoulders,
    BodyPart.back,
  ]),

  // ── Arms ──
  ExerciseInfo(Exercise.EXERCISE_BARBELL_CURL, 'Barbell Curl', 'BB Curl', '💪', [
    BodyPart.arms,
  ]),
  ExerciseInfo(Exercise.EXERCISE_DUMBBELL_CURL, 'Dumbbell Curl', 'DB Curl', '💪', [
    BodyPart.arms,
  ]),
  ExerciseInfo(Exercise.EXERCISE_HAMMER_CURL, 'Hammer Curl', 'Hammer', '🔨', [
    BodyPart.arms,
  ]),
  ExerciseInfo(Exercise.EXERCISE_PREACHER_CURL, 'Preacher Curl', 'Preacher', '🙏', [
    BodyPart.arms,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_CONCENTRATION_CURL,
    'Concentration Curl',
    'Conc Curl',
    '🧠',
    [BodyPart.arms],
  ),
  ExerciseInfo(Exercise.EXERCISE_CABLE_CURL, 'Cable Curl', 'Cbl Curl', '💪', [
    BodyPart.arms,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_TRICEP_PUSHDOWN,
    'Tricep Pushdown',
    'Pushdown',
    '🔽',
    [BodyPart.arms],
  ),
  ExerciseInfo(
    Exercise.EXERCISE_OVERHEAD_TRICEP_EXTENSION,
    'Overhead Tricep Extension',
    'OH Tri',
    '🙌',
    [BodyPart.arms],
  ),
  ExerciseInfo(Exercise.EXERCISE_SKULL_CRUSHER, 'Skull Crusher', 'Skullcr', '💀', [
    BodyPart.arms,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_CLOSE_GRIP_BENCH_PRESS,
    'Close-Grip Bench Press',
    'CGBP',
    '🤏',
    [BodyPart.arms, BodyPart.chest],
  ),
  ExerciseInfo(Exercise.EXERCISE_TRICEP_DIP, 'Tricep Dip', 'Tri Dip', '🔻', [
    BodyPart.arms,
    BodyPart.chest,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_TRICEP_KICKBACK,
    'Tricep Kickback',
    'Kickback',
    '🦶',
    [BodyPart.arms],
  ),

  // ── Legs ──
  ExerciseInfo(Exercise.EXERCISE_FRONT_SQUAT, 'Front Squat', 'Frnt Sq', '🦵', [
    BodyPart.legs,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_LEG_PRESS, 'Leg Press', 'Leg Press', '🦿', [
    BodyPart.legs,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_LEG_EXTENSION, 'Leg Extension', 'Leg Ext', '🦵', [
    BodyPart.legs,
  ]),
  ExerciseInfo(Exercise.EXERCISE_HACK_SQUAT, 'Hack Squat', 'Hack Sq', '🦵', [
    BodyPart.legs,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_GOBLET_SQUAT, 'Goblet Squat', 'Goblet', '🏆', [
    BodyPart.legs,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_WALKING_LUNGE, 'Walking Lunge', 'Wlk Lunge', '🚶', [
    BodyPart.legs,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_STEP_UP, 'Step-Up', 'Step-Up', '🪜', [
    BodyPart.legs,
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_CALF_RAISE, 'Calf Raise', 'Calf', '🐄', [
    BodyPart.legs,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_SEATED_CALF_RAISE,
    'Seated Calf Raise',
    'St Calf',
    '🐄',
    [BodyPart.legs],
  ),
  ExerciseInfo(Exercise.EXERCISE_NORDIC_CURL, 'Nordic Curl', 'Nordic', '🦵', [
    BodyPart.legs,
  ]),
  ExerciseInfo(Exercise.EXERCISE_GOOD_MORNING, 'Good Morning', 'Good AM', '🌅', [
    BodyPart.ass,
    BodyPart.back,
  ]),

  // ── Ass ──
  ExerciseInfo(Exercise.EXERCISE_GLUTE_KICKBACK, 'Glute Kickback', 'Glt Kick', '🍑', [
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_SUMO_DEADLIFT, 'Sumo Deadlift', 'Sumo DL', '🤼', [
    BodyPart.ass,
    BodyPart.back,
  ]),
  ExerciseInfo(Exercise.EXERCISE_SUMO_SQUAT, 'Sumo Squat', 'Sumo Sq', '🤼', [
    BodyPart.ass,
    BodyPart.legs,
  ]),
  ExerciseInfo(Exercise.EXERCISE_CURTSY_LUNGE, 'Curtsy Lunge', 'Curtsy', '💃', [
    BodyPart.ass,
    BodyPart.legs,
  ]),
  ExerciseInfo(Exercise.EXERCISE_FROG_PUMP, 'Frog Pump', 'Frog', '🐸', [
    BodyPart.ass,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_SINGLE_LEG_HIP_THRUST,
    'Single-Leg Hip Thrust',
    'SL Thrust',
    '🍑',
    [BodyPart.ass, BodyPart.legs],
  ),
  ExerciseInfo(
    Exercise.EXERCISE_CABLE_PULL_THROUGH,
    'Cable Pull-Through',
    'Pull-Thru',
    '🍑',
    [BodyPart.ass, BodyPart.back],
  ),
  ExerciseInfo(Exercise.EXERCISE_HIP_ABDUCTION, 'Hip Abduction', 'Abduction', '↔️', [
    BodyPart.ass,
  ]),
  ExerciseInfo(Exercise.EXERCISE_HIP_ADDUCTION, 'Hip Adduction', 'Adduction', '🦵', [
    BodyPart.legs,
  ]),

  // ── Core ──
  ExerciseInfo(Exercise.EXERCISE_PLANK, 'Plank', 'Plank', '🧘', [BodyPart.core]),
  ExerciseInfo(
    Exercise.EXERCISE_HANGING_LEG_RAISE,
    'Hanging Leg Raise',
    'Leg Raise',
    '🧗',
    [BodyPart.core],
  ),
  ExerciseInfo(Exercise.EXERCISE_CABLE_CRUNCH, 'Cable Crunch', 'Cbl Crunch', '🌀', [
    BodyPart.core,
  ]),
  ExerciseInfo(Exercise.EXERCISE_RUSSIAN_TWIST, 'Russian Twist', 'Twist', '🌪️', [
    BodyPart.core,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_AB_WHEEL_ROLLOUT,
    'Ab Wheel Rollout',
    'Ab Wheel',
    '🛞',
    [BodyPart.core],
  ),
  ExerciseInfo(Exercise.EXERCISE_SIT_UP, 'Sit-Up', 'Sit-Up', '🔄', [
    BodyPart.core,
  ]),
  ExerciseInfo(Exercise.EXERCISE_CRUNCH, 'Crunch', 'Crunch', '🥨', [
    BodyPart.core,
  ]),
  ExerciseInfo(
    Exercise.EXERCISE_MOUNTAIN_CLIMBER,
    'Mountain Climber',
    'Mtn Climb',
    '🏔️',
    [BodyPart.core, BodyPart.legs],
  ),
];

/// Catalogue indexed by exercise for O(1) lookups.
final Map<Exercise, ExerciseInfo> exerciseInfo = {
  for (final info in exerciseCatalog) info.exercise: info,
};

// ── Legacy lookup maps, derived from the catalogue ──

final Map<Exercise, String> exerciseNames = {
  Exercise.EXERCISE_UNSPECIFIED: '?',
  for (final info in exerciseCatalog) info.exercise: info.name,
};

final Map<Exercise, String> exerciseEmojis = {
  Exercise.EXERCISE_UNSPECIFIED: '?',
  for (final info in exerciseCatalog) info.exercise: info.emoji,
};

final Map<Exercise, String> shortNames = {
  Exercise.EXERCISE_UNSPECIFIED: '?',
  for (final info in exerciseCatalog) info.exercise: info.shortName,
};

final Map<Exercise, List<BodyPart>> exerciseBodyParts = {
  for (final info in exerciseCatalog) info.exercise: info.bodyParts,
};
