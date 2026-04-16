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
  ];

  static final $core.List<Exercise?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 11);
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
