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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'workout.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'workout.pbenum.dart';

class User extends $pb.GeneratedMessage {
  factory User({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? createdAt,
    $core.String? profileEmoji,
    $core.String? profileColorHex,
    $core.double? bodyWeightKg,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (createdAt != null) result.createdAt = createdAt;
    if (profileEmoji != null) result.profileEmoji = profileEmoji;
    if (profileColorHex != null) result.profileColorHex = profileColorHex;
    if (bodyWeightKg != null) result.bodyWeightKg = bodyWeightKg;
    return result;
  }

  User._();

  factory User.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory User.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'User',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'createdAt')
    ..aOS(4, _omitFieldNames ? '' : 'profileEmoji')
    ..aOS(5, _omitFieldNames ? '' : 'profileColorHex')
    ..aD(6, _omitFieldNames ? '' : 'bodyWeightKg',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  User copyWith(void Function(User) updates) =>
      super.copyWith((message) => updates(message as User)) as User;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static User create() => User._();
  @$core.override
  User createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static User getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<User>(create);
  static User? _defaultInstance;

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
  $fixnum.Int64 get createdAt => $_getI64(2);
  @$pb.TagNumber(3)
  set createdAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get profileEmoji => $_getSZ(3);
  @$pb.TagNumber(4)
  set profileEmoji($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProfileEmoji() => $_has(3);
  @$pb.TagNumber(4)
  void clearProfileEmoji() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get profileColorHex => $_getSZ(4);
  @$pb.TagNumber(5)
  set profileColorHex($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasProfileColorHex() => $_has(4);
  @$pb.TagNumber(5)
  void clearProfileColorHex() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get bodyWeightKg => $_getN(5);
  @$pb.TagNumber(6)
  set bodyWeightKg($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBodyWeightKg() => $_has(5);
  @$pb.TagNumber(6)
  void clearBodyWeightKg() => $_clearField(6);
}

class Workout extends $pb.GeneratedMessage {
  factory Workout({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? startTime,
    $fixnum.Int64? endTime,
    $core.String? sessionId,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  Workout._();

  factory Workout.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Workout.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Workout',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'startTime')
    ..aInt64(4, _omitFieldNames ? '' : 'endTime')
    ..aOS(5, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Workout clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Workout copyWith(void Function(Workout) updates) =>
      super.copyWith((message) => updates(message as Workout)) as Workout;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Workout create() => Workout._();
  @$core.override
  Workout createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Workout getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Workout>(create);
  static Workout? _defaultInstance;

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
}

class ExerciseTypeConfig extends $pb.GeneratedMessage {
  factory ExerciseTypeConfig({
    Exercise? exercise,
    $core.double? startWeight,
    $core.double? endWeight,
    $core.int? reps,
    $core.bool? includeWarmup,
    RestConfig? restConfig,
    $core.bool? lastSetAmrap,
    $core.Iterable<WorkingSetSpec>? workingSets,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (startWeight != null) result.startWeight = startWeight;
    if (endWeight != null) result.endWeight = endWeight;
    if (reps != null) result.reps = reps;
    if (includeWarmup != null) result.includeWarmup = includeWarmup;
    if (restConfig != null) result.restConfig = restConfig;
    if (lastSetAmrap != null) result.lastSetAmrap = lastSetAmrap;
    if (workingSets != null) result.workingSets.addAll(workingSets);
    return result;
  }

  ExerciseTypeConfig._();

  factory ExerciseTypeConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseTypeConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseTypeConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..aD(2, _omitFieldNames ? '' : 'startWeight', fieldType: $pb.PbFieldType.OF)
    ..aD(3, _omitFieldNames ? '' : 'endWeight', fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'reps')
    ..aOB(5, _omitFieldNames ? '' : 'includeWarmup')
    ..aOM<RestConfig>(6, _omitFieldNames ? '' : 'restConfig',
        subBuilder: RestConfig.create)
    ..aOB(7, _omitFieldNames ? '' : 'lastSetAmrap')
    ..pPM<WorkingSetSpec>(8, _omitFieldNames ? '' : 'workingSets',
        subBuilder: WorkingSetSpec.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseTypeConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseTypeConfig copyWith(void Function(ExerciseTypeConfig) updates) =>
      super.copyWith((message) => updates(message as ExerciseTypeConfig))
          as ExerciseTypeConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseTypeConfig create() => ExerciseTypeConfig._();
  @$core.override
  ExerciseTypeConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseTypeConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseTypeConfig>(create);
  static ExerciseTypeConfig? _defaultInstance;

  @$pb.TagNumber(1)
  Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise(Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get startWeight => $_getN(1);
  @$pb.TagNumber(2)
  set startWeight($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartWeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartWeight() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get endWeight => $_getN(2);
  @$pb.TagNumber(3)
  set endWeight($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEndWeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearEndWeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get reps => $_getIZ(3);
  @$pb.TagNumber(4)
  set reps($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReps() => $_has(3);
  @$pb.TagNumber(4)
  void clearReps() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get includeWarmup => $_getBF(4);
  @$pb.TagNumber(5)
  set includeWarmup($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIncludeWarmup() => $_has(4);
  @$pb.TagNumber(5)
  void clearIncludeWarmup() => $_clearField(5);

  @$pb.TagNumber(6)
  RestConfig get restConfig => $_getN(5);
  @$pb.TagNumber(6)
  set restConfig(RestConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRestConfig() => $_has(5);
  @$pb.TagNumber(6)
  void clearRestConfig() => $_clearField(6);
  @$pb.TagNumber(6)
  RestConfig ensureRestConfig() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.bool get lastSetAmrap => $_getBF(6);
  @$pb.TagNumber(7)
  set lastSetAmrap($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLastSetAmrap() => $_has(6);
  @$pb.TagNumber(7)
  void clearLastSetAmrap() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<WorkingSetSpec> get workingSets => $_getList(7);
}

class WorkingSetSpec extends $pb.GeneratedMessage {
  factory WorkingSetSpec({
    $core.double? targetWeight,
    $core.int? targetReps,
    $core.bool? isAmrap,
    $core.String? instruction,
    ProgressionHint? progressionHint,
  }) {
    final result = create();
    if (targetWeight != null) result.targetWeight = targetWeight;
    if (targetReps != null) result.targetReps = targetReps;
    if (isAmrap != null) result.isAmrap = isAmrap;
    if (instruction != null) result.instruction = instruction;
    if (progressionHint != null) result.progressionHint = progressionHint;
    return result;
  }

  WorkingSetSpec._();

  factory WorkingSetSpec.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkingSetSpec.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkingSetSpec',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'targetWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aI(2, _omitFieldNames ? '' : 'targetReps')
    ..aOB(3, _omitFieldNames ? '' : 'isAmrap')
    ..aOS(4, _omitFieldNames ? '' : 'instruction')
    ..aOM<ProgressionHint>(5, _omitFieldNames ? '' : 'progressionHint',
        subBuilder: ProgressionHint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkingSetSpec clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkingSetSpec copyWith(void Function(WorkingSetSpec) updates) =>
      super.copyWith((message) => updates(message as WorkingSetSpec))
          as WorkingSetSpec;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkingSetSpec create() => WorkingSetSpec._();
  @$core.override
  WorkingSetSpec createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkingSetSpec getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkingSetSpec>(create);
  static WorkingSetSpec? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get targetWeight => $_getN(0);
  @$pb.TagNumber(1)
  set targetWeight($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTargetWeight() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetWeight() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get targetReps => $_getIZ(1);
  @$pb.TagNumber(2)
  set targetReps($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetReps() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetReps() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isAmrap => $_getBF(2);
  @$pb.TagNumber(3)
  set isAmrap($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsAmrap() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsAmrap() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get instruction => $_getSZ(3);
  @$pb.TagNumber(4)
  set instruction($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInstruction() => $_has(3);
  @$pb.TagNumber(4)
  void clearInstruction() => $_clearField(4);

  @$pb.TagNumber(5)
  ProgressionHint get progressionHint => $_getN(4);
  @$pb.TagNumber(5)
  set progressionHint(ProgressionHint value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasProgressionHint() => $_has(4);
  @$pb.TagNumber(5)
  void clearProgressionHint() => $_clearField(5);
  @$pb.TagNumber(5)
  ProgressionHint ensureProgressionHint() => $_ensure(4);
}

class RestConfig extends $pb.GeneratedMessage {
  factory RestConfig({
    $core.int? restAfterSuccess,
    $core.int? restAfterFailure,
    $core.int? restAfterWarmup,
    $core.int? restAfterLastWarmup,
  }) {
    final result = create();
    if (restAfterSuccess != null) result.restAfterSuccess = restAfterSuccess;
    if (restAfterFailure != null) result.restAfterFailure = restAfterFailure;
    if (restAfterWarmup != null) result.restAfterWarmup = restAfterWarmup;
    if (restAfterLastWarmup != null)
      result.restAfterLastWarmup = restAfterLastWarmup;
    return result;
  }

  RestConfig._();

  factory RestConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RestConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'restAfterSuccess')
    ..aI(2, _omitFieldNames ? '' : 'restAfterFailure')
    ..aI(3, _omitFieldNames ? '' : 'restAfterWarmup')
    ..aI(4, _omitFieldNames ? '' : 'restAfterLastWarmup')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestConfig copyWith(void Function(RestConfig) updates) =>
      super.copyWith((message) => updates(message as RestConfig)) as RestConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RestConfig create() => RestConfig._();
  @$core.override
  RestConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RestConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestConfig>(create);
  static RestConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get restAfterSuccess => $_getIZ(0);
  @$pb.TagNumber(1)
  set restAfterSuccess($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRestAfterSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearRestAfterSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get restAfterFailure => $_getIZ(1);
  @$pb.TagNumber(2)
  set restAfterFailure($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRestAfterFailure() => $_has(1);
  @$pb.TagNumber(2)
  void clearRestAfterFailure() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get restAfterWarmup => $_getIZ(2);
  @$pb.TagNumber(3)
  set restAfterWarmup($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRestAfterWarmup() => $_has(2);
  @$pb.TagNumber(3)
  void clearRestAfterWarmup() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get restAfterLastWarmup => $_getIZ(3);
  @$pb.TagNumber(4)
  set restAfterLastWarmup($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRestAfterLastWarmup() => $_has(3);
  @$pb.TagNumber(4)
  void clearRestAfterLastWarmup() => $_clearField(4);
}

class ExerciseGroup extends $pb.GeneratedMessage {
  factory ExerciseGroup({
    $core.String? id,
    $core.String? workoutId,
    $core.String? name,
    $core.int? sets,
    $core.bool? interleaveWarmups,
    $core.int? workoutOrder,
    $core.Iterable<ExerciseTypeConfig>? exerciseConfigs,
    RestConfig? restConfig,
    $core.String? instruction,
    $core.bool? prescribedByRegime,
    $core.Iterable<ProposedSet>? materializedSets,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (workoutId != null) result.workoutId = workoutId;
    if (name != null) result.name = name;
    if (sets != null) result.sets = sets;
    if (interleaveWarmups != null) result.interleaveWarmups = interleaveWarmups;
    if (workoutOrder != null) result.workoutOrder = workoutOrder;
    if (exerciseConfigs != null) result.exerciseConfigs.addAll(exerciseConfigs);
    if (restConfig != null) result.restConfig = restConfig;
    if (instruction != null) result.instruction = instruction;
    if (prescribedByRegime != null)
      result.prescribedByRegime = prescribedByRegime;
    if (materializedSets != null)
      result.materializedSets.addAll(materializedSets);
    return result;
  }

  ExerciseGroup._();

  factory ExerciseGroup.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseGroup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'workoutId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'sets')
    ..aOB(5, _omitFieldNames ? '' : 'interleaveWarmups')
    ..aI(6, _omitFieldNames ? '' : 'workoutOrder')
    ..pPM<ExerciseTypeConfig>(7, _omitFieldNames ? '' : 'exerciseConfigs',
        subBuilder: ExerciseTypeConfig.create)
    ..aOM<RestConfig>(8, _omitFieldNames ? '' : 'restConfig',
        subBuilder: RestConfig.create)
    ..aOS(9, _omitFieldNames ? '' : 'instruction')
    ..aOB(10, _omitFieldNames ? '' : 'prescribedByRegime')
    ..pPM<ProposedSet>(11, _omitFieldNames ? '' : 'materializedSets',
        subBuilder: ProposedSet.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseGroup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseGroup copyWith(void Function(ExerciseGroup) updates) =>
      super.copyWith((message) => updates(message as ExerciseGroup))
          as ExerciseGroup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseGroup create() => ExerciseGroup._();
  @$core.override
  ExerciseGroup createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseGroup>(create);
  static ExerciseGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set workoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get sets => $_getIZ(3);
  @$pb.TagNumber(4)
  set sets($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSets() => $_has(3);
  @$pb.TagNumber(4)
  void clearSets() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get interleaveWarmups => $_getBF(4);
  @$pb.TagNumber(5)
  set interleaveWarmups($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInterleaveWarmups() => $_has(4);
  @$pb.TagNumber(5)
  void clearInterleaveWarmups() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get workoutOrder => $_getIZ(5);
  @$pb.TagNumber(6)
  set workoutOrder($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasWorkoutOrder() => $_has(5);
  @$pb.TagNumber(6)
  void clearWorkoutOrder() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<ExerciseTypeConfig> get exerciseConfigs => $_getList(6);

  @$pb.TagNumber(8)
  RestConfig get restConfig => $_getN(7);
  @$pb.TagNumber(8)
  set restConfig(RestConfig value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasRestConfig() => $_has(7);
  @$pb.TagNumber(8)
  void clearRestConfig() => $_clearField(8);
  @$pb.TagNumber(8)
  RestConfig ensureRestConfig() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.String get instruction => $_getSZ(8);
  @$pb.TagNumber(9)
  set instruction($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasInstruction() => $_has(8);
  @$pb.TagNumber(9)
  void clearInstruction() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get prescribedByRegime => $_getBF(9);
  @$pb.TagNumber(10)
  set prescribedByRegime($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPrescribedByRegime() => $_has(9);
  @$pb.TagNumber(10)
  void clearPrescribedByRegime() => $_clearField(10);

  /// Server-materialized display sets, populated only in the schedule response so
  /// the home preview renders them directly. Not persisted / not sent on mutations.
  @$pb.TagNumber(11)
  $pb.PbList<ProposedSet> get materializedSets => $_getList(10);
}

class ProposedSet extends $pb.GeneratedMessage {
  factory ProposedSet({
    $core.String? id,
    $core.String? workoutId,
    $core.int? workoutOrder,
    Exercise? exercise,
    $core.int? targetReps,
    $core.double? targetWeight,
    $core.bool? warmup,
    $core.String? exerciseGroupId,
    $core.int? restAfterSuccess,
    $core.int? restAfterFailure,
    $core.bool? cancelled,
    $core.bool? isAmrap,
    $core.String? instruction,
    ProgressionHint? progressionHint,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (workoutId != null) result.workoutId = workoutId;
    if (workoutOrder != null) result.workoutOrder = workoutOrder;
    if (exercise != null) result.exercise = exercise;
    if (targetReps != null) result.targetReps = targetReps;
    if (targetWeight != null) result.targetWeight = targetWeight;
    if (warmup != null) result.warmup = warmup;
    if (exerciseGroupId != null) result.exerciseGroupId = exerciseGroupId;
    if (restAfterSuccess != null) result.restAfterSuccess = restAfterSuccess;
    if (restAfterFailure != null) result.restAfterFailure = restAfterFailure;
    if (cancelled != null) result.cancelled = cancelled;
    if (isAmrap != null) result.isAmrap = isAmrap;
    if (instruction != null) result.instruction = instruction;
    if (progressionHint != null) result.progressionHint = progressionHint;
    return result;
  }

  ProposedSet._();

  factory ProposedSet.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProposedSet.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProposedSet',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'workoutId')
    ..aI(3, _omitFieldNames ? '' : 'workoutOrder')
    ..aE<Exercise>(4, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..aI(5, _omitFieldNames ? '' : 'targetReps')
    ..aD(6, _omitFieldNames ? '' : 'targetWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aOB(7, _omitFieldNames ? '' : 'warmup')
    ..aOS(8, _omitFieldNames ? '' : 'exerciseGroupId')
    ..aI(9, _omitFieldNames ? '' : 'restAfterSuccess')
    ..aI(10, _omitFieldNames ? '' : 'restAfterFailure')
    ..aOB(11, _omitFieldNames ? '' : 'cancelled')
    ..aOB(12, _omitFieldNames ? '' : 'isAmrap')
    ..aOS(13, _omitFieldNames ? '' : 'instruction')
    ..aOM<ProgressionHint>(14, _omitFieldNames ? '' : 'progressionHint',
        subBuilder: ProgressionHint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProposedSet clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProposedSet copyWith(void Function(ProposedSet) updates) =>
      super.copyWith((message) => updates(message as ProposedSet))
          as ProposedSet;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProposedSet create() => ProposedSet._();
  @$core.override
  ProposedSet createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProposedSet getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProposedSet>(create);
  static ProposedSet? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set workoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get workoutOrder => $_getIZ(2);
  @$pb.TagNumber(3)
  set workoutOrder($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWorkoutOrder() => $_has(2);
  @$pb.TagNumber(3)
  void clearWorkoutOrder() => $_clearField(3);

  @$pb.TagNumber(4)
  Exercise get exercise => $_getN(3);
  @$pb.TagNumber(4)
  set exercise(Exercise value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasExercise() => $_has(3);
  @$pb.TagNumber(4)
  void clearExercise() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get targetReps => $_getIZ(4);
  @$pb.TagNumber(5)
  set targetReps($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTargetReps() => $_has(4);
  @$pb.TagNumber(5)
  void clearTargetReps() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get targetWeight => $_getN(5);
  @$pb.TagNumber(6)
  set targetWeight($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTargetWeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearTargetWeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get warmup => $_getBF(6);
  @$pb.TagNumber(7)
  set warmup($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasWarmup() => $_has(6);
  @$pb.TagNumber(7)
  void clearWarmup() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get exerciseGroupId => $_getSZ(7);
  @$pb.TagNumber(8)
  set exerciseGroupId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExerciseGroupId() => $_has(7);
  @$pb.TagNumber(8)
  void clearExerciseGroupId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get restAfterSuccess => $_getIZ(8);
  @$pb.TagNumber(9)
  set restAfterSuccess($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRestAfterSuccess() => $_has(8);
  @$pb.TagNumber(9)
  void clearRestAfterSuccess() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get restAfterFailure => $_getIZ(9);
  @$pb.TagNumber(10)
  set restAfterFailure($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasRestAfterFailure() => $_has(9);
  @$pb.TagNumber(10)
  void clearRestAfterFailure() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get cancelled => $_getBF(10);
  @$pb.TagNumber(11)
  set cancelled($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCancelled() => $_has(10);
  @$pb.TagNumber(11)
  void clearCancelled() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get isAmrap => $_getBF(11);
  @$pb.TagNumber(12)
  set isAmrap($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasIsAmrap() => $_has(11);
  @$pb.TagNumber(12)
  void clearIsAmrap() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get instruction => $_getSZ(12);
  @$pb.TagNumber(13)
  set instruction($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasInstruction() => $_has(12);
  @$pb.TagNumber(13)
  void clearInstruction() => $_clearField(13);

  @$pb.TagNumber(14)
  ProgressionHint get progressionHint => $_getN(13);
  @$pb.TagNumber(14)
  set progressionHint(ProgressionHint value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasProgressionHint() => $_has(13);
  @$pb.TagNumber(14)
  void clearProgressionHint() => $_clearField(14);
  @$pb.TagNumber(14)
  ProgressionHint ensureProgressionHint() => $_ensure(13);
}

class CompletedSet extends $pb.GeneratedMessage {
  factory CompletedSet({
    $core.String? id,
    $core.String? workoutId,
    $core.String? proposedSetId,
    $core.int? actualReps,
    $core.double? actualWeight,
    $fixnum.Int64? startedAt,
    $fixnum.Int64? endedAt,
    $fixnum.Int64? restUntil,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (workoutId != null) result.workoutId = workoutId;
    if (proposedSetId != null) result.proposedSetId = proposedSetId;
    if (actualReps != null) result.actualReps = actualReps;
    if (actualWeight != null) result.actualWeight = actualWeight;
    if (startedAt != null) result.startedAt = startedAt;
    if (endedAt != null) result.endedAt = endedAt;
    if (restUntil != null) result.restUntil = restUntil;
    return result;
  }

  CompletedSet._();

  factory CompletedSet.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompletedSet.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompletedSet',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'workoutId')
    ..aOS(3, _omitFieldNames ? '' : 'proposedSetId')
    ..aI(4, _omitFieldNames ? '' : 'actualReps')
    ..aD(5, _omitFieldNames ? '' : 'actualWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aInt64(6, _omitFieldNames ? '' : 'startedAt')
    ..aInt64(7, _omitFieldNames ? '' : 'endedAt')
    ..aInt64(8, _omitFieldNames ? '' : 'restUntil')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompletedSet clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompletedSet copyWith(void Function(CompletedSet) updates) =>
      super.copyWith((message) => updates(message as CompletedSet))
          as CompletedSet;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompletedSet create() => CompletedSet._();
  @$core.override
  CompletedSet createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompletedSet getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompletedSet>(create);
  static CompletedSet? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set workoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get proposedSetId => $_getSZ(2);
  @$pb.TagNumber(3)
  set proposedSetId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProposedSetId() => $_has(2);
  @$pb.TagNumber(3)
  void clearProposedSetId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get actualReps => $_getIZ(3);
  @$pb.TagNumber(4)
  set actualReps($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasActualReps() => $_has(3);
  @$pb.TagNumber(4)
  void clearActualReps() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get actualWeight => $_getN(4);
  @$pb.TagNumber(5)
  set actualWeight($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasActualWeight() => $_has(4);
  @$pb.TagNumber(5)
  void clearActualWeight() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get startedAt => $_getI64(5);
  @$pb.TagNumber(6)
  set startedAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStartedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearStartedAt() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get endedAt => $_getI64(6);
  @$pb.TagNumber(7)
  set endedAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEndedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearEndedAt() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get restUntil => $_getI64(7);
  @$pb.TagNumber(8)
  set restUntil($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRestUntil() => $_has(7);
  @$pb.TagNumber(8)
  void clearRestUntil() => $_clearField(8);
}

class ProgressionDetails extends $pb.GeneratedMessage {
  factory ProgressionDetails({
    ProgressionChangeKind? changeKind,
    ProgressionMetricKind? metricKind,
    $core.double? previousWeight,
    $core.double? nextWeight,
    $core.String? previousStage,
    $core.String? nextStage,
    $core.String? sourceWorkoutId,
    $core.String? contextLabel,
    ProgressionReasonKind? reasonKind,
    $core.String? reasonText,
  }) {
    final result = create();
    if (changeKind != null) result.changeKind = changeKind;
    if (metricKind != null) result.metricKind = metricKind;
    if (previousWeight != null) result.previousWeight = previousWeight;
    if (nextWeight != null) result.nextWeight = nextWeight;
    if (previousStage != null) result.previousStage = previousStage;
    if (nextStage != null) result.nextStage = nextStage;
    if (sourceWorkoutId != null) result.sourceWorkoutId = sourceWorkoutId;
    if (contextLabel != null) result.contextLabel = contextLabel;
    if (reasonKind != null) result.reasonKind = reasonKind;
    if (reasonText != null) result.reasonText = reasonText;
    return result;
  }

  ProgressionDetails._();

  factory ProgressionDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgressionDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressionDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<ProgressionChangeKind>(1, _omitFieldNames ? '' : 'changeKind',
        enumValues: ProgressionChangeKind.values)
    ..aE<ProgressionMetricKind>(2, _omitFieldNames ? '' : 'metricKind',
        enumValues: ProgressionMetricKind.values)
    ..aD(3, _omitFieldNames ? '' : 'previousWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'nextWeight', fieldType: $pb.PbFieldType.OF)
    ..aOS(5, _omitFieldNames ? '' : 'previousStage')
    ..aOS(6, _omitFieldNames ? '' : 'nextStage')
    ..aOS(7, _omitFieldNames ? '' : 'sourceWorkoutId')
    ..aOS(8, _omitFieldNames ? '' : 'contextLabel')
    ..aE<ProgressionReasonKind>(9, _omitFieldNames ? '' : 'reasonKind',
        enumValues: ProgressionReasonKind.values)
    ..aOS(10, _omitFieldNames ? '' : 'reasonText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressionDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressionDetails copyWith(void Function(ProgressionDetails) updates) =>
      super.copyWith((message) => updates(message as ProgressionDetails))
          as ProgressionDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProgressionDetails create() => ProgressionDetails._();
  @$core.override
  ProgressionDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgressionDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgressionDetails>(create);
  static ProgressionDetails? _defaultInstance;

  @$pb.TagNumber(1)
  ProgressionChangeKind get changeKind => $_getN(0);
  @$pb.TagNumber(1)
  set changeKind(ProgressionChangeKind value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasChangeKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearChangeKind() => $_clearField(1);

  @$pb.TagNumber(2)
  ProgressionMetricKind get metricKind => $_getN(1);
  @$pb.TagNumber(2)
  set metricKind(ProgressionMetricKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMetricKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearMetricKind() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get previousWeight => $_getN(2);
  @$pb.TagNumber(3)
  set previousWeight($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPreviousWeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearPreviousWeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get nextWeight => $_getN(3);
  @$pb.TagNumber(4)
  set nextWeight($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNextWeight() => $_has(3);
  @$pb.TagNumber(4)
  void clearNextWeight() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get previousStage => $_getSZ(4);
  @$pb.TagNumber(5)
  set previousStage($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPreviousStage() => $_has(4);
  @$pb.TagNumber(5)
  void clearPreviousStage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get nextStage => $_getSZ(5);
  @$pb.TagNumber(6)
  set nextStage($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNextStage() => $_has(5);
  @$pb.TagNumber(6)
  void clearNextStage() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get sourceWorkoutId => $_getSZ(6);
  @$pb.TagNumber(7)
  set sourceWorkoutId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSourceWorkoutId() => $_has(6);
  @$pb.TagNumber(7)
  void clearSourceWorkoutId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get contextLabel => $_getSZ(7);
  @$pb.TagNumber(8)
  set contextLabel($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasContextLabel() => $_has(7);
  @$pb.TagNumber(8)
  void clearContextLabel() => $_clearField(8);

  @$pb.TagNumber(9)
  ProgressionReasonKind get reasonKind => $_getN(8);
  @$pb.TagNumber(9)
  set reasonKind(ProgressionReasonKind value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasReasonKind() => $_has(8);
  @$pb.TagNumber(9)
  void clearReasonKind() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get reasonText => $_getSZ(9);
  @$pb.TagNumber(10)
  set reasonText($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasReasonText() => $_has(9);
  @$pb.TagNumber(10)
  void clearReasonText() => $_clearField(10);
}

enum UserMessageDetails_Detail { progression, notSet }

class UserMessageDetails extends $pb.GeneratedMessage {
  factory UserMessageDetails({
    ProgressionDetails? progression,
  }) {
    final result = create();
    if (progression != null) result.progression = progression;
    return result;
  }

  UserMessageDetails._();

  factory UserMessageDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserMessageDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, UserMessageDetails_Detail>
      _UserMessageDetails_DetailByTag = {
    1: UserMessageDetails_Detail.progression,
    0: UserMessageDetails_Detail.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserMessageDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1])
    ..aOM<ProgressionDetails>(1, _omitFieldNames ? '' : 'progression',
        subBuilder: ProgressionDetails.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserMessageDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserMessageDetails copyWith(void Function(UserMessageDetails) updates) =>
      super.copyWith((message) => updates(message as UserMessageDetails))
          as UserMessageDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserMessageDetails create() => UserMessageDetails._();
  @$core.override
  UserMessageDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserMessageDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserMessageDetails>(create);
  static UserMessageDetails? _defaultInstance;

  @$pb.TagNumber(1)
  UserMessageDetails_Detail whichDetail() =>
      _UserMessageDetails_DetailByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  void clearDetail() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ProgressionDetails get progression => $_getN(0);
  @$pb.TagNumber(1)
  set progression(ProgressionDetails value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProgression() => $_has(0);
  @$pb.TagNumber(1)
  void clearProgression() => $_clearField(1);
  @$pb.TagNumber(1)
  ProgressionDetails ensureProgression() => $_ensure(0);
}

class UserMessage extends $pb.GeneratedMessage {
  factory UserMessage({
    $core.String? messageKey,
    UserMessageKind? kind,
    UserMessageSurface? surface,
    $core.String? title,
    $core.String? body,
    $core.bool? dismissible,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? updatedAt,
    $core.String? workoutId,
    $core.String? exerciseGroupId,
    Exercise? exercise,
    $core.String? slotKey,
    UserMessageDetails? details,
    $core.String? sourceWorkoutId,
  }) {
    final result = create();
    if (messageKey != null) result.messageKey = messageKey;
    if (kind != null) result.kind = kind;
    if (surface != null) result.surface = surface;
    if (title != null) result.title = title;
    if (body != null) result.body = body;
    if (dismissible != null) result.dismissible = dismissible;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (workoutId != null) result.workoutId = workoutId;
    if (exerciseGroupId != null) result.exerciseGroupId = exerciseGroupId;
    if (exercise != null) result.exercise = exercise;
    if (slotKey != null) result.slotKey = slotKey;
    if (details != null) result.details = details;
    if (sourceWorkoutId != null) result.sourceWorkoutId = sourceWorkoutId;
    return result;
  }

  UserMessage._();

  factory UserMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageKey')
    ..aE<UserMessageKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: UserMessageKind.values)
    ..aE<UserMessageSurface>(3, _omitFieldNames ? '' : 'surface',
        enumValues: UserMessageSurface.values)
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'body')
    ..aOB(6, _omitFieldNames ? '' : 'dismissible')
    ..aInt64(7, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(8, _omitFieldNames ? '' : 'updatedAt')
    ..aOS(9, _omitFieldNames ? '' : 'workoutId')
    ..aOS(10, _omitFieldNames ? '' : 'exerciseGroupId')
    ..aE<Exercise>(11, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..aOS(12, _omitFieldNames ? '' : 'slotKey')
    ..aOM<UserMessageDetails>(14, _omitFieldNames ? '' : 'details',
        subBuilder: UserMessageDetails.create)
    ..aOS(15, _omitFieldNames ? '' : 'sourceWorkoutId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserMessage copyWith(void Function(UserMessage) updates) =>
      super.copyWith((message) => updates(message as UserMessage))
          as UserMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserMessage create() => UserMessage._();
  @$core.override
  UserMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserMessage>(create);
  static UserMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageKey() => $_clearField(1);

  @$pb.TagNumber(2)
  UserMessageKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(UserMessageKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  @$pb.TagNumber(3)
  UserMessageSurface get surface => $_getN(2);
  @$pb.TagNumber(3)
  set surface(UserMessageSurface value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSurface() => $_has(2);
  @$pb.TagNumber(3)
  void clearSurface() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get body => $_getSZ(4);
  @$pb.TagNumber(5)
  set body($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBody() => $_has(4);
  @$pb.TagNumber(5)
  void clearBody() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get dismissible => $_getBF(5);
  @$pb.TagNumber(6)
  set dismissible($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDismissible() => $_has(5);
  @$pb.TagNumber(6)
  void clearDismissible() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get createdAt => $_getI64(6);
  @$pb.TagNumber(7)
  set createdAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get updatedAt => $_getI64(7);
  @$pb.TagNumber(8)
  set updatedAt($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUpdatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearUpdatedAt() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get workoutId => $_getSZ(8);
  @$pb.TagNumber(9)
  set workoutId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasWorkoutId() => $_has(8);
  @$pb.TagNumber(9)
  void clearWorkoutId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get exerciseGroupId => $_getSZ(9);
  @$pb.TagNumber(10)
  set exerciseGroupId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasExerciseGroupId() => $_has(9);
  @$pb.TagNumber(10)
  void clearExerciseGroupId() => $_clearField(10);

  @$pb.TagNumber(11)
  Exercise get exercise => $_getN(10);
  @$pb.TagNumber(11)
  set exercise(Exercise value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasExercise() => $_has(10);
  @$pb.TagNumber(11)
  void clearExercise() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get slotKey => $_getSZ(11);
  @$pb.TagNumber(12)
  set slotKey($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSlotKey() => $_has(11);
  @$pb.TagNumber(12)
  void clearSlotKey() => $_clearField(12);

  @$pb.TagNumber(14)
  UserMessageDetails get details => $_getN(12);
  @$pb.TagNumber(14)
  set details(UserMessageDetails value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasDetails() => $_has(12);
  @$pb.TagNumber(14)
  void clearDetails() => $_clearField(14);
  @$pb.TagNumber(14)
  UserMessageDetails ensureDetails() => $_ensure(12);

  @$pb.TagNumber(15)
  $core.String get sourceWorkoutId => $_getSZ(13);
  @$pb.TagNumber(15)
  set sourceWorkoutId($core.String value) => $_setString(13, value);
  @$pb.TagNumber(15)
  $core.bool hasSourceWorkoutId() => $_has(13);
  @$pb.TagNumber(15)
  void clearSourceWorkoutId() => $_clearField(15);
}

class StartWorkoutRequest extends $pb.GeneratedMessage {
  factory StartWorkoutRequest({
    $core.String? name,
    $core.Iterable<ExerciseGroup>? exerciseGroups,
    $fixnum.Int64? startedAt,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (exerciseGroups != null) result.exerciseGroups.addAll(exerciseGroups);
    if (startedAt != null) result.startedAt = startedAt;
    return result;
  }

  StartWorkoutRequest._();

  factory StartWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..pPM<ExerciseGroup>(2, _omitFieldNames ? '' : 'exerciseGroups',
        subBuilder: ExerciseGroup.create)
    ..aInt64(3, _omitFieldNames ? '' : 'startedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartWorkoutRequest copyWith(void Function(StartWorkoutRequest) updates) =>
      super.copyWith((message) => updates(message as StartWorkoutRequest))
          as StartWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartWorkoutRequest create() => StartWorkoutRequest._();
  @$core.override
  StartWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StartWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartWorkoutRequest>(create);
  static StartWorkoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ExerciseGroup> get exerciseGroups => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get startedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set startedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartedAt() => $_clearField(3);
}

class StartWorkoutResponse extends $pb.GeneratedMessage {
  factory StartWorkoutResponse({
    $core.String? id,
    Workout? workout,
    $core.Iterable<ExerciseGroup>? exerciseGroups,
    $core.Iterable<ProposedSet>? proposedSets,
    $core.Iterable<CompletedSet>? completedSets,
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (workout != null) result.workout = workout;
    if (exerciseGroups != null) result.exerciseGroups.addAll(exerciseGroups);
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
    if (completedSets != null) result.completedSets.addAll(completedSets);
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  StartWorkoutResponse._();

  factory StartWorkoutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartWorkoutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartWorkoutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOM<Workout>(2, _omitFieldNames ? '' : 'workout',
        subBuilder: Workout.create)
    ..pPM<ExerciseGroup>(3, _omitFieldNames ? '' : 'exerciseGroups',
        subBuilder: ExerciseGroup.create)
    ..pPM<ProposedSet>(4, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: ProposedSet.create)
    ..pPM<CompletedSet>(5, _omitFieldNames ? '' : 'completedSets',
        subBuilder: CompletedSet.create)
    ..aOM<ProposedSet>(6, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(7, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(8, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartWorkoutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartWorkoutResponse copyWith(void Function(StartWorkoutResponse) updates) =>
      super.copyWith((message) => updates(message as StartWorkoutResponse))
          as StartWorkoutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartWorkoutResponse create() => StartWorkoutResponse._();
  @$core.override
  StartWorkoutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StartWorkoutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartWorkoutResponse>(create);
  static StartWorkoutResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  Workout get workout => $_getN(1);
  @$pb.TagNumber(2)
  set workout(Workout value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkout() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkout() => $_clearField(2);
  @$pb.TagNumber(2)
  Workout ensureWorkout() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<ExerciseGroup> get exerciseGroups => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<ProposedSet> get proposedSets => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<CompletedSet> get completedSets => $_getList(4);

  @$pb.TagNumber(6)
  ProposedSet get nextUpSet => $_getN(5);
  @$pb.TagNumber(6)
  set nextUpSet(ProposedSet value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasNextUpSet() => $_has(5);
  @$pb.TagNumber(6)
  void clearNextUpSet() => $_clearField(6);
  @$pb.TagNumber(6)
  ProposedSet ensureNextUpSet() => $_ensure(5);

  @$pb.TagNumber(7)
  WorkoutStateSnapshot get stateSnapshot => $_getN(6);
  @$pb.TagNumber(7)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasStateSnapshot() => $_has(6);
  @$pb.TagNumber(7)
  void clearStateSnapshot() => $_clearField(7);
  @$pb.TagNumber(7)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(6);

  @$pb.TagNumber(8)
  $pb.PbList<UserMessage> get userMessages => $_getList(7);
}

class GetWorkoutRequest extends $pb.GeneratedMessage {
  factory GetWorkoutRequest({
    $core.String? workoutId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    return result;
  }

  GetWorkoutRequest._();

  factory GetWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutRequest copyWith(void Function(GetWorkoutRequest) updates) =>
      super.copyWith((message) => updates(message as GetWorkoutRequest))
          as GetWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetWorkoutRequest create() => GetWorkoutRequest._();
  @$core.override
  GetWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetWorkoutRequest>(create);
  static GetWorkoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);
}

/// Server-computed rollup for one exercise within a workout (working sets only).
class ExerciseSummary extends $pb.GeneratedMessage {
  factory ExerciseSummary({
    Exercise? exercise,
    $core.int? totalSets,
    $core.int? totalReps,
    $core.double? totalVolume,
    $core.double? bestOneRepMax,
    $core.double? heaviestSetWeight,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (totalSets != null) result.totalSets = totalSets;
    if (totalReps != null) result.totalReps = totalReps;
    if (totalVolume != null) result.totalVolume = totalVolume;
    if (bestOneRepMax != null) result.bestOneRepMax = bestOneRepMax;
    if (heaviestSetWeight != null) result.heaviestSetWeight = heaviestSetWeight;
    return result;
  }

  ExerciseSummary._();

  factory ExerciseSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..aI(2, _omitFieldNames ? '' : 'totalSets')
    ..aI(3, _omitFieldNames ? '' : 'totalReps')
    ..aD(4, _omitFieldNames ? '' : 'totalVolume', fieldType: $pb.PbFieldType.OF)
    ..aD(5, _omitFieldNames ? '' : 'bestOneRepMax',
        fieldType: $pb.PbFieldType.OF)
    ..aD(6, _omitFieldNames ? '' : 'heaviestSetWeight',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseSummary copyWith(void Function(ExerciseSummary) updates) =>
      super.copyWith((message) => updates(message as ExerciseSummary))
          as ExerciseSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseSummary create() => ExerciseSummary._();
  @$core.override
  ExerciseSummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseSummary>(create);
  static ExerciseSummary? _defaultInstance;

  @$pb.TagNumber(1)
  Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise(Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalSets => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalSets($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalSets() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalSets() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get totalReps => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalReps($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalReps() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalReps() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get totalVolume => $_getN(3);
  @$pb.TagNumber(4)
  set totalVolume($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalVolume() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalVolume() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get bestOneRepMax => $_getN(4);
  @$pb.TagNumber(5)
  set bestOneRepMax($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBestOneRepMax() => $_has(4);
  @$pb.TagNumber(5)
  void clearBestOneRepMax() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get heaviestSetWeight => $_getN(5);
  @$pb.TagNumber(6)
  set heaviestSetWeight($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeaviestSetWeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeaviestSetWeight() => $_clearField(6);
}

/// Server-computed rollup for a whole workout. The client renders this directly
/// instead of aggregating raw sets. Volume/per-exercise cover working sets only;
/// the time breakdown covers every completed set (warmups included).
class WorkoutSummary extends $pb.GeneratedMessage {
  factory WorkoutSummary({
    $core.double? totalVolume,
    $fixnum.Int64? durationSeconds,
    $fixnum.Int64? liftingSeconds,
    $fixnum.Int64? restingSeconds,
    $fixnum.Int64? yappingSeconds,
    $core.double? volumePerMinute,
    $core.double? workRestRatio,
    $core.Iterable<ExerciseSummary>? exercises,
  }) {
    final result = create();
    if (totalVolume != null) result.totalVolume = totalVolume;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    if (liftingSeconds != null) result.liftingSeconds = liftingSeconds;
    if (restingSeconds != null) result.restingSeconds = restingSeconds;
    if (yappingSeconds != null) result.yappingSeconds = yappingSeconds;
    if (volumePerMinute != null) result.volumePerMinute = volumePerMinute;
    if (workRestRatio != null) result.workRestRatio = workRestRatio;
    if (exercises != null) result.exercises.addAll(exercises);
    return result;
  }

  WorkoutSummary._();

  factory WorkoutSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'totalVolume', fieldType: $pb.PbFieldType.OF)
    ..aInt64(2, _omitFieldNames ? '' : 'durationSeconds')
    ..aInt64(3, _omitFieldNames ? '' : 'liftingSeconds')
    ..aInt64(4, _omitFieldNames ? '' : 'restingSeconds')
    ..aInt64(5, _omitFieldNames ? '' : 'yappingSeconds')
    ..aD(6, _omitFieldNames ? '' : 'volumePerMinute',
        fieldType: $pb.PbFieldType.OF)
    ..aD(7, _omitFieldNames ? '' : 'workRestRatio',
        fieldType: $pb.PbFieldType.OF)
    ..pPM<ExerciseSummary>(8, _omitFieldNames ? '' : 'exercises',
        subBuilder: ExerciseSummary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutSummary copyWith(void Function(WorkoutSummary) updates) =>
      super.copyWith((message) => updates(message as WorkoutSummary))
          as WorkoutSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutSummary create() => WorkoutSummary._();
  @$core.override
  WorkoutSummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutSummary>(create);
  static WorkoutSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get totalVolume => $_getN(0);
  @$pb.TagNumber(1)
  set totalVolume($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalVolume() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalVolume() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get durationSeconds => $_getI64(1);
  @$pb.TagNumber(2)
  set durationSeconds($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDurationSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearDurationSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get liftingSeconds => $_getI64(2);
  @$pb.TagNumber(3)
  set liftingSeconds($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLiftingSeconds() => $_has(2);
  @$pb.TagNumber(3)
  void clearLiftingSeconds() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get restingSeconds => $_getI64(3);
  @$pb.TagNumber(4)
  set restingSeconds($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRestingSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearRestingSeconds() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get yappingSeconds => $_getI64(4);
  @$pb.TagNumber(5)
  set yappingSeconds($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasYappingSeconds() => $_has(4);
  @$pb.TagNumber(5)
  void clearYappingSeconds() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get volumePerMinute => $_getN(5);
  @$pb.TagNumber(6)
  set volumePerMinute($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVolumePerMinute() => $_has(5);
  @$pb.TagNumber(6)
  void clearVolumePerMinute() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get workRestRatio => $_getN(6);
  @$pb.TagNumber(7)
  set workRestRatio($core.double value) => $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasWorkRestRatio() => $_has(6);
  @$pb.TagNumber(7)
  void clearWorkRestRatio() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<ExerciseSummary> get exercises => $_getList(7);
}

class GetWorkoutResponse extends $pb.GeneratedMessage {
  factory GetWorkoutResponse({
    Workout? workout,
    $core.Iterable<ExerciseGroup>? exerciseGroups,
    $core.Iterable<ProposedSet>? proposedSets,
    $core.Iterable<CompletedSet>? completedSets,
    ProposedSet? nextUpSet,
    WorkoutPlanChangeStats? planChangeStats,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
    WorkoutSummary? summary,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
    if (exerciseGroups != null) result.exerciseGroups.addAll(exerciseGroups);
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
    if (completedSets != null) result.completedSets.addAll(completedSets);
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (planChangeStats != null) result.planChangeStats = planChangeStats;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    if (summary != null) result.summary = summary;
    return result;
  }

  GetWorkoutResponse._();

  factory GetWorkoutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetWorkoutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetWorkoutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<Workout>(1, _omitFieldNames ? '' : 'workout',
        subBuilder: Workout.create)
    ..pPM<ExerciseGroup>(2, _omitFieldNames ? '' : 'exerciseGroups',
        subBuilder: ExerciseGroup.create)
    ..pPM<ProposedSet>(3, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: ProposedSet.create)
    ..pPM<CompletedSet>(4, _omitFieldNames ? '' : 'completedSets',
        subBuilder: CompletedSet.create)
    ..aOM<ProposedSet>(5, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutPlanChangeStats>(6, _omitFieldNames ? '' : 'planChangeStats',
        subBuilder: WorkoutPlanChangeStats.create)
    ..aOM<WorkoutStateSnapshot>(7, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(8, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..aOM<WorkoutSummary>(9, _omitFieldNames ? '' : 'summary',
        subBuilder: WorkoutSummary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutResponse copyWith(void Function(GetWorkoutResponse) updates) =>
      super.copyWith((message) => updates(message as GetWorkoutResponse))
          as GetWorkoutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetWorkoutResponse create() => GetWorkoutResponse._();
  @$core.override
  GetWorkoutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetWorkoutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetWorkoutResponse>(create);
  static GetWorkoutResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Workout get workout => $_getN(0);
  @$pb.TagNumber(1)
  set workout(Workout value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkout() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkout() => $_clearField(1);
  @$pb.TagNumber(1)
  Workout ensureWorkout() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<ExerciseGroup> get exerciseGroups => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<ProposedSet> get proposedSets => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<CompletedSet> get completedSets => $_getList(3);

  @$pb.TagNumber(5)
  ProposedSet get nextUpSet => $_getN(4);
  @$pb.TagNumber(5)
  set nextUpSet(ProposedSet value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasNextUpSet() => $_has(4);
  @$pb.TagNumber(5)
  void clearNextUpSet() => $_clearField(5);
  @$pb.TagNumber(5)
  ProposedSet ensureNextUpSet() => $_ensure(4);

  @$pb.TagNumber(6)
  WorkoutPlanChangeStats get planChangeStats => $_getN(5);
  @$pb.TagNumber(6)
  set planChangeStats(WorkoutPlanChangeStats value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPlanChangeStats() => $_has(5);
  @$pb.TagNumber(6)
  void clearPlanChangeStats() => $_clearField(6);
  @$pb.TagNumber(6)
  WorkoutPlanChangeStats ensurePlanChangeStats() => $_ensure(5);

  @$pb.TagNumber(7)
  WorkoutStateSnapshot get stateSnapshot => $_getN(6);
  @$pb.TagNumber(7)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasStateSnapshot() => $_has(6);
  @$pb.TagNumber(7)
  void clearStateSnapshot() => $_clearField(7);
  @$pb.TagNumber(7)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(6);

  @$pb.TagNumber(8)
  $pb.PbList<UserMessage> get userMessages => $_getList(7);

  @$pb.TagNumber(9)
  WorkoutSummary get summary => $_getN(8);
  @$pb.TagNumber(9)
  set summary(WorkoutSummary value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasSummary() => $_has(8);
  @$pb.TagNumber(9)
  void clearSummary() => $_clearField(9);
  @$pb.TagNumber(9)
  WorkoutSummary ensureSummary() => $_ensure(8);
}

class WorkoutPlanChangeStats extends $pb.GeneratedMessage {
  factory WorkoutPlanChangeStats({
    $core.int? cancelledTotal,
    $core.int? cancelledWarmups,
    $core.int? cancelledWorking,
  }) {
    final result = create();
    if (cancelledTotal != null) result.cancelledTotal = cancelledTotal;
    if (cancelledWarmups != null) result.cancelledWarmups = cancelledWarmups;
    if (cancelledWorking != null) result.cancelledWorking = cancelledWorking;
    return result;
  }

  WorkoutPlanChangeStats._();

  factory WorkoutPlanChangeStats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutPlanChangeStats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutPlanChangeStats',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'cancelledTotal')
    ..aI(2, _omitFieldNames ? '' : 'cancelledWarmups')
    ..aI(3, _omitFieldNames ? '' : 'cancelledWorking')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutPlanChangeStats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutPlanChangeStats copyWith(
          void Function(WorkoutPlanChangeStats) updates) =>
      super.copyWith((message) => updates(message as WorkoutPlanChangeStats))
          as WorkoutPlanChangeStats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutPlanChangeStats create() => WorkoutPlanChangeStats._();
  @$core.override
  WorkoutPlanChangeStats createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutPlanChangeStats getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutPlanChangeStats>(create);
  static WorkoutPlanChangeStats? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get cancelledTotal => $_getIZ(0);
  @$pb.TagNumber(1)
  set cancelledTotal($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCancelledTotal() => $_has(0);
  @$pb.TagNumber(1)
  void clearCancelledTotal() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get cancelledWarmups => $_getIZ(1);
  @$pb.TagNumber(2)
  set cancelledWarmups($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCancelledWarmups() => $_has(1);
  @$pb.TagNumber(2)
  void clearCancelledWarmups() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get cancelledWorking => $_getIZ(2);
  @$pb.TagNumber(3)
  set cancelledWorking($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCancelledWorking() => $_has(2);
  @$pb.TagNumber(3)
  void clearCancelledWorking() => $_clearField(3);
}

class WorkoutStateSnapshot extends $pb.GeneratedMessage {
  factory WorkoutStateSnapshot({
    WorkoutState? state,
    ProposedSet? displaySet,
    $fixnum.Int64? activeStartedAt,
    $fixnum.Int64? restUntil,
    $fixnum.Int64? lastRestEnd,
  }) {
    final result = create();
    if (state != null) result.state = state;
    if (displaySet != null) result.displaySet = displaySet;
    if (activeStartedAt != null) result.activeStartedAt = activeStartedAt;
    if (restUntil != null) result.restUntil = restUntil;
    if (lastRestEnd != null) result.lastRestEnd = lastRestEnd;
    return result;
  }

  WorkoutStateSnapshot._();

  factory WorkoutStateSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutStateSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutStateSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<WorkoutState>(1, _omitFieldNames ? '' : 'state',
        enumValues: WorkoutState.values)
    ..aOM<ProposedSet>(2, _omitFieldNames ? '' : 'displaySet',
        subBuilder: ProposedSet.create)
    ..aInt64(3, _omitFieldNames ? '' : 'activeStartedAt')
    ..aInt64(4, _omitFieldNames ? '' : 'restUntil')
    ..aInt64(5, _omitFieldNames ? '' : 'lastRestEnd')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutStateSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutStateSnapshot copyWith(void Function(WorkoutStateSnapshot) updates) =>
      super.copyWith((message) => updates(message as WorkoutStateSnapshot))
          as WorkoutStateSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutStateSnapshot create() => WorkoutStateSnapshot._();
  @$core.override
  WorkoutStateSnapshot createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutStateSnapshot getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutStateSnapshot>(create);
  static WorkoutStateSnapshot? _defaultInstance;

  @$pb.TagNumber(1)
  WorkoutState get state => $_getN(0);
  @$pb.TagNumber(1)
  set state(WorkoutState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);

  @$pb.TagNumber(2)
  ProposedSet get displaySet => $_getN(1);
  @$pb.TagNumber(2)
  set displaySet(ProposedSet value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplaySet() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplaySet() => $_clearField(2);
  @$pb.TagNumber(2)
  ProposedSet ensureDisplaySet() => $_ensure(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get activeStartedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set activeStartedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveStartedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveStartedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get restUntil => $_getI64(3);
  @$pb.TagNumber(4)
  set restUntil($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRestUntil() => $_has(3);
  @$pb.TagNumber(4)
  void clearRestUntil() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get lastRestEnd => $_getI64(4);
  @$pb.TagNumber(5)
  set lastRestEnd($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastRestEnd() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastRestEnd() => $_clearField(5);
}

class ListWorkoutsRequest extends $pb.GeneratedMessage {
  factory ListWorkoutsRequest() => create();

  ListWorkoutsRequest._();

  factory ListWorkoutsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListWorkoutsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListWorkoutsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWorkoutsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWorkoutsRequest copyWith(void Function(ListWorkoutsRequest) updates) =>
      super.copyWith((message) => updates(message as ListWorkoutsRequest))
          as ListWorkoutsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListWorkoutsRequest create() => ListWorkoutsRequest._();
  @$core.override
  ListWorkoutsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListWorkoutsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListWorkoutsRequest>(create);
  static ListWorkoutsRequest? _defaultInstance;
}

class ListWorkoutsResponse extends $pb.GeneratedMessage {
  factory ListWorkoutsResponse({
    $core.Iterable<Workout>? workouts,
  }) {
    final result = create();
    if (workouts != null) result.workouts.addAll(workouts);
    return result;
  }

  ListWorkoutsResponse._();

  factory ListWorkoutsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListWorkoutsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListWorkoutsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<Workout>(1, _omitFieldNames ? '' : 'workouts',
        subBuilder: Workout.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWorkoutsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWorkoutsResponse copyWith(void Function(ListWorkoutsResponse) updates) =>
      super.copyWith((message) => updates(message as ListWorkoutsResponse))
          as ListWorkoutsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListWorkoutsResponse create() => ListWorkoutsResponse._();
  @$core.override
  ListWorkoutsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListWorkoutsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListWorkoutsResponse>(create);
  static ListWorkoutsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Workout> get workouts => $_getList(0);
}

class WorkoutWithSummary extends $pb.GeneratedMessage {
  factory WorkoutWithSummary({
    Workout? workout,
    WorkoutSummary? summary,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
    if (summary != null) result.summary = summary;
    return result;
  }

  WorkoutWithSummary._();

  factory WorkoutWithSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutWithSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutWithSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<Workout>(1, _omitFieldNames ? '' : 'workout',
        subBuilder: Workout.create)
    ..aOM<WorkoutSummary>(2, _omitFieldNames ? '' : 'summary',
        subBuilder: WorkoutSummary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutWithSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutWithSummary copyWith(void Function(WorkoutWithSummary) updates) =>
      super.copyWith((message) => updates(message as WorkoutWithSummary))
          as WorkoutWithSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutWithSummary create() => WorkoutWithSummary._();
  @$core.override
  WorkoutWithSummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutWithSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutWithSummary>(create);
  static WorkoutWithSummary? _defaultInstance;

  @$pb.TagNumber(1)
  Workout get workout => $_getN(0);
  @$pb.TagNumber(1)
  set workout(Workout value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkout() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkout() => $_clearField(1);
  @$pb.TagNumber(1)
  Workout ensureWorkout() => $_ensure(0);

  @$pb.TagNumber(2)
  WorkoutSummary get summary => $_getN(1);
  @$pb.TagNumber(2)
  set summary(WorkoutSummary value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSummary() => $_has(1);
  @$pb.TagNumber(2)
  void clearSummary() => $_clearField(2);
  @$pb.TagNumber(2)
  WorkoutSummary ensureSummary() => $_ensure(1);
}

class ListWorkoutSummariesRequest extends $pb.GeneratedMessage {
  factory ListWorkoutSummariesRequest() => create();

  ListWorkoutSummariesRequest._();

  factory ListWorkoutSummariesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListWorkoutSummariesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListWorkoutSummariesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWorkoutSummariesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWorkoutSummariesRequest copyWith(
          void Function(ListWorkoutSummariesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ListWorkoutSummariesRequest))
          as ListWorkoutSummariesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListWorkoutSummariesRequest create() =>
      ListWorkoutSummariesRequest._();
  @$core.override
  ListWorkoutSummariesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListWorkoutSummariesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListWorkoutSummariesRequest>(create);
  static ListWorkoutSummariesRequest? _defaultInstance;
}

class ListWorkoutSummariesResponse extends $pb.GeneratedMessage {
  factory ListWorkoutSummariesResponse({
    $core.Iterable<WorkoutWithSummary>? workouts,
  }) {
    final result = create();
    if (workouts != null) result.workouts.addAll(workouts);
    return result;
  }

  ListWorkoutSummariesResponse._();

  factory ListWorkoutSummariesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListWorkoutSummariesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListWorkoutSummariesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<WorkoutWithSummary>(1, _omitFieldNames ? '' : 'workouts',
        subBuilder: WorkoutWithSummary.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWorkoutSummariesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWorkoutSummariesResponse copyWith(
          void Function(ListWorkoutSummariesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ListWorkoutSummariesResponse))
          as ListWorkoutSummariesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListWorkoutSummariesResponse create() =>
      ListWorkoutSummariesResponse._();
  @$core.override
  ListWorkoutSummariesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListWorkoutSummariesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListWorkoutSummariesResponse>(create);
  static ListWorkoutSummariesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<WorkoutWithSummary> get workouts => $_getList(0);
}

/// One session's data point for one exercise (working sets only).
class ExerciseProgressPoint extends $pb.GeneratedMessage {
  factory ExerciseProgressPoint({
    $fixnum.Int64? date,
    $core.String? workoutId,
    $core.double? topWeight,
    $core.int? topReps,
    $core.double? bestOneRepMax,
    $core.double? volume,
    $core.int? sets,
  }) {
    final result = create();
    if (date != null) result.date = date;
    if (workoutId != null) result.workoutId = workoutId;
    if (topWeight != null) result.topWeight = topWeight;
    if (topReps != null) result.topReps = topReps;
    if (bestOneRepMax != null) result.bestOneRepMax = bestOneRepMax;
    if (volume != null) result.volume = volume;
    if (sets != null) result.sets = sets;
    return result;
  }

  ExerciseProgressPoint._();

  factory ExerciseProgressPoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseProgressPoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseProgressPoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'date')
    ..aOS(2, _omitFieldNames ? '' : 'workoutId')
    ..aD(3, _omitFieldNames ? '' : 'topWeight', fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'topReps')
    ..aD(5, _omitFieldNames ? '' : 'bestOneRepMax',
        fieldType: $pb.PbFieldType.OF)
    ..aD(6, _omitFieldNames ? '' : 'volume', fieldType: $pb.PbFieldType.OF)
    ..aI(7, _omitFieldNames ? '' : 'sets')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseProgressPoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseProgressPoint copyWith(
          void Function(ExerciseProgressPoint) updates) =>
      super.copyWith((message) => updates(message as ExerciseProgressPoint))
          as ExerciseProgressPoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseProgressPoint create() => ExerciseProgressPoint._();
  @$core.override
  ExerciseProgressPoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseProgressPoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseProgressPoint>(create);
  static ExerciseProgressPoint? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get date => $_getI64(0);
  @$pb.TagNumber(1)
  set date($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDate() => $_has(0);
  @$pb.TagNumber(1)
  void clearDate() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set workoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get topWeight => $_getN(2);
  @$pb.TagNumber(3)
  set topWeight($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTopWeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearTopWeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get topReps => $_getIZ(3);
  @$pb.TagNumber(4)
  set topReps($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTopReps() => $_has(3);
  @$pb.TagNumber(4)
  void clearTopReps() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get bestOneRepMax => $_getN(4);
  @$pb.TagNumber(5)
  set bestOneRepMax($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBestOneRepMax() => $_has(4);
  @$pb.TagNumber(5)
  void clearBestOneRepMax() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get volume => $_getN(5);
  @$pb.TagNumber(6)
  set volume($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVolume() => $_has(5);
  @$pb.TagNumber(6)
  void clearVolume() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get sets => $_getIZ(6);
  @$pb.TagNumber(7)
  set sets($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSets() => $_has(6);
  @$pb.TagNumber(7)
  void clearSets() => $_clearField(7);
}

class ExerciseProgress extends $pb.GeneratedMessage {
  factory ExerciseProgress({
    Exercise? exercise,
    $core.Iterable<ExerciseProgressPoint>? points,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (points != null) result.points.addAll(points);
    return result;
  }

  ExerciseProgress._();

  factory ExerciseProgress.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseProgress.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseProgress',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..pPM<ExerciseProgressPoint>(2, _omitFieldNames ? '' : 'points',
        subBuilder: ExerciseProgressPoint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseProgress clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseProgress copyWith(void Function(ExerciseProgress) updates) =>
      super.copyWith((message) => updates(message as ExerciseProgress))
          as ExerciseProgress;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseProgress create() => ExerciseProgress._();
  @$core.override
  ExerciseProgress createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseProgress getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseProgress>(create);
  static ExerciseProgress? _defaultInstance;

  @$pb.TagNumber(1)
  Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise(Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ExerciseProgressPoint> get points => $_getList(1);
}

class RecommendedWeight extends $pb.GeneratedMessage {
  factory RecommendedWeight({
    $core.String? fieldKey,
    $core.double? pounds,
  }) {
    final result = create();
    if (fieldKey != null) result.fieldKey = fieldKey;
    if (pounds != null) result.pounds = pounds;
    return result;
  }

  RecommendedWeight._();

  factory RecommendedWeight.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecommendedWeight.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecommendedWeight',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fieldKey')
    ..aD(2, _omitFieldNames ? '' : 'pounds', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecommendedWeight clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecommendedWeight copyWith(void Function(RecommendedWeight) updates) =>
      super.copyWith((message) => updates(message as RecommendedWeight))
          as RecommendedWeight;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecommendedWeight create() => RecommendedWeight._();
  @$core.override
  RecommendedWeight createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecommendedWeight getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecommendedWeight>(create);
  static RecommendedWeight? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get fieldKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set fieldKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFieldKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearFieldKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get pounds => $_getN(1);
  @$pb.TagNumber(2)
  set pounds($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPounds() => $_has(1);
  @$pb.TagNumber(2)
  void clearPounds() => $_clearField(2);
}

class GetRecommendedStartingWeightsRequest extends $pb.GeneratedMessage {
  factory GetRecommendedStartingWeightsRequest({
    $core.double? bodyweightKg,
    ExperienceLevel? experience,
  }) {
    final result = create();
    if (bodyweightKg != null) result.bodyweightKg = bodyweightKg;
    if (experience != null) result.experience = experience;
    return result;
  }

  GetRecommendedStartingWeightsRequest._();

  factory GetRecommendedStartingWeightsRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRecommendedStartingWeightsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRecommendedStartingWeightsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'bodyweightKg')
    ..aE<ExperienceLevel>(2, _omitFieldNames ? '' : 'experience',
        enumValues: ExperienceLevel.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRecommendedStartingWeightsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRecommendedStartingWeightsRequest copyWith(
          void Function(GetRecommendedStartingWeightsRequest) updates) =>
      super.copyWith((message) =>
              updates(message as GetRecommendedStartingWeightsRequest))
          as GetRecommendedStartingWeightsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRecommendedStartingWeightsRequest create() =>
      GetRecommendedStartingWeightsRequest._();
  @$core.override
  GetRecommendedStartingWeightsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRecommendedStartingWeightsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetRecommendedStartingWeightsRequest>(create);
  static GetRecommendedStartingWeightsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get bodyweightKg => $_getN(0);
  @$pb.TagNumber(1)
  set bodyweightKg($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBodyweightKg() => $_has(0);
  @$pb.TagNumber(1)
  void clearBodyweightKg() => $_clearField(1);

  @$pb.TagNumber(2)
  ExperienceLevel get experience => $_getN(1);
  @$pb.TagNumber(2)
  set experience(ExperienceLevel value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasExperience() => $_has(1);
  @$pb.TagNumber(2)
  void clearExperience() => $_clearField(2);
}

class GetRecommendedStartingWeightsResponse extends $pb.GeneratedMessage {
  factory GetRecommendedStartingWeightsResponse({
    $core.Iterable<RecommendedWeight>? weights,
  }) {
    final result = create();
    if (weights != null) result.weights.addAll(weights);
    return result;
  }

  GetRecommendedStartingWeightsResponse._();

  factory GetRecommendedStartingWeightsResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRecommendedStartingWeightsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRecommendedStartingWeightsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<RecommendedWeight>(1, _omitFieldNames ? '' : 'weights',
        subBuilder: RecommendedWeight.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRecommendedStartingWeightsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRecommendedStartingWeightsResponse copyWith(
          void Function(GetRecommendedStartingWeightsResponse) updates) =>
      super.copyWith((message) =>
              updates(message as GetRecommendedStartingWeightsResponse))
          as GetRecommendedStartingWeightsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRecommendedStartingWeightsResponse create() =>
      GetRecommendedStartingWeightsResponse._();
  @$core.override
  GetRecommendedStartingWeightsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRecommendedStartingWeightsResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetRecommendedStartingWeightsResponse>(create);
  static GetRecommendedStartingWeightsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RecommendedWeight> get weights => $_getList(0);
}

class GetExerciseProgressRequest extends $pb.GeneratedMessage {
  factory GetExerciseProgressRequest() => create();

  GetExerciseProgressRequest._();

  factory GetExerciseProgressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetExerciseProgressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetExerciseProgressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetExerciseProgressRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetExerciseProgressRequest copyWith(
          void Function(GetExerciseProgressRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetExerciseProgressRequest))
          as GetExerciseProgressRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetExerciseProgressRequest create() => GetExerciseProgressRequest._();
  @$core.override
  GetExerciseProgressRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetExerciseProgressRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetExerciseProgressRequest>(create);
  static GetExerciseProgressRequest? _defaultInstance;
}

class GetExerciseProgressResponse extends $pb.GeneratedMessage {
  factory GetExerciseProgressResponse({
    $core.Iterable<ExerciseProgress>? exercises,
    $core.int? workoutCount,
    $core.double? totalVolume,
    $fixnum.Int64? since,
  }) {
    final result = create();
    if (exercises != null) result.exercises.addAll(exercises);
    if (workoutCount != null) result.workoutCount = workoutCount;
    if (totalVolume != null) result.totalVolume = totalVolume;
    if (since != null) result.since = since;
    return result;
  }

  GetExerciseProgressResponse._();

  factory GetExerciseProgressResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetExerciseProgressResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetExerciseProgressResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<ExerciseProgress>(1, _omitFieldNames ? '' : 'exercises',
        subBuilder: ExerciseProgress.create)
    ..aI(2, _omitFieldNames ? '' : 'workoutCount')
    ..aD(3, _omitFieldNames ? '' : 'totalVolume', fieldType: $pb.PbFieldType.OF)
    ..aInt64(4, _omitFieldNames ? '' : 'since')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetExerciseProgressResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetExerciseProgressResponse copyWith(
          void Function(GetExerciseProgressResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetExerciseProgressResponse))
          as GetExerciseProgressResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetExerciseProgressResponse create() =>
      GetExerciseProgressResponse._();
  @$core.override
  GetExerciseProgressResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetExerciseProgressResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetExerciseProgressResponse>(create);
  static GetExerciseProgressResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ExerciseProgress> get exercises => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get workoutCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set workoutCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get totalVolume => $_getN(2);
  @$pb.TagNumber(3)
  set totalVolume($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalVolume() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalVolume() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get since => $_getI64(3);
  @$pb.TagNumber(4)
  set since($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSince() => $_has(3);
  @$pb.TagNumber(4)
  void clearSince() => $_clearField(4);
}

class PlannedGroupSet extends $pb.GeneratedMessage {
  factory PlannedGroupSet({
    Exercise? exercise,
    $core.int? targetReps,
    $core.double? targetWeight,
    $core.bool? warmup,
    $core.int? restAfterSuccess,
    $core.int? restAfterFailure,
    $core.bool? isAmrap,
    $core.String? instruction,
    ProgressionHint? progressionHint,
    $core.String? clientSetId,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (targetReps != null) result.targetReps = targetReps;
    if (targetWeight != null) result.targetWeight = targetWeight;
    if (warmup != null) result.warmup = warmup;
    if (restAfterSuccess != null) result.restAfterSuccess = restAfterSuccess;
    if (restAfterFailure != null) result.restAfterFailure = restAfterFailure;
    if (isAmrap != null) result.isAmrap = isAmrap;
    if (instruction != null) result.instruction = instruction;
    if (progressionHint != null) result.progressionHint = progressionHint;
    if (clientSetId != null) result.clientSetId = clientSetId;
    return result;
  }

  PlannedGroupSet._();

  factory PlannedGroupSet.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlannedGroupSet.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlannedGroupSet',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..aI(2, _omitFieldNames ? '' : 'targetReps')
    ..aD(3, _omitFieldNames ? '' : 'targetWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aOB(4, _omitFieldNames ? '' : 'warmup')
    ..aI(5, _omitFieldNames ? '' : 'restAfterSuccess')
    ..aI(6, _omitFieldNames ? '' : 'restAfterFailure')
    ..aOB(7, _omitFieldNames ? '' : 'isAmrap')
    ..aOS(8, _omitFieldNames ? '' : 'instruction')
    ..aOM<ProgressionHint>(9, _omitFieldNames ? '' : 'progressionHint',
        subBuilder: ProgressionHint.create)
    ..aOS(10, _omitFieldNames ? '' : 'clientSetId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlannedGroupSet clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlannedGroupSet copyWith(void Function(PlannedGroupSet) updates) =>
      super.copyWith((message) => updates(message as PlannedGroupSet))
          as PlannedGroupSet;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlannedGroupSet create() => PlannedGroupSet._();
  @$core.override
  PlannedGroupSet createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlannedGroupSet getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlannedGroupSet>(create);
  static PlannedGroupSet? _defaultInstance;

  @$pb.TagNumber(1)
  Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise(Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get targetReps => $_getIZ(1);
  @$pb.TagNumber(2)
  set targetReps($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetReps() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetReps() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get targetWeight => $_getN(2);
  @$pb.TagNumber(3)
  set targetWeight($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTargetWeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetWeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get warmup => $_getBF(3);
  @$pb.TagNumber(4)
  set warmup($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWarmup() => $_has(3);
  @$pb.TagNumber(4)
  void clearWarmup() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get restAfterSuccess => $_getIZ(4);
  @$pb.TagNumber(5)
  set restAfterSuccess($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRestAfterSuccess() => $_has(4);
  @$pb.TagNumber(5)
  void clearRestAfterSuccess() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get restAfterFailure => $_getIZ(5);
  @$pb.TagNumber(6)
  set restAfterFailure($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRestAfterFailure() => $_has(5);
  @$pb.TagNumber(6)
  void clearRestAfterFailure() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isAmrap => $_getBF(6);
  @$pb.TagNumber(7)
  set isAmrap($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsAmrap() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsAmrap() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get instruction => $_getSZ(7);
  @$pb.TagNumber(8)
  set instruction($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasInstruction() => $_has(7);
  @$pb.TagNumber(8)
  void clearInstruction() => $_clearField(8);

  @$pb.TagNumber(9)
  ProgressionHint get progressionHint => $_getN(8);
  @$pb.TagNumber(9)
  set progressionHint(ProgressionHint value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasProgressionHint() => $_has(8);
  @$pb.TagNumber(9)
  void clearProgressionHint() => $_clearField(9);
  @$pb.TagNumber(9)
  ProgressionHint ensureProgressionHint() => $_ensure(8);

  @$pb.TagNumber(10)
  $core.String get clientSetId => $_getSZ(9);
  @$pb.TagNumber(10)
  set clientSetId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasClientSetId() => $_has(9);
  @$pb.TagNumber(10)
  void clearClientSetId() => $_clearField(10);
}

class ProgressionHint extends $pb.GeneratedMessage {
  factory ProgressionHint({
    $core.String? slotKey,
    $core.String? tier,
    ProgressionRule? rule,
    $core.int? amrapSuccessThreshold,
    $core.bool? countsTowardProgram,
  }) {
    final result = create();
    if (slotKey != null) result.slotKey = slotKey;
    if (tier != null) result.tier = tier;
    if (rule != null) result.rule = rule;
    if (amrapSuccessThreshold != null)
      result.amrapSuccessThreshold = amrapSuccessThreshold;
    if (countsTowardProgram != null)
      result.countsTowardProgram = countsTowardProgram;
    return result;
  }

  ProgressionHint._();

  factory ProgressionHint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgressionHint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressionHint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'slotKey')
    ..aOS(2, _omitFieldNames ? '' : 'tier')
    ..aE<ProgressionRule>(3, _omitFieldNames ? '' : 'rule',
        enumValues: ProgressionRule.values)
    ..aI(4, _omitFieldNames ? '' : 'amrapSuccessThreshold')
    ..aOB(5, _omitFieldNames ? '' : 'countsTowardProgram')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressionHint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressionHint copyWith(void Function(ProgressionHint) updates) =>
      super.copyWith((message) => updates(message as ProgressionHint))
          as ProgressionHint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProgressionHint create() => ProgressionHint._();
  @$core.override
  ProgressionHint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgressionHint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgressionHint>(create);
  static ProgressionHint? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get slotKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set slotKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSlotKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSlotKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tier => $_getSZ(1);
  @$pb.TagNumber(2)
  set tier($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTier() => $_has(1);
  @$pb.TagNumber(2)
  void clearTier() => $_clearField(2);

  @$pb.TagNumber(3)
  ProgressionRule get rule => $_getN(2);
  @$pb.TagNumber(3)
  set rule(ProgressionRule value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRule() => $_has(2);
  @$pb.TagNumber(3)
  void clearRule() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get amrapSuccessThreshold => $_getIZ(3);
  @$pb.TagNumber(4)
  set amrapSuccessThreshold($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmrapSuccessThreshold() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmrapSuccessThreshold() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get countsTowardProgram => $_getBF(4);
  @$pb.TagNumber(5)
  set countsTowardProgram($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCountsTowardProgram() => $_has(4);
  @$pb.TagNumber(5)
  void clearCountsTowardProgram() => $_clearField(5);
}

class ReplaceExerciseGroupPlanRequest extends $pb.GeneratedMessage {
  factory ReplaceExerciseGroupPlanRequest({
    $core.String? workoutId,
    $core.String? exerciseGroupId,
    $core.String? name,
    $core.bool? interleaveWarmups,
    $core.Iterable<PlannedGroupSet>? sets,
    RestConfig? restConfig,
    $core.bool? deleteGroupIfEmpty,
    $core.String? instruction,
    $core.bool? createIfMissing,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (exerciseGroupId != null) result.exerciseGroupId = exerciseGroupId;
    if (name != null) result.name = name;
    if (interleaveWarmups != null) result.interleaveWarmups = interleaveWarmups;
    if (sets != null) result.sets.addAll(sets);
    if (restConfig != null) result.restConfig = restConfig;
    if (deleteGroupIfEmpty != null)
      result.deleteGroupIfEmpty = deleteGroupIfEmpty;
    if (instruction != null) result.instruction = instruction;
    if (createIfMissing != null) result.createIfMissing = createIfMissing;
    return result;
  }

  ReplaceExerciseGroupPlanRequest._();

  factory ReplaceExerciseGroupPlanRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReplaceExerciseGroupPlanRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReplaceExerciseGroupPlanRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'exerciseGroupId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOB(4, _omitFieldNames ? '' : 'interleaveWarmups')
    ..pPM<PlannedGroupSet>(5, _omitFieldNames ? '' : 'sets',
        subBuilder: PlannedGroupSet.create)
    ..aOM<RestConfig>(6, _omitFieldNames ? '' : 'restConfig',
        subBuilder: RestConfig.create)
    ..aOB(7, _omitFieldNames ? '' : 'deleteGroupIfEmpty')
    ..aOS(8, _omitFieldNames ? '' : 'instruction')
    ..aOB(9, _omitFieldNames ? '' : 'createIfMissing')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplaceExerciseGroupPlanRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplaceExerciseGroupPlanRequest copyWith(
          void Function(ReplaceExerciseGroupPlanRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ReplaceExerciseGroupPlanRequest))
          as ReplaceExerciseGroupPlanRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReplaceExerciseGroupPlanRequest create() =>
      ReplaceExerciseGroupPlanRequest._();
  @$core.override
  ReplaceExerciseGroupPlanRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReplaceExerciseGroupPlanRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReplaceExerciseGroupPlanRequest>(
          create);
  static ReplaceExerciseGroupPlanRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exerciseGroupId => $_getSZ(1);
  @$pb.TagNumber(2)
  set exerciseGroupId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExerciseGroupId() => $_has(1);
  @$pb.TagNumber(2)
  void clearExerciseGroupId() => $_clearField(2);

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
  $pb.PbList<PlannedGroupSet> get sets => $_getList(4);

  @$pb.TagNumber(6)
  RestConfig get restConfig => $_getN(5);
  @$pb.TagNumber(6)
  set restConfig(RestConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRestConfig() => $_has(5);
  @$pb.TagNumber(6)
  void clearRestConfig() => $_clearField(6);
  @$pb.TagNumber(6)
  RestConfig ensureRestConfig() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.bool get deleteGroupIfEmpty => $_getBF(6);
  @$pb.TagNumber(7)
  set deleteGroupIfEmpty($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDeleteGroupIfEmpty() => $_has(6);
  @$pb.TagNumber(7)
  void clearDeleteGroupIfEmpty() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get instruction => $_getSZ(7);
  @$pb.TagNumber(8)
  set instruction($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasInstruction() => $_has(7);
  @$pb.TagNumber(8)
  void clearInstruction() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get createIfMissing => $_getBF(8);
  @$pb.TagNumber(9)
  set createIfMissing($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCreateIfMissing() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreateIfMissing() => $_clearField(9);
}

class ReplaceExerciseGroupPlanResponse extends $pb.GeneratedMessage {
  factory ReplaceExerciseGroupPlanResponse({
    ExerciseGroup? group,
    $core.Iterable<ProposedSet>? generatedSets,
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
  }) {
    final result = create();
    if (group != null) result.group = group;
    if (generatedSets != null) result.generatedSets.addAll(generatedSets);
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    return result;
  }

  ReplaceExerciseGroupPlanResponse._();

  factory ReplaceExerciseGroupPlanResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReplaceExerciseGroupPlanResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReplaceExerciseGroupPlanResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ExerciseGroup>(1, _omitFieldNames ? '' : 'group',
        subBuilder: ExerciseGroup.create)
    ..pPM<ProposedSet>(2, _omitFieldNames ? '' : 'generatedSets',
        subBuilder: ProposedSet.create)
    ..aOM<ProposedSet>(3, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(4, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplaceExerciseGroupPlanResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplaceExerciseGroupPlanResponse copyWith(
          void Function(ReplaceExerciseGroupPlanResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ReplaceExerciseGroupPlanResponse))
          as ReplaceExerciseGroupPlanResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReplaceExerciseGroupPlanResponse create() =>
      ReplaceExerciseGroupPlanResponse._();
  @$core.override
  ReplaceExerciseGroupPlanResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReplaceExerciseGroupPlanResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReplaceExerciseGroupPlanResponse>(
          create);
  static ReplaceExerciseGroupPlanResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ExerciseGroup get group => $_getN(0);
  @$pb.TagNumber(1)
  set group(ExerciseGroup value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasGroup() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroup() => $_clearField(1);
  @$pb.TagNumber(1)
  ExerciseGroup ensureGroup() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<ProposedSet> get generatedSets => $_getList(1);

  @$pb.TagNumber(3)
  ProposedSet get nextUpSet => $_getN(2);
  @$pb.TagNumber(3)
  set nextUpSet(ProposedSet value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasNextUpSet() => $_has(2);
  @$pb.TagNumber(3)
  void clearNextUpSet() => $_clearField(3);
  @$pb.TagNumber(3)
  ProposedSet ensureNextUpSet() => $_ensure(2);

  @$pb.TagNumber(4)
  WorkoutStateSnapshot get stateSnapshot => $_getN(3);
  @$pb.TagNumber(4)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStateSnapshot() => $_has(3);
  @$pb.TagNumber(4)
  void clearStateSnapshot() => $_clearField(4);
  @$pb.TagNumber(4)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(3);
}

class CreateExerciseGroupRequest extends $pb.GeneratedMessage {
  factory CreateExerciseGroupRequest({
    $core.String? workoutId,
    $core.String? name,
    $core.int? sets,
    $core.bool? interleaveWarmups,
    $core.Iterable<ExerciseTypeConfig>? exerciseConfigs,
    RestConfig? restConfig,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (name != null) result.name = name;
    if (sets != null) result.sets = sets;
    if (interleaveWarmups != null) result.interleaveWarmups = interleaveWarmups;
    if (exerciseConfigs != null) result.exerciseConfigs.addAll(exerciseConfigs);
    if (restConfig != null) result.restConfig = restConfig;
    return result;
  }

  CreateExerciseGroupRequest._();

  factory CreateExerciseGroupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateExerciseGroupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateExerciseGroupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'sets')
    ..aOB(4, _omitFieldNames ? '' : 'interleaveWarmups')
    ..pPM<ExerciseTypeConfig>(5, _omitFieldNames ? '' : 'exerciseConfigs',
        subBuilder: ExerciseTypeConfig.create)
    ..aOM<RestConfig>(6, _omitFieldNames ? '' : 'restConfig',
        subBuilder: RestConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExerciseGroupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExerciseGroupRequest copyWith(
          void Function(CreateExerciseGroupRequest) updates) =>
      super.copyWith(
              (message) => updates(message as CreateExerciseGroupRequest))
          as CreateExerciseGroupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateExerciseGroupRequest create() => CreateExerciseGroupRequest._();
  @$core.override
  CreateExerciseGroupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateExerciseGroupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateExerciseGroupRequest>(create);
  static CreateExerciseGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get sets => $_getIZ(2);
  @$pb.TagNumber(3)
  set sets($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSets() => $_has(2);
  @$pb.TagNumber(3)
  void clearSets() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get interleaveWarmups => $_getBF(3);
  @$pb.TagNumber(4)
  set interleaveWarmups($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInterleaveWarmups() => $_has(3);
  @$pb.TagNumber(4)
  void clearInterleaveWarmups() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<ExerciseTypeConfig> get exerciseConfigs => $_getList(4);

  @$pb.TagNumber(6)
  RestConfig get restConfig => $_getN(5);
  @$pb.TagNumber(6)
  set restConfig(RestConfig value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRestConfig() => $_has(5);
  @$pb.TagNumber(6)
  void clearRestConfig() => $_clearField(6);
  @$pb.TagNumber(6)
  RestConfig ensureRestConfig() => $_ensure(5);
}

class CreateExerciseGroupResponse extends $pb.GeneratedMessage {
  factory CreateExerciseGroupResponse({
    ExerciseGroup? group,
    $core.Iterable<ProposedSet>? generatedSets,
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
  }) {
    final result = create();
    if (group != null) result.group = group;
    if (generatedSets != null) result.generatedSets.addAll(generatedSets);
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    return result;
  }

  CreateExerciseGroupResponse._();

  factory CreateExerciseGroupResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateExerciseGroupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateExerciseGroupResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ExerciseGroup>(1, _omitFieldNames ? '' : 'group',
        subBuilder: ExerciseGroup.create)
    ..pPM<ProposedSet>(2, _omitFieldNames ? '' : 'generatedSets',
        subBuilder: ProposedSet.create)
    ..aOM<ProposedSet>(3, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(4, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExerciseGroupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateExerciseGroupResponse copyWith(
          void Function(CreateExerciseGroupResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CreateExerciseGroupResponse))
          as CreateExerciseGroupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateExerciseGroupResponse create() =>
      CreateExerciseGroupResponse._();
  @$core.override
  CreateExerciseGroupResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateExerciseGroupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateExerciseGroupResponse>(create);
  static CreateExerciseGroupResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ExerciseGroup get group => $_getN(0);
  @$pb.TagNumber(1)
  set group(ExerciseGroup value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasGroup() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroup() => $_clearField(1);
  @$pb.TagNumber(1)
  ExerciseGroup ensureGroup() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<ProposedSet> get generatedSets => $_getList(1);

  @$pb.TagNumber(3)
  ProposedSet get nextUpSet => $_getN(2);
  @$pb.TagNumber(3)
  set nextUpSet(ProposedSet value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasNextUpSet() => $_has(2);
  @$pb.TagNumber(3)
  void clearNextUpSet() => $_clearField(3);
  @$pb.TagNumber(3)
  ProposedSet ensureNextUpSet() => $_ensure(2);

  @$pb.TagNumber(4)
  WorkoutStateSnapshot get stateSnapshot => $_getN(3);
  @$pb.TagNumber(4)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStateSnapshot() => $_has(3);
  @$pb.TagNumber(4)
  void clearStateSnapshot() => $_clearField(4);
  @$pb.TagNumber(4)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(3);
}

class StartSetRequest extends $pb.GeneratedMessage {
  factory StartSetRequest({
    $core.String? workoutId,
    $core.String? proposedSetId,
    $fixnum.Int64? startedAt,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (proposedSetId != null) result.proposedSetId = proposedSetId;
    if (startedAt != null) result.startedAt = startedAt;
    return result;
  }

  StartSetRequest._();

  factory StartSetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartSetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartSetRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'proposedSetId')
    ..aInt64(3, _omitFieldNames ? '' : 'startedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSetRequest copyWith(void Function(StartSetRequest) updates) =>
      super.copyWith((message) => updates(message as StartSetRequest))
          as StartSetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartSetRequest create() => StartSetRequest._();
  @$core.override
  StartSetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StartSetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartSetRequest>(create);
  static StartSetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get proposedSetId => $_getSZ(1);
  @$pb.TagNumber(2)
  set proposedSetId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProposedSetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProposedSetId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get startedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set startedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartedAt() => $_clearField(3);
}

class StartSetResponse extends $pb.GeneratedMessage {
  factory StartSetResponse({
    CompletedSet? completedSet,
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (completedSet != null) result.completedSet = completedSet;
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  StartSetResponse._();

  factory StartSetResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StartSetResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartSetResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<CompletedSet>(1, _omitFieldNames ? '' : 'completedSet',
        subBuilder: CompletedSet.create)
    ..aOM<ProposedSet>(2, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(3, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(4, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSetResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartSetResponse copyWith(void Function(StartSetResponse) updates) =>
      super.copyWith((message) => updates(message as StartSetResponse))
          as StartSetResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StartSetResponse create() => StartSetResponse._();
  @$core.override
  StartSetResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StartSetResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartSetResponse>(create);
  static StartSetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  CompletedSet get completedSet => $_getN(0);
  @$pb.TagNumber(1)
  set completedSet(CompletedSet value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCompletedSet() => $_has(0);
  @$pb.TagNumber(1)
  void clearCompletedSet() => $_clearField(1);
  @$pb.TagNumber(1)
  CompletedSet ensureCompletedSet() => $_ensure(0);

  @$pb.TagNumber(2)
  ProposedSet get nextUpSet => $_getN(1);
  @$pb.TagNumber(2)
  set nextUpSet(ProposedSet value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNextUpSet() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextUpSet() => $_clearField(2);
  @$pb.TagNumber(2)
  ProposedSet ensureNextUpSet() => $_ensure(1);

  @$pb.TagNumber(3)
  WorkoutStateSnapshot get stateSnapshot => $_getN(2);
  @$pb.TagNumber(3)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStateSnapshot() => $_has(2);
  @$pb.TagNumber(3)
  void clearStateSnapshot() => $_clearField(3);
  @$pb.TagNumber(3)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<UserMessage> get userMessages => $_getList(3);
}

class CompleteSetRequest extends $pb.GeneratedMessage {
  factory CompleteSetRequest({
    $core.String? workoutId,
    $core.String? proposedSetId,
    $core.int? actualReps,
    $core.double? actualWeight,
    $fixnum.Int64? completedAt,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (proposedSetId != null) result.proposedSetId = proposedSetId;
    if (actualReps != null) result.actualReps = actualReps;
    if (actualWeight != null) result.actualWeight = actualWeight;
    if (completedAt != null) result.completedAt = completedAt;
    return result;
  }

  CompleteSetRequest._();

  factory CompleteSetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteSetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteSetRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'proposedSetId')
    ..aI(3, _omitFieldNames ? '' : 'actualReps')
    ..aD(4, _omitFieldNames ? '' : 'actualWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aInt64(5, _omitFieldNames ? '' : 'completedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteSetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteSetRequest copyWith(void Function(CompleteSetRequest) updates) =>
      super.copyWith((message) => updates(message as CompleteSetRequest))
          as CompleteSetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteSetRequest create() => CompleteSetRequest._();
  @$core.override
  CompleteSetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteSetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteSetRequest>(create);
  static CompleteSetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get proposedSetId => $_getSZ(1);
  @$pb.TagNumber(2)
  set proposedSetId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProposedSetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProposedSetId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get actualReps => $_getIZ(2);
  @$pb.TagNumber(3)
  set actualReps($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActualReps() => $_has(2);
  @$pb.TagNumber(3)
  void clearActualReps() => $_clearField(3);

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

class CompleteSetResponse extends $pb.GeneratedMessage {
  factory CompleteSetResponse({
    CompletedSet? completedSet,
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (completedSet != null) result.completedSet = completedSet;
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  CompleteSetResponse._();

  factory CompleteSetResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteSetResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteSetResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<CompletedSet>(1, _omitFieldNames ? '' : 'completedSet',
        subBuilder: CompletedSet.create)
    ..aOM<ProposedSet>(2, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(3, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(4, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteSetResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteSetResponse copyWith(void Function(CompleteSetResponse) updates) =>
      super.copyWith((message) => updates(message as CompleteSetResponse))
          as CompleteSetResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteSetResponse create() => CompleteSetResponse._();
  @$core.override
  CompleteSetResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteSetResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteSetResponse>(create);
  static CompleteSetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  CompletedSet get completedSet => $_getN(0);
  @$pb.TagNumber(1)
  set completedSet(CompletedSet value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCompletedSet() => $_has(0);
  @$pb.TagNumber(1)
  void clearCompletedSet() => $_clearField(1);
  @$pb.TagNumber(1)
  CompletedSet ensureCompletedSet() => $_ensure(0);

  @$pb.TagNumber(2)
  ProposedSet get nextUpSet => $_getN(1);
  @$pb.TagNumber(2)
  set nextUpSet(ProposedSet value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNextUpSet() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextUpSet() => $_clearField(2);
  @$pb.TagNumber(2)
  ProposedSet ensureNextUpSet() => $_ensure(1);

  @$pb.TagNumber(3)
  WorkoutStateSnapshot get stateSnapshot => $_getN(2);
  @$pb.TagNumber(3)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStateSnapshot() => $_has(2);
  @$pb.TagNumber(3)
  void clearStateSnapshot() => $_clearField(3);
  @$pb.TagNumber(3)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<UserMessage> get userMessages => $_getList(3);
}

class DeleteCompletedSetRequest extends $pb.GeneratedMessage {
  factory DeleteCompletedSetRequest({
    $core.String? workoutId,
    $core.String? completedSetId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (completedSetId != null) result.completedSetId = completedSetId;
    return result;
  }

  DeleteCompletedSetRequest._();

  factory DeleteCompletedSetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteCompletedSetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteCompletedSetRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'completedSetId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCompletedSetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCompletedSetRequest copyWith(
          void Function(DeleteCompletedSetRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteCompletedSetRequest))
          as DeleteCompletedSetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteCompletedSetRequest create() => DeleteCompletedSetRequest._();
  @$core.override
  DeleteCompletedSetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteCompletedSetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteCompletedSetRequest>(create);
  static DeleteCompletedSetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get completedSetId => $_getSZ(1);
  @$pb.TagNumber(2)
  set completedSetId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCompletedSetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCompletedSetId() => $_clearField(2);
}

class DeleteCompletedSetResponse extends $pb.GeneratedMessage {
  factory DeleteCompletedSetResponse({
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  DeleteCompletedSetResponse._();

  factory DeleteCompletedSetResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteCompletedSetResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteCompletedSetResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ProposedSet>(1, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(2, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(3, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCompletedSetResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCompletedSetResponse copyWith(
          void Function(DeleteCompletedSetResponse) updates) =>
      super.copyWith(
              (message) => updates(message as DeleteCompletedSetResponse))
          as DeleteCompletedSetResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteCompletedSetResponse create() => DeleteCompletedSetResponse._();
  @$core.override
  DeleteCompletedSetResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteCompletedSetResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteCompletedSetResponse>(create);
  static DeleteCompletedSetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ProposedSet get nextUpSet => $_getN(0);
  @$pb.TagNumber(1)
  set nextUpSet(ProposedSet value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNextUpSet() => $_has(0);
  @$pb.TagNumber(1)
  void clearNextUpSet() => $_clearField(1);
  @$pb.TagNumber(1)
  ProposedSet ensureNextUpSet() => $_ensure(0);

  @$pb.TagNumber(2)
  WorkoutStateSnapshot get stateSnapshot => $_getN(1);
  @$pb.TagNumber(2)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStateSnapshot() => $_has(1);
  @$pb.TagNumber(2)
  void clearStateSnapshot() => $_clearField(2);
  @$pb.TagNumber(2)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<UserMessage> get userMessages => $_getList(2);
}

class CancelProposedSetRequest extends $pb.GeneratedMessage {
  factory CancelProposedSetRequest({
    $core.String? workoutId,
    $core.String? proposedSetId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (proposedSetId != null) result.proposedSetId = proposedSetId;
    return result;
  }

  CancelProposedSetRequest._();

  factory CancelProposedSetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CancelProposedSetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelProposedSetRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'proposedSetId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelProposedSetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelProposedSetRequest copyWith(
          void Function(CancelProposedSetRequest) updates) =>
      super.copyWith((message) => updates(message as CancelProposedSetRequest))
          as CancelProposedSetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CancelProposedSetRequest create() => CancelProposedSetRequest._();
  @$core.override
  CancelProposedSetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CancelProposedSetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CancelProposedSetRequest>(create);
  static CancelProposedSetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get proposedSetId => $_getSZ(1);
  @$pb.TagNumber(2)
  set proposedSetId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProposedSetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProposedSetId() => $_clearField(2);
}

class CancelProposedSetResponse extends $pb.GeneratedMessage {
  factory CancelProposedSetResponse({
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  CancelProposedSetResponse._();

  factory CancelProposedSetResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CancelProposedSetResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelProposedSetResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ProposedSet>(1, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(2, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(3, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelProposedSetResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelProposedSetResponse copyWith(
          void Function(CancelProposedSetResponse) updates) =>
      super.copyWith((message) => updates(message as CancelProposedSetResponse))
          as CancelProposedSetResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CancelProposedSetResponse create() => CancelProposedSetResponse._();
  @$core.override
  CancelProposedSetResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CancelProposedSetResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CancelProposedSetResponse>(create);
  static CancelProposedSetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ProposedSet get nextUpSet => $_getN(0);
  @$pb.TagNumber(1)
  set nextUpSet(ProposedSet value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNextUpSet() => $_has(0);
  @$pb.TagNumber(1)
  void clearNextUpSet() => $_clearField(1);
  @$pb.TagNumber(1)
  ProposedSet ensureNextUpSet() => $_ensure(0);

  @$pb.TagNumber(2)
  WorkoutStateSnapshot get stateSnapshot => $_getN(1);
  @$pb.TagNumber(2)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStateSnapshot() => $_has(1);
  @$pb.TagNumber(2)
  void clearStateSnapshot() => $_clearField(2);
  @$pb.TagNumber(2)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<UserMessage> get userMessages => $_getList(2);
}

class EndWorkoutRequest extends $pb.GeneratedMessage {
  factory EndWorkoutRequest({
    $core.String? workoutId,
    $fixnum.Int64? endedAt,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (endedAt != null) result.endedAt = endedAt;
    return result;
  }

  EndWorkoutRequest._();

  factory EndWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EndWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EndWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aInt64(2, _omitFieldNames ? '' : 'endedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EndWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EndWorkoutRequest copyWith(void Function(EndWorkoutRequest) updates) =>
      super.copyWith((message) => updates(message as EndWorkoutRequest))
          as EndWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EndWorkoutRequest create() => EndWorkoutRequest._();
  @$core.override
  EndWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EndWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EndWorkoutRequest>(create);
  static EndWorkoutRequest? _defaultInstance;

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

class EndWorkoutResponse extends $pb.GeneratedMessage {
  factory EndWorkoutResponse({
    Workout? workout,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  EndWorkoutResponse._();

  factory EndWorkoutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EndWorkoutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EndWorkoutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<Workout>(1, _omitFieldNames ? '' : 'workout',
        subBuilder: Workout.create)
    ..pPM<UserMessage>(2, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EndWorkoutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EndWorkoutResponse copyWith(void Function(EndWorkoutResponse) updates) =>
      super.copyWith((message) => updates(message as EndWorkoutResponse))
          as EndWorkoutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EndWorkoutResponse create() => EndWorkoutResponse._();
  @$core.override
  EndWorkoutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EndWorkoutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EndWorkoutResponse>(create);
  static EndWorkoutResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Workout get workout => $_getN(0);
  @$pb.TagNumber(1)
  set workout(Workout value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkout() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkout() => $_clearField(1);
  @$pb.TagNumber(1)
  Workout ensureWorkout() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<UserMessage> get userMessages => $_getList(1);
}

class GetProposedWorkoutScheduleRequest extends $pb.GeneratedMessage {
  factory GetProposedWorkoutScheduleRequest({
    $core.String? userId,
    $fixnum.Int64? atTime,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (atTime != null) result.atTime = atTime;
    return result;
  }

  GetProposedWorkoutScheduleRequest._();

  factory GetProposedWorkoutScheduleRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProposedWorkoutScheduleRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProposedWorkoutScheduleRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aInt64(2, _omitFieldNames ? '' : 'atTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProposedWorkoutScheduleRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProposedWorkoutScheduleRequest copyWith(
          void Function(GetProposedWorkoutScheduleRequest) updates) =>
      super.copyWith((message) =>
              updates(message as GetProposedWorkoutScheduleRequest))
          as GetProposedWorkoutScheduleRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProposedWorkoutScheduleRequest create() =>
      GetProposedWorkoutScheduleRequest._();
  @$core.override
  GetProposedWorkoutScheduleRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProposedWorkoutScheduleRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProposedWorkoutScheduleRequest>(
          create);
  static GetProposedWorkoutScheduleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get atTime => $_getI64(1);
  @$pb.TagNumber(2)
  set atTime($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAtTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearAtTime() => $_clearField(2);
}

class ExerciseStatus extends $pb.GeneratedMessage {
  factory ExerciseStatus({
    Exercise? exercise,
    $core.double? targetWeight,
    $fixnum.Int64? lastPerformedAt,
    $core.Iterable<$core.double>? weightHistory,
    $core.Iterable<MuscleGroup>? muscleGroups,
    $core.int? defaultSets,
    $core.int? defaultReps,
    $core.bool? recovered,
    $core.bool? alwaysInclude,
    ExerciseCategory? category,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (targetWeight != null) result.targetWeight = targetWeight;
    if (lastPerformedAt != null) result.lastPerformedAt = lastPerformedAt;
    if (weightHistory != null) result.weightHistory.addAll(weightHistory);
    if (muscleGroups != null) result.muscleGroups.addAll(muscleGroups);
    if (defaultSets != null) result.defaultSets = defaultSets;
    if (defaultReps != null) result.defaultReps = defaultReps;
    if (recovered != null) result.recovered = recovered;
    if (alwaysInclude != null) result.alwaysInclude = alwaysInclude;
    if (category != null) result.category = category;
    return result;
  }

  ExerciseStatus._();

  factory ExerciseStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..aD(2, _omitFieldNames ? '' : 'targetWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aInt64(3, _omitFieldNames ? '' : 'lastPerformedAt')
    ..p<$core.double>(
        4, _omitFieldNames ? '' : 'weightHistory', $pb.PbFieldType.KF)
    ..pc<MuscleGroup>(
        5, _omitFieldNames ? '' : 'muscleGroups', $pb.PbFieldType.KE,
        valueOf: MuscleGroup.valueOf,
        enumValues: MuscleGroup.values,
        defaultEnumValue: MuscleGroup.MUSCLE_GROUP_UNSPECIFIED)
    ..aI(6, _omitFieldNames ? '' : 'defaultSets')
    ..aI(7, _omitFieldNames ? '' : 'defaultReps')
    ..aOB(8, _omitFieldNames ? '' : 'recovered')
    ..aOB(9, _omitFieldNames ? '' : 'alwaysInclude')
    ..aE<ExerciseCategory>(10, _omitFieldNames ? '' : 'category',
        enumValues: ExerciseCategory.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseStatus copyWith(void Function(ExerciseStatus) updates) =>
      super.copyWith((message) => updates(message as ExerciseStatus))
          as ExerciseStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseStatus create() => ExerciseStatus._();
  @$core.override
  ExerciseStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseStatus>(create);
  static ExerciseStatus? _defaultInstance;

  @$pb.TagNumber(1)
  Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise(Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get targetWeight => $_getN(1);
  @$pb.TagNumber(2)
  set targetWeight($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetWeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetWeight() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lastPerformedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set lastPerformedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastPerformedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastPerformedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.double> get weightHistory => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<MuscleGroup> get muscleGroups => $_getList(4);

  @$pb.TagNumber(6)
  $core.int get defaultSets => $_getIZ(5);
  @$pb.TagNumber(6)
  set defaultSets($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDefaultSets() => $_has(5);
  @$pb.TagNumber(6)
  void clearDefaultSets() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get defaultReps => $_getIZ(6);
  @$pb.TagNumber(7)
  set defaultReps($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDefaultReps() => $_has(6);
  @$pb.TagNumber(7)
  void clearDefaultReps() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get recovered => $_getBF(7);
  @$pb.TagNumber(8)
  set recovered($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRecovered() => $_has(7);
  @$pb.TagNumber(8)
  void clearRecovered() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get alwaysInclude => $_getBF(8);
  @$pb.TagNumber(9)
  set alwaysInclude($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAlwaysInclude() => $_has(8);
  @$pb.TagNumber(9)
  void clearAlwaysInclude() => $_clearField(9);

  @$pb.TagNumber(10)
  ExerciseCategory get category => $_getN(9);
  @$pb.TagNumber(10)
  set category(ExerciseCategory value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasCategory() => $_has(9);
  @$pb.TagNumber(10)
  void clearCategory() => $_clearField(10);
}

class ProposedExerciseGroup extends $pb.GeneratedMessage {
  factory ProposedExerciseGroup({
    $core.String? name,
    $core.int? sets,
    $core.bool? interleaveWarmups,
    $core.Iterable<ExerciseTypeConfig>? exerciseConfigs,
    RestConfig? restConfig,
    $core.Iterable<$core.String>? tags,
    $core.bool? prescribedByRegime,
    $fixnum.Int64? estimatedDurationSeconds,
    $core.Iterable<ProposedSet>? materializedSets,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (sets != null) result.sets = sets;
    if (interleaveWarmups != null) result.interleaveWarmups = interleaveWarmups;
    if (exerciseConfigs != null) result.exerciseConfigs.addAll(exerciseConfigs);
    if (restConfig != null) result.restConfig = restConfig;
    if (tags != null) result.tags.addAll(tags);
    if (prescribedByRegime != null)
      result.prescribedByRegime = prescribedByRegime;
    if (estimatedDurationSeconds != null)
      result.estimatedDurationSeconds = estimatedDurationSeconds;
    if (materializedSets != null)
      result.materializedSets.addAll(materializedSets);
    return result;
  }

  ProposedExerciseGroup._();

  factory ProposedExerciseGroup.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProposedExerciseGroup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProposedExerciseGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aI(2, _omitFieldNames ? '' : 'sets')
    ..aOB(3, _omitFieldNames ? '' : 'interleaveWarmups')
    ..pPM<ExerciseTypeConfig>(4, _omitFieldNames ? '' : 'exerciseConfigs',
        subBuilder: ExerciseTypeConfig.create)
    ..aOM<RestConfig>(5, _omitFieldNames ? '' : 'restConfig',
        subBuilder: RestConfig.create)
    ..pPS(6, _omitFieldNames ? '' : 'tags')
    ..aOB(7, _omitFieldNames ? '' : 'prescribedByRegime')
    ..aInt64(8, _omitFieldNames ? '' : 'estimatedDurationSeconds')
    ..pPM<ProposedSet>(9, _omitFieldNames ? '' : 'materializedSets',
        subBuilder: ProposedSet.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProposedExerciseGroup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProposedExerciseGroup copyWith(
          void Function(ProposedExerciseGroup) updates) =>
      super.copyWith((message) => updates(message as ProposedExerciseGroup))
          as ProposedExerciseGroup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProposedExerciseGroup create() => ProposedExerciseGroup._();
  @$core.override
  ProposedExerciseGroup createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProposedExerciseGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProposedExerciseGroup>(create);
  static ProposedExerciseGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get sets => $_getIZ(1);
  @$pb.TagNumber(2)
  set sets($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSets() => $_has(1);
  @$pb.TagNumber(2)
  void clearSets() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get interleaveWarmups => $_getBF(2);
  @$pb.TagNumber(3)
  set interleaveWarmups($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInterleaveWarmups() => $_has(2);
  @$pb.TagNumber(3)
  void clearInterleaveWarmups() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<ExerciseTypeConfig> get exerciseConfigs => $_getList(3);

  @$pb.TagNumber(5)
  RestConfig get restConfig => $_getN(4);
  @$pb.TagNumber(5)
  set restConfig(RestConfig value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRestConfig() => $_has(4);
  @$pb.TagNumber(5)
  void clearRestConfig() => $_clearField(5);
  @$pb.TagNumber(5)
  RestConfig ensureRestConfig() => $_ensure(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get tags => $_getList(5);

  @$pb.TagNumber(7)
  $core.bool get prescribedByRegime => $_getBF(6);
  @$pb.TagNumber(7)
  set prescribedByRegime($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPrescribedByRegime() => $_has(6);
  @$pb.TagNumber(7)
  void clearPrescribedByRegime() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get estimatedDurationSeconds => $_getI64(7);
  @$pb.TagNumber(8)
  set estimatedDurationSeconds($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEstimatedDurationSeconds() => $_has(7);
  @$pb.TagNumber(8)
  void clearEstimatedDurationSeconds() => $_clearField(8);

  /// Server-materialized display sets (warmups + working sets, plate-snapped) so
  /// the preview renders them directly instead of expanding client-side.
  @$pb.TagNumber(9)
  $pb.PbList<ProposedSet> get materializedSets => $_getList(8);
}

class SlotTrainingStatus extends $pb.GeneratedMessage {
  factory SlotTrainingStatus({
    $core.String? slotKey,
    $core.String? label,
    $core.String? tier,
    $fixnum.Int64? lastTrainedAt,
    $core.int? daysSinceLastTrained,
    $core.int? targetSetsPer7Days,
    $core.int? completedSetsPer7Days,
    $core.int? remainingSetsPer7Days,
    $core.bool? appearsInNextWorkout,
    $core.String? statusLabel,
  }) {
    final result = create();
    if (slotKey != null) result.slotKey = slotKey;
    if (label != null) result.label = label;
    if (tier != null) result.tier = tier;
    if (lastTrainedAt != null) result.lastTrainedAt = lastTrainedAt;
    if (daysSinceLastTrained != null)
      result.daysSinceLastTrained = daysSinceLastTrained;
    if (targetSetsPer7Days != null)
      result.targetSetsPer7Days = targetSetsPer7Days;
    if (completedSetsPer7Days != null)
      result.completedSetsPer7Days = completedSetsPer7Days;
    if (remainingSetsPer7Days != null)
      result.remainingSetsPer7Days = remainingSetsPer7Days;
    if (appearsInNextWorkout != null)
      result.appearsInNextWorkout = appearsInNextWorkout;
    if (statusLabel != null) result.statusLabel = statusLabel;
    return result;
  }

  SlotTrainingStatus._();

  factory SlotTrainingStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SlotTrainingStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SlotTrainingStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'slotKey')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'tier')
    ..aInt64(4, _omitFieldNames ? '' : 'lastTrainedAt')
    ..aI(5, _omitFieldNames ? '' : 'daysSinceLastTrained')
    ..aI(6, _omitFieldNames ? '' : 'targetSetsPer7Days',
        protoName: 'target_sets_per_7_days')
    ..aI(7, _omitFieldNames ? '' : 'completedSetsPer7Days',
        protoName: 'completed_sets_per_7_days')
    ..aI(8, _omitFieldNames ? '' : 'remainingSetsPer7Days',
        protoName: 'remaining_sets_per_7_days')
    ..aOB(9, _omitFieldNames ? '' : 'appearsInNextWorkout')
    ..aOS(10, _omitFieldNames ? '' : 'statusLabel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SlotTrainingStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SlotTrainingStatus copyWith(void Function(SlotTrainingStatus) updates) =>
      super.copyWith((message) => updates(message as SlotTrainingStatus))
          as SlotTrainingStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SlotTrainingStatus create() => SlotTrainingStatus._();
  @$core.override
  SlotTrainingStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SlotTrainingStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SlotTrainingStatus>(create);
  static SlotTrainingStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get slotKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set slotKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSlotKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSlotKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get tier => $_getSZ(2);
  @$pb.TagNumber(3)
  set tier($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTier() => $_has(2);
  @$pb.TagNumber(3)
  void clearTier() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get lastTrainedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set lastTrainedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastTrainedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastTrainedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get daysSinceLastTrained => $_getIZ(4);
  @$pb.TagNumber(5)
  set daysSinceLastTrained($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDaysSinceLastTrained() => $_has(4);
  @$pb.TagNumber(5)
  void clearDaysSinceLastTrained() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get targetSetsPer7Days => $_getIZ(5);
  @$pb.TagNumber(6)
  set targetSetsPer7Days($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTargetSetsPer7Days() => $_has(5);
  @$pb.TagNumber(6)
  void clearTargetSetsPer7Days() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get completedSetsPer7Days => $_getIZ(6);
  @$pb.TagNumber(7)
  set completedSetsPer7Days($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCompletedSetsPer7Days() => $_has(6);
  @$pb.TagNumber(7)
  void clearCompletedSetsPer7Days() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get remainingSetsPer7Days => $_getIZ(7);
  @$pb.TagNumber(8)
  set remainingSetsPer7Days($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRemainingSetsPer7Days() => $_has(7);
  @$pb.TagNumber(8)
  void clearRemainingSetsPer7Days() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get appearsInNextWorkout => $_getBF(8);
  @$pb.TagNumber(9)
  set appearsInNextWorkout($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasAppearsInNextWorkout() => $_has(8);
  @$pb.TagNumber(9)
  void clearAppearsInNextWorkout() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get statusLabel => $_getSZ(9);
  @$pb.TagNumber(10)
  set statusLabel($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasStatusLabel() => $_has(9);
  @$pb.TagNumber(10)
  void clearStatusLabel() => $_clearField(10);
}

class MuscleRecoveryStatus extends $pb.GeneratedMessage {
  factory MuscleRecoveryStatus({
    $core.String? muscleKey,
    $core.String? label,
    $fixnum.Int64? lastTrainedAt,
    $fixnum.Int64? recoveredAt,
    $core.double? fraction,
    $fixnum.Int64? hoursRemaining,
    $core.bool? recovered,
    $core.bool? inNextWorkout,
  }) {
    final result = create();
    if (muscleKey != null) result.muscleKey = muscleKey;
    if (label != null) result.label = label;
    if (lastTrainedAt != null) result.lastTrainedAt = lastTrainedAt;
    if (recoveredAt != null) result.recoveredAt = recoveredAt;
    if (fraction != null) result.fraction = fraction;
    if (hoursRemaining != null) result.hoursRemaining = hoursRemaining;
    if (recovered != null) result.recovered = recovered;
    if (inNextWorkout != null) result.inNextWorkout = inNextWorkout;
    return result;
  }

  MuscleRecoveryStatus._();

  factory MuscleRecoveryStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MuscleRecoveryStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MuscleRecoveryStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'muscleKey')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aInt64(3, _omitFieldNames ? '' : 'lastTrainedAt')
    ..aInt64(4, _omitFieldNames ? '' : 'recoveredAt')
    ..aD(5, _omitFieldNames ? '' : 'fraction', fieldType: $pb.PbFieldType.OF)
    ..aInt64(6, _omitFieldNames ? '' : 'hoursRemaining')
    ..aOB(7, _omitFieldNames ? '' : 'recovered')
    ..aOB(8, _omitFieldNames ? '' : 'inNextWorkout')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MuscleRecoveryStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MuscleRecoveryStatus copyWith(void Function(MuscleRecoveryStatus) updates) =>
      super.copyWith((message) => updates(message as MuscleRecoveryStatus))
          as MuscleRecoveryStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MuscleRecoveryStatus create() => MuscleRecoveryStatus._();
  @$core.override
  MuscleRecoveryStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MuscleRecoveryStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MuscleRecoveryStatus>(create);
  static MuscleRecoveryStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get muscleKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set muscleKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMuscleKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearMuscleKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lastTrainedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set lastTrainedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastTrainedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastTrainedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get recoveredAt => $_getI64(3);
  @$pb.TagNumber(4)
  set recoveredAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRecoveredAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearRecoveredAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get fraction => $_getN(4);
  @$pb.TagNumber(5)
  set fraction($core.double value) => $_setFloat(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFraction() => $_has(4);
  @$pb.TagNumber(5)
  void clearFraction() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get hoursRemaining => $_getI64(5);
  @$pb.TagNumber(6)
  set hoursRemaining($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHoursRemaining() => $_has(5);
  @$pb.TagNumber(6)
  void clearHoursRemaining() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get recovered => $_getBF(6);
  @$pb.TagNumber(7)
  set recovered($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRecovered() => $_has(6);
  @$pb.TagNumber(7)
  void clearRecovered() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get inNextWorkout => $_getBF(7);
  @$pb.TagNumber(8)
  set inNextWorkout($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasInNextWorkout() => $_has(7);
  @$pb.TagNumber(8)
  void clearInNextWorkout() => $_clearField(8);
}

class TrainingStatus extends $pb.GeneratedMessage {
  factory TrainingStatus({
    $fixnum.Int64? nextSessionAt,
    $fixnum.Int64? lastSessionAt,
    $core.String? headline,
    $core.String? detail,
    $core.bool? shouldTrainNow,
    $core.int? targetSessionsPer7Days,
    $core.int? completedSessionsPer7Days,
    $core.int? remainingSessionsPer7Days,
    $core.int? targetSetsPer7Days,
    $core.int? completedSetsPer7Days,
    $core.int? remainingSetsPer7Days,
    $core.Iterable<SlotTrainingStatus>? slotStatuses,
    ReadinessState? readinessState,
    $fixnum.Int64? nextReadyAt,
    $core.Iterable<MuscleRecoveryStatus>? muscleRecovery,
    $core.Iterable<$core.String>? blockingMuscles,
    $core.int? avgGapHours,
    $core.int? sessionsLast7Days,
    $core.String? nextWorkoutLabel,
  }) {
    final result = create();
    if (nextSessionAt != null) result.nextSessionAt = nextSessionAt;
    if (lastSessionAt != null) result.lastSessionAt = lastSessionAt;
    if (headline != null) result.headline = headline;
    if (detail != null) result.detail = detail;
    if (shouldTrainNow != null) result.shouldTrainNow = shouldTrainNow;
    if (targetSessionsPer7Days != null)
      result.targetSessionsPer7Days = targetSessionsPer7Days;
    if (completedSessionsPer7Days != null)
      result.completedSessionsPer7Days = completedSessionsPer7Days;
    if (remainingSessionsPer7Days != null)
      result.remainingSessionsPer7Days = remainingSessionsPer7Days;
    if (targetSetsPer7Days != null)
      result.targetSetsPer7Days = targetSetsPer7Days;
    if (completedSetsPer7Days != null)
      result.completedSetsPer7Days = completedSetsPer7Days;
    if (remainingSetsPer7Days != null)
      result.remainingSetsPer7Days = remainingSetsPer7Days;
    if (slotStatuses != null) result.slotStatuses.addAll(slotStatuses);
    if (readinessState != null) result.readinessState = readinessState;
    if (nextReadyAt != null) result.nextReadyAt = nextReadyAt;
    if (muscleRecovery != null) result.muscleRecovery.addAll(muscleRecovery);
    if (blockingMuscles != null) result.blockingMuscles.addAll(blockingMuscles);
    if (avgGapHours != null) result.avgGapHours = avgGapHours;
    if (sessionsLast7Days != null) result.sessionsLast7Days = sessionsLast7Days;
    if (nextWorkoutLabel != null) result.nextWorkoutLabel = nextWorkoutLabel;
    return result;
  }

  TrainingStatus._();

  factory TrainingStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'nextSessionAt')
    ..aInt64(2, _omitFieldNames ? '' : 'lastSessionAt')
    ..aOS(3, _omitFieldNames ? '' : 'headline')
    ..aOS(4, _omitFieldNames ? '' : 'detail')
    ..aOB(5, _omitFieldNames ? '' : 'shouldTrainNow')
    ..aI(6, _omitFieldNames ? '' : 'targetSessionsPer7Days',
        protoName: 'target_sessions_per_7_days')
    ..aI(7, _omitFieldNames ? '' : 'completedSessionsPer7Days',
        protoName: 'completed_sessions_per_7_days')
    ..aI(8, _omitFieldNames ? '' : 'remainingSessionsPer7Days',
        protoName: 'remaining_sessions_per_7_days')
    ..aI(9, _omitFieldNames ? '' : 'targetSetsPer7Days',
        protoName: 'target_sets_per_7_days')
    ..aI(10, _omitFieldNames ? '' : 'completedSetsPer7Days',
        protoName: 'completed_sets_per_7_days')
    ..aI(11, _omitFieldNames ? '' : 'remainingSetsPer7Days',
        protoName: 'remaining_sets_per_7_days')
    ..pPM<SlotTrainingStatus>(12, _omitFieldNames ? '' : 'slotStatuses',
        subBuilder: SlotTrainingStatus.create)
    ..aE<ReadinessState>(13, _omitFieldNames ? '' : 'readinessState',
        enumValues: ReadinessState.values)
    ..aInt64(14, _omitFieldNames ? '' : 'nextReadyAt')
    ..pPM<MuscleRecoveryStatus>(15, _omitFieldNames ? '' : 'muscleRecovery',
        subBuilder: MuscleRecoveryStatus.create)
    ..pPS(16, _omitFieldNames ? '' : 'blockingMuscles')
    ..aI(17, _omitFieldNames ? '' : 'avgGapHours')
    ..aI(18, _omitFieldNames ? '' : 'sessionsLast7Days',
        protoName: 'sessions_last_7_days')
    ..aOS(19, _omitFieldNames ? '' : 'nextWorkoutLabel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingStatus copyWith(void Function(TrainingStatus) updates) =>
      super.copyWith((message) => updates(message as TrainingStatus))
          as TrainingStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingStatus create() => TrainingStatus._();
  @$core.override
  TrainingStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingStatus>(create);
  static TrainingStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get nextSessionAt => $_getI64(0);
  @$pb.TagNumber(1)
  set nextSessionAt($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNextSessionAt() => $_has(0);
  @$pb.TagNumber(1)
  void clearNextSessionAt() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get lastSessionAt => $_getI64(1);
  @$pb.TagNumber(2)
  set lastSessionAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLastSessionAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearLastSessionAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get headline => $_getSZ(2);
  @$pb.TagNumber(3)
  set headline($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeadline() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeadline() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get detail => $_getSZ(3);
  @$pb.TagNumber(4)
  set detail($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDetail() => $_has(3);
  @$pb.TagNumber(4)
  void clearDetail() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get shouldTrainNow => $_getBF(4);
  @$pb.TagNumber(5)
  set shouldTrainNow($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShouldTrainNow() => $_has(4);
  @$pb.TagNumber(5)
  void clearShouldTrainNow() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get targetSessionsPer7Days => $_getIZ(5);
  @$pb.TagNumber(6)
  set targetSessionsPer7Days($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTargetSessionsPer7Days() => $_has(5);
  @$pb.TagNumber(6)
  void clearTargetSessionsPer7Days() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get completedSessionsPer7Days => $_getIZ(6);
  @$pb.TagNumber(7)
  set completedSessionsPer7Days($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCompletedSessionsPer7Days() => $_has(6);
  @$pb.TagNumber(7)
  void clearCompletedSessionsPer7Days() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get remainingSessionsPer7Days => $_getIZ(7);
  @$pb.TagNumber(8)
  set remainingSessionsPer7Days($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRemainingSessionsPer7Days() => $_has(7);
  @$pb.TagNumber(8)
  void clearRemainingSessionsPer7Days() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get targetSetsPer7Days => $_getIZ(8);
  @$pb.TagNumber(9)
  set targetSetsPer7Days($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTargetSetsPer7Days() => $_has(8);
  @$pb.TagNumber(9)
  void clearTargetSetsPer7Days() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get completedSetsPer7Days => $_getIZ(9);
  @$pb.TagNumber(10)
  set completedSetsPer7Days($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCompletedSetsPer7Days() => $_has(9);
  @$pb.TagNumber(10)
  void clearCompletedSetsPer7Days() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get remainingSetsPer7Days => $_getIZ(10);
  @$pb.TagNumber(11)
  set remainingSetsPer7Days($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasRemainingSetsPer7Days() => $_has(10);
  @$pb.TagNumber(11)
  void clearRemainingSetsPer7Days() => $_clearField(11);

  @$pb.TagNumber(12)
  $pb.PbList<SlotTrainingStatus> get slotStatuses => $_getList(11);

  /// Readiness redesign (recovery + frequency model).
  @$pb.TagNumber(13)
  ReadinessState get readinessState => $_getN(12);
  @$pb.TagNumber(13)
  set readinessState(ReadinessState value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasReadinessState() => $_has(12);
  @$pb.TagNumber(13)
  void clearReadinessState() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get nextReadyAt => $_getI64(13);
  @$pb.TagNumber(14)
  set nextReadyAt($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasNextReadyAt() => $_has(13);
  @$pb.TagNumber(14)
  void clearNextReadyAt() => $_clearField(14);

  @$pb.TagNumber(15)
  $pb.PbList<MuscleRecoveryStatus> get muscleRecovery => $_getList(14);

  @$pb.TagNumber(16)
  $pb.PbList<$core.String> get blockingMuscles => $_getList(15);

  @$pb.TagNumber(17)
  $core.int get avgGapHours => $_getIZ(16);
  @$pb.TagNumber(17)
  set avgGapHours($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(17)
  $core.bool hasAvgGapHours() => $_has(16);
  @$pb.TagNumber(17)
  void clearAvgGapHours() => $_clearField(17);

  @$pb.TagNumber(18)
  $core.int get sessionsLast7Days => $_getIZ(17);
  @$pb.TagNumber(18)
  set sessionsLast7Days($core.int value) => $_setSignedInt32(17, value);
  @$pb.TagNumber(18)
  $core.bool hasSessionsLast7Days() => $_has(17);
  @$pb.TagNumber(18)
  void clearSessionsLast7Days() => $_clearField(18);

  @$pb.TagNumber(19)
  $core.String get nextWorkoutLabel => $_getSZ(18);
  @$pb.TagNumber(19)
  set nextWorkoutLabel($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasNextWorkoutLabel() => $_has(18);
  @$pb.TagNumber(19)
  void clearNextWorkoutLabel() => $_clearField(19);
}

class RegimeContext extends $pb.GeneratedMessage {
  factory RegimeContext({
    $core.String? regimeDisplayName,
    $core.String? sessionDescription,
    $core.String? nextSessionPreview,
    $core.String? phaseNarrative,
    $core.String? lastSessionSummary,
  }) {
    final result = create();
    if (regimeDisplayName != null) result.regimeDisplayName = regimeDisplayName;
    if (sessionDescription != null)
      result.sessionDescription = sessionDescription;
    if (nextSessionPreview != null)
      result.nextSessionPreview = nextSessionPreview;
    if (phaseNarrative != null) result.phaseNarrative = phaseNarrative;
    if (lastSessionSummary != null)
      result.lastSessionSummary = lastSessionSummary;
    return result;
  }

  RegimeContext._();

  factory RegimeContext.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegimeContext.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegimeContext',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'regimeDisplayName')
    ..aOS(2, _omitFieldNames ? '' : 'sessionDescription')
    ..aOS(3, _omitFieldNames ? '' : 'nextSessionPreview')
    ..aOS(4, _omitFieldNames ? '' : 'phaseNarrative')
    ..aOS(5, _omitFieldNames ? '' : 'lastSessionSummary')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegimeContext clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegimeContext copyWith(void Function(RegimeContext) updates) =>
      super.copyWith((message) => updates(message as RegimeContext))
          as RegimeContext;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegimeContext create() => RegimeContext._();
  @$core.override
  RegimeContext createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegimeContext getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegimeContext>(create);
  static RegimeContext? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get regimeDisplayName => $_getSZ(0);
  @$pb.TagNumber(1)
  set regimeDisplayName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRegimeDisplayName() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegimeDisplayName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionDescription => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionDescription($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get nextSessionPreview => $_getSZ(2);
  @$pb.TagNumber(3)
  set nextSessionPreview($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNextSessionPreview() => $_has(2);
  @$pb.TagNumber(3)
  void clearNextSessionPreview() => $_clearField(3);

  /// Phase explanation ("why today looks like this"). phase_narrative describes
  /// where you are in the cycle and what this session is (from program state);
  /// last_session_summary recaps what changed since last time (e.g. "Squat +5,
  /// Bench held") and is filled server-side from the progression messages.
  @$pb.TagNumber(4)
  $core.String get phaseNarrative => $_getSZ(3);
  @$pb.TagNumber(4)
  set phaseNarrative($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPhaseNarrative() => $_has(3);
  @$pb.TagNumber(4)
  void clearPhaseNarrative() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get lastSessionSummary => $_getSZ(4);
  @$pb.TagNumber(5)
  set lastSessionSummary($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastSessionSummary() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastSessionSummary() => $_clearField(5);
}

class GetProposedWorkoutScheduleResponse extends $pb.GeneratedMessage {
  factory GetProposedWorkoutScheduleResponse({
    $core.Iterable<ExerciseStatus>? exerciseStatuses,
    $core.String? activeWorkoutId,
    $core.Iterable<ProposedExerciseGroup>? proposedGroups,
    RegimeContext? regimeContext,
    TrainingStatus? trainingStatus,
    $core.String? suggestedWorkoutName,
    WorkoutDraft? draft,
    $core.Iterable<ExerciseGroup>? savedExerciseGroups,
    $core.Iterable<UserMessage>? userMessages,
    $core.Iterable<NextSessionOption>? selectableNextSessions,
  }) {
    final result = create();
    if (exerciseStatuses != null)
      result.exerciseStatuses.addAll(exerciseStatuses);
    if (activeWorkoutId != null) result.activeWorkoutId = activeWorkoutId;
    if (proposedGroups != null) result.proposedGroups.addAll(proposedGroups);
    if (regimeContext != null) result.regimeContext = regimeContext;
    if (trainingStatus != null) result.trainingStatus = trainingStatus;
    if (suggestedWorkoutName != null)
      result.suggestedWorkoutName = suggestedWorkoutName;
    if (draft != null) result.draft = draft;
    if (savedExerciseGroups != null)
      result.savedExerciseGroups.addAll(savedExerciseGroups);
    if (userMessages != null) result.userMessages.addAll(userMessages);
    if (selectableNextSessions != null)
      result.selectableNextSessions.addAll(selectableNextSessions);
    return result;
  }

  GetProposedWorkoutScheduleResponse._();

  factory GetProposedWorkoutScheduleResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProposedWorkoutScheduleResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProposedWorkoutScheduleResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<ExerciseStatus>(1, _omitFieldNames ? '' : 'exerciseStatuses',
        subBuilder: ExerciseStatus.create)
    ..aOS(2, _omitFieldNames ? '' : 'activeWorkoutId')
    ..pPM<ProposedExerciseGroup>(3, _omitFieldNames ? '' : 'proposedGroups',
        subBuilder: ProposedExerciseGroup.create)
    ..aOM<RegimeContext>(4, _omitFieldNames ? '' : 'regimeContext',
        subBuilder: RegimeContext.create)
    ..aOM<TrainingStatus>(5, _omitFieldNames ? '' : 'trainingStatus',
        subBuilder: TrainingStatus.create)
    ..aOS(6, _omitFieldNames ? '' : 'suggestedWorkoutName')
    ..aOM<WorkoutDraft>(7, _omitFieldNames ? '' : 'draft',
        subBuilder: WorkoutDraft.create)
    ..pPM<ExerciseGroup>(8, _omitFieldNames ? '' : 'savedExerciseGroups',
        subBuilder: ExerciseGroup.create)
    ..pPM<UserMessage>(9, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..pPM<NextSessionOption>(
        10, _omitFieldNames ? '' : 'selectableNextSessions',
        subBuilder: NextSessionOption.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProposedWorkoutScheduleResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProposedWorkoutScheduleResponse copyWith(
          void Function(GetProposedWorkoutScheduleResponse) updates) =>
      super.copyWith((message) =>
              updates(message as GetProposedWorkoutScheduleResponse))
          as GetProposedWorkoutScheduleResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProposedWorkoutScheduleResponse create() =>
      GetProposedWorkoutScheduleResponse._();
  @$core.override
  GetProposedWorkoutScheduleResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProposedWorkoutScheduleResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProposedWorkoutScheduleResponse>(
          create);
  static GetProposedWorkoutScheduleResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ExerciseStatus> get exerciseStatuses => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get activeWorkoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set activeWorkoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveWorkoutId() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<ProposedExerciseGroup> get proposedGroups => $_getList(2);

  @$pb.TagNumber(4)
  RegimeContext get regimeContext => $_getN(3);
  @$pb.TagNumber(4)
  set regimeContext(RegimeContext value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRegimeContext() => $_has(3);
  @$pb.TagNumber(4)
  void clearRegimeContext() => $_clearField(4);
  @$pb.TagNumber(4)
  RegimeContext ensureRegimeContext() => $_ensure(3);

  @$pb.TagNumber(5)
  TrainingStatus get trainingStatus => $_getN(4);
  @$pb.TagNumber(5)
  set trainingStatus(TrainingStatus value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasTrainingStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearTrainingStatus() => $_clearField(5);
  @$pb.TagNumber(5)
  TrainingStatus ensureTrainingStatus() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get suggestedWorkoutName => $_getSZ(5);
  @$pb.TagNumber(6)
  set suggestedWorkoutName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSuggestedWorkoutName() => $_has(5);
  @$pb.TagNumber(6)
  void clearSuggestedWorkoutName() => $_clearField(6);

  @$pb.TagNumber(7)
  WorkoutDraft get draft => $_getN(6);
  @$pb.TagNumber(7)
  set draft(WorkoutDraft value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDraft() => $_has(6);
  @$pb.TagNumber(7)
  void clearDraft() => $_clearField(7);
  @$pb.TagNumber(7)
  WorkoutDraft ensureDraft() => $_ensure(6);

  @$pb.TagNumber(8)
  $pb.PbList<ExerciseGroup> get savedExerciseGroups => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<UserMessage> get userMessages => $_getList(8);

  /// Selectable next-session choices (e.g. Linear 5×5 Workout A / B) so the home
  /// prompt can offer a one-tap swap. Empty when the regime has no choice.
  @$pb.TagNumber(10)
  $pb.PbList<NextSessionOption> get selectableNextSessions => $_getList(9);
}

class NextSessionOption extends $pb.GeneratedMessage {
  factory NextSessionOption({
    $core.String? key,
    $core.String? label,
    $core.bool? isCurrent,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (label != null) result.label = label;
    if (isCurrent != null) result.isCurrent = isCurrent;
    return result;
  }

  NextSessionOption._();

  factory NextSessionOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NextSessionOption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NextSessionOption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOB(3, _omitFieldNames ? '' : 'isCurrent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NextSessionOption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NextSessionOption copyWith(void Function(NextSessionOption) updates) =>
      super.copyWith((message) => updates(message as NextSessionOption))
          as NextSessionOption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NextSessionOption create() => NextSessionOption._();
  @$core.override
  NextSessionOption createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NextSessionOption getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NextSessionOption>(create);
  static NextSessionOption? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isCurrent => $_getBF(2);
  @$pb.TagNumber(3)
  set isCurrent($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsCurrent() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsCurrent() => $_clearField(3);
}

class SetNextWorkoutRequest extends $pb.GeneratedMessage {
  factory SetNextWorkoutRequest({
    $core.String? sessionKey,
  }) {
    final result = create();
    if (sessionKey != null) result.sessionKey = sessionKey;
    return result;
  }

  SetNextWorkoutRequest._();

  factory SetNextWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetNextWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetNextWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetNextWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetNextWorkoutRequest copyWith(
          void Function(SetNextWorkoutRequest) updates) =>
      super.copyWith((message) => updates(message as SetNextWorkoutRequest))
          as SetNextWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetNextWorkoutRequest create() => SetNextWorkoutRequest._();
  @$core.override
  SetNextWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetNextWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetNextWorkoutRequest>(create);
  static SetNextWorkoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionKey($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionKey() => $_clearField(1);
}

class SetNextWorkoutResponse extends $pb.GeneratedMessage {
  factory SetNextWorkoutResponse() => create();

  SetNextWorkoutResponse._();

  factory SetNextWorkoutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetNextWorkoutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetNextWorkoutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetNextWorkoutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetNextWorkoutResponse copyWith(
          void Function(SetNextWorkoutResponse) updates) =>
      super.copyWith((message) => updates(message as SetNextWorkoutResponse))
          as SetNextWorkoutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetNextWorkoutResponse create() => SetNextWorkoutResponse._();
  @$core.override
  SetNextWorkoutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetNextWorkoutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetNextWorkoutResponse>(create);
  static SetNextWorkoutResponse? _defaultInstance;
}

class SaveProfileExerciseGroupRequest extends $pb.GeneratedMessage {
  factory SaveProfileExerciseGroupRequest({
    ExerciseGroup? group,
  }) {
    final result = create();
    if (group != null) result.group = group;
    return result;
  }

  SaveProfileExerciseGroupRequest._();

  factory SaveProfileExerciseGroupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaveProfileExerciseGroupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveProfileExerciseGroupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ExerciseGroup>(1, _omitFieldNames ? '' : 'group',
        subBuilder: ExerciseGroup.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveProfileExerciseGroupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveProfileExerciseGroupRequest copyWith(
          void Function(SaveProfileExerciseGroupRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SaveProfileExerciseGroupRequest))
          as SaveProfileExerciseGroupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaveProfileExerciseGroupRequest create() =>
      SaveProfileExerciseGroupRequest._();
  @$core.override
  SaveProfileExerciseGroupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SaveProfileExerciseGroupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveProfileExerciseGroupRequest>(
          create);
  static SaveProfileExerciseGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  ExerciseGroup get group => $_getN(0);
  @$pb.TagNumber(1)
  set group(ExerciseGroup value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasGroup() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroup() => $_clearField(1);
  @$pb.TagNumber(1)
  ExerciseGroup ensureGroup() => $_ensure(0);
}

class SaveProfileExerciseGroupResponse extends $pb.GeneratedMessage {
  factory SaveProfileExerciseGroupResponse({
    ExerciseGroup? group,
  }) {
    final result = create();
    if (group != null) result.group = group;
    return result;
  }

  SaveProfileExerciseGroupResponse._();

  factory SaveProfileExerciseGroupResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaveProfileExerciseGroupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveProfileExerciseGroupResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ExerciseGroup>(1, _omitFieldNames ? '' : 'group',
        subBuilder: ExerciseGroup.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveProfileExerciseGroupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveProfileExerciseGroupResponse copyWith(
          void Function(SaveProfileExerciseGroupResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SaveProfileExerciseGroupResponse))
          as SaveProfileExerciseGroupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaveProfileExerciseGroupResponse create() =>
      SaveProfileExerciseGroupResponse._();
  @$core.override
  SaveProfileExerciseGroupResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SaveProfileExerciseGroupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveProfileExerciseGroupResponse>(
          create);
  static SaveProfileExerciseGroupResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ExerciseGroup get group => $_getN(0);
  @$pb.TagNumber(1)
  set group(ExerciseGroup value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasGroup() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroup() => $_clearField(1);
  @$pb.TagNumber(1)
  ExerciseGroup ensureGroup() => $_ensure(0);
}

class DeleteProfileExerciseGroupRequest extends $pb.GeneratedMessage {
  factory DeleteProfileExerciseGroupRequest({
    $core.String? groupId,
  }) {
    final result = create();
    if (groupId != null) result.groupId = groupId;
    return result;
  }

  DeleteProfileExerciseGroupRequest._();

  factory DeleteProfileExerciseGroupRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteProfileExerciseGroupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProfileExerciseGroupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'groupId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProfileExerciseGroupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProfileExerciseGroupRequest copyWith(
          void Function(DeleteProfileExerciseGroupRequest) updates) =>
      super.copyWith((message) =>
              updates(message as DeleteProfileExerciseGroupRequest))
          as DeleteProfileExerciseGroupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteProfileExerciseGroupRequest create() =>
      DeleteProfileExerciseGroupRequest._();
  @$core.override
  DeleteProfileExerciseGroupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteProfileExerciseGroupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProfileExerciseGroupRequest>(
          create);
  static DeleteProfileExerciseGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get groupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set groupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGroupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroupId() => $_clearField(1);
}

class DeleteProfileExerciseGroupResponse extends $pb.GeneratedMessage {
  factory DeleteProfileExerciseGroupResponse() => create();

  DeleteProfileExerciseGroupResponse._();

  factory DeleteProfileExerciseGroupResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteProfileExerciseGroupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteProfileExerciseGroupResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProfileExerciseGroupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteProfileExerciseGroupResponse copyWith(
          void Function(DeleteProfileExerciseGroupResponse) updates) =>
      super.copyWith((message) =>
              updates(message as DeleteProfileExerciseGroupResponse))
          as DeleteProfileExerciseGroupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteProfileExerciseGroupResponse create() =>
      DeleteProfileExerciseGroupResponse._();
  @$core.override
  DeleteProfileExerciseGroupResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteProfileExerciseGroupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteProfileExerciseGroupResponse>(
          create);
  static DeleteProfileExerciseGroupResponse? _defaultInstance;
}

class WorkoutDraft extends $pb.GeneratedMessage {
  factory WorkoutDraft({
    $core.String? name,
    $core.Iterable<ExerciseGroup>? exerciseGroups,
    $fixnum.Int64? updatedAt,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (exerciseGroups != null) result.exerciseGroups.addAll(exerciseGroups);
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  WorkoutDraft._();

  factory WorkoutDraft.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutDraft.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutDraft',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..pPM<ExerciseGroup>(2, _omitFieldNames ? '' : 'exerciseGroups',
        subBuilder: ExerciseGroup.create)
    ..aInt64(3, _omitFieldNames ? '' : 'updatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutDraft clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutDraft copyWith(void Function(WorkoutDraft) updates) =>
      super.copyWith((message) => updates(message as WorkoutDraft))
          as WorkoutDraft;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutDraft create() => WorkoutDraft._();
  @$core.override
  WorkoutDraft createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutDraft getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutDraft>(create);
  static WorkoutDraft? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ExerciseGroup> get exerciseGroups => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get updatedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set updatedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUpdatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpdatedAt() => $_clearField(3);
}

class SaveWorkoutDraftRequest extends $pb.GeneratedMessage {
  factory SaveWorkoutDraftRequest({
    WorkoutDraft? draft,
  }) {
    final result = create();
    if (draft != null) result.draft = draft;
    return result;
  }

  SaveWorkoutDraftRequest._();

  factory SaveWorkoutDraftRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaveWorkoutDraftRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveWorkoutDraftRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<WorkoutDraft>(1, _omitFieldNames ? '' : 'draft',
        subBuilder: WorkoutDraft.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveWorkoutDraftRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveWorkoutDraftRequest copyWith(
          void Function(SaveWorkoutDraftRequest) updates) =>
      super.copyWith((message) => updates(message as SaveWorkoutDraftRequest))
          as SaveWorkoutDraftRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaveWorkoutDraftRequest create() => SaveWorkoutDraftRequest._();
  @$core.override
  SaveWorkoutDraftRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SaveWorkoutDraftRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveWorkoutDraftRequest>(create);
  static SaveWorkoutDraftRequest? _defaultInstance;

  @$pb.TagNumber(1)
  WorkoutDraft get draft => $_getN(0);
  @$pb.TagNumber(1)
  set draft(WorkoutDraft value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDraft() => $_has(0);
  @$pb.TagNumber(1)
  void clearDraft() => $_clearField(1);
  @$pb.TagNumber(1)
  WorkoutDraft ensureDraft() => $_ensure(0);
}

class SaveWorkoutDraftResponse extends $pb.GeneratedMessage {
  factory SaveWorkoutDraftResponse({
    WorkoutDraft? draft,
  }) {
    final result = create();
    if (draft != null) result.draft = draft;
    return result;
  }

  SaveWorkoutDraftResponse._();

  factory SaveWorkoutDraftResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaveWorkoutDraftResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveWorkoutDraftResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<WorkoutDraft>(1, _omitFieldNames ? '' : 'draft',
        subBuilder: WorkoutDraft.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveWorkoutDraftResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveWorkoutDraftResponse copyWith(
          void Function(SaveWorkoutDraftResponse) updates) =>
      super.copyWith((message) => updates(message as SaveWorkoutDraftResponse))
          as SaveWorkoutDraftResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaveWorkoutDraftResponse create() => SaveWorkoutDraftResponse._();
  @$core.override
  SaveWorkoutDraftResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SaveWorkoutDraftResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveWorkoutDraftResponse>(create);
  static SaveWorkoutDraftResponse? _defaultInstance;

  @$pb.TagNumber(1)
  WorkoutDraft get draft => $_getN(0);
  @$pb.TagNumber(1)
  set draft(WorkoutDraft value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDraft() => $_has(0);
  @$pb.TagNumber(1)
  void clearDraft() => $_clearField(1);
  @$pb.TagNumber(1)
  WorkoutDraft ensureDraft() => $_ensure(0);
}

class ClearWorkoutDraftRequest extends $pb.GeneratedMessage {
  factory ClearWorkoutDraftRequest() => create();

  ClearWorkoutDraftRequest._();

  factory ClearWorkoutDraftRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClearWorkoutDraftRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClearWorkoutDraftRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearWorkoutDraftRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearWorkoutDraftRequest copyWith(
          void Function(ClearWorkoutDraftRequest) updates) =>
      super.copyWith((message) => updates(message as ClearWorkoutDraftRequest))
          as ClearWorkoutDraftRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClearWorkoutDraftRequest create() => ClearWorkoutDraftRequest._();
  @$core.override
  ClearWorkoutDraftRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClearWorkoutDraftRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClearWorkoutDraftRequest>(create);
  static ClearWorkoutDraftRequest? _defaultInstance;
}

class ClearWorkoutDraftResponse extends $pb.GeneratedMessage {
  factory ClearWorkoutDraftResponse() => create();

  ClearWorkoutDraftResponse._();

  factory ClearWorkoutDraftResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClearWorkoutDraftResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClearWorkoutDraftResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearWorkoutDraftResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearWorkoutDraftResponse copyWith(
          void Function(ClearWorkoutDraftResponse) updates) =>
      super.copyWith((message) => updates(message as ClearWorkoutDraftResponse))
          as ClearWorkoutDraftResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClearWorkoutDraftResponse create() => ClearWorkoutDraftResponse._();
  @$core.override
  ClearWorkoutDraftResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClearWorkoutDraftResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClearWorkoutDraftResponse>(create);
  static ClearWorkoutDraftResponse? _defaultInstance;
}

class GetActiveWorkoutRequest extends $pb.GeneratedMessage {
  factory GetActiveWorkoutRequest() => create();

  GetActiveWorkoutRequest._();

  factory GetActiveWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetActiveWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetActiveWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveWorkoutRequest copyWith(
          void Function(GetActiveWorkoutRequest) updates) =>
      super.copyWith((message) => updates(message as GetActiveWorkoutRequest))
          as GetActiveWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetActiveWorkoutRequest create() => GetActiveWorkoutRequest._();
  @$core.override
  GetActiveWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetActiveWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetActiveWorkoutRequest>(create);
  static GetActiveWorkoutRequest? _defaultInstance;
}

class GetActiveWorkoutResponse extends $pb.GeneratedMessage {
  factory GetActiveWorkoutResponse({
    Workout? workout,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
    return result;
  }

  GetActiveWorkoutResponse._();

  factory GetActiveWorkoutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetActiveWorkoutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetActiveWorkoutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<Workout>(1, _omitFieldNames ? '' : 'workout',
        subBuilder: Workout.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveWorkoutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveWorkoutResponse copyWith(
          void Function(GetActiveWorkoutResponse) updates) =>
      super.copyWith((message) => updates(message as GetActiveWorkoutResponse))
          as GetActiveWorkoutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetActiveWorkoutResponse create() => GetActiveWorkoutResponse._();
  @$core.override
  GetActiveWorkoutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetActiveWorkoutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetActiveWorkoutResponse>(create);
  static GetActiveWorkoutResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Workout get workout => $_getN(0);
  @$pb.TagNumber(1)
  set workout(Workout value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkout() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkout() => $_clearField(1);
  @$pb.TagNumber(1)
  Workout ensureWorkout() => $_ensure(0);
}

class UpdateExerciseGroupRequest extends $pb.GeneratedMessage {
  factory UpdateExerciseGroupRequest({
    $core.String? workoutId,
    $core.String? exerciseGroupId,
    $core.String? name,
    $core.int? sets,
    $core.bool? interleaveWarmups,
    $core.Iterable<ExerciseTypeConfig>? exerciseConfigs,
    RestConfig? restConfig,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (exerciseGroupId != null) result.exerciseGroupId = exerciseGroupId;
    if (name != null) result.name = name;
    if (sets != null) result.sets = sets;
    if (interleaveWarmups != null) result.interleaveWarmups = interleaveWarmups;
    if (exerciseConfigs != null) result.exerciseConfigs.addAll(exerciseConfigs);
    if (restConfig != null) result.restConfig = restConfig;
    return result;
  }

  UpdateExerciseGroupRequest._();

  factory UpdateExerciseGroupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateExerciseGroupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateExerciseGroupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'exerciseGroupId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'sets')
    ..aOB(5, _omitFieldNames ? '' : 'interleaveWarmups')
    ..pPM<ExerciseTypeConfig>(6, _omitFieldNames ? '' : 'exerciseConfigs',
        subBuilder: ExerciseTypeConfig.create)
    ..aOM<RestConfig>(7, _omitFieldNames ? '' : 'restConfig',
        subBuilder: RestConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateExerciseGroupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateExerciseGroupRequest copyWith(
          void Function(UpdateExerciseGroupRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateExerciseGroupRequest))
          as UpdateExerciseGroupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateExerciseGroupRequest create() => UpdateExerciseGroupRequest._();
  @$core.override
  UpdateExerciseGroupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateExerciseGroupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateExerciseGroupRequest>(create);
  static UpdateExerciseGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exerciseGroupId => $_getSZ(1);
  @$pb.TagNumber(2)
  set exerciseGroupId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExerciseGroupId() => $_has(1);
  @$pb.TagNumber(2)
  void clearExerciseGroupId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get sets => $_getIZ(3);
  @$pb.TagNumber(4)
  set sets($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSets() => $_has(3);
  @$pb.TagNumber(4)
  void clearSets() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get interleaveWarmups => $_getBF(4);
  @$pb.TagNumber(5)
  set interleaveWarmups($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInterleaveWarmups() => $_has(4);
  @$pb.TagNumber(5)
  void clearInterleaveWarmups() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<ExerciseTypeConfig> get exerciseConfigs => $_getList(5);

  @$pb.TagNumber(7)
  RestConfig get restConfig => $_getN(6);
  @$pb.TagNumber(7)
  set restConfig(RestConfig value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRestConfig() => $_has(6);
  @$pb.TagNumber(7)
  void clearRestConfig() => $_clearField(7);
  @$pb.TagNumber(7)
  RestConfig ensureRestConfig() => $_ensure(6);
}

class UpdateExerciseGroupResponse extends $pb.GeneratedMessage {
  factory UpdateExerciseGroupResponse({
    ExerciseGroup? group,
    $core.Iterable<ProposedSet>? generatedSets,
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (group != null) result.group = group;
    if (generatedSets != null) result.generatedSets.addAll(generatedSets);
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  UpdateExerciseGroupResponse._();

  factory UpdateExerciseGroupResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateExerciseGroupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateExerciseGroupResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ExerciseGroup>(1, _omitFieldNames ? '' : 'group',
        subBuilder: ExerciseGroup.create)
    ..pPM<ProposedSet>(2, _omitFieldNames ? '' : 'generatedSets',
        subBuilder: ProposedSet.create)
    ..aOM<ProposedSet>(3, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(4, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(5, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateExerciseGroupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateExerciseGroupResponse copyWith(
          void Function(UpdateExerciseGroupResponse) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateExerciseGroupResponse))
          as UpdateExerciseGroupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateExerciseGroupResponse create() =>
      UpdateExerciseGroupResponse._();
  @$core.override
  UpdateExerciseGroupResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateExerciseGroupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateExerciseGroupResponse>(create);
  static UpdateExerciseGroupResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ExerciseGroup get group => $_getN(0);
  @$pb.TagNumber(1)
  set group(ExerciseGroup value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasGroup() => $_has(0);
  @$pb.TagNumber(1)
  void clearGroup() => $_clearField(1);
  @$pb.TagNumber(1)
  ExerciseGroup ensureGroup() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<ProposedSet> get generatedSets => $_getList(1);

  @$pb.TagNumber(3)
  ProposedSet get nextUpSet => $_getN(2);
  @$pb.TagNumber(3)
  set nextUpSet(ProposedSet value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasNextUpSet() => $_has(2);
  @$pb.TagNumber(3)
  void clearNextUpSet() => $_clearField(3);
  @$pb.TagNumber(3)
  ProposedSet ensureNextUpSet() => $_ensure(2);

  @$pb.TagNumber(4)
  WorkoutStateSnapshot get stateSnapshot => $_getN(3);
  @$pb.TagNumber(4)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStateSnapshot() => $_has(3);
  @$pb.TagNumber(4)
  void clearStateSnapshot() => $_clearField(4);
  @$pb.TagNumber(4)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(3);

  @$pb.TagNumber(5)
  $pb.PbList<UserMessage> get userMessages => $_getList(4);
}

class DeleteExerciseGroupRequest extends $pb.GeneratedMessage {
  factory DeleteExerciseGroupRequest({
    $core.String? workoutId,
    $core.String? exerciseGroupId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (exerciseGroupId != null) result.exerciseGroupId = exerciseGroupId;
    return result;
  }

  DeleteExerciseGroupRequest._();

  factory DeleteExerciseGroupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteExerciseGroupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteExerciseGroupRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOS(2, _omitFieldNames ? '' : 'exerciseGroupId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteExerciseGroupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteExerciseGroupRequest copyWith(
          void Function(DeleteExerciseGroupRequest) updates) =>
      super.copyWith(
              (message) => updates(message as DeleteExerciseGroupRequest))
          as DeleteExerciseGroupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteExerciseGroupRequest create() => DeleteExerciseGroupRequest._();
  @$core.override
  DeleteExerciseGroupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteExerciseGroupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteExerciseGroupRequest>(create);
  static DeleteExerciseGroupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get exerciseGroupId => $_getSZ(1);
  @$pb.TagNumber(2)
  set exerciseGroupId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExerciseGroupId() => $_has(1);
  @$pb.TagNumber(2)
  void clearExerciseGroupId() => $_clearField(2);
}

class DeleteExerciseGroupResponse extends $pb.GeneratedMessage {
  factory DeleteExerciseGroupResponse({
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  DeleteExerciseGroupResponse._();

  factory DeleteExerciseGroupResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteExerciseGroupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteExerciseGroupResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ProposedSet>(1, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(2, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(3, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteExerciseGroupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteExerciseGroupResponse copyWith(
          void Function(DeleteExerciseGroupResponse) updates) =>
      super.copyWith(
              (message) => updates(message as DeleteExerciseGroupResponse))
          as DeleteExerciseGroupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteExerciseGroupResponse create() =>
      DeleteExerciseGroupResponse._();
  @$core.override
  DeleteExerciseGroupResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteExerciseGroupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteExerciseGroupResponse>(create);
  static DeleteExerciseGroupResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ProposedSet get nextUpSet => $_getN(0);
  @$pb.TagNumber(1)
  set nextUpSet(ProposedSet value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNextUpSet() => $_has(0);
  @$pb.TagNumber(1)
  void clearNextUpSet() => $_clearField(1);
  @$pb.TagNumber(1)
  ProposedSet ensureNextUpSet() => $_ensure(0);

  @$pb.TagNumber(2)
  WorkoutStateSnapshot get stateSnapshot => $_getN(1);
  @$pb.TagNumber(2)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStateSnapshot() => $_has(1);
  @$pb.TagNumber(2)
  void clearStateSnapshot() => $_clearField(2);
  @$pb.TagNumber(2)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<UserMessage> get userMessages => $_getList(2);
}

class ReorderExerciseGroupsRequest extends $pb.GeneratedMessage {
  factory ReorderExerciseGroupsRequest({
    $core.String? workoutId,
    $core.Iterable<$core.String>? exerciseGroupIds,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (exerciseGroupIds != null)
      result.exerciseGroupIds.addAll(exerciseGroupIds);
    return result;
  }

  ReorderExerciseGroupsRequest._();

  factory ReorderExerciseGroupsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderExerciseGroupsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderExerciseGroupsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..pPS(2, _omitFieldNames ? '' : 'exerciseGroupIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderExerciseGroupsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderExerciseGroupsRequest copyWith(
          void Function(ReorderExerciseGroupsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ReorderExerciseGroupsRequest))
          as ReorderExerciseGroupsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderExerciseGroupsRequest create() =>
      ReorderExerciseGroupsRequest._();
  @$core.override
  ReorderExerciseGroupsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderExerciseGroupsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderExerciseGroupsRequest>(create);
  static ReorderExerciseGroupsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get exerciseGroupIds => $_getList(1);
}

class ReorderExerciseGroupsResponse extends $pb.GeneratedMessage {
  factory ReorderExerciseGroupsResponse({
    ProposedSet? nextUpSet,
    WorkoutStateSnapshot? stateSnapshot,
    $core.Iterable<UserMessage>? userMessages,
  }) {
    final result = create();
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (stateSnapshot != null) result.stateSnapshot = stateSnapshot;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    return result;
  }

  ReorderExerciseGroupsResponse._();

  factory ReorderExerciseGroupsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderExerciseGroupsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderExerciseGroupsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ProposedSet>(1, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: ProposedSet.create)
    ..aOM<WorkoutStateSnapshot>(2, _omitFieldNames ? '' : 'stateSnapshot',
        subBuilder: WorkoutStateSnapshot.create)
    ..pPM<UserMessage>(3, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderExerciseGroupsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderExerciseGroupsResponse copyWith(
          void Function(ReorderExerciseGroupsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ReorderExerciseGroupsResponse))
          as ReorderExerciseGroupsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderExerciseGroupsResponse create() =>
      ReorderExerciseGroupsResponse._();
  @$core.override
  ReorderExerciseGroupsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderExerciseGroupsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderExerciseGroupsResponse>(create);
  static ReorderExerciseGroupsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ProposedSet get nextUpSet => $_getN(0);
  @$pb.TagNumber(1)
  set nextUpSet(ProposedSet value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNextUpSet() => $_has(0);
  @$pb.TagNumber(1)
  void clearNextUpSet() => $_clearField(1);
  @$pb.TagNumber(1)
  ProposedSet ensureNextUpSet() => $_ensure(0);

  @$pb.TagNumber(2)
  WorkoutStateSnapshot get stateSnapshot => $_getN(1);
  @$pb.TagNumber(2)
  set stateSnapshot(WorkoutStateSnapshot value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStateSnapshot() => $_has(1);
  @$pb.TagNumber(2)
  void clearStateSnapshot() => $_clearField(2);
  @$pb.TagNumber(2)
  WorkoutStateSnapshot ensureStateSnapshot() => $_ensure(1);

  @$pb.TagNumber(3)
  $pb.PbList<UserMessage> get userMessages => $_getList(2);
}

class WorkoutHeartRatePoint extends $pb.GeneratedMessage {
  factory WorkoutHeartRatePoint({
    $fixnum.Int64? sampledAt,
    $core.double? bpm,
    $core.int? availability,
  }) {
    final result = create();
    if (sampledAt != null) result.sampledAt = sampledAt;
    if (bpm != null) result.bpm = bpm;
    if (availability != null) result.availability = availability;
    return result;
  }

  WorkoutHeartRatePoint._();

  factory WorkoutHeartRatePoint.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutHeartRatePoint.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutHeartRatePoint',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'sampledAt')
    ..aD(2, _omitFieldNames ? '' : 'bpm', fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'availability')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutHeartRatePoint clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutHeartRatePoint copyWith(
          void Function(WorkoutHeartRatePoint) updates) =>
      super.copyWith((message) => updates(message as WorkoutHeartRatePoint))
          as WorkoutHeartRatePoint;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutHeartRatePoint create() => WorkoutHeartRatePoint._();
  @$core.override
  WorkoutHeartRatePoint createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutHeartRatePoint getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutHeartRatePoint>(create);
  static WorkoutHeartRatePoint? _defaultInstance;

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
  $core.int get availability => $_getIZ(2);
  @$pb.TagNumber(3)
  set availability($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAvailability() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvailability() => $_clearField(3);
}

class AppendWorkoutHeartRateRequest extends $pb.GeneratedMessage {
  factory AppendWorkoutHeartRateRequest({
    $core.String? workoutId,
    $core.Iterable<WorkoutHeartRatePoint>? samples,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (samples != null) result.samples.addAll(samples);
    return result;
  }

  AppendWorkoutHeartRateRequest._();

  factory AppendWorkoutHeartRateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppendWorkoutHeartRateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppendWorkoutHeartRateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..pPM<WorkoutHeartRatePoint>(2, _omitFieldNames ? '' : 'samples',
        subBuilder: WorkoutHeartRatePoint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppendWorkoutHeartRateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppendWorkoutHeartRateRequest copyWith(
          void Function(AppendWorkoutHeartRateRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AppendWorkoutHeartRateRequest))
          as AppendWorkoutHeartRateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppendWorkoutHeartRateRequest create() =>
      AppendWorkoutHeartRateRequest._();
  @$core.override
  AppendWorkoutHeartRateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppendWorkoutHeartRateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AppendWorkoutHeartRateRequest>(create);
  static AppendWorkoutHeartRateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<WorkoutHeartRatePoint> get samples => $_getList(1);
}

class AppendWorkoutHeartRateResponse extends $pb.GeneratedMessage {
  factory AppendWorkoutHeartRateResponse({
    $core.int? stored,
  }) {
    final result = create();
    if (stored != null) result.stored = stored;
    return result;
  }

  AppendWorkoutHeartRateResponse._();

  factory AppendWorkoutHeartRateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppendWorkoutHeartRateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppendWorkoutHeartRateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'stored')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppendWorkoutHeartRateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppendWorkoutHeartRateResponse copyWith(
          void Function(AppendWorkoutHeartRateResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AppendWorkoutHeartRateResponse))
          as AppendWorkoutHeartRateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppendWorkoutHeartRateResponse create() =>
      AppendWorkoutHeartRateResponse._();
  @$core.override
  AppendWorkoutHeartRateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppendWorkoutHeartRateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AppendWorkoutHeartRateResponse>(create);
  static AppendWorkoutHeartRateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get stored => $_getIZ(0);
  @$pb.TagNumber(1)
  set stored($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStored() => $_has(0);
  @$pb.TagNumber(1)
  void clearStored() => $_clearField(1);
}

class GetWorkoutHeartRateRequest extends $pb.GeneratedMessage {
  factory GetWorkoutHeartRateRequest({
    $core.String? workoutId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    return result;
  }

  GetWorkoutHeartRateRequest._();

  factory GetWorkoutHeartRateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetWorkoutHeartRateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetWorkoutHeartRateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutHeartRateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutHeartRateRequest copyWith(
          void Function(GetWorkoutHeartRateRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetWorkoutHeartRateRequest))
          as GetWorkoutHeartRateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetWorkoutHeartRateRequest create() => GetWorkoutHeartRateRequest._();
  @$core.override
  GetWorkoutHeartRateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetWorkoutHeartRateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetWorkoutHeartRateRequest>(create);
  static GetWorkoutHeartRateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);
}

class GetWorkoutHeartRateResponse extends $pb.GeneratedMessage {
  factory GetWorkoutHeartRateResponse({
    $core.Iterable<WorkoutHeartRatePoint>? samples,
  }) {
    final result = create();
    if (samples != null) result.samples.addAll(samples);
    return result;
  }

  GetWorkoutHeartRateResponse._();

  factory GetWorkoutHeartRateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetWorkoutHeartRateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetWorkoutHeartRateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<WorkoutHeartRatePoint>(1, _omitFieldNames ? '' : 'samples',
        subBuilder: WorkoutHeartRatePoint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutHeartRateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetWorkoutHeartRateResponse copyWith(
          void Function(GetWorkoutHeartRateResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetWorkoutHeartRateResponse))
          as GetWorkoutHeartRateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetWorkoutHeartRateResponse create() =>
      GetWorkoutHeartRateResponse._();
  @$core.override
  GetWorkoutHeartRateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetWorkoutHeartRateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetWorkoutHeartRateResponse>(create);
  static GetWorkoutHeartRateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<WorkoutHeartRatePoint> get samples => $_getList(0);
}

enum WorkoutMutation_Mutation {
  startSet,
  completeSet,
  cancelProposedSet,
  deleteCompletedSet,
  endWorkout,
  replaceExerciseGroupPlan,
  reorderExerciseGroups,
  notSet
}

class WorkoutMutation extends $pb.GeneratedMessage {
  factory WorkoutMutation({
    $core.String? eventId,
    $fixnum.Int64? clientCreatedAt,
    StartSetRequest? startSet,
    CompleteSetRequest? completeSet,
    CancelProposedSetRequest? cancelProposedSet,
    DeleteCompletedSetRequest? deleteCompletedSet,
    EndWorkoutRequest? endWorkout,
    ReplaceExerciseGroupPlanRequest? replaceExerciseGroupPlan,
    ReorderExerciseGroupsRequest? reorderExerciseGroups,
  }) {
    final result = create();
    if (eventId != null) result.eventId = eventId;
    if (clientCreatedAt != null) result.clientCreatedAt = clientCreatedAt;
    if (startSet != null) result.startSet = startSet;
    if (completeSet != null) result.completeSet = completeSet;
    if (cancelProposedSet != null) result.cancelProposedSet = cancelProposedSet;
    if (deleteCompletedSet != null)
      result.deleteCompletedSet = deleteCompletedSet;
    if (endWorkout != null) result.endWorkout = endWorkout;
    if (replaceExerciseGroupPlan != null)
      result.replaceExerciseGroupPlan = replaceExerciseGroupPlan;
    if (reorderExerciseGroups != null)
      result.reorderExerciseGroups = reorderExerciseGroups;
    return result;
  }

  WorkoutMutation._();

  factory WorkoutMutation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutMutation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, WorkoutMutation_Mutation>
      _WorkoutMutation_MutationByTag = {
    10: WorkoutMutation_Mutation.startSet,
    11: WorkoutMutation_Mutation.completeSet,
    12: WorkoutMutation_Mutation.cancelProposedSet,
    13: WorkoutMutation_Mutation.deleteCompletedSet,
    14: WorkoutMutation_Mutation.endWorkout,
    15: WorkoutMutation_Mutation.replaceExerciseGroupPlan,
    16: WorkoutMutation_Mutation.reorderExerciseGroups,
    0: WorkoutMutation_Mutation.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutMutation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16])
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..aInt64(2, _omitFieldNames ? '' : 'clientCreatedAt')
    ..aOM<StartSetRequest>(10, _omitFieldNames ? '' : 'startSet',
        subBuilder: StartSetRequest.create)
    ..aOM<CompleteSetRequest>(11, _omitFieldNames ? '' : 'completeSet',
        subBuilder: CompleteSetRequest.create)
    ..aOM<CancelProposedSetRequest>(
        12, _omitFieldNames ? '' : 'cancelProposedSet',
        subBuilder: CancelProposedSetRequest.create)
    ..aOM<DeleteCompletedSetRequest>(
        13, _omitFieldNames ? '' : 'deleteCompletedSet',
        subBuilder: DeleteCompletedSetRequest.create)
    ..aOM<EndWorkoutRequest>(14, _omitFieldNames ? '' : 'endWorkout',
        subBuilder: EndWorkoutRequest.create)
    ..aOM<ReplaceExerciseGroupPlanRequest>(
        15, _omitFieldNames ? '' : 'replaceExerciseGroupPlan',
        subBuilder: ReplaceExerciseGroupPlanRequest.create)
    ..aOM<ReorderExerciseGroupsRequest>(
        16, _omitFieldNames ? '' : 'reorderExerciseGroups',
        subBuilder: ReorderExerciseGroupsRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutMutation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutMutation copyWith(void Function(WorkoutMutation) updates) =>
      super.copyWith((message) => updates(message as WorkoutMutation))
          as WorkoutMutation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutMutation create() => WorkoutMutation._();
  @$core.override
  WorkoutMutation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutMutation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutMutation>(create);
  static WorkoutMutation? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  WorkoutMutation_Mutation whichMutation() =>
      _WorkoutMutation_MutationByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  void clearMutation() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get clientCreatedAt => $_getI64(1);
  @$pb.TagNumber(2)
  set clientCreatedAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientCreatedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientCreatedAt() => $_clearField(2);

  @$pb.TagNumber(10)
  StartSetRequest get startSet => $_getN(2);
  @$pb.TagNumber(10)
  set startSet(StartSetRequest value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasStartSet() => $_has(2);
  @$pb.TagNumber(10)
  void clearStartSet() => $_clearField(10);
  @$pb.TagNumber(10)
  StartSetRequest ensureStartSet() => $_ensure(2);

  @$pb.TagNumber(11)
  CompleteSetRequest get completeSet => $_getN(3);
  @$pb.TagNumber(11)
  set completeSet(CompleteSetRequest value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCompleteSet() => $_has(3);
  @$pb.TagNumber(11)
  void clearCompleteSet() => $_clearField(11);
  @$pb.TagNumber(11)
  CompleteSetRequest ensureCompleteSet() => $_ensure(3);

  @$pb.TagNumber(12)
  CancelProposedSetRequest get cancelProposedSet => $_getN(4);
  @$pb.TagNumber(12)
  set cancelProposedSet(CancelProposedSetRequest value) =>
      $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCancelProposedSet() => $_has(4);
  @$pb.TagNumber(12)
  void clearCancelProposedSet() => $_clearField(12);
  @$pb.TagNumber(12)
  CancelProposedSetRequest ensureCancelProposedSet() => $_ensure(4);

  @$pb.TagNumber(13)
  DeleteCompletedSetRequest get deleteCompletedSet => $_getN(5);
  @$pb.TagNumber(13)
  set deleteCompletedSet(DeleteCompletedSetRequest value) =>
      $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasDeleteCompletedSet() => $_has(5);
  @$pb.TagNumber(13)
  void clearDeleteCompletedSet() => $_clearField(13);
  @$pb.TagNumber(13)
  DeleteCompletedSetRequest ensureDeleteCompletedSet() => $_ensure(5);

  @$pb.TagNumber(14)
  EndWorkoutRequest get endWorkout => $_getN(6);
  @$pb.TagNumber(14)
  set endWorkout(EndWorkoutRequest value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasEndWorkout() => $_has(6);
  @$pb.TagNumber(14)
  void clearEndWorkout() => $_clearField(14);
  @$pb.TagNumber(14)
  EndWorkoutRequest ensureEndWorkout() => $_ensure(6);

  @$pb.TagNumber(15)
  ReplaceExerciseGroupPlanRequest get replaceExerciseGroupPlan => $_getN(7);
  @$pb.TagNumber(15)
  set replaceExerciseGroupPlan(ReplaceExerciseGroupPlanRequest value) =>
      $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasReplaceExerciseGroupPlan() => $_has(7);
  @$pb.TagNumber(15)
  void clearReplaceExerciseGroupPlan() => $_clearField(15);
  @$pb.TagNumber(15)
  ReplaceExerciseGroupPlanRequest ensureReplaceExerciseGroupPlan() =>
      $_ensure(7);

  @$pb.TagNumber(16)
  ReorderExerciseGroupsRequest get reorderExerciseGroups => $_getN(8);
  @$pb.TagNumber(16)
  set reorderExerciseGroups(ReorderExerciseGroupsRequest value) =>
      $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasReorderExerciseGroups() => $_has(8);
  @$pb.TagNumber(16)
  void clearReorderExerciseGroups() => $_clearField(16);
  @$pb.TagNumber(16)
  ReorderExerciseGroupsRequest ensureReorderExerciseGroups() => $_ensure(8);
}

class AppendWorkoutMutationsRequest extends $pb.GeneratedMessage {
  factory AppendWorkoutMutationsRequest({
    $core.Iterable<WorkoutMutation>? mutations,
  }) {
    final result = create();
    if (mutations != null) result.mutations.addAll(mutations);
    return result;
  }

  AppendWorkoutMutationsRequest._();

  factory AppendWorkoutMutationsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppendWorkoutMutationsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppendWorkoutMutationsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<WorkoutMutation>(1, _omitFieldNames ? '' : 'mutations',
        subBuilder: WorkoutMutation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppendWorkoutMutationsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppendWorkoutMutationsRequest copyWith(
          void Function(AppendWorkoutMutationsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AppendWorkoutMutationsRequest))
          as AppendWorkoutMutationsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppendWorkoutMutationsRequest create() =>
      AppendWorkoutMutationsRequest._();
  @$core.override
  AppendWorkoutMutationsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppendWorkoutMutationsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AppendWorkoutMutationsRequest>(create);
  static AppendWorkoutMutationsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<WorkoutMutation> get mutations => $_getList(0);
}

class AppendWorkoutMutationsResponse extends $pb.GeneratedMessage {
  factory AppendWorkoutMutationsResponse({
    $core.Iterable<$core.String>? appliedEventIds,
    GetWorkoutResponse? workoutState,
  }) {
    final result = create();
    if (appliedEventIds != null) result.appliedEventIds.addAll(appliedEventIds);
    if (workoutState != null) result.workoutState = workoutState;
    return result;
  }

  AppendWorkoutMutationsResponse._();

  factory AppendWorkoutMutationsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AppendWorkoutMutationsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AppendWorkoutMutationsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'appliedEventIds')
    ..aOM<GetWorkoutResponse>(2, _omitFieldNames ? '' : 'workoutState',
        subBuilder: GetWorkoutResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppendWorkoutMutationsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AppendWorkoutMutationsResponse copyWith(
          void Function(AppendWorkoutMutationsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AppendWorkoutMutationsResponse))
          as AppendWorkoutMutationsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AppendWorkoutMutationsResponse create() =>
      AppendWorkoutMutationsResponse._();
  @$core.override
  AppendWorkoutMutationsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AppendWorkoutMutationsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AppendWorkoutMutationsResponse>(create);
  static AppendWorkoutMutationsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get appliedEventIds => $_getList(0);

  @$pb.TagNumber(2)
  GetWorkoutResponse get workoutState => $_getN(1);
  @$pb.TagNumber(2)
  set workoutState(GetWorkoutResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutState() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutState() => $_clearField(2);
  @$pb.TagNumber(2)
  GetWorkoutResponse ensureWorkoutState() => $_ensure(1);
}

class DismissUserMessagesRequest extends $pb.GeneratedMessage {
  factory DismissUserMessagesRequest({
    $core.Iterable<$core.String>? messageKeys,
  }) {
    final result = create();
    if (messageKeys != null) result.messageKeys.addAll(messageKeys);
    return result;
  }

  DismissUserMessagesRequest._();

  factory DismissUserMessagesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DismissUserMessagesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DismissUserMessagesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'messageKeys')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissUserMessagesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissUserMessagesRequest copyWith(
          void Function(DismissUserMessagesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as DismissUserMessagesRequest))
          as DismissUserMessagesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DismissUserMessagesRequest create() => DismissUserMessagesRequest._();
  @$core.override
  DismissUserMessagesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DismissUserMessagesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DismissUserMessagesRequest>(create);
  static DismissUserMessagesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get messageKeys => $_getList(0);
}

class DismissUserMessagesResponse extends $pb.GeneratedMessage {
  factory DismissUserMessagesResponse({
    $core.Iterable<$core.String>? dismissedMessageKeys,
  }) {
    final result = create();
    if (dismissedMessageKeys != null)
      result.dismissedMessageKeys.addAll(dismissedMessageKeys);
    return result;
  }

  DismissUserMessagesResponse._();

  factory DismissUserMessagesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DismissUserMessagesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DismissUserMessagesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'dismissedMessageKeys')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissUserMessagesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissUserMessagesResponse copyWith(
          void Function(DismissUserMessagesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as DismissUserMessagesResponse))
          as DismissUserMessagesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DismissUserMessagesResponse create() =>
      DismissUserMessagesResponse._();
  @$core.override
  DismissUserMessagesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DismissUserMessagesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DismissUserMessagesResponse>(create);
  static DismissUserMessagesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get dismissedMessageKeys => $_getList(0);
}

class RehydrateWorkoutFromEventsRequest extends $pb.GeneratedMessage {
  factory RehydrateWorkoutFromEventsRequest({
    $core.String? workoutId,
    $core.bool? persist,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (persist != null) result.persist = persist;
    return result;
  }

  RehydrateWorkoutFromEventsRequest._();

  factory RehydrateWorkoutFromEventsRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RehydrateWorkoutFromEventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RehydrateWorkoutFromEventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..aOB(2, _omitFieldNames ? '' : 'persist')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RehydrateWorkoutFromEventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RehydrateWorkoutFromEventsRequest copyWith(
          void Function(RehydrateWorkoutFromEventsRequest) updates) =>
      super.copyWith((message) =>
              updates(message as RehydrateWorkoutFromEventsRequest))
          as RehydrateWorkoutFromEventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RehydrateWorkoutFromEventsRequest create() =>
      RehydrateWorkoutFromEventsRequest._();
  @$core.override
  RehydrateWorkoutFromEventsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RehydrateWorkoutFromEventsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RehydrateWorkoutFromEventsRequest>(
          create);
  static RehydrateWorkoutFromEventsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get persist => $_getBF(1);
  @$pb.TagNumber(2)
  set persist($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPersist() => $_has(1);
  @$pb.TagNumber(2)
  void clearPersist() => $_clearField(2);
}

class RehydrateWorkoutFromEventsResponse extends $pb.GeneratedMessage {
  factory RehydrateWorkoutFromEventsResponse({
    GetWorkoutResponse? workoutState,
    $core.int? appliedEventCount,
  }) {
    final result = create();
    if (workoutState != null) result.workoutState = workoutState;
    if (appliedEventCount != null) result.appliedEventCount = appliedEventCount;
    return result;
  }

  RehydrateWorkoutFromEventsResponse._();

  factory RehydrateWorkoutFromEventsResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RehydrateWorkoutFromEventsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RehydrateWorkoutFromEventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<GetWorkoutResponse>(1, _omitFieldNames ? '' : 'workoutState',
        subBuilder: GetWorkoutResponse.create)
    ..aI(2, _omitFieldNames ? '' : 'appliedEventCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RehydrateWorkoutFromEventsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RehydrateWorkoutFromEventsResponse copyWith(
          void Function(RehydrateWorkoutFromEventsResponse) updates) =>
      super.copyWith((message) =>
              updates(message as RehydrateWorkoutFromEventsResponse))
          as RehydrateWorkoutFromEventsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RehydrateWorkoutFromEventsResponse create() =>
      RehydrateWorkoutFromEventsResponse._();
  @$core.override
  RehydrateWorkoutFromEventsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RehydrateWorkoutFromEventsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RehydrateWorkoutFromEventsResponse>(
          create);
  static RehydrateWorkoutFromEventsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GetWorkoutResponse get workoutState => $_getN(0);
  @$pb.TagNumber(1)
  set workoutState(GetWorkoutResponse value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutState() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutState() => $_clearField(1);
  @$pb.TagNumber(1)
  GetWorkoutResponse ensureWorkoutState() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get appliedEventCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set appliedEventCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAppliedEventCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAppliedEventCount() => $_clearField(2);
}

class CreateUserRequest extends $pb.GeneratedMessage {
  factory CreateUserRequest({
    $core.String? name,
  }) {
    final result = create();
    if (name != null) result.name = name;
    return result;
  }

  CreateUserRequest._();

  factory CreateUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateUserRequest copyWith(void Function(CreateUserRequest) updates) =>
      super.copyWith((message) => updates(message as CreateUserRequest))
          as CreateUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateUserRequest create() => CreateUserRequest._();
  @$core.override
  CreateUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateUserRequest>(create);
  static CreateUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);
}

class CreateUserResponse extends $pb.GeneratedMessage {
  factory CreateUserResponse({
    User? user,
  }) {
    final result = create();
    if (user != null) result.user = user;
    return result;
  }

  CreateUserResponse._();

  factory CreateUserResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateUserResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateUserResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateUserResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateUserResponse copyWith(void Function(CreateUserResponse) updates) =>
      super.copyWith((message) => updates(message as CreateUserResponse))
          as CreateUserResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateUserResponse create() => CreateUserResponse._();
  @$core.override
  CreateUserResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateUserResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateUserResponse>(create);
  static CreateUserResponse? _defaultInstance;

  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);
}

class GetUserRequest extends $pb.GeneratedMessage {
  factory GetUserRequest({
    $core.String? userId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    return result;
  }

  GetUserRequest._();

  factory GetUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserRequest copyWith(void Function(GetUserRequest) updates) =>
      super.copyWith((message) => updates(message as GetUserRequest))
          as GetUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUserRequest create() => GetUserRequest._();
  @$core.override
  GetUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUserRequest>(create);
  static GetUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);
}

class GetUserResponse extends $pb.GeneratedMessage {
  factory GetUserResponse({
    User? user,
  }) {
    final result = create();
    if (user != null) result.user = user;
    return result;
  }

  GetUserResponse._();

  factory GetUserResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUserResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUserResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserResponse copyWith(void Function(GetUserResponse) updates) =>
      super.copyWith((message) => updates(message as GetUserResponse))
          as GetUserResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUserResponse create() => GetUserResponse._();
  @$core.override
  GetUserResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUserResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUserResponse>(create);
  static GetUserResponse? _defaultInstance;

  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);
}

class UpdateMyProfileRequest extends $pb.GeneratedMessage {
  factory UpdateMyProfileRequest({
    $core.String? profileEmoji,
    $core.String? profileColorHex,
    $core.double? bodyWeightKg,
  }) {
    final result = create();
    if (profileEmoji != null) result.profileEmoji = profileEmoji;
    if (profileColorHex != null) result.profileColorHex = profileColorHex;
    if (bodyWeightKg != null) result.bodyWeightKg = bodyWeightKg;
    return result;
  }

  UpdateMyProfileRequest._();

  factory UpdateMyProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateMyProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateMyProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'profileEmoji')
    ..aOS(2, _omitFieldNames ? '' : 'profileColorHex')
    ..aD(3, _omitFieldNames ? '' : 'bodyWeightKg',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMyProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMyProfileRequest copyWith(
          void Function(UpdateMyProfileRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateMyProfileRequest))
          as UpdateMyProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateMyProfileRequest create() => UpdateMyProfileRequest._();
  @$core.override
  UpdateMyProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateMyProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateMyProfileRequest>(create);
  static UpdateMyProfileRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get profileEmoji => $_getSZ(0);
  @$pb.TagNumber(1)
  set profileEmoji($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProfileEmoji() => $_has(0);
  @$pb.TagNumber(1)
  void clearProfileEmoji() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get profileColorHex => $_getSZ(1);
  @$pb.TagNumber(2)
  set profileColorHex($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProfileColorHex() => $_has(1);
  @$pb.TagNumber(2)
  void clearProfileColorHex() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get bodyWeightKg => $_getN(2);
  @$pb.TagNumber(3)
  set bodyWeightKg($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBodyWeightKg() => $_has(2);
  @$pb.TagNumber(3)
  void clearBodyWeightKg() => $_clearField(3);
}

class UpdateMyProfileResponse extends $pb.GeneratedMessage {
  factory UpdateMyProfileResponse({
    User? user,
  }) {
    final result = create();
    if (user != null) result.user = user;
    return result;
  }

  UpdateMyProfileResponse._();

  factory UpdateMyProfileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateMyProfileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateMyProfileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<User>(1, _omitFieldNames ? '' : 'user', subBuilder: User.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMyProfileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateMyProfileResponse copyWith(
          void Function(UpdateMyProfileResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateMyProfileResponse))
          as UpdateMyProfileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateMyProfileResponse create() => UpdateMyProfileResponse._();
  @$core.override
  UpdateMyProfileResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateMyProfileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateMyProfileResponse>(create);
  static UpdateMyProfileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  User ensureUser() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
