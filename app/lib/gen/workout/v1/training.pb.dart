// This is a generated file - do not edit.
//
// Generated from workout/v1/training.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'training.pbenum.dart';
import 'workout.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'training.pbenum.dart';

/// A measurement. Strength uses weight+reps; other modalities can populate
/// duration/distance later without a schema change.
class Measure extends $pb.GeneratedMessage {
  factory Measure({
    $core.double? weight,
    $core.int? reps,
    $core.int? durationS,
    $core.double? distanceM,
  }) {
    final result = create();
    if (weight != null) result.weight = weight;
    if (reps != null) result.reps = reps;
    if (durationS != null) result.durationS = durationS;
    if (distanceM != null) result.distanceM = distanceM;
    return result;
  }

  Measure._();

  factory Measure.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Measure.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Measure',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'weight')
    ..aI(2, _omitFieldNames ? '' : 'reps')
    ..aI(3, _omitFieldNames ? '' : 'durationS')
    ..aD(4, _omitFieldNames ? '' : 'distanceM')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Measure clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Measure copyWith(void Function(Measure) updates) =>
      super.copyWith((message) => updates(message as Measure)) as Measure;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Measure create() => Measure._();
  @$core.override
  Measure createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Measure getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Measure>(create);
  static Measure? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get weight => $_getN(0);
  @$pb.TagNumber(1)
  set weight($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWeight() => $_has(0);
  @$pb.TagNumber(1)
  void clearWeight() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get reps => $_getIZ(1);
  @$pb.TagNumber(2)
  set reps($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReps() => $_has(1);
  @$pb.TagNumber(2)
  void clearReps() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get durationS => $_getIZ(2);
  @$pb.TagNumber(3)
  set durationS($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationS() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationS() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get distanceM => $_getN(3);
  @$pb.TagNumber(4)
  set distanceM($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDistanceM() => $_has(3);
  @$pb.TagNumber(4)
  void clearDistanceM() => $_clearField(4);
}

class SetView extends $pb.GeneratedMessage {
  factory SetView({
    $core.String? id,
    $core.String? blockId,
    $core.int? order,
    $1.Exercise? exercise,
    SetRole? role,
    Measure? proposed,
    Measure? target,
    Measure? entry,
    $core.bool? hasEntry_9,
    $core.bool? skipped,
    $core.bool? isAmrap,
    $core.String? instruction,
    $core.bool? countsTowardProgram,
    $core.String? slotKey,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (blockId != null) result.blockId = blockId;
    if (order != null) result.order = order;
    if (exercise != null) result.exercise = exercise;
    if (role != null) result.role = role;
    if (proposed != null) result.proposed = proposed;
    if (target != null) result.target = target;
    if (entry != null) result.entry = entry;
    if (hasEntry_9 != null) result.hasEntry_9 = hasEntry_9;
    if (skipped != null) result.skipped = skipped;
    if (isAmrap != null) result.isAmrap = isAmrap;
    if (instruction != null) result.instruction = instruction;
    if (countsTowardProgram != null)
      result.countsTowardProgram = countsTowardProgram;
    if (slotKey != null) result.slotKey = slotKey;
    return result;
  }

  SetView._();

  factory SetView.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetView.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetView',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'blockId')
    ..aI(3, _omitFieldNames ? '' : 'order')
    ..aE<$1.Exercise>(4, _omitFieldNames ? '' : 'exercise',
        enumValues: $1.Exercise.values)
    ..aE<SetRole>(5, _omitFieldNames ? '' : 'role', enumValues: SetRole.values)
    ..aOM<Measure>(6, _omitFieldNames ? '' : 'proposed',
        subBuilder: Measure.create)
    ..aOM<Measure>(7, _omitFieldNames ? '' : 'target',
        subBuilder: Measure.create)
    ..aOM<Measure>(8, _omitFieldNames ? '' : 'entry',
        subBuilder: Measure.create)
    ..aOB(9, _omitFieldNames ? '' : 'hasEntry')
    ..aOB(10, _omitFieldNames ? '' : 'skipped')
    ..aOB(11, _omitFieldNames ? '' : 'isAmrap')
    ..aOS(12, _omitFieldNames ? '' : 'instruction')
    ..aOB(13, _omitFieldNames ? '' : 'countsTowardProgram')
    ..aOS(14, _omitFieldNames ? '' : 'slotKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetView clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetView copyWith(void Function(SetView) updates) =>
      super.copyWith((message) => updates(message as SetView)) as SetView;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetView create() => SetView._();
  @$core.override
  SetView createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetView getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetView>(create);
  static SetView? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get blockId => $_getSZ(1);
  @$pb.TagNumber(2)
  set blockId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBlockId() => $_has(1);
  @$pb.TagNumber(2)
  void clearBlockId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get order => $_getIZ(2);
  @$pb.TagNumber(3)
  set order($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOrder() => $_has(2);
  @$pb.TagNumber(3)
  void clearOrder() => $_clearField(3);

  @$pb.TagNumber(4)
  $1.Exercise get exercise => $_getN(3);
  @$pb.TagNumber(4)
  set exercise($1.Exercise value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasExercise() => $_has(3);
  @$pb.TagNumber(4)
  void clearExercise() => $_clearField(4);

  @$pb.TagNumber(5)
  SetRole get role => $_getN(4);
  @$pb.TagNumber(5)
  set role(SetRole value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRole() => $_has(4);
  @$pb.TagNumber(5)
  void clearRole() => $_clearField(5);

  @$pb.TagNumber(6)
  Measure get proposed => $_getN(5);
  @$pb.TagNumber(6)
  set proposed(Measure value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasProposed() => $_has(5);
  @$pb.TagNumber(6)
  void clearProposed() => $_clearField(6);
  @$pb.TagNumber(6)
  Measure ensureProposed() => $_ensure(5);

  @$pb.TagNumber(7)
  Measure get target => $_getN(6);
  @$pb.TagNumber(7)
  set target(Measure value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasTarget() => $_has(6);
  @$pb.TagNumber(7)
  void clearTarget() => $_clearField(7);
  @$pb.TagNumber(7)
  Measure ensureTarget() => $_ensure(6);

  @$pb.TagNumber(8)
  Measure get entry => $_getN(7);
  @$pb.TagNumber(8)
  set entry(Measure value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasEntry() => $_has(7);
  @$pb.TagNumber(8)
  void clearEntry() => $_clearField(8);
  @$pb.TagNumber(8)
  Measure ensureEntry() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.bool get hasEntry_9 => $_getBF(8);
  @$pb.TagNumber(9)
  set hasEntry_9($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHasEntry_9() => $_has(8);
  @$pb.TagNumber(9)
  void clearHasEntry_9() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get skipped => $_getBF(9);
  @$pb.TagNumber(10)
  set skipped($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSkipped() => $_has(9);
  @$pb.TagNumber(10)
  void clearSkipped() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get isAmrap => $_getBF(10);
  @$pb.TagNumber(11)
  set isAmrap($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasIsAmrap() => $_has(10);
  @$pb.TagNumber(11)
  void clearIsAmrap() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get instruction => $_getSZ(11);
  @$pb.TagNumber(12)
  set instruction($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasInstruction() => $_has(11);
  @$pb.TagNumber(12)
  void clearInstruction() => $_clearField(12);

  /// True once this set counts toward program progression (came from a regime
  /// prescription). Freestyle sets are false and CloseWorkout ignores them.
  @$pb.TagNumber(13)
  $core.bool get countsTowardProgram => $_getBF(12);
  @$pb.TagNumber(13)
  set countsTowardProgram($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCountsTowardProgram() => $_has(12);
  @$pb.TagNumber(13)
  void clearCountsTowardProgram() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get slotKey => $_getSZ(13);
  @$pb.TagNumber(14)
  set slotKey($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSlotKey() => $_has(13);
  @$pb.TagNumber(14)
  void clearSlotKey() => $_clearField(14);
}

class BlockView extends $pb.GeneratedMessage {
  factory BlockView({
    $core.String? id,
    $core.int? order,
    $core.String? name,
    $core.bool? interleaveWarmups,
    $1.RestConfig? restConfig,
    $core.Iterable<SetView>? sets,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (order != null) result.order = order;
    if (name != null) result.name = name;
    if (interleaveWarmups != null) result.interleaveWarmups = interleaveWarmups;
    if (restConfig != null) result.restConfig = restConfig;
    if (sets != null) result.sets.addAll(sets);
    return result;
  }

  BlockView._();

  factory BlockView.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BlockView.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockView',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'order')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOB(4, _omitFieldNames ? '' : 'interleaveWarmups')
    ..aOM<$1.RestConfig>(5, _omitFieldNames ? '' : 'restConfig',
        subBuilder: $1.RestConfig.create)
    ..pPM<SetView>(6, _omitFieldNames ? '' : 'sets', subBuilder: SetView.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockView clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockView copyWith(void Function(BlockView) updates) =>
      super.copyWith((message) => updates(message as BlockView)) as BlockView;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockView create() => BlockView._();
  @$core.override
  BlockView createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BlockView getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockView>(create);
  static BlockView? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get order => $_getIZ(1);
  @$pb.TagNumber(2)
  set order($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOrder() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrder() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get interleaveWarmups => $_getBF(3);
  @$pb.TagNumber(4)
  set interleaveWarmups($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInterleaveWarmups() => $_has(3);
  @$pb.TagNumber(4)
  void clearInterleaveWarmups() => $_clearField(4);

  @$pb.TagNumber(5)
  $1.RestConfig get restConfig => $_getN(4);
  @$pb.TagNumber(5)
  set restConfig($1.RestConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRestConfig() => $_has(4);
  @$pb.TagNumber(5)
  void clearRestConfig() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.RestConfig ensureRestConfig() => $_ensure(4);

  @$pb.TagNumber(6)
  $pb.PbList<SetView> get sets => $_getList(5);
}

class WorkoutView extends $pb.GeneratedMessage {
  factory WorkoutView({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? startTime,
    $fixnum.Int64? endTime,
    $core.String? sessionId,
    $core.Iterable<BlockView>? blocks,
    $core.String? activeSetId,
    $fixnum.Int64? activeStartedAt,
    $core.bool? fromProgram,
    $core.bool? closed,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (sessionId != null) result.sessionId = sessionId;
    if (blocks != null) result.blocks.addAll(blocks);
    if (activeSetId != null) result.activeSetId = activeSetId;
    if (activeStartedAt != null) result.activeStartedAt = activeStartedAt;
    if (fromProgram != null) result.fromProgram = fromProgram;
    if (closed != null) result.closed = closed;
    return result;
  }

  WorkoutView._();

  factory WorkoutView.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutView.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutView',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'startTime')
    ..aInt64(4, _omitFieldNames ? '' : 'endTime')
    ..aOS(5, _omitFieldNames ? '' : 'sessionId')
    ..pPM<BlockView>(6, _omitFieldNames ? '' : 'blocks',
        subBuilder: BlockView.create)
    ..aOS(7, _omitFieldNames ? '' : 'activeSetId')
    ..aInt64(8, _omitFieldNames ? '' : 'activeStartedAt')
    ..aOB(9, _omitFieldNames ? '' : 'fromProgram')
    ..aOB(10, _omitFieldNames ? '' : 'closed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutView clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutView copyWith(void Function(WorkoutView) updates) =>
      super.copyWith((message) => updates(message as WorkoutView))
          as WorkoutView;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutView create() => WorkoutView._();
  @$core.override
  WorkoutView createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutView getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutView>(create);
  static WorkoutView? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get startTime => $_getI64(2);
  @$pb.TagNumber(3)
  set startTime($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartTime() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get endTime => $_getI64(3);
  @$pb.TagNumber(4)
  set endTime($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEndTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndTime() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sessionId => $_getSZ(4);
  @$pb.TagNumber(5)
  set sessionId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSessionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearSessionId() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<BlockView> get blocks => $_getList(5);

  @$pb.TagNumber(7)
  $core.String get activeSetId => $_getSZ(6);
  @$pb.TagNumber(7)
  set activeSetId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasActiveSetId() => $_has(6);
  @$pb.TagNumber(7)
  void clearActiveSetId() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get activeStartedAt => $_getI64(7);
  @$pb.TagNumber(8)
  set activeStartedAt($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasActiveStartedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearActiveStartedAt() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get fromProgram => $_getBF(8);
  @$pb.TagNumber(9)
  set fromProgram($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasFromProgram() => $_has(8);
  @$pb.TagNumber(9)
  void clearFromProgram() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get closed => $_getBF(9);
  @$pb.TagNumber(10)
  set closed($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasClosed() => $_has(9);
  @$pb.TagNumber(10)
  void clearClosed() => $_clearField(10);
}

/// A whole block to add, with its planned sets. Used by CreateWorkout and AddBlock.
class BlockPlan extends $pb.GeneratedMessage {
  factory BlockPlan({
    $core.String? name,
    $core.bool? interleaveWarmups,
    $1.RestConfig? restConfig,
    $core.Iterable<SetPlan>? sets,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (interleaveWarmups != null) result.interleaveWarmups = interleaveWarmups;
    if (restConfig != null) result.restConfig = restConfig;
    if (sets != null) result.sets.addAll(sets);
    return result;
  }

  BlockPlan._();

  factory BlockPlan.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BlockPlan.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BlockPlan',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOB(2, _omitFieldNames ? '' : 'interleaveWarmups')
    ..aOM<$1.RestConfig>(3, _omitFieldNames ? '' : 'restConfig',
        subBuilder: $1.RestConfig.create)
    ..pPM<SetPlan>(4, _omitFieldNames ? '' : 'sets', subBuilder: SetPlan.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockPlan clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BlockPlan copyWith(void Function(BlockPlan) updates) =>
      super.copyWith((message) => updates(message as BlockPlan)) as BlockPlan;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockPlan create() => BlockPlan._();
  @$core.override
  BlockPlan createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BlockPlan getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockPlan>(create);
  static BlockPlan? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get interleaveWarmups => $_getBF(1);
  @$pb.TagNumber(2)
  set interleaveWarmups($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInterleaveWarmups() => $_has(1);
  @$pb.TagNumber(2)
  void clearInterleaveWarmups() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.RestConfig get restConfig => $_getN(2);
  @$pb.TagNumber(3)
  set restConfig($1.RestConfig value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRestConfig() => $_has(2);
  @$pb.TagNumber(3)
  void clearRestConfig() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.RestConfig ensureRestConfig() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<SetPlan> get sets => $_getList(3);
}

class SetPlan extends $pb.GeneratedMessage {
  factory SetPlan({
    $1.Exercise? exercise,
    SetRole? role,
    Measure? target,
    $core.bool? isAmrap,
    $core.String? instruction,
    $core.bool? countsTowardProgram,
    $core.String? slotKey,
    $core.String? clientId,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (role != null) result.role = role;
    if (target != null) result.target = target;
    if (isAmrap != null) result.isAmrap = isAmrap;
    if (instruction != null) result.instruction = instruction;
    if (countsTowardProgram != null)
      result.countsTowardProgram = countsTowardProgram;
    if (slotKey != null) result.slotKey = slotKey;
    if (clientId != null) result.clientId = clientId;
    return result;
  }

  SetPlan._();

  factory SetPlan.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetPlan.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetPlan',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<$1.Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: $1.Exercise.values)
    ..aE<SetRole>(2, _omitFieldNames ? '' : 'role', enumValues: SetRole.values)
    ..aOM<Measure>(3, _omitFieldNames ? '' : 'target',
        subBuilder: Measure.create)
    ..aOB(4, _omitFieldNames ? '' : 'isAmrap')
    ..aOS(5, _omitFieldNames ? '' : 'instruction')
    ..aOB(6, _omitFieldNames ? '' : 'countsTowardProgram')
    ..aOS(7, _omitFieldNames ? '' : 'slotKey')
    ..aOS(8, _omitFieldNames ? '' : 'clientId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPlan clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPlan copyWith(void Function(SetPlan) updates) =>
      super.copyWith((message) => updates(message as SetPlan)) as SetPlan;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetPlan create() => SetPlan._();
  @$core.override
  SetPlan createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetPlan getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetPlan>(create);
  static SetPlan? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise($1.Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  SetRole get role => $_getN(1);
  @$pb.TagNumber(2)
  set role(SetRole value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRole() => $_has(1);
  @$pb.TagNumber(2)
  void clearRole() => $_clearField(2);

  @$pb.TagNumber(3)
  Measure get target => $_getN(2);
  @$pb.TagNumber(3)
  set target(Measure value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasTarget() => $_has(2);
  @$pb.TagNumber(3)
  void clearTarget() => $_clearField(3);
  @$pb.TagNumber(3)
  Measure ensureTarget() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.bool get isAmrap => $_getBF(3);
  @$pb.TagNumber(4)
  set isAmrap($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsAmrap() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsAmrap() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get instruction => $_getSZ(4);
  @$pb.TagNumber(5)
  set instruction($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInstruction() => $_has(4);
  @$pb.TagNumber(5)
  void clearInstruction() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get countsTowardProgram => $_getBF(5);
  @$pb.TagNumber(6)
  set countsTowardProgram($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCountsTowardProgram() => $_has(5);
  @$pb.TagNumber(6)
  void clearCountsTowardProgram() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get slotKey => $_getSZ(6);
  @$pb.TagNumber(7)
  set slotKey($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSlotKey() => $_has(6);
  @$pb.TagNumber(7)
  void clearSlotKey() => $_clearField(7);

  /// Optional stable id so the client can address the set before the server
  /// round-trips (offline-first). Server generates one if empty.
  @$pb.TagNumber(8)
  $core.String get clientId => $_getSZ(7);
  @$pb.TagNumber(8)
  set clientId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasClientId() => $_has(7);
  @$pb.TagNumber(8)
  void clearClientId() => $_clearField(8);
}

class EditTarget extends $pb.GeneratedMessage {
  factory EditTarget({
    $core.String? setId,
    Measure? target,
  }) {
    final result = create();
    if (setId != null) result.setId = setId;
    if (target != null) result.target = target;
    return result;
  }

  EditTarget._();

  factory EditTarget.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EditTarget.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditTarget',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'setId')
    ..aOM<Measure>(2, _omitFieldNames ? '' : 'target',
        subBuilder: Measure.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditTarget clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditTarget copyWith(void Function(EditTarget) updates) =>
      super.copyWith((message) => updates(message as EditTarget)) as EditTarget;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EditTarget create() => EditTarget._();
  @$core.override
  EditTarget createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EditTarget getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditTarget>(create);
  static EditTarget? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get setId => $_getSZ(0);
  @$pb.TagNumber(1)
  set setId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetId() => $_clearField(1);

  @$pb.TagNumber(2)
  Measure get target => $_getN(1);
  @$pb.TagNumber(2)
  set target(Measure value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTarget() => $_has(1);
  @$pb.TagNumber(2)
  void clearTarget() => $_clearField(2);
  @$pb.TagNumber(2)
  Measure ensureTarget() => $_ensure(1);
}

class AddSetOp extends $pb.GeneratedMessage {
  factory AddSetOp({
    $core.String? blockId,
    SetPlan? set,
  }) {
    final result = create();
    if (blockId != null) result.blockId = blockId;
    if (set != null) result.set = set;
    return result;
  }

  AddSetOp._();

  factory AddSetOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddSetOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddSetOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'blockId')
    ..aOM<SetPlan>(2, _omitFieldNames ? '' : 'set', subBuilder: SetPlan.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddSetOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddSetOp copyWith(void Function(AddSetOp) updates) =>
      super.copyWith((message) => updates(message as AddSetOp)) as AddSetOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddSetOp create() => AddSetOp._();
  @$core.override
  AddSetOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddSetOp getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AddSetOp>(create);
  static AddSetOp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get blockId => $_getSZ(0);
  @$pb.TagNumber(1)
  set blockId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBlockId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlockId() => $_clearField(1);

  @$pb.TagNumber(2)
  SetPlan get set => $_getN(1);
  @$pb.TagNumber(2)
  set set(SetPlan value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSet() => $_has(1);
  @$pb.TagNumber(2)
  void clearSet() => $_clearField(2);
  @$pb.TagNumber(2)
  SetPlan ensureSet() => $_ensure(1);
}

class RemoveSetOp extends $pb.GeneratedMessage {
  factory RemoveSetOp({
    $core.String? setId,
  }) {
    final result = create();
    if (setId != null) result.setId = setId;
    return result;
  }

  RemoveSetOp._();

  factory RemoveSetOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveSetOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveSetOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'setId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveSetOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveSetOp copyWith(void Function(RemoveSetOp) updates) =>
      super.copyWith((message) => updates(message as RemoveSetOp))
          as RemoveSetOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveSetOp create() => RemoveSetOp._();
  @$core.override
  RemoveSetOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveSetOp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveSetOp>(create);
  static RemoveSetOp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get setId => $_getSZ(0);
  @$pb.TagNumber(1)
  set setId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetId() => $_clearField(1);
}

class SkipSetOp extends $pb.GeneratedMessage {
  factory SkipSetOp({
    $core.String? setId,
    $core.bool? skipped,
  }) {
    final result = create();
    if (setId != null) result.setId = setId;
    if (skipped != null) result.skipped = skipped;
    return result;
  }

  SkipSetOp._();

  factory SkipSetOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SkipSetOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SkipSetOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'setId')
    ..aOB(2, _omitFieldNames ? '' : 'skipped')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkipSetOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkipSetOp copyWith(void Function(SkipSetOp) updates) =>
      super.copyWith((message) => updates(message as SkipSetOp)) as SkipSetOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SkipSetOp create() => SkipSetOp._();
  @$core.override
  SkipSetOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SkipSetOp getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SkipSetOp>(create);
  static SkipSetOp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get setId => $_getSZ(0);
  @$pb.TagNumber(1)
  set setId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get skipped => $_getBF(1);
  @$pb.TagNumber(2)
  set skipped($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSkipped() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkipped() => $_clearField(2);
}

class StartSetOp extends $pb.GeneratedMessage {
  factory StartSetOp({
    $core.String? setId,
    $fixnum.Int64? at,
  }) {
    final result = create();
    if (setId != null) result.setId = setId;
    if (at != null) result.at = at;
    return result;
  }

  StartSetOp._();

  factory StartSetOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartSetOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartSetOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'setId')
    ..aInt64(2, _omitFieldNames ? '' : 'at')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSetOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSetOp copyWith(void Function(StartSetOp) updates) =>
      super.copyWith((message) => updates(message as StartSetOp)) as StartSetOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartSetOp create() => StartSetOp._();
  @$core.override
  StartSetOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StartSetOp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartSetOp>(create);
  static StartSetOp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get setId => $_getSZ(0);
  @$pb.TagNumber(1)
  set setId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get at => $_getI64(1);
  @$pb.TagNumber(2)
  set at($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearAt() => $_clearField(2);
}

class LogSetOp extends $pb.GeneratedMessage {
  factory LogSetOp({
    $core.String? setId,
    Measure? result,
    $fixnum.Int64? performedAt,
  }) {
    final result$ = create();
    if (setId != null) result$.setId = setId;
    if (result != null) result$.result = result;
    if (performedAt != null) result$.performedAt = performedAt;
    return result$;
  }

  LogSetOp._();

  factory LogSetOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogSetOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogSetOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'setId')
    ..aOM<Measure>(2, _omitFieldNames ? '' : 'result',
        subBuilder: Measure.create)
    ..aInt64(3, _omitFieldNames ? '' : 'performedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogSetOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogSetOp copyWith(void Function(LogSetOp) updates) =>
      super.copyWith((message) => updates(message as LogSetOp)) as LogSetOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogSetOp create() => LogSetOp._();
  @$core.override
  LogSetOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogSetOp getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogSetOp>(create);
  static LogSetOp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get setId => $_getSZ(0);
  @$pb.TagNumber(1)
  set setId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetId() => $_clearField(1);

  @$pb.TagNumber(2)
  Measure get result => $_getN(1);
  @$pb.TagNumber(2)
  set result(Measure value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResult() => $_has(1);
  @$pb.TagNumber(2)
  void clearResult() => $_clearField(2);
  @$pb.TagNumber(2)
  Measure ensureResult() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get performedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set performedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPerformedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearPerformedAt() => $_clearField(3);
}

class CorrectEntryOp extends $pb.GeneratedMessage {
  factory CorrectEntryOp({
    $core.String? setId,
    Measure? result,
    $fixnum.Int64? performedAt,
  }) {
    final result$ = create();
    if (setId != null) result$.setId = setId;
    if (result != null) result$.result = result;
    if (performedAt != null) result$.performedAt = performedAt;
    return result$;
  }

  CorrectEntryOp._();

  factory CorrectEntryOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CorrectEntryOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CorrectEntryOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'setId')
    ..aOM<Measure>(2, _omitFieldNames ? '' : 'result',
        subBuilder: Measure.create)
    ..aInt64(3, _omitFieldNames ? '' : 'performedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CorrectEntryOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CorrectEntryOp copyWith(void Function(CorrectEntryOp) updates) =>
      super.copyWith((message) => updates(message as CorrectEntryOp))
          as CorrectEntryOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CorrectEntryOp create() => CorrectEntryOp._();
  @$core.override
  CorrectEntryOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CorrectEntryOp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CorrectEntryOp>(create);
  static CorrectEntryOp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get setId => $_getSZ(0);
  @$pb.TagNumber(1)
  set setId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetId() => $_clearField(1);

  @$pb.TagNumber(2)
  Measure get result => $_getN(1);
  @$pb.TagNumber(2)
  set result(Measure value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasResult() => $_has(1);
  @$pb.TagNumber(2)
  void clearResult() => $_clearField(2);
  @$pb.TagNumber(2)
  Measure ensureResult() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get performedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set performedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPerformedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearPerformedAt() => $_clearField(3);
}

class DeleteEntryOp extends $pb.GeneratedMessage {
  factory DeleteEntryOp({
    $core.String? setId,
  }) {
    final result = create();
    if (setId != null) result.setId = setId;
    return result;
  }

  DeleteEntryOp._();

  factory DeleteEntryOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteEntryOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteEntryOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'setId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteEntryOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteEntryOp copyWith(void Function(DeleteEntryOp) updates) =>
      super.copyWith((message) => updates(message as DeleteEntryOp))
          as DeleteEntryOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteEntryOp create() => DeleteEntryOp._();
  @$core.override
  DeleteEntryOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteEntryOp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteEntryOp>(create);
  static DeleteEntryOp? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get setId => $_getSZ(0);
  @$pb.TagNumber(1)
  set setId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetId() => $_clearField(1);
}

class ReorderBlocksOp extends $pb.GeneratedMessage {
  factory ReorderBlocksOp({
    $core.Iterable<$core.String>? blockIds,
  }) {
    final result = create();
    if (blockIds != null) result.blockIds.addAll(blockIds);
    return result;
  }

  ReorderBlocksOp._();

  factory ReorderBlocksOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderBlocksOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderBlocksOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'blockIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderBlocksOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderBlocksOp copyWith(void Function(ReorderBlocksOp) updates) =>
      super.copyWith((message) => updates(message as ReorderBlocksOp))
          as ReorderBlocksOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderBlocksOp create() => ReorderBlocksOp._();
  @$core.override
  ReorderBlocksOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderBlocksOp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderBlocksOp>(create);
  static ReorderBlocksOp? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get blockIds => $_getList(0);
}

class AddBlockOp extends $pb.GeneratedMessage {
  factory AddBlockOp({
    BlockPlan? block,
  }) {
    final result = create();
    if (block != null) result.block = block;
    return result;
  }

  AddBlockOp._();

  factory AddBlockOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddBlockOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddBlockOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<BlockPlan>(1, _omitFieldNames ? '' : 'block',
        subBuilder: BlockPlan.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddBlockOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddBlockOp copyWith(void Function(AddBlockOp) updates) =>
      super.copyWith((message) => updates(message as AddBlockOp)) as AddBlockOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddBlockOp create() => AddBlockOp._();
  @$core.override
  AddBlockOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddBlockOp getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddBlockOp>(create);
  static AddBlockOp? _defaultInstance;

  @$pb.TagNumber(1)
  BlockPlan get block => $_getN(0);
  @$pb.TagNumber(1)
  set block(BlockPlan value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBlock() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlock() => $_clearField(1);
  @$pb.TagNumber(1)
  BlockPlan ensureBlock() => $_ensure(0);
}

enum WorkoutOp_Op {
  editTarget,
  addSet,
  removeSet,
  skipSet,
  startSet,
  logSet,
  correctEntry,
  deleteEntry,
  reorderBlocks,
  addBlock,
  notSet
}

class WorkoutOp extends $pb.GeneratedMessage {
  factory WorkoutOp({
    EditTarget? editTarget,
    AddSetOp? addSet,
    RemoveSetOp? removeSet,
    SkipSetOp? skipSet,
    StartSetOp? startSet,
    LogSetOp? logSet,
    CorrectEntryOp? correctEntry,
    DeleteEntryOp? deleteEntry,
    ReorderBlocksOp? reorderBlocks,
    AddBlockOp? addBlock,
  }) {
    final result = create();
    if (editTarget != null) result.editTarget = editTarget;
    if (addSet != null) result.addSet = addSet;
    if (removeSet != null) result.removeSet = removeSet;
    if (skipSet != null) result.skipSet = skipSet;
    if (startSet != null) result.startSet = startSet;
    if (logSet != null) result.logSet = logSet;
    if (correctEntry != null) result.correctEntry = correctEntry;
    if (deleteEntry != null) result.deleteEntry = deleteEntry;
    if (reorderBlocks != null) result.reorderBlocks = reorderBlocks;
    if (addBlock != null) result.addBlock = addBlock;
    return result;
  }

  WorkoutOp._();

  factory WorkoutOp.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutOp.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, WorkoutOp_Op> _WorkoutOp_OpByTag = {
    1: WorkoutOp_Op.editTarget,
    2: WorkoutOp_Op.addSet,
    3: WorkoutOp_Op.removeSet,
    4: WorkoutOp_Op.skipSet,
    5: WorkoutOp_Op.startSet,
    6: WorkoutOp_Op.logSet,
    7: WorkoutOp_Op.correctEntry,
    8: WorkoutOp_Op.deleteEntry,
    9: WorkoutOp_Op.reorderBlocks,
    10: WorkoutOp_Op.addBlock,
    0: WorkoutOp_Op.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutOp',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    ..aOM<EditTarget>(1, _omitFieldNames ? '' : 'editTarget',
        subBuilder: EditTarget.create)
    ..aOM<AddSetOp>(2, _omitFieldNames ? '' : 'addSet',
        subBuilder: AddSetOp.create)
    ..aOM<RemoveSetOp>(3, _omitFieldNames ? '' : 'removeSet',
        subBuilder: RemoveSetOp.create)
    ..aOM<SkipSetOp>(4, _omitFieldNames ? '' : 'skipSet',
        subBuilder: SkipSetOp.create)
    ..aOM<StartSetOp>(5, _omitFieldNames ? '' : 'startSet',
        subBuilder: StartSetOp.create)
    ..aOM<LogSetOp>(6, _omitFieldNames ? '' : 'logSet',
        subBuilder: LogSetOp.create)
    ..aOM<CorrectEntryOp>(7, _omitFieldNames ? '' : 'correctEntry',
        subBuilder: CorrectEntryOp.create)
    ..aOM<DeleteEntryOp>(8, _omitFieldNames ? '' : 'deleteEntry',
        subBuilder: DeleteEntryOp.create)
    ..aOM<ReorderBlocksOp>(9, _omitFieldNames ? '' : 'reorderBlocks',
        subBuilder: ReorderBlocksOp.create)
    ..aOM<AddBlockOp>(10, _omitFieldNames ? '' : 'addBlock',
        subBuilder: AddBlockOp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutOp clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutOp copyWith(void Function(WorkoutOp) updates) =>
      super.copyWith((message) => updates(message as WorkoutOp)) as WorkoutOp;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutOp create() => WorkoutOp._();
  @$core.override
  WorkoutOp createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutOp getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorkoutOp>(create);
  static WorkoutOp? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  WorkoutOp_Op whichOp() => _WorkoutOp_OpByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  void clearOp() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  EditTarget get editTarget => $_getN(0);
  @$pb.TagNumber(1)
  set editTarget(EditTarget value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasEditTarget() => $_has(0);
  @$pb.TagNumber(1)
  void clearEditTarget() => $_clearField(1);
  @$pb.TagNumber(1)
  EditTarget ensureEditTarget() => $_ensure(0);

  @$pb.TagNumber(2)
  AddSetOp get addSet => $_getN(1);
  @$pb.TagNumber(2)
  set addSet(AddSetOp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAddSet() => $_has(1);
  @$pb.TagNumber(2)
  void clearAddSet() => $_clearField(2);
  @$pb.TagNumber(2)
  AddSetOp ensureAddSet() => $_ensure(1);

  @$pb.TagNumber(3)
  RemoveSetOp get removeSet => $_getN(2);
  @$pb.TagNumber(3)
  set removeSet(RemoveSetOp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRemoveSet() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemoveSet() => $_clearField(3);
  @$pb.TagNumber(3)
  RemoveSetOp ensureRemoveSet() => $_ensure(2);

  @$pb.TagNumber(4)
  SkipSetOp get skipSet => $_getN(3);
  @$pb.TagNumber(4)
  set skipSet(SkipSetOp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSkipSet() => $_has(3);
  @$pb.TagNumber(4)
  void clearSkipSet() => $_clearField(4);
  @$pb.TagNumber(4)
  SkipSetOp ensureSkipSet() => $_ensure(3);

  @$pb.TagNumber(5)
  StartSetOp get startSet => $_getN(4);
  @$pb.TagNumber(5)
  set startSet(StartSetOp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStartSet() => $_has(4);
  @$pb.TagNumber(5)
  void clearStartSet() => $_clearField(5);
  @$pb.TagNumber(5)
  StartSetOp ensureStartSet() => $_ensure(4);

  @$pb.TagNumber(6)
  LogSetOp get logSet => $_getN(5);
  @$pb.TagNumber(6)
  set logSet(LogSetOp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasLogSet() => $_has(5);
  @$pb.TagNumber(6)
  void clearLogSet() => $_clearField(6);
  @$pb.TagNumber(6)
  LogSetOp ensureLogSet() => $_ensure(5);

  @$pb.TagNumber(7)
  CorrectEntryOp get correctEntry => $_getN(6);
  @$pb.TagNumber(7)
  set correctEntry(CorrectEntryOp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCorrectEntry() => $_has(6);
  @$pb.TagNumber(7)
  void clearCorrectEntry() => $_clearField(7);
  @$pb.TagNumber(7)
  CorrectEntryOp ensureCorrectEntry() => $_ensure(6);

  @$pb.TagNumber(8)
  DeleteEntryOp get deleteEntry => $_getN(7);
  @$pb.TagNumber(8)
  set deleteEntry(DeleteEntryOp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasDeleteEntry() => $_has(7);
  @$pb.TagNumber(8)
  void clearDeleteEntry() => $_clearField(8);
  @$pb.TagNumber(8)
  DeleteEntryOp ensureDeleteEntry() => $_ensure(7);

  @$pb.TagNumber(9)
  ReorderBlocksOp get reorderBlocks => $_getN(8);
  @$pb.TagNumber(9)
  set reorderBlocks(ReorderBlocksOp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasReorderBlocks() => $_has(8);
  @$pb.TagNumber(9)
  void clearReorderBlocks() => $_clearField(9);
  @$pb.TagNumber(9)
  ReorderBlocksOp ensureReorderBlocks() => $_ensure(8);

  @$pb.TagNumber(10)
  AddBlockOp get addBlock => $_getN(9);
  @$pb.TagNumber(10)
  set addBlock(AddBlockOp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasAddBlock() => $_has(9);
  @$pb.TagNumber(10)
  void clearAddBlock() => $_clearField(10);
  @$pb.TagNumber(10)
  AddBlockOp ensureAddBlock() => $_ensure(9);
}

class CreateWorkoutRequest extends $pb.GeneratedMessage {
  factory CreateWorkoutRequest({
    $core.String? name,
    $core.Iterable<BlockPlan>? blocks,
    $fixnum.Int64? startedAt,
    $core.bool? fromProgram,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (blocks != null) result.blocks.addAll(blocks);
    if (startedAt != null) result.startedAt = startedAt;
    if (fromProgram != null) result.fromProgram = fromProgram;
    return result;
  }

  CreateWorkoutRequest._();

  factory CreateWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..pPM<BlockPlan>(2, _omitFieldNames ? '' : 'blocks',
        subBuilder: BlockPlan.create)
    ..aInt64(3, _omitFieldNames ? '' : 'startedAt')
    ..aOB(4, _omitFieldNames ? '' : 'fromProgram')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateWorkoutRequest copyWith(void Function(CreateWorkoutRequest) updates) =>
      super.copyWith((message) => updates(message as CreateWorkoutRequest))
          as CreateWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateWorkoutRequest create() => CreateWorkoutRequest._();
  @$core.override
  CreateWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateWorkoutRequest>(create);
  static CreateWorkoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<BlockPlan> get blocks => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get startedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set startedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get fromProgram => $_getBF(3);
  @$pb.TagNumber(4)
  set fromProgram($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFromProgram() => $_has(3);
  @$pb.TagNumber(4)
  void clearFromProgram() => $_clearField(4);
}

class MutateWorkoutRequest extends $pb.GeneratedMessage {
  factory MutateWorkoutRequest({
    $core.String? workoutId,
    $core.Iterable<WorkoutOp>? ops,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (ops != null) result.ops.addAll(ops);
    return result;
  }

  MutateWorkoutRequest._();

  factory MutateWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MutateWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MutateWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..pPM<WorkoutOp>(2, _omitFieldNames ? '' : 'ops',
        subBuilder: WorkoutOp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MutateWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MutateWorkoutRequest copyWith(void Function(MutateWorkoutRequest) updates) =>
      super.copyWith((message) => updates(message as MutateWorkoutRequest))
          as MutateWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MutateWorkoutRequest create() => MutateWorkoutRequest._();
  @$core.override
  MutateWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MutateWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MutateWorkoutRequest>(create);
  static MutateWorkoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<WorkoutOp> get ops => $_getList(1);
}

class GetWorkoutV2Request extends $pb.GeneratedMessage {
  factory GetWorkoutV2Request({
    $core.String? workoutId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    return result;
  }

  GetWorkoutV2Request._();

  factory GetWorkoutV2Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetWorkoutV2Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetWorkoutV2Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutV2Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutV2Request copyWith(void Function(GetWorkoutV2Request) updates) =>
      super.copyWith((message) => updates(message as GetWorkoutV2Request))
          as GetWorkoutV2Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetWorkoutV2Request create() => GetWorkoutV2Request._();
  @$core.override
  GetWorkoutV2Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetWorkoutV2Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetWorkoutV2Request>(create);
  static GetWorkoutV2Request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);
}

class CloseWorkoutRequest extends $pb.GeneratedMessage {
  factory CloseWorkoutRequest({
    $core.String? workoutId,
    $fixnum.Int64? endedAt,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (endedAt != null) result.endedAt = endedAt;
    return result;
  }

  CloseWorkoutRequest._();

  factory CloseWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CloseWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloseWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aInt64(2, _omitFieldNames ? '' : 'endedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseWorkoutRequest copyWith(void Function(CloseWorkoutRequest) updates) =>
      super.copyWith((message) => updates(message as CloseWorkoutRequest))
          as CloseWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CloseWorkoutRequest create() => CloseWorkoutRequest._();
  @$core.override
  CloseWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CloseWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloseWorkoutRequest>(create);
  static CloseWorkoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get endedAt => $_getI64(1);
  @$pb.TagNumber(2)
  set endedAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndedAt() => $_clearField(2);
}

class CloseWorkoutResponse extends $pb.GeneratedMessage {
  factory CloseWorkoutResponse({
    WorkoutView? workout,
    $core.Iterable<ProgressionChange>? changes,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
    if (changes != null) result.changes.addAll(changes);
    return result;
  }

  CloseWorkoutResponse._();

  factory CloseWorkoutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CloseWorkoutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloseWorkoutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<WorkoutView>(1, _omitFieldNames ? '' : 'workout',
        subBuilder: WorkoutView.create)
    ..pPM<ProgressionChange>(2, _omitFieldNames ? '' : 'changes',
        subBuilder: ProgressionChange.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseWorkoutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseWorkoutResponse copyWith(void Function(CloseWorkoutResponse) updates) =>
      super.copyWith((message) => updates(message as CloseWorkoutResponse))
          as CloseWorkoutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CloseWorkoutResponse create() => CloseWorkoutResponse._();
  @$core.override
  CloseWorkoutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CloseWorkoutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloseWorkoutResponse>(create);
  static CloseWorkoutResponse? _defaultInstance;

  @$pb.TagNumber(1)
  WorkoutView get workout => $_getN(0);
  @$pb.TagNumber(1)
  set workout(WorkoutView value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkout() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkout() => $_clearField(1);
  @$pb.TagNumber(1)
  WorkoutView ensureWorkout() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<ProgressionChange> get changes => $_getList(1);
}

/// One trainer decision for one lift, for the UI rationale and the history chart.
class ProgressionChange extends $pb.GeneratedMessage {
  factory ProgressionChange({
    $1.Exercise? exercise,
    $core.String? slotKey,
    $core.String? reason,
    $core.double? fromWeight,
    $core.double? toWeight,
    $core.String? headline,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (slotKey != null) result.slotKey = slotKey;
    if (reason != null) result.reason = reason;
    if (fromWeight != null) result.fromWeight = fromWeight;
    if (toWeight != null) result.toWeight = toWeight;
    if (headline != null) result.headline = headline;
    return result;
  }

  ProgressionChange._();

  factory ProgressionChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgressionChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressionChange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<$1.Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: $1.Exercise.values)
    ..aOS(2, _omitFieldNames ? '' : 'slotKey')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..aD(4, _omitFieldNames ? '' : 'fromWeight')
    ..aD(5, _omitFieldNames ? '' : 'toWeight')
    ..aOS(6, _omitFieldNames ? '' : 'headline')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressionChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressionChange copyWith(void Function(ProgressionChange) updates) =>
      super.copyWith((message) => updates(message as ProgressionChange))
          as ProgressionChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProgressionChange create() => ProgressionChange._();
  @$core.override
  ProgressionChange createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgressionChange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgressionChange>(create);
  static ProgressionChange? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise($1.Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get slotKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set slotKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSlotKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearSlotKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get fromWeight => $_getN(3);
  @$pb.TagNumber(4)
  set fromWeight($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFromWeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearFromWeight() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get toWeight => $_getN(4);
  @$pb.TagNumber(5)
  set toWeight($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasToWeight() => $_has(4);
  @$pb.TagNumber(5)
  void clearToWeight() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get headline => $_getSZ(5);
  @$pb.TagNumber(6)
  set headline($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeadline() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeadline() => $_clearField(6);
}

class GetProgressionHistoryRequest extends $pb.GeneratedMessage {
  factory GetProgressionHistoryRequest({
    $core.String? slotKey,
    $core.int? limit,
  }) {
    final result = create();
    if (slotKey != null) result.slotKey = slotKey;
    if (limit != null) result.limit = limit;
    return result;
  }

  GetProgressionHistoryRequest._();

  factory GetProgressionHistoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProgressionHistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProgressionHistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'slotKey')
    ..aI(2, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProgressionHistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProgressionHistoryRequest copyWith(
          void Function(GetProgressionHistoryRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetProgressionHistoryRequest))
          as GetProgressionHistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProgressionHistoryRequest create() =>
      GetProgressionHistoryRequest._();
  @$core.override
  GetProgressionHistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProgressionHistoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProgressionHistoryRequest>(create);
  static GetProgressionHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get slotKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set slotKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSlotKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSlotKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);
}

class ProgressionHistoryEntry extends $pb.GeneratedMessage {
  factory ProgressionHistoryEntry({
    $core.String? workoutId,
    $fixnum.Int64? at,
    $1.Exercise? exercise,
    $core.String? slotKey,
    $core.String? reason,
    $core.double? fromWeight,
    $core.double? toWeight,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (at != null) result.at = at;
    if (exercise != null) result.exercise = exercise;
    if (slotKey != null) result.slotKey = slotKey;
    if (reason != null) result.reason = reason;
    if (fromWeight != null) result.fromWeight = fromWeight;
    if (toWeight != null) result.toWeight = toWeight;
    return result;
  }

  ProgressionHistoryEntry._();

  factory ProgressionHistoryEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgressionHistoryEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressionHistoryEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aInt64(2, _omitFieldNames ? '' : 'at')
    ..aE<$1.Exercise>(3, _omitFieldNames ? '' : 'exercise',
        enumValues: $1.Exercise.values)
    ..aOS(4, _omitFieldNames ? '' : 'slotKey')
    ..aOS(5, _omitFieldNames ? '' : 'reason')
    ..aD(6, _omitFieldNames ? '' : 'fromWeight')
    ..aD(7, _omitFieldNames ? '' : 'toWeight')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressionHistoryEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressionHistoryEntry copyWith(
          void Function(ProgressionHistoryEntry) updates) =>
      super.copyWith((message) => updates(message as ProgressionHistoryEntry))
          as ProgressionHistoryEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProgressionHistoryEntry create() => ProgressionHistoryEntry._();
  @$core.override
  ProgressionHistoryEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgressionHistoryEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgressionHistoryEntry>(create);
  static ProgressionHistoryEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get at => $_getI64(1);
  @$pb.TagNumber(2)
  set at($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.Exercise get exercise => $_getN(2);
  @$pb.TagNumber(3)
  set exercise($1.Exercise value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExercise() => $_has(2);
  @$pb.TagNumber(3)
  void clearExercise() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get slotKey => $_getSZ(3);
  @$pb.TagNumber(4)
  set slotKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSlotKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearSlotKey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get reason => $_getSZ(4);
  @$pb.TagNumber(5)
  set reason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReason() => $_has(4);
  @$pb.TagNumber(5)
  void clearReason() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get fromWeight => $_getN(5);
  @$pb.TagNumber(6)
  set fromWeight($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFromWeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearFromWeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get toWeight => $_getN(6);
  @$pb.TagNumber(7)
  set toWeight($core.double value) => $_setDouble(6, value);
  @$pb.TagNumber(7)
  $core.bool hasToWeight() => $_has(6);
  @$pb.TagNumber(7)
  void clearToWeight() => $_clearField(7);
}

class GetProgressionHistoryResponse extends $pb.GeneratedMessage {
  factory GetProgressionHistoryResponse({
    $core.Iterable<ProgressionHistoryEntry>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  GetProgressionHistoryResponse._();

  factory GetProgressionHistoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProgressionHistoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProgressionHistoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<ProgressionHistoryEntry>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: ProgressionHistoryEntry.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProgressionHistoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProgressionHistoryResponse copyWith(
          void Function(GetProgressionHistoryResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetProgressionHistoryResponse))
          as GetProgressionHistoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProgressionHistoryResponse create() =>
      GetProgressionHistoryResponse._();
  @$core.override
  GetProgressionHistoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProgressionHistoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProgressionHistoryResponse>(create);
  static GetProgressionHistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ProgressionHistoryEntry> get entries => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
