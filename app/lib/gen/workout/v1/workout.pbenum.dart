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

/// How many more reps a calibration rung done in full had left in it. Each
/// answer counts as a reserve in the rung's shown max (core/src/plan.rs):
/// 0–1 as 0.5, 2–4 as 3, 5+ as 8.
class RepsLeft extends $pb.ProtobufEnum {
  static const RepsLeft REPS_LEFT_UNSPECIFIED =
      RepsLeft._(0, _omitEnumNames ? '' : 'REPS_LEFT_UNSPECIFIED');
  static const RepsLeft REPS_LEFT_ZERO_TO_ONE =
      RepsLeft._(1, _omitEnumNames ? '' : 'REPS_LEFT_ZERO_TO_ONE');
  static const RepsLeft REPS_LEFT_TWO_TO_FOUR =
      RepsLeft._(2, _omitEnumNames ? '' : 'REPS_LEFT_TWO_TO_FOUR');
  static const RepsLeft REPS_LEFT_FIVE_PLUS =
      RepsLeft._(3, _omitEnumNames ? '' : 'REPS_LEFT_FIVE_PLUS');

  static const $core.List<RepsLeft> values = <RepsLeft>[
    REPS_LEFT_UNSPECIFIED,
    REPS_LEFT_ZERO_TO_ONE,
    REPS_LEFT_TWO_TO_FOUR,
    REPS_LEFT_FIVE_PLUS,
  ];

  static final $core.List<RepsLeft?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static RepsLeft? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RepsLeft._(super.value, super.name);
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

  /// Stopped early, a rushed miss, or the user lowered the weight: the max
  /// unchanged. `cause` says which when it was not the weight (STOPPED_EARLY,
  /// RUSHED).
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
  /// No longer given: sets were the time budget's until it went.
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

  /// The lift follows a progression of the program's other than the
  /// estimated max: `rule` names it, `text` is the program's note on it.
  static const PlanReasonKind PLAN_REASON_KIND_RULE =
      PlanReasonKind._(13, _omitEnumNames ? '' : 'PLAN_REASON_KIND_RULE');

  /// `count` sessions in a row with a rep missed: the weight cut to
  /// `after` from `before` (lb).
  static const PlanReasonKind PLAN_REASON_KIND_DELOAD =
      PlanReasonKind._(14, _omitEnumNames ? '' : 'PLAN_REASON_KIND_DELOAD');

  /// The lift's rule could not plan it (`text` says why): planned from the
  /// estimated max instead.
  static const PlanReasonKind PLAN_REASON_KIND_FALLBACK =
      PlanReasonKind._(15, _omitEnumNames ? '' : 'PLAN_REASON_KIND_FALLBACK');

  /// A cycle's step `count` of `of`: `after` is the fraction of the max.
  static const PlanReasonKind PLAN_REASON_KIND_CYCLE_STEP =
      PlanReasonKind._(16, _omitEnumNames ? '' : 'PLAN_REASON_KIND_CYCLE_STEP');

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
    PLAN_REASON_KIND_RULE,
    PLAN_REASON_KIND_DELOAD,
    PLAN_REASON_KIND_FALLBACK,
    PLAN_REASON_KIND_CYCLE_STEP,
  ];

  static final $core.List<PlanReasonKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 16);
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

  /// Every working set done, but a miss came before the previous set's rest
  /// was up: excused, the max held.
  static const PlanChangeCause PLAN_CHANGE_CAUSE_RUSHED =
      PlanChangeCause._(6, _omitEnumNames ? '' : 'PLAN_CHANGE_CAUSE_RUSHED');

  static const $core.List<PlanChangeCause> values = <PlanChangeCause>[
    PLAN_CHANGE_CAUSE_UNSPECIFIED,
    PLAN_CHANGE_CAUSE_HIT,
    PLAN_CHANGE_CAUSE_MISSED,
    PLAN_CHANGE_CAUSE_STOPPED_EARLY,
    PLAN_CHANGE_CAUSE_SETS,
    PLAN_CHANGE_CAUSE_TIME_OFF,
    PLAN_CHANGE_CAUSE_RUSHED,
  ];

  static final $core.List<PlanChangeCause?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static PlanChangeCause? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const PlanChangeCause._(super.value, super.name);
}

/// A set's role within its lift (docs/plans/set-types.md).
class SetRole extends $pb.ProtobufEnum {
  /// A plain working set: every set recorded before roles, and a warmup or
  /// rung (which keep their own flags).
  static const SetRole SET_ROLE_UNSPECIFIED =
      SetRole._(0, _omitEnumNames ? '' : 'SET_ROLE_UNSPECIFIED');
  static const SetRole SET_ROLE_TOP =
      SetRole._(1, _omitEnumNames ? '' : 'SET_ROLE_TOP');
  static const SetRole SET_ROLE_BACKOFF =
      SetRole._(2, _omitEnumNames ? '' : 'SET_ROLE_BACKOFF');

  /// Straight after the set before it, lighter, no rest: taken to failure.
  static const SetRole SET_ROLE_DROP =
      SetRole._(3, _omitEnumNames ? '' : 'SET_ROLE_DROP');

  /// A short set after a short rest: rest-pause, myo-reps, clusters.
  static const SetRole SET_ROLE_MINI =
      SetRole._(4, _omitEnumNames ? '' : 'SET_ROLE_MINI');

  static const $core.List<SetRole> values = <SetRole>[
    SET_ROLE_UNSPECIFIED,
    SET_ROLE_TOP,
    SET_ROLE_BACKOFF,
    SET_ROLE_DROP,
    SET_ROLE_MINI,
  ];

  static final $core.List<SetRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SetRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SetRole._(super.value, super.name);
}

/// What a lift's number counts.
class Measure extends $pb.ProtobufEnum {
  /// Reps: every lift before measures.
  static const Measure MEASURE_UNSPECIFIED =
      Measure._(0, _omitEnumNames ? '' : 'MEASURE_UNSPECIFIED');
  static const Measure MEASURE_SECONDS =
      Measure._(1, _omitEnumNames ? '' : 'MEASURE_SECONDS');
  static const Measure MEASURE_METRES =
      Measure._(2, _omitEnumNames ? '' : 'MEASURE_METRES');

  static const $core.List<Measure> values = <Measure>[
    MEASURE_UNSPECIFIED,
    MEASURE_SECONDS,
    MEASURE_METRES,
  ];

  static final $core.List<Measure?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Measure? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Measure._(super.value, super.name);
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

  /// A set missed: the lift's sets still to do lighter (OnMiss.fraction),
  /// or back where they were once it's put back to every rep.
  static const WeightChangeCause WEIGHT_CHANGE_CAUSE_MISS =
      WeightChangeCause._(5, _omitEnumNames ? '' : 'WEIGHT_CHANGE_CAUSE_MISS');

  static const $core.List<WeightChangeCause> values = <WeightChangeCause>[
    WEIGHT_CHANGE_CAUSE_UNSPECIFIED,
    WEIGHT_CHANGE_CAUSE_USER_ADJUST,
    WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP,
    WEIGHT_CHANGE_CAUSE_CALIBRATION_SETTLED,
    WEIGHT_CHANGE_CAUSE_CORRECTION,
    WEIGHT_CHANGE_CAUSE_MISS,
  ];

  static final $core.List<WeightChangeCause?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
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

class NextRule extends $pb.ProtobufEnum {
  /// By volume: the program's default rule.
  static const NextRule NEXT_RULE_UNSPECIFIED =
      NextRule._(0, _omitEnumNames ? '' : 'NEXT_RULE_UNSPECIFIED');
  static const NextRule NEXT_RULE_SEQUENCE =
      NextRule._(1, _omitEnumNames ? '' : 'NEXT_RULE_SEQUENCE');
  static const NextRule NEXT_RULE_SCHEDULE =
      NextRule._(2, _omitEnumNames ? '' : 'NEXT_RULE_SCHEDULE');

  static const $core.List<NextRule> values = <NextRule>[
    NEXT_RULE_UNSPECIFIED,
    NEXT_RULE_SEQUENCE,
    NEXT_RULE_SCHEDULE,
  ];

  static final $core.List<NextRule?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static NextRule? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NextRule._(super.value, super.name);
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

  static const $core.List<RotationWarningKind> values = <RotationWarningKind>[
    ROTATION_WARNING_KIND_UNSPECIFIED,
    ROTATION_WARNING_KIND_GAP,
    ROTATION_WARNING_KIND_OVERLAP,
  ];

  static final $core.List<RotationWarningKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static RotationWarningKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RotationWarningKind._(super.value, super.name);
}

class SuggestionStatus extends $pb.ProtobufEnum {
  /// Waiting for the person.
  static const SuggestionStatus SUGGESTION_STATUS_UNSPECIFIED =
      SuggestionStatus._(
          0, _omitEnumNames ? '' : 'SUGGESTION_STATUS_UNSPECIFIED');
  static const SuggestionStatus SUGGESTION_STATUS_ACCEPTED =
      SuggestionStatus._(1, _omitEnumNames ? '' : 'SUGGESTION_STATUS_ACCEPTED');
  static const SuggestionStatus SUGGESTION_STATUS_DECLINED =
      SuggestionStatus._(2, _omitEnumNames ? '' : 'SUGGESTION_STATUS_DECLINED');

  static const $core.List<SuggestionStatus> values = <SuggestionStatus>[
    SUGGESTION_STATUS_UNSPECIFIED,
    SUGGESTION_STATUS_ACCEPTED,
    SUGGESTION_STATUS_DECLINED,
  ];

  static final $core.List<SuggestionStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SuggestionStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SuggestionStatus._(super.value, super.name);
}

/// What one change of a suggestion does, for the app to say in its words.
class ChangeVerb extends $pb.ProtobufEnum {
  /// Sets a number or a field.
  static const ChangeVerb CHANGE_VERB_UNSPECIFIED =
      ChangeVerb._(0, _omitEnumNames ? '' : 'CHANGE_VERB_UNSPECIFIED');
  static const ChangeVerb CHANGE_VERB_ADD =
      ChangeVerb._(1, _omitEnumNames ? '' : 'CHANGE_VERB_ADD');
  static const ChangeVerb CHANGE_VERB_CHANGE =
      ChangeVerb._(2, _omitEnumNames ? '' : 'CHANGE_VERB_CHANGE');
  static const ChangeVerb CHANGE_VERB_REMOVE =
      ChangeVerb._(3, _omitEnumNames ? '' : 'CHANGE_VERB_REMOVE');

  static const $core.List<ChangeVerb> values = <ChangeVerb>[
    CHANGE_VERB_UNSPECIFIED,
    CHANGE_VERB_ADD,
    CHANGE_VERB_CHANGE,
    CHANGE_VERB_REMOVE,
  ];

  static final $core.List<ChangeVerb?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ChangeVerb? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ChangeVerb._(super.value, super.name);
}

class ChangeSubject extends $pb.ProtobufEnum {
  /// One of the program's numbers.
  static const ChangeSubject CHANGE_SUBJECT_UNSPECIFIED =
      ChangeSubject._(0, _omitEnumNames ? '' : 'CHANGE_SUBJECT_UNSPECIFIED');
  static const ChangeSubject CHANGE_SUBJECT_WORKOUT =
      ChangeSubject._(1, _omitEnumNames ? '' : 'CHANGE_SUBJECT_WORKOUT');
  static const ChangeSubject CHANGE_SUBJECT_EXERCISE =
      ChangeSubject._(2, _omitEnumNames ? '' : 'CHANGE_SUBJECT_EXERCISE');
  static const ChangeSubject CHANGE_SUBJECT_SCHEME =
      ChangeSubject._(3, _omitEnumNames ? '' : 'CHANGE_SUBJECT_SCHEME');
  static const ChangeSubject CHANGE_SUBJECT_PROGRESSION =
      ChangeSubject._(4, _omitEnumNames ? '' : 'CHANGE_SUBJECT_PROGRESSION');
  static const ChangeSubject CHANGE_SUBJECT_CLASS =
      ChangeSubject._(5, _omitEnumNames ? '' : 'CHANGE_SUBJECT_CLASS');

  static const $core.List<ChangeSubject> values = <ChangeSubject>[
    CHANGE_SUBJECT_UNSPECIFIED,
    CHANGE_SUBJECT_WORKOUT,
    CHANGE_SUBJECT_EXERCISE,
    CHANGE_SUBJECT_SCHEME,
    CHANGE_SUBJECT_PROGRESSION,
    CHANGE_SUBJECT_CLASS,
  ];

  static final $core.List<ChangeSubject?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ChangeSubject? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ChangeSubject._(super.value, super.name);
}

/// How the simulated sessions go.
class SimulatedEffort extends $pb.ProtobufEnum {
  static const SimulatedEffort SIMULATED_EFFORT_UNSPECIFIED = SimulatedEffort._(
      0, _omitEnumNames ? '' : 'SIMULATED_EFFORT_UNSPECIFIED');

  /// Every rep of every set.
  static const SimulatedEffort SIMULATED_EFFORT_ALL_HIT =
      SimulatedEffort._(1, _omitEnumNames ? '' : 'SIMULATED_EFFORT_ALL_HIT');

  /// The last set of each lift one rep short.
  static const SimulatedEffort SIMULATED_EFFORT_LAST_SET_SHORT =
      SimulatedEffort._(
          2, _omitEnumNames ? '' : 'SIMULATED_EFFORT_LAST_SET_SHORT');

  /// Every set one rep short.
  static const SimulatedEffort SIMULATED_EFFORT_ALL_SHORT =
      SimulatedEffort._(3, _omitEnumNames ? '' : 'SIMULATED_EFFORT_ALL_SHORT');

  /// All hit, but every `miss_every`th session of a lift the last set one
  /// rep short.
  static const SimulatedEffort SIMULATED_EFFORT_MISS_EVERY =
      SimulatedEffort._(4, _omitEnumNames ? '' : 'SIMULATED_EFFORT_MISS_EVERY');

  static const $core.List<SimulatedEffort> values = <SimulatedEffort>[
    SIMULATED_EFFORT_UNSPECIFIED,
    SIMULATED_EFFORT_ALL_HIT,
    SIMULATED_EFFORT_LAST_SET_SHORT,
    SIMULATED_EFFORT_ALL_SHORT,
    SIMULATED_EFFORT_MISS_EVERY,
  ];

  static final $core.List<SimulatedEffort?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SimulatedEffort? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SimulatedEffort._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
