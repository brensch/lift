// This is a generated file - do not edit.
//
// Generated from workout/v1/wearable.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'wearable.pbenum.dart';
import 'workout.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'wearable.pbenum.dart';

/// Everything the watch prints is a string the phone rendered. The watch
/// lays them out; it never derives text from the workout.
class WearStatusCard extends $pb.GeneratedMessage {
  factory WearStatusCard({
    $core.String? stateLabel,
    $core.String? timerText,
    $0.ProposedSet? displaySet,
    $core.String? exerciseName,
    $core.String? setLine,
    $core.String? setText,
    $core.String? yappingLabel,
    $core.String? weightText,
    $core.String? unitText,
    $core.String? repsText,
    $core.bool? firstTime,
    $core.Iterable<WearPlate>? plates,
    $core.String? platesText,
    $core.String? barText,
  }) {
    final result = create();
    if (stateLabel != null) result.stateLabel = stateLabel;
    if (timerText != null) result.timerText = timerText;
    if (displaySet != null) result.displaySet = displaySet;
    if (exerciseName != null) result.exerciseName = exerciseName;
    if (setLine != null) result.setLine = setLine;
    if (setText != null) result.setText = setText;
    if (yappingLabel != null) result.yappingLabel = yappingLabel;
    if (weightText != null) result.weightText = weightText;
    if (unitText != null) result.unitText = unitText;
    if (repsText != null) result.repsText = repsText;
    if (firstTime != null) result.firstTime = firstTime;
    if (plates != null) result.plates.addAll(plates);
    if (platesText != null) result.platesText = platesText;
    if (barText != null) result.barText = barText;
    return result;
  }

  WearStatusCard._();

  factory WearStatusCard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearStatusCard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearStatusCard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(3, _omitFieldNames ? '' : 'stateLabel')
    ..aOS(4, _omitFieldNames ? '' : 'timerText')
    ..aOM<$0.ProposedSet>(6, _omitFieldNames ? '' : 'displaySet',
        subBuilder: $0.ProposedSet.create)
    ..aOS(9, _omitFieldNames ? '' : 'exerciseName')
    ..aOS(10, _omitFieldNames ? '' : 'setLine')
    ..aOS(11, _omitFieldNames ? '' : 'setText')
    ..aOS(12, _omitFieldNames ? '' : 'yappingLabel')
    ..aOS(14, _omitFieldNames ? '' : 'weightText')
    ..aOS(15, _omitFieldNames ? '' : 'unitText')
    ..aOS(16, _omitFieldNames ? '' : 'repsText')
    ..aOB(18, _omitFieldNames ? '' : 'firstTime')
    ..pPM<WearPlate>(19, _omitFieldNames ? '' : 'plates',
        subBuilder: WearPlate.create)
    ..aOS(20, _omitFieldNames ? '' : 'platesText')
    ..aOS(21, _omitFieldNames ? '' : 'barText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearStatusCard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearStatusCard copyWith(void Function(WearStatusCard) updates) =>
      super.copyWith((message) => updates(message as WearStatusCard))
          as WearStatusCard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearStatusCard create() => WearStatusCard._();
  @$core.override
  WearStatusCard createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearStatusCard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearStatusCard>(create);
  static WearStatusCard? _defaultInstance;

  @$pb.TagNumber(3)
  $core.String get stateLabel => $_getSZ(0);
  @$pb.TagNumber(3)
  set stateLabel($core.String value) => $_setString(0, value);
  @$pb.TagNumber(3)
  $core.bool hasStateLabel() => $_has(0);
  @$pb.TagNumber(3)
  void clearStateLabel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get timerText => $_getSZ(1);
  @$pb.TagNumber(4)
  set timerText($core.String value) => $_setString(1, value);
  @$pb.TagNumber(4)
  $core.bool hasTimerText() => $_has(1);
  @$pb.TagNumber(4)
  void clearTimerText() => $_clearField(4);

  @$pb.TagNumber(6)
  $0.ProposedSet get displaySet => $_getN(2);
  @$pb.TagNumber(6)
  set displaySet($0.ProposedSet value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDisplaySet() => $_has(2);
  @$pb.TagNumber(6)
  void clearDisplaySet() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.ProposedSet ensureDisplaySet() => $_ensure(2);

  @$pb.TagNumber(9)
  $core.String get exerciseName => $_getSZ(3);
  @$pb.TagNumber(9)
  set exerciseName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(9)
  $core.bool hasExerciseName() => $_has(3);
  @$pb.TagNumber(9)
  void clearExerciseName() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get setLine => $_getSZ(4);
  @$pb.TagNumber(10)
  set setLine($core.String value) => $_setString(4, value);
  @$pb.TagNumber(10)
  $core.bool hasSetLine() => $_has(4);
  @$pb.TagNumber(10)
  void clearSetLine() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get setText => $_getSZ(5);
  @$pb.TagNumber(11)
  set setText($core.String value) => $_setString(5, value);
  @$pb.TagNumber(11)
  $core.bool hasSetText() => $_has(5);
  @$pb.TagNumber(11)
  void clearSetText() => $_clearField(11);

  /// What the watch switches to on its own when the countdown reaches zero
  /// (RESTING becoming YAPPING), before the next snapshot arrives.
  @$pb.TagNumber(12)
  $core.String get yappingLabel => $_getSZ(6);
  @$pb.TagNumber(12)
  set yappingLabel($core.String value) => $_setString(6, value);
  @$pb.TagNumber(12)
  $core.bool hasYappingLabel() => $_has(6);
  @$pb.TagNumber(12)
  void clearYappingLabel() => $_clearField(12);

  @$pb.TagNumber(14)
  $core.String get weightText => $_getSZ(7);
  @$pb.TagNumber(14)
  set weightText($core.String value) => $_setString(7, value);
  @$pb.TagNumber(14)
  $core.bool hasWeightText() => $_has(7);
  @$pb.TagNumber(14)
  void clearWeightText() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get unitText => $_getSZ(8);
  @$pb.TagNumber(15)
  set unitText($core.String value) => $_setString(8, value);
  @$pb.TagNumber(15)
  $core.bool hasUnitText() => $_has(8);
  @$pb.TagNumber(15)
  void clearUnitText() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get repsText => $_getSZ(9);
  @$pb.TagNumber(16)
  set repsText($core.String value) => $_setString(9, value);
  @$pb.TagNumber(16)
  $core.bool hasRepsText() => $_has(9);
  @$pb.TagNumber(16)
  void clearRepsText() => $_clearField(16);

  /// The opening set of an exercise never done: no weight yet. A tap starts
  /// the calibration sets; giving the weight is done on the phone.
  @$pb.TagNumber(18)
  $core.bool get firstTime => $_getBF(10);
  @$pb.TagNumber(18)
  set firstTime($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(18)
  $core.bool hasFirstTime() => $_has(10);
  @$pb.TagNumber(18)
  void clearFirstTime() => $_clearField(18);

  /// The plates for display_set, one side, heaviest (loaded first) first;
  /// empty off a barbell or on an empty bar. Shown when the weight is tapped.
  @$pb.TagNumber(19)
  $pb.PbList<WearPlate> get plates => $_getList(11);

  @$pb.TagNumber(20)
  $core.String get platesText => $_getSZ(12);
  @$pb.TagNumber(20)
  set platesText($core.String value) => $_setString(12, value);
  @$pb.TagNumber(20)
  $core.bool hasPlatesText() => $_has(12);
  @$pb.TagNumber(20)
  void clearPlatesText() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.String get barText => $_getSZ(13);
  @$pb.TagNumber(21)
  set barText($core.String value) => $_setString(13, value);
  @$pb.TagNumber(21)
  $core.bool hasBarText() => $_has(13);
  @$pb.TagNumber(21)
  void clearBarText() => $_clearField(21);
}

/// The dimmed face counts rest in whole minutes: it is redrawn about once a
/// minute, so seconds would be wrong most of the time.
class WearAmbientCopy extends $pb.GeneratedMessage {
  factory WearAmbientCopy({
    $core.String? minLeft,
    $core.String? underAMin,
    $core.String? minOver,
    $core.String? restUntil,
  }) {
    final result = create();
    if (minLeft != null) result.minLeft = minLeft;
    if (underAMin != null) result.underAMin = underAMin;
    if (minOver != null) result.minOver = minOver;
    if (restUntil != null) result.restUntil = restUntil;
    return result;
  }

  WearAmbientCopy._();

  factory WearAmbientCopy.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearAmbientCopy.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearAmbientCopy',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'minLeft')
    ..aOS(2, _omitFieldNames ? '' : 'underAMin')
    ..aOS(3, _omitFieldNames ? '' : 'minOver')
    ..aOS(4, _omitFieldNames ? '' : 'restUntil')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearAmbientCopy clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearAmbientCopy copyWith(void Function(WearAmbientCopy) updates) =>
      super.copyWith((message) => updates(message as WearAmbientCopy))
          as WearAmbientCopy;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearAmbientCopy create() => WearAmbientCopy._();
  @$core.override
  WearAmbientCopy createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearAmbientCopy getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearAmbientCopy>(create);
  static WearAmbientCopy? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get minLeft => $_getSZ(0);
  @$pb.TagNumber(1)
  set minLeft($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMinLeft() => $_has(0);
  @$pb.TagNumber(1)
  void clearMinLeft() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get underAMin => $_getSZ(1);
  @$pb.TagNumber(2)
  set underAMin($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUnderAMin() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnderAMin() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get minOver => $_getSZ(2);
  @$pb.TagNumber(3)
  set minOver($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMinOver() => $_has(2);
  @$pb.TagNumber(3)
  void clearMinOver() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get restUntil => $_getSZ(3);
  @$pb.TagNumber(4)
  set restUntil($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRestUntil() => $_has(3);
  @$pb.TagNumber(4)
  void clearRestUntil() => $_clearField(4);
}

/// One set of the exercise in hand, as a circle. A tap on it is a TapSetIntent:
/// the phone does what a tap on its own circle does.
class WearSetCircle extends $pb.GeneratedMessage {
  factory WearSetCircle({
    $core.String? setId,
    $core.String? text,
    WearCircleState? state,
    $core.bool? warmup,
  }) {
    final result = create();
    if (setId != null) result.setId = setId;
    if (text != null) result.text = text;
    if (state != null) result.state = state;
    if (warmup != null) result.warmup = warmup;
    return result;
  }

  WearSetCircle._();

  factory WearSetCircle.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearSetCircle.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearSetCircle',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'setId')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..aE<WearCircleState>(3, _omitFieldNames ? '' : 'state',
        enumValues: WearCircleState.values)
    ..aOB(4, _omitFieldNames ? '' : 'warmup')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearSetCircle clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearSetCircle copyWith(void Function(WearSetCircle) updates) =>
      super.copyWith((message) => updates(message as WearSetCircle))
          as WearSetCircle;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearSetCircle create() => WearSetCircle._();
  @$core.override
  WearSetCircle createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearSetCircle getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearSetCircle>(create);
  static WearSetCircle? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get setId => $_getSZ(0);
  @$pb.TagNumber(1)
  set setId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  WearCircleState get state => $_getN(2);
  @$pb.TagNumber(3)
  set state(WearCircleState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get warmup => $_getBF(3);
  @$pb.TagNumber(4)
  set warmup($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWarmup() => $_has(3);
  @$pb.TagNumber(4)
  void clearWarmup() => $_clearField(4);
}

/// One plate on the bar, as the phone draws it.
class WearPlate extends $pb.GeneratedMessage {
  factory WearPlate({
    $core.String? label,
    $core.String? colorHex,
    $core.double? size,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (colorHex != null) result.colorHex = colorHex;
    if (size != null) result.size = size;
    return result;
  }

  WearPlate._();

  factory WearPlate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearPlate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearPlate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aOS(2, _omitFieldNames ? '' : 'colorHex')
    ..aD(3, _omitFieldNames ? '' : 'size', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearPlate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearPlate copyWith(void Function(WearPlate) updates) =>
      super.copyWith((message) => updates(message as WearPlate)) as WearPlate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearPlate create() => WearPlate._();
  @$core.override
  WearPlate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearPlate getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WearPlate>(create);
  static WearPlate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get colorHex => $_getSZ(1);
  @$pb.TagNumber(2)
  set colorHex($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasColorHex() => $_has(1);
  @$pb.TagNumber(2)
  void clearColorHex() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get size => $_getN(2);
  @$pb.TagNumber(3)
  set size($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearSize() => $_clearField(3);
}

class WearAction extends $pb.GeneratedMessage {
  factory WearAction({
    WearActionType? type,
    $core.String? label,
    $core.String? setId,
    $core.int? reps,
    $core.double? actualWeight,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (label != null) result.label = label;
    if (setId != null) result.setId = setId;
    if (reps != null) result.reps = reps;
    if (actualWeight != null) result.actualWeight = actualWeight;
    return result;
  }

  WearAction._();

  factory WearAction.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearAction.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearAction',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<WearActionType>(1, _omitFieldNames ? '' : 'type',
        enumValues: WearActionType.values)
    ..aOS(3, _omitFieldNames ? '' : 'label')
    ..aOS(4, _omitFieldNames ? '' : 'setId')
    ..aI(5, _omitFieldNames ? '' : 'reps')
    ..aD(6, _omitFieldNames ? '' : 'actualWeight',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearAction clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearAction copyWith(void Function(WearAction) updates) =>
      super.copyWith((message) => updates(message as WearAction)) as WearAction;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearAction create() => WearAction._();
  @$core.override
  WearAction createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearAction getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearAction>(create);
  static WearAction? _defaultInstance;

  @$pb.TagNumber(1)
  WearActionType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(WearActionType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(3)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(3)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(3)
  void clearLabel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get setId => $_getSZ(2);
  @$pb.TagNumber(4)
  set setId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(4)
  $core.bool hasSetId() => $_has(2);
  @$pb.TagNumber(4)
  void clearSetId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get reps => $_getIZ(3);
  @$pb.TagNumber(5)
  set reps($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(5)
  $core.bool hasReps() => $_has(3);
  @$pb.TagNumber(5)
  void clearReps() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get actualWeight => $_getN(4);
  @$pb.TagNumber(6)
  set actualWeight($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(6)
  $core.bool hasActualWeight() => $_has(4);
  @$pb.TagNumber(6)
  void clearActualWeight() => $_clearField(6);
}

class WearWorkoutSnapshot extends $pb.GeneratedMessage {
  factory WearWorkoutSnapshot({
    $core.String? workoutId,
    $fixnum.Int64? emittedAt,
    $0.WorkoutState? state,
    $fixnum.Int64? workoutStartTime,
    $fixnum.Int64? restUntil,
    $core.String? elapsedText,
    WearStatusCard? youCard,
    $core.Iterable<WearAction>? actions,
    WearCompletionSummary? completionSummary,
    $fixnum.Int64? liftingStartedAt,
    $fixnum.Int64? lastSetEndedAt,
    $core.Iterable<WearSetCircle>? circles,
    $core.String? upNextText,
    WearAmbientCopy? ambientCopy,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (emittedAt != null) result.emittedAt = emittedAt;
    if (state != null) result.state = state;
    if (workoutStartTime != null) result.workoutStartTime = workoutStartTime;
    if (restUntil != null) result.restUntil = restUntil;
    if (elapsedText != null) result.elapsedText = elapsedText;
    if (youCard != null) result.youCard = youCard;
    if (actions != null) result.actions.addAll(actions);
    if (completionSummary != null) result.completionSummary = completionSummary;
    if (liftingStartedAt != null) result.liftingStartedAt = liftingStartedAt;
    if (lastSetEndedAt != null) result.lastSetEndedAt = lastSetEndedAt;
    if (circles != null) result.circles.addAll(circles);
    if (upNextText != null) result.upNextText = upNextText;
    if (ambientCopy != null) result.ambientCopy = ambientCopy;
    return result;
  }

  WearWorkoutSnapshot._();

  factory WearWorkoutSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearWorkoutSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearWorkoutSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aInt64(2, _omitFieldNames ? '' : 'emittedAt')
    ..aE<$0.WorkoutState>(3, _omitFieldNames ? '' : 'state',
        enumValues: $0.WorkoutState.values)
    ..aInt64(4, _omitFieldNames ? '' : 'workoutStartTime')
    ..aInt64(6, _omitFieldNames ? '' : 'restUntil')
    ..aOS(8, _omitFieldNames ? '' : 'elapsedText')
    ..aOM<WearStatusCard>(9, _omitFieldNames ? '' : 'youCard',
        subBuilder: WearStatusCard.create)
    ..pPM<WearAction>(11, _omitFieldNames ? '' : 'actions',
        subBuilder: WearAction.create)
    ..aOM<WearCompletionSummary>(12, _omitFieldNames ? '' : 'completionSummary',
        subBuilder: WearCompletionSummary.create)
    ..aInt64(15, _omitFieldNames ? '' : 'liftingStartedAt')
    ..aInt64(16, _omitFieldNames ? '' : 'lastSetEndedAt')
    ..pPM<WearSetCircle>(17, _omitFieldNames ? '' : 'circles',
        subBuilder: WearSetCircle.create)
    ..aOS(20, _omitFieldNames ? '' : 'upNextText')
    ..aOM<WearAmbientCopy>(21, _omitFieldNames ? '' : 'ambientCopy',
        subBuilder: WearAmbientCopy.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearWorkoutSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearWorkoutSnapshot copyWith(void Function(WearWorkoutSnapshot) updates) =>
      super.copyWith((message) => updates(message as WearWorkoutSnapshot))
          as WearWorkoutSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearWorkoutSnapshot create() => WearWorkoutSnapshot._();
  @$core.override
  WearWorkoutSnapshot createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearWorkoutSnapshot getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearWorkoutSnapshot>(create);
  static WearWorkoutSnapshot? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get emittedAt => $_getI64(1);
  @$pb.TagNumber(2)
  set emittedAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmittedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmittedAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.WorkoutState get state => $_getN(2);
  @$pb.TagNumber(3)
  set state($0.WorkoutState value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get workoutStartTime => $_getI64(3);
  @$pb.TagNumber(4)
  set workoutStartTime($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWorkoutStartTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearWorkoutStartTime() => $_clearField(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get restUntil => $_getI64(4);
  @$pb.TagNumber(6)
  set restUntil($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(6)
  $core.bool hasRestUntil() => $_has(4);
  @$pb.TagNumber(6)
  void clearRestUntil() => $_clearField(6);

  @$pb.TagNumber(8)
  $core.String get elapsedText => $_getSZ(5);
  @$pb.TagNumber(8)
  set elapsedText($core.String value) => $_setString(5, value);
  @$pb.TagNumber(8)
  $core.bool hasElapsedText() => $_has(5);
  @$pb.TagNumber(8)
  void clearElapsedText() => $_clearField(8);

  @$pb.TagNumber(9)
  WearStatusCard get youCard => $_getN(6);
  @$pb.TagNumber(9)
  set youCard(WearStatusCard value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasYouCard() => $_has(6);
  @$pb.TagNumber(9)
  void clearYouCard() => $_clearField(9);
  @$pb.TagNumber(9)
  WearStatusCard ensureYouCard() => $_ensure(6);

  @$pb.TagNumber(11)
  $pb.PbList<WearAction> get actions => $_getList(7);

  @$pb.TagNumber(12)
  WearCompletionSummary get completionSummary => $_getN(8);
  @$pb.TagNumber(12)
  set completionSummary(WearCompletionSummary value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCompletionSummary() => $_has(8);
  @$pb.TagNumber(12)
  void clearCompletionSummary() => $_clearField(12);
  @$pb.TagNumber(12)
  WearCompletionSummary ensureCompletionSummary() => $_ensure(8);

  @$pb.TagNumber(15)
  $fixnum.Int64 get liftingStartedAt => $_getI64(9);
  @$pb.TagNumber(15)
  set liftingStartedAt($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(15)
  $core.bool hasLiftingStartedAt() => $_has(9);
  @$pb.TagNumber(15)
  void clearLiftingStartedAt() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get lastSetEndedAt => $_getI64(10);
  @$pb.TagNumber(16)
  set lastSetEndedAt($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(16)
  $core.bool hasLastSetEndedAt() => $_has(10);
  @$pb.TagNumber(16)
  void clearLastSetEndedAt() => $_clearField(16);

  /// The exercise in hand's sets, in order, warmups first.
  @$pb.TagNumber(17)
  $pb.PbList<WearSetCircle> get circles => $_getList(11);

  /// The phone's "up next" chip, when the wearer lifts next in a session;
  /// empty otherwise (solo, or someone else is next).
  @$pb.TagNumber(20)
  $core.String get upNextText => $_getSZ(12);
  @$pb.TagNumber(20)
  set upNextText($core.String value) => $_setString(12, value);
  @$pb.TagNumber(20)
  $core.bool hasUpNextText() => $_has(12);
  @$pb.TagNumber(20)
  void clearUpNextText() => $_clearField(20);

  /// The words the dimmed (always-on) face prints around its minute count.
  @$pb.TagNumber(21)
  WearAmbientCopy get ambientCopy => $_getN(13);
  @$pb.TagNumber(21)
  set ambientCopy(WearAmbientCopy value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasAmbientCopy() => $_has(13);
  @$pb.TagNumber(21)
  void clearAmbientCopy() => $_clearField(21);
  @$pb.TagNumber(21)
  WearAmbientCopy ensureAmbientCopy() => $_ensure(13);
}

class WearCompletionSummary extends $pb.GeneratedMessage {
  factory WearCompletionSummary({
    $core.String? durationText,
    $core.int? completedWorkingSets,
    $core.int? totalVolumeLb,
    $core.String? volumeText,
  }) {
    final result = create();
    if (durationText != null) result.durationText = durationText;
    if (completedWorkingSets != null)
      result.completedWorkingSets = completedWorkingSets;
    if (totalVolumeLb != null) result.totalVolumeLb = totalVolumeLb;
    if (volumeText != null) result.volumeText = volumeText;
    return result;
  }

  WearCompletionSummary._();

  factory WearCompletionSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearCompletionSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearCompletionSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'durationText')
    ..aI(2, _omitFieldNames ? '' : 'completedWorkingSets')
    ..aI(3, _omitFieldNames ? '' : 'totalVolumeLb')
    ..aOS(4, _omitFieldNames ? '' : 'volumeText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearCompletionSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearCompletionSummary copyWith(
          void Function(WearCompletionSummary) updates) =>
      super.copyWith((message) => updates(message as WearCompletionSummary))
          as WearCompletionSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearCompletionSummary create() => WearCompletionSummary._();
  @$core.override
  WearCompletionSummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearCompletionSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearCompletionSummary>(create);
  static WearCompletionSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get durationText => $_getSZ(0);
  @$pb.TagNumber(1)
  set durationText($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDurationText() => $_has(0);
  @$pb.TagNumber(1)
  void clearDurationText() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get completedWorkingSets => $_getIZ(1);
  @$pb.TagNumber(2)
  set completedWorkingSets($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCompletedWorkingSets() => $_has(1);
  @$pb.TagNumber(2)
  void clearCompletedWorkingSets() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get totalVolumeLb => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalVolumeLb($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalVolumeLb() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalVolumeLb() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get volumeText => $_getSZ(3);
  @$pb.TagNumber(4)
  set volumeText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVolumeText() => $_has(3);
  @$pb.TagNumber(4)
  void clearVolumeText() => $_clearField(4);
}

class CompleteSetIntent extends $pb.GeneratedMessage {
  factory CompleteSetIntent({
    $core.String? workoutId,
    $core.String? setId,
    $core.int? reps,
    $core.double? actualWeight,
    $fixnum.Int64? completedAt,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (setId != null) result.setId = setId;
    if (reps != null) result.reps = reps;
    if (actualWeight != null) result.actualWeight = actualWeight;
    if (completedAt != null) result.completedAt = completedAt;
    return result;
  }

  CompleteSetIntent._();

  factory CompleteSetIntent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteSetIntent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteSetIntent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'setId')
    ..aI(3, _omitFieldNames ? '' : 'reps')
    ..aD(4, _omitFieldNames ? '' : 'actualWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aInt64(5, _omitFieldNames ? '' : 'completedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteSetIntent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteSetIntent copyWith(void Function(CompleteSetIntent) updates) =>
      super.copyWith((message) => updates(message as CompleteSetIntent))
          as CompleteSetIntent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteSetIntent create() => CompleteSetIntent._();
  @$core.override
  CompleteSetIntent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteSetIntent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteSetIntent>(create);
  static CompleteSetIntent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get setId => $_getSZ(1);
  @$pb.TagNumber(2)
  set setId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSetId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get reps => $_getIZ(2);
  @$pb.TagNumber(3)
  set reps($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReps() => $_has(2);
  @$pb.TagNumber(3)
  void clearReps() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get actualWeight => $_getN(3);
  @$pb.TagNumber(4)
  set actualWeight($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasActualWeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearActualWeight() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get completedAt => $_getI64(4);
  @$pb.TagNumber(5)
  set completedAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCompletedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearCompletedAt() => $_clearField(5);
}

class StartSetIntent extends $pb.GeneratedMessage {
  factory StartSetIntent({
    $core.String? workoutId,
    $core.String? setId,
    $fixnum.Int64? startedAt,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (setId != null) result.setId = setId;
    if (startedAt != null) result.startedAt = startedAt;
    return result;
  }

  StartSetIntent._();

  factory StartSetIntent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartSetIntent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartSetIntent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'setId')
    ..aInt64(3, _omitFieldNames ? '' : 'startedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSetIntent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSetIntent copyWith(void Function(StartSetIntent) updates) =>
      super.copyWith((message) => updates(message as StartSetIntent))
          as StartSetIntent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartSetIntent create() => StartSetIntent._();
  @$core.override
  StartSetIntent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StartSetIntent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartSetIntent>(create);
  static StartSetIntent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get setId => $_getSZ(1);
  @$pb.TagNumber(2)
  set setId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSetId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get startedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set startedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartedAt() => $_clearField(3);
}

/// A tap on a set's circle on the watch: the phone does what a tap on its own
/// circle does (start, done, a rep off, undone).
class TapSetIntent extends $pb.GeneratedMessage {
  factory TapSetIntent({
    $core.String? workoutId,
    $core.String? setId,
    $fixnum.Int64? tappedAt,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (setId != null) result.setId = setId;
    if (tappedAt != null) result.tappedAt = tappedAt;
    return result;
  }

  TapSetIntent._();

  factory TapSetIntent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TapSetIntent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TapSetIntent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'setId')
    ..aInt64(3, _omitFieldNames ? '' : 'tappedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TapSetIntent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TapSetIntent copyWith(void Function(TapSetIntent) updates) =>
      super.copyWith((message) => updates(message as TapSetIntent))
          as TapSetIntent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TapSetIntent create() => TapSetIntent._();
  @$core.override
  TapSetIntent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TapSetIntent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TapSetIntent>(create);
  static TapSetIntent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get setId => $_getSZ(1);
  @$pb.TagNumber(2)
  set setId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSetId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get tappedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set tappedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTappedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearTappedAt() => $_clearField(3);
}

class EndWorkoutIntent extends $pb.GeneratedMessage {
  factory EndWorkoutIntent({
    $core.String? workoutId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    return result;
  }

  EndWorkoutIntent._();

  factory EndWorkoutIntent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EndWorkoutIntent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EndWorkoutIntent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EndWorkoutIntent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EndWorkoutIntent copyWith(void Function(EndWorkoutIntent) updates) =>
      super.copyWith((message) => updates(message as EndWorkoutIntent))
          as EndWorkoutIntent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EndWorkoutIntent create() => EndWorkoutIntent._();
  @$core.override
  EndWorkoutIntent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EndWorkoutIntent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EndWorkoutIntent>(create);
  static EndWorkoutIntent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);
}

enum WearIntent_Intent { completeSet, endWorkout, startSet, tapSet, notSet }

class WearIntent extends $pb.GeneratedMessage {
  factory WearIntent({
    $core.String? intentId,
    $fixnum.Int64? sentAt,
    CompleteSetIntent? completeSet,
    EndWorkoutIntent? endWorkout,
    StartSetIntent? startSet,
    TapSetIntent? tapSet,
  }) {
    final result = create();
    if (intentId != null) result.intentId = intentId;
    if (sentAt != null) result.sentAt = sentAt;
    if (completeSet != null) result.completeSet = completeSet;
    if (endWorkout != null) result.endWorkout = endWorkout;
    if (startSet != null) result.startSet = startSet;
    if (tapSet != null) result.tapSet = tapSet;
    return result;
  }

  WearIntent._();

  factory WearIntent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearIntent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, WearIntent_Intent> _WearIntent_IntentByTag =
      {
    11: WearIntent_Intent.completeSet,
    13: WearIntent_Intent.endWorkout,
    17: WearIntent_Intent.startSet,
    19: WearIntent_Intent.tapSet,
    0: WearIntent_Intent.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearIntent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [11, 13, 17, 19])
    ..aOS(1, _omitFieldNames ? '' : 'intentId')
    ..aInt64(2, _omitFieldNames ? '' : 'sentAt')
    ..aOM<CompleteSetIntent>(11, _omitFieldNames ? '' : 'completeSet',
        subBuilder: CompleteSetIntent.create)
    ..aOM<EndWorkoutIntent>(13, _omitFieldNames ? '' : 'endWorkout',
        subBuilder: EndWorkoutIntent.create)
    ..aOM<StartSetIntent>(17, _omitFieldNames ? '' : 'startSet',
        subBuilder: StartSetIntent.create)
    ..aOM<TapSetIntent>(19, _omitFieldNames ? '' : 'tapSet',
        subBuilder: TapSetIntent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearIntent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearIntent copyWith(void Function(WearIntent) updates) =>
      super.copyWith((message) => updates(message as WearIntent)) as WearIntent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearIntent create() => WearIntent._();
  @$core.override
  WearIntent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearIntent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearIntent>(create);
  static WearIntent? _defaultInstance;

  @$pb.TagNumber(11)
  @$pb.TagNumber(13)
  @$pb.TagNumber(17)
  @$pb.TagNumber(19)
  WearIntent_Intent whichIntent() => _WearIntent_IntentByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(11)
  @$pb.TagNumber(13)
  @$pb.TagNumber(17)
  @$pb.TagNumber(19)
  void clearIntent() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get intentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set intentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIntentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearIntentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sentAt => $_getI64(1);
  @$pb.TagNumber(2)
  set sentAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSentAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearSentAt() => $_clearField(2);

  @$pb.TagNumber(11)
  CompleteSetIntent get completeSet => $_getN(2);
  @$pb.TagNumber(11)
  set completeSet(CompleteSetIntent value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCompleteSet() => $_has(2);
  @$pb.TagNumber(11)
  void clearCompleteSet() => $_clearField(11);
  @$pb.TagNumber(11)
  CompleteSetIntent ensureCompleteSet() => $_ensure(2);

  @$pb.TagNumber(13)
  EndWorkoutIntent get endWorkout => $_getN(3);
  @$pb.TagNumber(13)
  set endWorkout(EndWorkoutIntent value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasEndWorkout() => $_has(3);
  @$pb.TagNumber(13)
  void clearEndWorkout() => $_clearField(13);
  @$pb.TagNumber(13)
  EndWorkoutIntent ensureEndWorkout() => $_ensure(3);

  @$pb.TagNumber(17)
  StartSetIntent get startSet => $_getN(4);
  @$pb.TagNumber(17)
  set startSet(StartSetIntent value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasStartSet() => $_has(4);
  @$pb.TagNumber(17)
  void clearStartSet() => $_clearField(17);
  @$pb.TagNumber(17)
  StartSetIntent ensureStartSet() => $_ensure(4);

  @$pb.TagNumber(19)
  TapSetIntent get tapSet => $_getN(5);
  @$pb.TagNumber(19)
  set tapSet(TapSetIntent value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasTapSet() => $_has(5);
  @$pb.TagNumber(19)
  void clearTapSet() => $_clearField(19);
  @$pb.TagNumber(19)
  TapSetIntent ensureTapSet() => $_ensure(5);
}

class HeartRateSample extends $pb.GeneratedMessage {
  factory HeartRateSample({
    $fixnum.Int64? sampledAt,
    $core.double? bpm,
    HeartRateAvailability? availability,
  }) {
    final result = create();
    if (sampledAt != null) result.sampledAt = sampledAt;
    if (bpm != null) result.bpm = bpm;
    if (availability != null) result.availability = availability;
    return result;
  }

  HeartRateSample._();

  factory HeartRateSample.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HeartRateSample.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HeartRateSample',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'sampledAt')
    ..aD(2, _omitFieldNames ? '' : 'bpm', fieldType: $pb.PbFieldType.OF)
    ..aE<HeartRateAvailability>(3, _omitFieldNames ? '' : 'availability',
        enumValues: HeartRateAvailability.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeartRateSample clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeartRateSample copyWith(void Function(HeartRateSample) updates) =>
      super.copyWith((message) => updates(message as HeartRateSample))
          as HeartRateSample;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeartRateSample create() => HeartRateSample._();
  @$core.override
  HeartRateSample createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeartRateSample getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HeartRateSample>(create);
  static HeartRateSample? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sampledAt => $_getI64(0);
  @$pb.TagNumber(1)
  set sampledAt($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSampledAt() => $_has(0);
  @$pb.TagNumber(1)
  void clearSampledAt() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get bpm => $_getN(1);
  @$pb.TagNumber(2)
  set bpm($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBpm() => $_has(1);
  @$pb.TagNumber(2)
  void clearBpm() => $_clearField(2);

  @$pb.TagNumber(3)
  HeartRateAvailability get availability => $_getN(2);
  @$pb.TagNumber(3)
  set availability(HeartRateAvailability value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAvailability() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvailability() => $_clearField(3);
}

class WearSensorBatch extends $pb.GeneratedMessage {
  factory WearSensorBatch({
    $core.String? batchId,
    $core.String? workoutId,
    $fixnum.Int64? sentAt,
    $core.Iterable<HeartRateSample>? heartRateSamples,
  }) {
    final result = create();
    if (batchId != null) result.batchId = batchId;
    if (workoutId != null) result.workoutId = workoutId;
    if (sentAt != null) result.sentAt = sentAt;
    if (heartRateSamples != null)
      result.heartRateSamples.addAll(heartRateSamples);
    return result;
  }

  WearSensorBatch._();

  factory WearSensorBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearSensorBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearSensorBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'batchId')
    ..aOS(2, _omitFieldNames ? '' : 'workoutId')
    ..aInt64(3, _omitFieldNames ? '' : 'sentAt')
    ..pPM<HeartRateSample>(4, _omitFieldNames ? '' : 'heartRateSamples',
        subBuilder: HeartRateSample.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearSensorBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearSensorBatch copyWith(void Function(WearSensorBatch) updates) =>
      super.copyWith((message) => updates(message as WearSensorBatch))
          as WearSensorBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearSensorBatch create() => WearSensorBatch._();
  @$core.override
  WearSensorBatch createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearSensorBatch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearSensorBatch>(create);
  static WearSensorBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get batchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set batchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set workoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get sentAt => $_getI64(2);
  @$pb.TagNumber(3)
  set sentAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSentAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearSentAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<HeartRateSample> get heartRateSamples => $_getList(3);
}

class WearSensorBatchAck extends $pb.GeneratedMessage {
  factory WearSensorBatchAck({
    $core.String? batchId,
    $core.String? workoutId,
    $fixnum.Int64? receivedAt,
  }) {
    final result = create();
    if (batchId != null) result.batchId = batchId;
    if (workoutId != null) result.workoutId = workoutId;
    if (receivedAt != null) result.receivedAt = receivedAt;
    return result;
  }

  WearSensorBatchAck._();

  factory WearSensorBatchAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearSensorBatchAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearSensorBatchAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'batchId')
    ..aOS(2, _omitFieldNames ? '' : 'workoutId')
    ..aInt64(3, _omitFieldNames ? '' : 'receivedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearSensorBatchAck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearSensorBatchAck copyWith(void Function(WearSensorBatchAck) updates) =>
      super.copyWith((message) => updates(message as WearSensorBatchAck))
          as WearSensorBatchAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearSensorBatchAck create() => WearSensorBatchAck._();
  @$core.override
  WearSensorBatchAck createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearSensorBatchAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearSensorBatchAck>(create);
  static WearSensorBatchAck? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get batchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set batchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set workoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get receivedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set receivedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReceivedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearReceivedAt() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
