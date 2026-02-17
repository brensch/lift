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

class WearStatusCard extends $pb.GeneratedMessage {
  factory WearStatusCard({
    $core.String? sideLabel,
    $core.String? header,
    $core.String? stateLabel,
    $core.String? timerText,
    $core.bool? isComplete,
    $0.ProposedSet? displaySet,
  }) {
    final result = create();
    if (sideLabel != null) result.sideLabel = sideLabel;
    if (header != null) result.header = header;
    if (stateLabel != null) result.stateLabel = stateLabel;
    if (timerText != null) result.timerText = timerText;
    if (isComplete != null) result.isComplete = isComplete;
    if (displaySet != null) result.displaySet = displaySet;
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
    ..aOS(1, _omitFieldNames ? '' : 'sideLabel')
    ..aOS(2, _omitFieldNames ? '' : 'header')
    ..aOS(3, _omitFieldNames ? '' : 'stateLabel')
    ..aOS(4, _omitFieldNames ? '' : 'timerText')
    ..aOB(5, _omitFieldNames ? '' : 'isComplete')
    ..aOM<$0.ProposedSet>(6, _omitFieldNames ? '' : 'displaySet',
        subBuilder: $0.ProposedSet.create)
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

  @$pb.TagNumber(1)
  $core.String get sideLabel => $_getSZ(0);
  @$pb.TagNumber(1)
  set sideLabel($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSideLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearSideLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get header => $_getSZ(1);
  @$pb.TagNumber(2)
  set header($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHeader() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeader() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get stateLabel => $_getSZ(2);
  @$pb.TagNumber(3)
  set stateLabel($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStateLabel() => $_has(2);
  @$pb.TagNumber(3)
  void clearStateLabel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get timerText => $_getSZ(3);
  @$pb.TagNumber(4)
  set timerText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTimerText() => $_has(3);
  @$pb.TagNumber(4)
  void clearTimerText() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get isComplete => $_getBF(4);
  @$pb.TagNumber(5)
  set isComplete($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsComplete() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsComplete() => $_clearField(5);

  @$pb.TagNumber(6)
  $0.ProposedSet get displaySet => $_getN(5);
  @$pb.TagNumber(6)
  set displaySet($0.ProposedSet value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDisplaySet() => $_has(5);
  @$pb.TagNumber(6)
  void clearDisplaySet() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.ProposedSet ensureDisplaySet() => $_ensure(5);
}

class WearAction extends $pb.GeneratedMessage {
  factory WearAction({
    WearActionType? type,
    WearActionStyle? style,
    $core.String? label,
    $core.String? setId,
    $core.int? reps,
    $core.double? actualWeight,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (style != null) result.style = style;
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
    ..aE<WearActionStyle>(2, _omitFieldNames ? '' : 'style',
        enumValues: WearActionStyle.values)
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

  @$pb.TagNumber(2)
  WearActionStyle get style => $_getN(1);
  @$pb.TagNumber(2)
  set style(WearActionStyle value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStyle() => $_has(1);
  @$pb.TagNumber(2)
  void clearStyle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get label => $_getSZ(2);
  @$pb.TagNumber(3)
  set label($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLabel() => $_has(2);
  @$pb.TagNumber(3)
  void clearLabel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get setId => $_getSZ(3);
  @$pb.TagNumber(4)
  set setId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSetId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSetId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get reps => $_getIZ(4);
  @$pb.TagNumber(5)
  set reps($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReps() => $_has(4);
  @$pb.TagNumber(5)
  void clearReps() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get actualWeight => $_getN(5);
  @$pb.TagNumber(6)
  set actualWeight($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasActualWeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearActualWeight() => $_clearField(6);
}

class WearWorkoutSnapshot extends $pb.GeneratedMessage {
  factory WearWorkoutSnapshot({
    $core.String? workoutId,
    $fixnum.Int64? emittedAt,
    $0.WorkoutState? state,
    $fixnum.Int64? workoutStartTime,
    $fixnum.Int64? activeStartedAt,
    $fixnum.Int64? restUntil,
    $fixnum.Int64? lastRestEnd,
    $core.String? elapsedText,
    WearStatusCard? youCard,
    WearStatusCard? groupCard,
    $core.Iterable<WearAction>? actions,
    WearCompletionSummary? completionSummary,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (emittedAt != null) result.emittedAt = emittedAt;
    if (state != null) result.state = state;
    if (workoutStartTime != null) result.workoutStartTime = workoutStartTime;
    if (activeStartedAt != null) result.activeStartedAt = activeStartedAt;
    if (restUntil != null) result.restUntil = restUntil;
    if (lastRestEnd != null) result.lastRestEnd = lastRestEnd;
    if (elapsedText != null) result.elapsedText = elapsedText;
    if (youCard != null) result.youCard = youCard;
    if (groupCard != null) result.groupCard = groupCard;
    if (actions != null) result.actions.addAll(actions);
    if (completionSummary != null) result.completionSummary = completionSummary;
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
    ..aInt64(5, _omitFieldNames ? '' : 'activeStartedAt')
    ..aInt64(6, _omitFieldNames ? '' : 'restUntil')
    ..aInt64(7, _omitFieldNames ? '' : 'lastRestEnd')
    ..aOS(8, _omitFieldNames ? '' : 'elapsedText')
    ..aOM<WearStatusCard>(9, _omitFieldNames ? '' : 'youCard',
        subBuilder: WearStatusCard.create)
    ..aOM<WearStatusCard>(10, _omitFieldNames ? '' : 'groupCard',
        subBuilder: WearStatusCard.create)
    ..pPM<WearAction>(11, _omitFieldNames ? '' : 'actions',
        subBuilder: WearAction.create)
    ..aOM<WearCompletionSummary>(12, _omitFieldNames ? '' : 'completionSummary',
        subBuilder: WearCompletionSummary.create)
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

  @$pb.TagNumber(5)
  $fixnum.Int64 get activeStartedAt => $_getI64(4);
  @$pb.TagNumber(5)
  set activeStartedAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasActiveStartedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearActiveStartedAt() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get restUntil => $_getI64(5);
  @$pb.TagNumber(6)
  set restUntil($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRestUntil() => $_has(5);
  @$pb.TagNumber(6)
  void clearRestUntil() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get lastRestEnd => $_getI64(6);
  @$pb.TagNumber(7)
  set lastRestEnd($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLastRestEnd() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastRestEnd() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get elapsedText => $_getSZ(7);
  @$pb.TagNumber(8)
  set elapsedText($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasElapsedText() => $_has(7);
  @$pb.TagNumber(8)
  void clearElapsedText() => $_clearField(8);

  @$pb.TagNumber(9)
  WearStatusCard get youCard => $_getN(8);
  @$pb.TagNumber(9)
  set youCard(WearStatusCard value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasYouCard() => $_has(8);
  @$pb.TagNumber(9)
  void clearYouCard() => $_clearField(9);
  @$pb.TagNumber(9)
  WearStatusCard ensureYouCard() => $_ensure(8);

  @$pb.TagNumber(10)
  WearStatusCard get groupCard => $_getN(9);
  @$pb.TagNumber(10)
  set groupCard(WearStatusCard value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasGroupCard() => $_has(9);
  @$pb.TagNumber(10)
  void clearGroupCard() => $_clearField(10);
  @$pb.TagNumber(10)
  WearStatusCard ensureGroupCard() => $_ensure(9);

  @$pb.TagNumber(11)
  $pb.PbList<WearAction> get actions => $_getList(10);

  @$pb.TagNumber(12)
  WearCompletionSummary get completionSummary => $_getN(11);
  @$pb.TagNumber(12)
  set completionSummary(WearCompletionSummary value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCompletionSummary() => $_has(11);
  @$pb.TagNumber(12)
  void clearCompletionSummary() => $_clearField(12);
  @$pb.TagNumber(12)
  WearCompletionSummary ensureCompletionSummary() => $_ensure(11);
}

class WearCompletionSummary extends $pb.GeneratedMessage {
  factory WearCompletionSummary({
    $core.String? durationText,
    $core.int? completedWorkingSets,
    $core.int? totalVolumeLb,
  }) {
    final result = create();
    if (durationText != null) result.durationText = durationText;
    if (completedWorkingSets != null)
      result.completedWorkingSets = completedWorkingSets;
    if (totalVolumeLb != null) result.totalVolumeLb = totalVolumeLb;
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
}

class StartSetIntent extends $pb.GeneratedMessage {
  factory StartSetIntent({
    $core.String? workoutId,
    $core.String? setId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (setId != null) result.setId = setId;
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

class SkipWarmupIntent extends $pb.GeneratedMessage {
  factory SkipWarmupIntent({
    $core.String? workoutId,
    $core.String? setId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (setId != null) result.setId = setId;
    return result;
  }

  SkipWarmupIntent._();

  factory SkipWarmupIntent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SkipWarmupIntent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SkipWarmupIntent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'setId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkipWarmupIntent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkipWarmupIntent copyWith(void Function(SkipWarmupIntent) updates) =>
      super.copyWith((message) => updates(message as SkipWarmupIntent))
          as SkipWarmupIntent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SkipWarmupIntent create() => SkipWarmupIntent._();
  @$core.override
  SkipWarmupIntent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SkipWarmupIntent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SkipWarmupIntent>(create);
  static SkipWarmupIntent? _defaultInstance;

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

enum WearIntent_Intent { startSet, completeSet, skipWarmup, endWorkout, notSet }

class WearIntent extends $pb.GeneratedMessage {
  factory WearIntent({
    $core.String? intentId,
    $fixnum.Int64? sentAt,
    StartSetIntent? startSet,
    CompleteSetIntent? completeSet,
    SkipWarmupIntent? skipWarmup,
    EndWorkoutIntent? endWorkout,
  }) {
    final result = create();
    if (intentId != null) result.intentId = intentId;
    if (sentAt != null) result.sentAt = sentAt;
    if (startSet != null) result.startSet = startSet;
    if (completeSet != null) result.completeSet = completeSet;
    if (skipWarmup != null) result.skipWarmup = skipWarmup;
    if (endWorkout != null) result.endWorkout = endWorkout;
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
    10: WearIntent_Intent.startSet,
    11: WearIntent_Intent.completeSet,
    12: WearIntent_Intent.skipWarmup,
    13: WearIntent_Intent.endWorkout,
    0: WearIntent_Intent.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearIntent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13])
    ..aOS(1, _omitFieldNames ? '' : 'intentId')
    ..aInt64(2, _omitFieldNames ? '' : 'sentAt')
    ..aOM<StartSetIntent>(10, _omitFieldNames ? '' : 'startSet',
        subBuilder: StartSetIntent.create)
    ..aOM<CompleteSetIntent>(11, _omitFieldNames ? '' : 'completeSet',
        subBuilder: CompleteSetIntent.create)
    ..aOM<SkipWarmupIntent>(12, _omitFieldNames ? '' : 'skipWarmup',
        subBuilder: SkipWarmupIntent.create)
    ..aOM<EndWorkoutIntent>(13, _omitFieldNames ? '' : 'endWorkout',
        subBuilder: EndWorkoutIntent.create)
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

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  WearIntent_Intent whichIntent() => _WearIntent_IntentByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
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

  @$pb.TagNumber(10)
  StartSetIntent get startSet => $_getN(2);
  @$pb.TagNumber(10)
  set startSet(StartSetIntent value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasStartSet() => $_has(2);
  @$pb.TagNumber(10)
  void clearStartSet() => $_clearField(10);
  @$pb.TagNumber(10)
  StartSetIntent ensureStartSet() => $_ensure(2);

  @$pb.TagNumber(11)
  CompleteSetIntent get completeSet => $_getN(3);
  @$pb.TagNumber(11)
  set completeSet(CompleteSetIntent value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCompleteSet() => $_has(3);
  @$pb.TagNumber(11)
  void clearCompleteSet() => $_clearField(11);
  @$pb.TagNumber(11)
  CompleteSetIntent ensureCompleteSet() => $_ensure(3);

  @$pb.TagNumber(12)
  SkipWarmupIntent get skipWarmup => $_getN(4);
  @$pb.TagNumber(12)
  set skipWarmup(SkipWarmupIntent value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasSkipWarmup() => $_has(4);
  @$pb.TagNumber(12)
  void clearSkipWarmup() => $_clearField(12);
  @$pb.TagNumber(12)
  SkipWarmupIntent ensureSkipWarmup() => $_ensure(4);

  @$pb.TagNumber(13)
  EndWorkoutIntent get endWorkout => $_getN(5);
  @$pb.TagNumber(13)
  set endWorkout(EndWorkoutIntent value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasEndWorkout() => $_has(5);
  @$pb.TagNumber(13)
  void clearEndWorkout() => $_clearField(13);
  @$pb.TagNumber(13)
  EndWorkoutIntent ensureEndWorkout() => $_ensure(5);
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
    $core.String? workoutId,
    $core.Iterable<HeartRateSample>? heartRateSamples,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
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
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..pPM<HeartRateSample>(2, _omitFieldNames ? '' : 'heartRateSamples',
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
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<HeartRateSample> get heartRateSamples => $_getList(1);
}

enum PhoneToWearEnvelope_Payload { snapshot, notSet }

class PhoneToWearEnvelope extends $pb.GeneratedMessage {
  factory PhoneToWearEnvelope({
    WearWorkoutSnapshot? snapshot,
  }) {
    final result = create();
    if (snapshot != null) result.snapshot = snapshot;
    return result;
  }

  PhoneToWearEnvelope._();

  factory PhoneToWearEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PhoneToWearEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, PhoneToWearEnvelope_Payload>
      _PhoneToWearEnvelope_PayloadByTag = {
    1: PhoneToWearEnvelope_Payload.snapshot,
    0: PhoneToWearEnvelope_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PhoneToWearEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1])
    ..aOM<WearWorkoutSnapshot>(1, _omitFieldNames ? '' : 'snapshot',
        subBuilder: WearWorkoutSnapshot.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhoneToWearEnvelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PhoneToWearEnvelope copyWith(void Function(PhoneToWearEnvelope) updates) =>
      super.copyWith((message) => updates(message as PhoneToWearEnvelope))
          as PhoneToWearEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PhoneToWearEnvelope create() => PhoneToWearEnvelope._();
  @$core.override
  PhoneToWearEnvelope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PhoneToWearEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PhoneToWearEnvelope>(create);
  static PhoneToWearEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  PhoneToWearEnvelope_Payload whichPayload() =>
      _PhoneToWearEnvelope_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  WearWorkoutSnapshot get snapshot => $_getN(0);
  @$pb.TagNumber(1)
  set snapshot(WearWorkoutSnapshot value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSnapshot() => $_has(0);
  @$pb.TagNumber(1)
  void clearSnapshot() => $_clearField(1);
  @$pb.TagNumber(1)
  WearWorkoutSnapshot ensureSnapshot() => $_ensure(0);
}

enum WearToPhoneEnvelope_Payload { intent, sensorBatch, notSet }

class WearToPhoneEnvelope extends $pb.GeneratedMessage {
  factory WearToPhoneEnvelope({
    WearIntent? intent,
    WearSensorBatch? sensorBatch,
  }) {
    final result = create();
    if (intent != null) result.intent = intent;
    if (sensorBatch != null) result.sensorBatch = sensorBatch;
    return result;
  }

  WearToPhoneEnvelope._();

  factory WearToPhoneEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WearToPhoneEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, WearToPhoneEnvelope_Payload>
      _WearToPhoneEnvelope_PayloadByTag = {
    1: WearToPhoneEnvelope_Payload.intent,
    2: WearToPhoneEnvelope_Payload.sensorBatch,
    0: WearToPhoneEnvelope_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WearToPhoneEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOM<WearIntent>(1, _omitFieldNames ? '' : 'intent',
        subBuilder: WearIntent.create)
    ..aOM<WearSensorBatch>(2, _omitFieldNames ? '' : 'sensorBatch',
        subBuilder: WearSensorBatch.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearToPhoneEnvelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WearToPhoneEnvelope copyWith(void Function(WearToPhoneEnvelope) updates) =>
      super.copyWith((message) => updates(message as WearToPhoneEnvelope))
          as WearToPhoneEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WearToPhoneEnvelope create() => WearToPhoneEnvelope._();
  @$core.override
  WearToPhoneEnvelope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WearToPhoneEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WearToPhoneEnvelope>(create);
  static WearToPhoneEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  WearToPhoneEnvelope_Payload whichPayload() =>
      _WearToPhoneEnvelope_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  WearIntent get intent => $_getN(0);
  @$pb.TagNumber(1)
  set intent(WearIntent value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasIntent() => $_has(0);
  @$pb.TagNumber(1)
  void clearIntent() => $_clearField(1);
  @$pb.TagNumber(1)
  WearIntent ensureIntent() => $_ensure(0);

  @$pb.TagNumber(2)
  WearSensorBatch get sensorBatch => $_getN(1);
  @$pb.TagNumber(2)
  set sensorBatch(WearSensorBatch value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSensorBatch() => $_has(1);
  @$pb.TagNumber(2)
  void clearSensorBatch() => $_clearField(2);
  @$pb.TagNumber(2)
  WearSensorBatch ensureSensorBatch() => $_ensure(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
