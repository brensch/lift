// This is a generated file - do not edit.
//
// Generated from workout/v1/workout.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class MuscleGroup extends $pb.ProtobufEnum {
  static const MuscleGroup MUSCLE_GROUP_UNSPECIFIED =
      MuscleGroup._(0, _omitEnumNames ? '' : 'MUSCLE_GROUP_UNSPECIFIED');
  static const MuscleGroup MUSCLE_GROUP_QUADS =
      MuscleGroup._(1, _omitEnumNames ? '' : 'MUSCLE_GROUP_QUADS');
  static const MuscleGroup MUSCLE_GROUP_HAMSTRINGS =
      MuscleGroup._(2, _omitEnumNames ? '' : 'MUSCLE_GROUP_HAMSTRINGS');
  static const MuscleGroup MUSCLE_GROUP_GLUTES =
      MuscleGroup._(3, _omitEnumNames ? '' : 'MUSCLE_GROUP_GLUTES');
  static const MuscleGroup MUSCLE_GROUP_CHEST =
      MuscleGroup._(4, _omitEnumNames ? '' : 'MUSCLE_GROUP_CHEST');
  static const MuscleGroup MUSCLE_GROUP_BACK =
      MuscleGroup._(5, _omitEnumNames ? '' : 'MUSCLE_GROUP_BACK');
  static const MuscleGroup MUSCLE_GROUP_SHOULDERS =
      MuscleGroup._(6, _omitEnumNames ? '' : 'MUSCLE_GROUP_SHOULDERS');
  static const MuscleGroup MUSCLE_GROUP_BICEPS =
      MuscleGroup._(7, _omitEnumNames ? '' : 'MUSCLE_GROUP_BICEPS');
  static const MuscleGroup MUSCLE_GROUP_TRICEPS =
      MuscleGroup._(8, _omitEnumNames ? '' : 'MUSCLE_GROUP_TRICEPS');

  static const $core.List<MuscleGroup> values = <MuscleGroup>[
    MUSCLE_GROUP_UNSPECIFIED,
    MUSCLE_GROUP_QUADS,
    MUSCLE_GROUP_HAMSTRINGS,
    MUSCLE_GROUP_GLUTES,
    MUSCLE_GROUP_CHEST,
    MUSCLE_GROUP_BACK,
    MUSCLE_GROUP_SHOULDERS,
    MUSCLE_GROUP_BICEPS,
    MUSCLE_GROUP_TRICEPS,
  ];

  static final $core.List<MuscleGroup?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static MuscleGroup? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MuscleGroup._(super.value, super.name);
}

class ExerciseCategory extends $pb.ProtobufEnum {
  static const ExerciseCategory EXERCISE_CATEGORY_UNSPECIFIED =
      ExerciseCategory._(
          0, _omitEnumNames ? '' : 'EXERCISE_CATEGORY_UNSPECIFIED');
  static const ExerciseCategory EXERCISE_CATEGORY_COMPOUND =
      ExerciseCategory._(1, _omitEnumNames ? '' : 'EXERCISE_CATEGORY_COMPOUND');
  static const ExerciseCategory EXERCISE_CATEGORY_AUXILIARY =
      ExerciseCategory._(
          2, _omitEnumNames ? '' : 'EXERCISE_CATEGORY_AUXILIARY');

  static const $core.List<ExerciseCategory> values = <ExerciseCategory>[
    EXERCISE_CATEGORY_UNSPECIFIED,
    EXERCISE_CATEGORY_COMPOUND,
    EXERCISE_CATEGORY_AUXILIARY,
  ];

  static final $core.List<ExerciseCategory?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ExerciseCategory? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ExerciseCategory._(super.value, super.name);
}

class Exercise extends $pb.ProtobufEnum {
  static const Exercise EXERCISE_UNSPECIFIED =
      Exercise._(0, _omitEnumNames ? '' : 'EXERCISE_UNSPECIFIED');
  static const Exercise EXERCISE_SQUAT =
      Exercise._(1, _omitEnumNames ? '' : 'EXERCISE_SQUAT');
  static const Exercise EXERCISE_BENCH_PRESS =
      Exercise._(2, _omitEnumNames ? '' : 'EXERCISE_BENCH_PRESS');
  static const Exercise EXERCISE_DEADLIFT =
      Exercise._(3, _omitEnumNames ? '' : 'EXERCISE_DEADLIFT');
  static const Exercise EXERCISE_OVERHEAD_PRESS =
      Exercise._(4, _omitEnumNames ? '' : 'EXERCISE_OVERHEAD_PRESS');
  static const Exercise EXERCISE_BARBELL_ROW =
      Exercise._(5, _omitEnumNames ? '' : 'EXERCISE_BARBELL_ROW');
  static const Exercise EXERCISE_HIP_THRUST =
      Exercise._(6, _omitEnumNames ? '' : 'EXERCISE_HIP_THRUST');
  static const Exercise EXERCISE_BULGARIAN_SPLIT_SQUAT =
      Exercise._(7, _omitEnumNames ? '' : 'EXERCISE_BULGARIAN_SPLIT_SQUAT');
  static const Exercise EXERCISE_ROMANIAN_DEADLIFT =
      Exercise._(8, _omitEnumNames ? '' : 'EXERCISE_ROMANIAN_DEADLIFT');
  static const Exercise EXERCISE_GLUTE_BRIDGE =
      Exercise._(9, _omitEnumNames ? '' : 'EXERCISE_GLUTE_BRIDGE');
  static const Exercise EXERCISE_LUNGE =
      Exercise._(10, _omitEnumNames ? '' : 'EXERCISE_LUNGE');
  static const Exercise EXERCISE_LEG_CURL =
      Exercise._(11, _omitEnumNames ? '' : 'EXERCISE_LEG_CURL');

  /// ── Chest ──
  static const Exercise EXERCISE_INCLINE_BENCH_PRESS =
      Exercise._(12, _omitEnumNames ? '' : 'EXERCISE_INCLINE_BENCH_PRESS');
  static const Exercise EXERCISE_DUMBBELL_BENCH_PRESS =
      Exercise._(13, _omitEnumNames ? '' : 'EXERCISE_DUMBBELL_BENCH_PRESS');
  static const Exercise EXERCISE_INCLINE_DUMBBELL_PRESS =
      Exercise._(14, _omitEnumNames ? '' : 'EXERCISE_INCLINE_DUMBBELL_PRESS');
  static const Exercise EXERCISE_DUMBBELL_FLY =
      Exercise._(15, _omitEnumNames ? '' : 'EXERCISE_DUMBBELL_FLY');
  static const Exercise EXERCISE_CABLE_FLY =
      Exercise._(16, _omitEnumNames ? '' : 'EXERCISE_CABLE_FLY');
  static const Exercise EXERCISE_PUSH_UP =
      Exercise._(17, _omitEnumNames ? '' : 'EXERCISE_PUSH_UP');
  static const Exercise EXERCISE_CHEST_DIP =
      Exercise._(18, _omitEnumNames ? '' : 'EXERCISE_CHEST_DIP');
  static const Exercise EXERCISE_MACHINE_CHEST_PRESS =
      Exercise._(19, _omitEnumNames ? '' : 'EXERCISE_MACHINE_CHEST_PRESS');
  static const Exercise EXERCISE_PEC_DECK =
      Exercise._(20, _omitEnumNames ? '' : 'EXERCISE_PEC_DECK');

  /// ── Back ──
  static const Exercise EXERCISE_PULL_UP =
      Exercise._(21, _omitEnumNames ? '' : 'EXERCISE_PULL_UP');
  static const Exercise EXERCISE_CHIN_UP =
      Exercise._(22, _omitEnumNames ? '' : 'EXERCISE_CHIN_UP');
  static const Exercise EXERCISE_LAT_PULLDOWN =
      Exercise._(23, _omitEnumNames ? '' : 'EXERCISE_LAT_PULLDOWN');
  static const Exercise EXERCISE_SEATED_CABLE_ROW =
      Exercise._(24, _omitEnumNames ? '' : 'EXERCISE_SEATED_CABLE_ROW');
  static const Exercise EXERCISE_DUMBBELL_ROW =
      Exercise._(25, _omitEnumNames ? '' : 'EXERCISE_DUMBBELL_ROW');
  static const Exercise EXERCISE_T_BAR_ROW =
      Exercise._(26, _omitEnumNames ? '' : 'EXERCISE_T_BAR_ROW');
  static const Exercise EXERCISE_PENDLAY_ROW =
      Exercise._(27, _omitEnumNames ? '' : 'EXERCISE_PENDLAY_ROW');
  static const Exercise EXERCISE_FACE_PULL =
      Exercise._(28, _omitEnumNames ? '' : 'EXERCISE_FACE_PULL');
  static const Exercise EXERCISE_SHRUG =
      Exercise._(29, _omitEnumNames ? '' : 'EXERCISE_SHRUG');
  static const Exercise EXERCISE_BACK_EXTENSION =
      Exercise._(30, _omitEnumNames ? '' : 'EXERCISE_BACK_EXTENSION');

  /// ── Shoulders ──
  static const Exercise EXERCISE_DUMBBELL_SHOULDER_PRESS =
      Exercise._(31, _omitEnumNames ? '' : 'EXERCISE_DUMBBELL_SHOULDER_PRESS');
  static const Exercise EXERCISE_ARNOLD_PRESS =
      Exercise._(32, _omitEnumNames ? '' : 'EXERCISE_ARNOLD_PRESS');
  static const Exercise EXERCISE_LATERAL_RAISE =
      Exercise._(33, _omitEnumNames ? '' : 'EXERCISE_LATERAL_RAISE');
  static const Exercise EXERCISE_FRONT_RAISE =
      Exercise._(34, _omitEnumNames ? '' : 'EXERCISE_FRONT_RAISE');
  static const Exercise EXERCISE_REAR_DELT_FLY =
      Exercise._(35, _omitEnumNames ? '' : 'EXERCISE_REAR_DELT_FLY');
  static const Exercise EXERCISE_UPRIGHT_ROW =
      Exercise._(36, _omitEnumNames ? '' : 'EXERCISE_UPRIGHT_ROW');

  /// ── Arms ──
  static const Exercise EXERCISE_BARBELL_CURL =
      Exercise._(37, _omitEnumNames ? '' : 'EXERCISE_BARBELL_CURL');
  static const Exercise EXERCISE_DUMBBELL_CURL =
      Exercise._(38, _omitEnumNames ? '' : 'EXERCISE_DUMBBELL_CURL');
  static const Exercise EXERCISE_HAMMER_CURL =
      Exercise._(39, _omitEnumNames ? '' : 'EXERCISE_HAMMER_CURL');
  static const Exercise EXERCISE_PREACHER_CURL =
      Exercise._(40, _omitEnumNames ? '' : 'EXERCISE_PREACHER_CURL');
  static const Exercise EXERCISE_CONCENTRATION_CURL =
      Exercise._(41, _omitEnumNames ? '' : 'EXERCISE_CONCENTRATION_CURL');
  static const Exercise EXERCISE_CABLE_CURL =
      Exercise._(42, _omitEnumNames ? '' : 'EXERCISE_CABLE_CURL');
  static const Exercise EXERCISE_TRICEP_PUSHDOWN =
      Exercise._(43, _omitEnumNames ? '' : 'EXERCISE_TRICEP_PUSHDOWN');
  static const Exercise EXERCISE_OVERHEAD_TRICEP_EXTENSION = Exercise._(
      44, _omitEnumNames ? '' : 'EXERCISE_OVERHEAD_TRICEP_EXTENSION');
  static const Exercise EXERCISE_SKULL_CRUSHER =
      Exercise._(45, _omitEnumNames ? '' : 'EXERCISE_SKULL_CRUSHER');
  static const Exercise EXERCISE_CLOSE_GRIP_BENCH_PRESS =
      Exercise._(46, _omitEnumNames ? '' : 'EXERCISE_CLOSE_GRIP_BENCH_PRESS');
  static const Exercise EXERCISE_TRICEP_DIP =
      Exercise._(47, _omitEnumNames ? '' : 'EXERCISE_TRICEP_DIP');
  static const Exercise EXERCISE_TRICEP_KICKBACK =
      Exercise._(48, _omitEnumNames ? '' : 'EXERCISE_TRICEP_KICKBACK');

  /// ── Legs ──
  static const Exercise EXERCISE_FRONT_SQUAT =
      Exercise._(49, _omitEnumNames ? '' : 'EXERCISE_FRONT_SQUAT');
  static const Exercise EXERCISE_LEG_PRESS =
      Exercise._(50, _omitEnumNames ? '' : 'EXERCISE_LEG_PRESS');
  static const Exercise EXERCISE_LEG_EXTENSION =
      Exercise._(51, _omitEnumNames ? '' : 'EXERCISE_LEG_EXTENSION');
  static const Exercise EXERCISE_HACK_SQUAT =
      Exercise._(52, _omitEnumNames ? '' : 'EXERCISE_HACK_SQUAT');
  static const Exercise EXERCISE_GOBLET_SQUAT =
      Exercise._(53, _omitEnumNames ? '' : 'EXERCISE_GOBLET_SQUAT');
  static const Exercise EXERCISE_WALKING_LUNGE =
      Exercise._(54, _omitEnumNames ? '' : 'EXERCISE_WALKING_LUNGE');
  static const Exercise EXERCISE_STEP_UP =
      Exercise._(55, _omitEnumNames ? '' : 'EXERCISE_STEP_UP');
  static const Exercise EXERCISE_CALF_RAISE =
      Exercise._(56, _omitEnumNames ? '' : 'EXERCISE_CALF_RAISE');
  static const Exercise EXERCISE_SEATED_CALF_RAISE =
      Exercise._(57, _omitEnumNames ? '' : 'EXERCISE_SEATED_CALF_RAISE');
  static const Exercise EXERCISE_NORDIC_CURL =
      Exercise._(58, _omitEnumNames ? '' : 'EXERCISE_NORDIC_CURL');
  static const Exercise EXERCISE_GOOD_MORNING =
      Exercise._(59, _omitEnumNames ? '' : 'EXERCISE_GOOD_MORNING');

  /// ── Ass ──
  static const Exercise EXERCISE_GLUTE_KICKBACK =
      Exercise._(60, _omitEnumNames ? '' : 'EXERCISE_GLUTE_KICKBACK');
  static const Exercise EXERCISE_SUMO_DEADLIFT =
      Exercise._(61, _omitEnumNames ? '' : 'EXERCISE_SUMO_DEADLIFT');
  static const Exercise EXERCISE_SUMO_SQUAT =
      Exercise._(62, _omitEnumNames ? '' : 'EXERCISE_SUMO_SQUAT');
  static const Exercise EXERCISE_CURTSY_LUNGE =
      Exercise._(63, _omitEnumNames ? '' : 'EXERCISE_CURTSY_LUNGE');
  static const Exercise EXERCISE_FROG_PUMP =
      Exercise._(64, _omitEnumNames ? '' : 'EXERCISE_FROG_PUMP');
  static const Exercise EXERCISE_SINGLE_LEG_HIP_THRUST =
      Exercise._(65, _omitEnumNames ? '' : 'EXERCISE_SINGLE_LEG_HIP_THRUST');
  static const Exercise EXERCISE_CABLE_PULL_THROUGH =
      Exercise._(66, _omitEnumNames ? '' : 'EXERCISE_CABLE_PULL_THROUGH');
  static const Exercise EXERCISE_HIP_ABDUCTION =
      Exercise._(67, _omitEnumNames ? '' : 'EXERCISE_HIP_ABDUCTION');

  /// ── Core ──
  static const Exercise EXERCISE_PLANK =
      Exercise._(68, _omitEnumNames ? '' : 'EXERCISE_PLANK');
  static const Exercise EXERCISE_HANGING_LEG_RAISE =
      Exercise._(69, _omitEnumNames ? '' : 'EXERCISE_HANGING_LEG_RAISE');
  static const Exercise EXERCISE_CABLE_CRUNCH =
      Exercise._(70, _omitEnumNames ? '' : 'EXERCISE_CABLE_CRUNCH');
  static const Exercise EXERCISE_RUSSIAN_TWIST =
      Exercise._(71, _omitEnumNames ? '' : 'EXERCISE_RUSSIAN_TWIST');
  static const Exercise EXERCISE_AB_WHEEL_ROLLOUT =
      Exercise._(72, _omitEnumNames ? '' : 'EXERCISE_AB_WHEEL_ROLLOUT');
  static const Exercise EXERCISE_SIT_UP =
      Exercise._(73, _omitEnumNames ? '' : 'EXERCISE_SIT_UP');
  static const Exercise EXERCISE_CRUNCH =
      Exercise._(74, _omitEnumNames ? '' : 'EXERCISE_CRUNCH');
  static const Exercise EXERCISE_MOUNTAIN_CLIMBER =
      Exercise._(75, _omitEnumNames ? '' : 'EXERCISE_MOUNTAIN_CLIMBER');
  static const Exercise EXERCISE_HIP_ADDUCTION =
      Exercise._(76, _omitEnumNames ? '' : 'EXERCISE_HIP_ADDUCTION');

  static const $core.List<Exercise> values = <Exercise>[
    EXERCISE_UNSPECIFIED,
    EXERCISE_SQUAT,
    EXERCISE_BENCH_PRESS,
    EXERCISE_DEADLIFT,
    EXERCISE_OVERHEAD_PRESS,
    EXERCISE_BARBELL_ROW,
    EXERCISE_HIP_THRUST,
    EXERCISE_BULGARIAN_SPLIT_SQUAT,
    EXERCISE_ROMANIAN_DEADLIFT,
    EXERCISE_GLUTE_BRIDGE,
    EXERCISE_LUNGE,
    EXERCISE_LEG_CURL,
    EXERCISE_INCLINE_BENCH_PRESS,
    EXERCISE_DUMBBELL_BENCH_PRESS,
    EXERCISE_INCLINE_DUMBBELL_PRESS,
    EXERCISE_DUMBBELL_FLY,
    EXERCISE_CABLE_FLY,
    EXERCISE_PUSH_UP,
    EXERCISE_CHEST_DIP,
    EXERCISE_MACHINE_CHEST_PRESS,
    EXERCISE_PEC_DECK,
    EXERCISE_PULL_UP,
    EXERCISE_CHIN_UP,
    EXERCISE_LAT_PULLDOWN,
    EXERCISE_SEATED_CABLE_ROW,
    EXERCISE_DUMBBELL_ROW,
    EXERCISE_T_BAR_ROW,
    EXERCISE_PENDLAY_ROW,
    EXERCISE_FACE_PULL,
    EXERCISE_SHRUG,
    EXERCISE_BACK_EXTENSION,
    EXERCISE_DUMBBELL_SHOULDER_PRESS,
    EXERCISE_ARNOLD_PRESS,
    EXERCISE_LATERAL_RAISE,
    EXERCISE_FRONT_RAISE,
    EXERCISE_REAR_DELT_FLY,
    EXERCISE_UPRIGHT_ROW,
    EXERCISE_BARBELL_CURL,
    EXERCISE_DUMBBELL_CURL,
    EXERCISE_HAMMER_CURL,
    EXERCISE_PREACHER_CURL,
    EXERCISE_CONCENTRATION_CURL,
    EXERCISE_CABLE_CURL,
    EXERCISE_TRICEP_PUSHDOWN,
    EXERCISE_OVERHEAD_TRICEP_EXTENSION,
    EXERCISE_SKULL_CRUSHER,
    EXERCISE_CLOSE_GRIP_BENCH_PRESS,
    EXERCISE_TRICEP_DIP,
    EXERCISE_TRICEP_KICKBACK,
    EXERCISE_FRONT_SQUAT,
    EXERCISE_LEG_PRESS,
    EXERCISE_LEG_EXTENSION,
    EXERCISE_HACK_SQUAT,
    EXERCISE_GOBLET_SQUAT,
    EXERCISE_WALKING_LUNGE,
    EXERCISE_STEP_UP,
    EXERCISE_CALF_RAISE,
    EXERCISE_SEATED_CALF_RAISE,
    EXERCISE_NORDIC_CURL,
    EXERCISE_GOOD_MORNING,
    EXERCISE_GLUTE_KICKBACK,
    EXERCISE_SUMO_DEADLIFT,
    EXERCISE_SUMO_SQUAT,
    EXERCISE_CURTSY_LUNGE,
    EXERCISE_FROG_PUMP,
    EXERCISE_SINGLE_LEG_HIP_THRUST,
    EXERCISE_CABLE_PULL_THROUGH,
    EXERCISE_HIP_ABDUCTION,
    EXERCISE_PLANK,
    EXERCISE_HANGING_LEG_RAISE,
    EXERCISE_CABLE_CRUNCH,
    EXERCISE_RUSSIAN_TWIST,
    EXERCISE_AB_WHEEL_ROLLOUT,
    EXERCISE_SIT_UP,
    EXERCISE_CRUNCH,
    EXERCISE_MOUNTAIN_CLIMBER,
    EXERCISE_HIP_ADDUCTION,
  ];

  static final $core.List<Exercise?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 76);
  static Exercise? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Exercise._(super.value, super.name);
}

class UserMessageKind extends $pb.ProtobufEnum {
  static const UserMessageKind USER_MESSAGE_KIND_UNSPECIFIED =
      UserMessageKind._(
          0, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_UNSPECIFIED');
  static const UserMessageKind USER_MESSAGE_KIND_COACHING_NOTE =
      UserMessageKind._(
          1, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_COACHING_NOTE');
  static const UserMessageKind USER_MESSAGE_KIND_GROUP_RATIONALE =
      UserMessageKind._(
          2, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_GROUP_RATIONALE');
  static const UserMessageKind USER_MESSAGE_KIND_LOAD_INCREASE =
      UserMessageKind._(
          3, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_LOAD_INCREASE');
  static const UserMessageKind USER_MESSAGE_KIND_LOAD_HOLD =
      UserMessageKind._(4, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_LOAD_HOLD');
  static const UserMessageKind USER_MESSAGE_KIND_STALL_DELOAD =
      UserMessageKind._(
          5, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_STALL_DELOAD');
  static const UserMessageKind USER_MESSAGE_KIND_TEMPORAL_DELOAD =
      UserMessageKind._(
          6, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_TEMPORAL_DELOAD');
  static const UserMessageKind USER_MESSAGE_KIND_SESSION_UPDATE =
      UserMessageKind._(
          7, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_SESSION_UPDATE');
  static const UserMessageKind USER_MESSAGE_KIND_CYCLE_ADVANCE =
      UserMessageKind._(
          8, _omitEnumNames ? '' : 'USER_MESSAGE_KIND_CYCLE_ADVANCE');

  static const $core.List<UserMessageKind> values = <UserMessageKind>[
    USER_MESSAGE_KIND_UNSPECIFIED,
    USER_MESSAGE_KIND_COACHING_NOTE,
    USER_MESSAGE_KIND_GROUP_RATIONALE,
    USER_MESSAGE_KIND_LOAD_INCREASE,
    USER_MESSAGE_KIND_LOAD_HOLD,
    USER_MESSAGE_KIND_STALL_DELOAD,
    USER_MESSAGE_KIND_TEMPORAL_DELOAD,
    USER_MESSAGE_KIND_SESSION_UPDATE,
    USER_MESSAGE_KIND_CYCLE_ADVANCE,
  ];

  static final $core.List<UserMessageKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static UserMessageKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const UserMessageKind._(super.value, super.name);
}

class UserMessageSurface extends $pb.ProtobufEnum {
  static const UserMessageSurface USER_MESSAGE_SURFACE_UNSPECIFIED =
      UserMessageSurface._(
          0, _omitEnumNames ? '' : 'USER_MESSAGE_SURFACE_UNSPECIFIED');
  static const UserMessageSurface USER_MESSAGE_SURFACE_SCHEDULE =
      UserMessageSurface._(
          1, _omitEnumNames ? '' : 'USER_MESSAGE_SURFACE_SCHEDULE');
  static const UserMessageSurface USER_MESSAGE_SURFACE_WORKOUT_BRIEFING =
      UserMessageSurface._(
          2, _omitEnumNames ? '' : 'USER_MESSAGE_SURFACE_WORKOUT_BRIEFING');
  static const UserMessageSurface USER_MESSAGE_SURFACE_WORKOUT_FEED =
      UserMessageSurface._(
          3, _omitEnumNames ? '' : 'USER_MESSAGE_SURFACE_WORKOUT_FEED');

  static const $core.List<UserMessageSurface> values = <UserMessageSurface>[
    USER_MESSAGE_SURFACE_UNSPECIFIED,
    USER_MESSAGE_SURFACE_SCHEDULE,
    USER_MESSAGE_SURFACE_WORKOUT_BRIEFING,
    USER_MESSAGE_SURFACE_WORKOUT_FEED,
  ];

  static final $core.List<UserMessageSurface?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static UserMessageSurface? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const UserMessageSurface._(super.value, super.name);
}

class ProgressionChangeKind extends $pb.ProtobufEnum {
  static const ProgressionChangeKind PROGRESSION_CHANGE_KIND_UNSPECIFIED =
      ProgressionChangeKind._(
          0, _omitEnumNames ? '' : 'PROGRESSION_CHANGE_KIND_UNSPECIFIED');
  static const ProgressionChangeKind PROGRESSION_CHANGE_KIND_INCREASE =
      ProgressionChangeKind._(
          1, _omitEnumNames ? '' : 'PROGRESSION_CHANGE_KIND_INCREASE');
  static const ProgressionChangeKind PROGRESSION_CHANGE_KIND_HOLD =
      ProgressionChangeKind._(
          2, _omitEnumNames ? '' : 'PROGRESSION_CHANGE_KIND_HOLD');
  static const ProgressionChangeKind PROGRESSION_CHANGE_KIND_DELOAD =
      ProgressionChangeKind._(
          3, _omitEnumNames ? '' : 'PROGRESSION_CHANGE_KIND_DELOAD');
  static const ProgressionChangeKind PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE =
      ProgressionChangeKind._(
          4, _omitEnumNames ? '' : 'PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE');

  static const $core.List<ProgressionChangeKind> values =
      <ProgressionChangeKind>[
    PROGRESSION_CHANGE_KIND_UNSPECIFIED,
    PROGRESSION_CHANGE_KIND_INCREASE,
    PROGRESSION_CHANGE_KIND_HOLD,
    PROGRESSION_CHANGE_KIND_DELOAD,
    PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE,
  ];

  static final $core.List<ProgressionChangeKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ProgressionChangeKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProgressionChangeKind._(super.value, super.name);
}

class ProgressionMetricKind extends $pb.ProtobufEnum {
  static const ProgressionMetricKind PROGRESSION_METRIC_KIND_UNSPECIFIED =
      ProgressionMetricKind._(
          0, _omitEnumNames ? '' : 'PROGRESSION_METRIC_KIND_UNSPECIFIED');
  static const ProgressionMetricKind PROGRESSION_METRIC_KIND_WORKING_WEIGHT =
      ProgressionMetricKind._(
          1, _omitEnumNames ? '' : 'PROGRESSION_METRIC_KIND_WORKING_WEIGHT');
  static const ProgressionMetricKind PROGRESSION_METRIC_KIND_TRAINING_MAX =
      ProgressionMetricKind._(
          2, _omitEnumNames ? '' : 'PROGRESSION_METRIC_KIND_TRAINING_MAX');

  static const $core.List<ProgressionMetricKind> values =
      <ProgressionMetricKind>[
    PROGRESSION_METRIC_KIND_UNSPECIFIED,
    PROGRESSION_METRIC_KIND_WORKING_WEIGHT,
    PROGRESSION_METRIC_KIND_TRAINING_MAX,
  ];

  static final $core.List<ProgressionMetricKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ProgressionMetricKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProgressionMetricKind._(super.value, super.name);
}

class ProgressionReasonKind extends $pb.ProtobufEnum {
  static const ProgressionReasonKind PROGRESSION_REASON_KIND_UNSPECIFIED =
      ProgressionReasonKind._(
          0, _omitEnumNames ? '' : 'PROGRESSION_REASON_KIND_UNSPECIFIED');
  static const ProgressionReasonKind
      PROGRESSION_REASON_KIND_COMPLETED_ALL_WORKING_SETS =
      ProgressionReasonKind._(
          1,
          _omitEnumNames
              ? ''
              : 'PROGRESSION_REASON_KIND_COMPLETED_ALL_WORKING_SETS');
  static const ProgressionReasonKind
      PROGRESSION_REASON_KIND_MISSED_TARGET_REPS = ProgressionReasonKind._(2,
          _omitEnumNames ? '' : 'PROGRESSION_REASON_KIND_MISSED_TARGET_REPS');
  static const ProgressionReasonKind PROGRESSION_REASON_KIND_REPEATED_MISSES =
      ProgressionReasonKind._(
          3, _omitEnumNames ? '' : 'PROGRESSION_REASON_KIND_REPEATED_MISSES');
  static const ProgressionReasonKind PROGRESSION_REASON_KIND_STAGE_ADVANCE =
      ProgressionReasonKind._(
          4, _omitEnumNames ? '' : 'PROGRESSION_REASON_KIND_STAGE_ADVANCE');
  static const ProgressionReasonKind PROGRESSION_REASON_KIND_CYCLE_COMPLETED =
      ProgressionReasonKind._(
          5, _omitEnumNames ? '' : 'PROGRESSION_REASON_KIND_CYCLE_COMPLETED');
  static const ProgressionReasonKind
      PROGRESSION_REASON_KIND_CLEARED_PROGRESSION_CHECK =
      ProgressionReasonKind._(
          6,
          _omitEnumNames
              ? ''
              : 'PROGRESSION_REASON_KIND_CLEARED_PROGRESSION_CHECK');

  static const $core.List<ProgressionReasonKind> values =
      <ProgressionReasonKind>[
    PROGRESSION_REASON_KIND_UNSPECIFIED,
    PROGRESSION_REASON_KIND_COMPLETED_ALL_WORKING_SETS,
    PROGRESSION_REASON_KIND_MISSED_TARGET_REPS,
    PROGRESSION_REASON_KIND_REPEATED_MISSES,
    PROGRESSION_REASON_KIND_STAGE_ADVANCE,
    PROGRESSION_REASON_KIND_CYCLE_COMPLETED,
    PROGRESSION_REASON_KIND_CLEARED_PROGRESSION_CHECK,
  ];

  static final $core.List<ProgressionReasonKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static ProgressionReasonKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProgressionReasonKind._(super.value, super.name);
}

class WorkoutState extends $pb.ProtobufEnum {
  static const WorkoutState WORKOUT_STATE_UNSPECIFIED =
      WorkoutState._(0, _omitEnumNames ? '' : 'WORKOUT_STATE_UNSPECIFIED');
  static const WorkoutState WORKOUT_STATE_ALL_DONE =
      WorkoutState._(1, _omitEnumNames ? '' : 'WORKOUT_STATE_ALL_DONE');
  static const WorkoutState WORKOUT_STATE_LIFTING =
      WorkoutState._(2, _omitEnumNames ? '' : 'WORKOUT_STATE_LIFTING');
  static const WorkoutState WORKOUT_STATE_RESTING =
      WorkoutState._(3, _omitEnumNames ? '' : 'WORKOUT_STATE_RESTING');
  static const WorkoutState WORKOUT_STATE_READY =
      WorkoutState._(5, _omitEnumNames ? '' : 'WORKOUT_STATE_READY');

  static const $core.List<WorkoutState> values = <WorkoutState>[
    WORKOUT_STATE_UNSPECIFIED,
    WORKOUT_STATE_ALL_DONE,
    WORKOUT_STATE_LIFTING,
    WORKOUT_STATE_RESTING,
    WORKOUT_STATE_READY,
  ];

  static final $core.List<WorkoutState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static WorkoutState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WorkoutState._(super.value, super.name);
}

class ProgressionRule extends $pb.ProtobufEnum {
  static const ProgressionRule PROGRESSION_RULE_UNSPECIFIED = ProgressionRule._(
      0, _omitEnumNames ? '' : 'PROGRESSION_RULE_UNSPECIFIED');
  static const ProgressionRule PROGRESSION_RULE_NONE =
      ProgressionRule._(1, _omitEnumNames ? '' : 'PROGRESSION_RULE_NONE');
  static const ProgressionRule PROGRESSION_RULE_ALL_SETS_MATCH_TARGET =
      ProgressionRule._(
          2, _omitEnumNames ? '' : 'PROGRESSION_RULE_ALL_SETS_MATCH_TARGET');
  static const ProgressionRule PROGRESSION_RULE_TOP_SET_AMRAP =
      ProgressionRule._(
          3, _omitEnumNames ? '' : 'PROGRESSION_RULE_TOP_SET_AMRAP');

  static const $core.List<ProgressionRule> values = <ProgressionRule>[
    PROGRESSION_RULE_UNSPECIFIED,
    PROGRESSION_RULE_NONE,
    PROGRESSION_RULE_ALL_SETS_MATCH_TARGET,
    PROGRESSION_RULE_TOP_SET_AMRAP,
  ];

  static final $core.List<ProgressionRule?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ProgressionRule? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ProgressionRule._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
