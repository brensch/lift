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

/// The 10-muscle taxonomy. Volume, recovery and the exercise catalog all
/// use this one list — there is no second muscle grouping anywhere.
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
  static const MuscleGroup MUSCLE_GROUP_CALVES =
      MuscleGroup._(9, _omitEnumNames ? '' : 'MUSCLE_GROUP_CALVES');
  static const MuscleGroup MUSCLE_GROUP_CORE =
      MuscleGroup._(10, _omitEnumNames ? '' : 'MUSCLE_GROUP_CORE');

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
    MUSCLE_GROUP_CALVES,
    MUSCLE_GROUP_CORE,
  ];

  static final $core.List<MuscleGroup?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
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

/// How an exercise is loaded. Drives the equipment filter in the picker
/// and the size of a progression step.
class EquipmentKind extends $pb.ProtobufEnum {
  static const EquipmentKind EQUIPMENT_KIND_UNSPECIFIED =
      EquipmentKind._(0, _omitEnumNames ? '' : 'EQUIPMENT_KIND_UNSPECIFIED');
  static const EquipmentKind EQUIPMENT_KIND_BARBELL =
      EquipmentKind._(1, _omitEnumNames ? '' : 'EQUIPMENT_KIND_BARBELL');
  static const EquipmentKind EQUIPMENT_KIND_DUMBBELL =
      EquipmentKind._(2, _omitEnumNames ? '' : 'EQUIPMENT_KIND_DUMBBELL');
  static const EquipmentKind EQUIPMENT_KIND_MACHINE =
      EquipmentKind._(3, _omitEnumNames ? '' : 'EQUIPMENT_KIND_MACHINE');
  static const EquipmentKind EQUIPMENT_KIND_CABLE =
      EquipmentKind._(4, _omitEnumNames ? '' : 'EQUIPMENT_KIND_CABLE');
  static const EquipmentKind EQUIPMENT_KIND_BODYWEIGHT =
      EquipmentKind._(5, _omitEnumNames ? '' : 'EQUIPMENT_KIND_BODYWEIGHT');

  static const $core.List<EquipmentKind> values = <EquipmentKind>[
    EQUIPMENT_KIND_UNSPECIFIED,
    EQUIPMENT_KIND_BARBELL,
    EQUIPMENT_KIND_DUMBBELL,
    EQUIPMENT_KIND_MACHINE,
    EQUIPMENT_KIND_CABLE,
    EQUIPMENT_KIND_BODYWEIGHT,
  ];

  static final $core.List<EquipmentKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static EquipmentKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const EquipmentKind._(super.value, super.name);
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

class PlanReasonKind extends $pb.ProtobufEnum {
  static const PlanReasonKind PLAN_REASON_KIND_UNSPECIFIED =
      PlanReasonKind._(0, _omitEnumNames ? '' : 'PLAN_REASON_KIND_UNSPECIFIED');

  /// Every working rep hit last time: the max nudged up.
  static const PlanReasonKind PLAN_REASON_KIND_MAX_UP =
      PlanReasonKind._(1, _omitEnumNames ? '' : 'PLAN_REASON_KIND_MAX_UP');

  /// A rep missed last time: the max reset to the most a set showed.
  static const PlanReasonKind PLAN_REASON_KIND_MAX_FROM_MISS = PlanReasonKind._(
      2, _omitEnumNames ? '' : 'PLAN_REASON_KIND_MAX_FROM_MISS');

  /// Stopped early, or the user lowered the weight: the max unchanged.
  static const PlanReasonKind PLAN_REASON_KIND_HELD =
      PlanReasonKind._(3, _omitEnumNames ? '' : 'PLAN_REASON_KIND_HELD');

  /// Three weeks or more away (six or more): the max cut to 90% (80%).
  static const PlanReasonKind PLAN_REASON_KIND_TIME_OFF =
      PlanReasonKind._(4, _omitEnumNames ? '' : 'PLAN_REASON_KIND_TIME_OFF');

  /// Never done: a calibration ramp finds the max (a bodyweight lift
  /// starts at the bottom of its range).
  static const PlanReasonKind PLAN_REASON_KIND_FIRST_TIME =
      PlanReasonKind._(5, _omitEnumNames ? '' : 'PLAN_REASON_KIND_FIRST_TIME');

  /// The user's own weight and reps, set at `at`.
  static const PlanReasonKind PLAN_REASON_KIND_USER_SET =
      PlanReasonKind._(6, _omitEnumNames ? '' : 'PLAN_REASON_KIND_USER_SET');

  /// This many sets: what the time budget fits, given to the lifts whose
  /// muscles are furthest behind this week.
  static const PlanReasonKind PLAN_REASON_KIND_SETS_FROM_TIME =
      PlanReasonKind._(
          7, _omitEnumNames ? '' : 'PLAN_REASON_KIND_SETS_FROM_TIME');

  /// The plan against the lift's last session, what the user sees move:
  /// before/after are the weights (lb), reps_*/sets_* the reps and sets,
  /// and `cause` why. One of these comes first whenever the lift has a
  /// last session to compare with (not after an override or a ramp alone).
  /// Heavier than last time.
  static const PlanReasonKind PLAN_REASON_KIND_WEIGHT_UP =
      PlanReasonKind._(8, _omitEnumNames ? '' : 'PLAN_REASON_KIND_WEIGHT_UP');

  /// Lighter than last time.
  static const PlanReasonKind PLAN_REASON_KIND_WEIGHT_DOWN =
      PlanReasonKind._(9, _omitEnumNames ? '' : 'PLAN_REASON_KIND_WEIGHT_DOWN');

  /// The same weight, more reps.
  static const PlanReasonKind PLAN_REASON_KIND_REPS_UP =
      PlanReasonKind._(10, _omitEnumNames ? '' : 'PLAN_REASON_KIND_REPS_UP');

  /// The same weight, fewer reps.
  static const PlanReasonKind PLAN_REASON_KIND_REPS_DOWN =
      PlanReasonKind._(11, _omitEnumNames ? '' : 'PLAN_REASON_KIND_REPS_DOWN');

  /// The same weight and reps as last time.
  static const PlanReasonKind PLAN_REASON_KIND_SAME_AS_LAST = PlanReasonKind._(
      12, _omitEnumNames ? '' : 'PLAN_REASON_KIND_SAME_AS_LAST');

  static const $core.List<PlanReasonKind> values = <PlanReasonKind>[
    PLAN_REASON_KIND_UNSPECIFIED,
    PLAN_REASON_KIND_MAX_UP,
    PLAN_REASON_KIND_MAX_FROM_MISS,
    PLAN_REASON_KIND_HELD,
    PLAN_REASON_KIND_TIME_OFF,
    PLAN_REASON_KIND_FIRST_TIME,
    PLAN_REASON_KIND_USER_SET,
    PLAN_REASON_KIND_SETS_FROM_TIME,
    PLAN_REASON_KIND_WEIGHT_UP,
    PLAN_REASON_KIND_WEIGHT_DOWN,
    PLAN_REASON_KIND_REPS_UP,
    PLAN_REASON_KIND_REPS_DOWN,
    PLAN_REASON_KIND_SAME_AS_LAST,
  ];

  static final $core.List<PlanReasonKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 12);
  static PlanReasonKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PlanReasonKind._(super.value, super.name);
}

/// Why a plan differs from (or matches) the lift's last session.
class PlanChangeCause extends $pb.ProtobufEnum {
  static const PlanChangeCause PLAN_CHANGE_CAUSE_UNSPECIFIED =
      PlanChangeCause._(
          0, _omitEnumNames ? '' : 'PLAN_CHANGE_CAUSE_UNSPECIFIED');

  /// Every rep hit last time.
  static const PlanChangeCause PLAN_CHANGE_CAUSE_HIT =
      PlanChangeCause._(1, _omitEnumNames ? '' : 'PLAN_CHANGE_CAUSE_HIT');

  /// A rep missed last time.
  static const PlanChangeCause PLAN_CHANGE_CAUSE_MISSED =
      PlanChangeCause._(2, _omitEnumNames ? '' : 'PLAN_CHANGE_CAUSE_MISSED');

  /// Last time stopped early: the max held.
  static const PlanChangeCause PLAN_CHANGE_CAUSE_STOPPED_EARLY =
      PlanChangeCause._(
          3, _omitEnumNames ? '' : 'PLAN_CHANGE_CAUSE_STOPPED_EARLY');

  /// A different number of sets: last time's sets would have kept last
  /// time's numbers (sets_before, sets_after).
  static const PlanChangeCause PLAN_CHANGE_CAUSE_SETS =
      PlanChangeCause._(4, _omitEnumNames ? '' : 'PLAN_CHANGE_CAUSE_SETS');

  /// Three weeks or more away (days_off): the max cut.
  static const PlanChangeCause PLAN_CHANGE_CAUSE_TIME_OFF =
      PlanChangeCause._(5, _omitEnumNames ? '' : 'PLAN_CHANGE_CAUSE_TIME_OFF');

  static const $core.List<PlanChangeCause> values = <PlanChangeCause>[
    PLAN_CHANGE_CAUSE_UNSPECIFIED,
    PLAN_CHANGE_CAUSE_HIT,
    PLAN_CHANGE_CAUSE_MISSED,
    PLAN_CHANGE_CAUSE_STOPPED_EARLY,
    PLAN_CHANGE_CAUSE_SETS,
    PLAN_CHANGE_CAUSE_TIME_OFF,
  ];

  static final $core.List<PlanChangeCause?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static PlanChangeCause? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PlanChangeCause._(super.value, super.name);
}

class WeightChangeCause extends $pb.ProtobufEnum {
  static const WeightChangeCause WEIGHT_CHANGE_CAUSE_UNSPECIFIED =
      WeightChangeCause._(
          0, _omitEnumNames ? '' : 'WEIGHT_CHANGE_CAUSE_UNSPECIFIED');

  /// AdjustExerciseWeight, from the phone or the watch.
  static const WeightChangeCause WEIGHT_CHANGE_CAUSE_USER_ADJUST =
      WeightChangeCause._(
          1, _omitEnumNames ? '' : 'WEIGHT_CHANGE_CAUSE_USER_ADJUST');

  /// The calibration ramp's next rung.
  static const WeightChangeCause WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP =
      WeightChangeCause._(
          2, _omitEnumNames ? '' : 'WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP');

  /// The ramp done: the working weight set.
  static const WeightChangeCause WEIGHT_CHANGE_CAUSE_CALIBRATION_SETTLED =
      WeightChangeCause._(
          3, _omitEnumNames ? '' : 'WEIGHT_CHANGE_CAUSE_CALIBRATION_SETTLED');

  /// EditCompletedSet: the weight recorded on a done set fixed.
  static const WeightChangeCause WEIGHT_CHANGE_CAUSE_CORRECTION =
      WeightChangeCause._(
          4, _omitEnumNames ? '' : 'WEIGHT_CHANGE_CAUSE_CORRECTION');

  static const $core.List<WeightChangeCause> values = <WeightChangeCause>[
    WEIGHT_CHANGE_CAUSE_UNSPECIFIED,
    WEIGHT_CHANGE_CAUSE_USER_ADJUST,
    WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP,
    WEIGHT_CHANGE_CAUSE_CALIBRATION_SETTLED,
    WEIGHT_CHANGE_CAUSE_CORRECTION,
  ];

  static final $core.List<WeightChangeCause?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static WeightChangeCause? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WeightChangeCause._(super.value, super.name);
}

/// A set is pending, done or cancelled. The workout's state is derived from
/// one moment, when the last set was done, and that set's prescribed rest:
///   READY    no set done yet (the first set is up)
///   LIFTING  a set has been started and not yet done (counts up)
///   RESTING  the last done set's rest is still running (counts down)
///   YAPPING  that rest has run out and the next set isn't started (counts up)
///   ALL_DONE nothing left to do
/// There is no in-progress set.
class WorkoutState extends $pb.ProtobufEnum {
  static const WorkoutState WORKOUT_STATE_UNSPECIFIED =
      WorkoutState._(0, _omitEnumNames ? '' : 'WORKOUT_STATE_UNSPECIFIED');
  static const WorkoutState WORKOUT_STATE_ALL_DONE =
      WorkoutState._(1, _omitEnumNames ? '' : 'WORKOUT_STATE_ALL_DONE');
  static const WorkoutState WORKOUT_STATE_RESTING =
      WorkoutState._(3, _omitEnumNames ? '' : 'WORKOUT_STATE_RESTING');
  static const WorkoutState WORKOUT_STATE_READY =
      WorkoutState._(5, _omitEnumNames ? '' : 'WORKOUT_STATE_READY');
  static const WorkoutState WORKOUT_STATE_YAPPING =
      WorkoutState._(6, _omitEnumNames ? '' : 'WORKOUT_STATE_YAPPING');
  static const WorkoutState WORKOUT_STATE_LIFTING =
      WorkoutState._(7, _omitEnumNames ? '' : 'WORKOUT_STATE_LIFTING');

  static const $core.List<WorkoutState> values = <WorkoutState>[
    WORKOUT_STATE_UNSPECIFIED,
    WORKOUT_STATE_ALL_DONE,
    WORKOUT_STATE_RESTING,
    WORKOUT_STATE_READY,
    WORKOUT_STATE_YAPPING,
    WORKOUT_STATE_LIFTING,
  ];

  static final $core.List<WorkoutState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static WorkoutState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WorkoutState._(super.value, super.name);
}

class RotationWarningKind extends $pb.ProtobufEnum {
  static const RotationWarningKind ROTATION_WARNING_KIND_UNSPECIFIED =
      RotationWarningKind._(
          0, _omitEnumNames ? '' : 'ROTATION_WARNING_KIND_UNSPECIFIED');

  /// A muscle nothing in rotation trains.
  static const RotationWarningKind ROTATION_WARNING_KIND_GAP =
      RotationWarningKind._(
          1, _omitEnumNames ? '' : 'ROTATION_WARNING_KIND_GAP');

  /// Two templates sharing over 70% of the smaller one's lifts.
  static const RotationWarningKind ROTATION_WARNING_KIND_OVERLAP =
      RotationWarningKind._(
          2, _omitEnumNames ? '' : 'ROTATION_WARNING_KIND_OVERLAP');

  /// Fewer than two templates in rotation.
  static const RotationWarningKind ROTATION_WARNING_KIND_TOO_FEW =
      RotationWarningKind._(
          4, _omitEnumNames ? '' : 'ROTATION_WARNING_KIND_TOO_FEW');

  static const $core.List<RotationWarningKind> values = <RotationWarningKind>[
    ROTATION_WARNING_KIND_UNSPECIFIED,
    ROTATION_WARNING_KIND_GAP,
    ROTATION_WARNING_KIND_OVERLAP,
    ROTATION_WARNING_KIND_TOO_FEW,
  ];

  static final $core.List<RotationWarningKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static RotationWarningKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RotationWarningKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
