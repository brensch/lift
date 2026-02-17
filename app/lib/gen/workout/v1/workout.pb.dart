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
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (createdAt != null) result.createdAt = createdAt;
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
}

class Workout extends $pb.GeneratedMessage {
  factory Workout({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? startTime,
    $fixnum.Int64? endTime,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
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
}

class ExerciseTypeConfig extends $pb.GeneratedMessage {
  factory ExerciseTypeConfig({
    Exercise? exercise,
    $core.double? startWeight,
    $core.double? endWeight,
    $core.int? reps,
    $core.bool? includeWarmup,
    RestConfig? restConfig,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (startWeight != null) result.startWeight = startWeight;
    if (endWeight != null) result.endWeight = endWeight;
    if (reps != null) result.reps = reps;
    if (includeWarmup != null) result.includeWarmup = includeWarmup;
    if (restConfig != null) result.restConfig = restConfig;
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

class StartWorkoutRequest extends $pb.GeneratedMessage {
  factory StartWorkoutRequest({
    $core.String? name,
    $core.Iterable<ExerciseGroup>? exerciseGroups,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (exerciseGroups != null) result.exerciseGroups.addAll(exerciseGroups);
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
}

class StartWorkoutResponse extends $pb.GeneratedMessage {
  factory StartWorkoutResponse({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
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

class GetWorkoutResponse extends $pb.GeneratedMessage {
  factory GetWorkoutResponse({
    Workout? workout,
    $core.Iterable<ExerciseGroup>? exerciseGroups,
    $core.Iterable<ProposedSet>? proposedSets,
    $core.Iterable<CompletedSet>? completedSets,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
    if (exerciseGroups != null) result.exerciseGroups.addAll(exerciseGroups);
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
    if (completedSets != null) result.completedSets.addAll(completedSets);
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
  }) {
    final result = create();
    if (group != null) result.group = group;
    if (generatedSets != null) result.generatedSets.addAll(generatedSets);
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
}

class StartSetRequest extends $pb.GeneratedMessage {
  factory StartSetRequest({
    $core.String? workoutId,
    $core.String? proposedSetId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (proposedSetId != null) result.proposedSetId = proposedSetId;
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
}

class StartSetResponse extends $pb.GeneratedMessage {
  factory StartSetResponse({
    CompletedSet? completedSet,
  }) {
    final result = create();
    if (completedSet != null) result.completedSet = completedSet;
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
}

class CompleteSetRequest extends $pb.GeneratedMessage {
  factory CompleteSetRequest({
    $core.String? workoutId,
    $core.String? proposedSetId,
    $core.int? actualReps,
    $core.double? actualWeight,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (proposedSetId != null) result.proposedSetId = proposedSetId;
    if (actualReps != null) result.actualReps = actualReps;
    if (actualWeight != null) result.actualWeight = actualWeight;
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
}

class CompleteSetResponse extends $pb.GeneratedMessage {
  factory CompleteSetResponse({
    CompletedSet? completedSet,
  }) {
    final result = create();
    if (completedSet != null) result.completedSet = completedSet;
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
  factory DeleteCompletedSetResponse() => create();

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
}

class EndWorkoutRequest extends $pb.GeneratedMessage {
  factory EndWorkoutRequest({
    $core.String? workoutId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
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
}

class EndWorkoutResponse extends $pb.GeneratedMessage {
  factory EndWorkoutResponse({
    Workout? workout,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
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
}

class GetProposedWorkoutScheduleRequest extends $pb.GeneratedMessage {
  factory GetProposedWorkoutScheduleRequest({
    $core.String? userId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
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
}

class ExerciseStatus extends $pb.GeneratedMessage {
  factory ExerciseStatus({
    Exercise? exercise,
    $core.double? targetWeight,
    $core.String? explanation,
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
    if (explanation != null) result.explanation = explanation;
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
    ..aOS(3, _omitFieldNames ? '' : 'explanation')
    ..aInt64(4, _omitFieldNames ? '' : 'lastPerformedAt')
    ..p<$core.double>(
        5, _omitFieldNames ? '' : 'weightHistory', $pb.PbFieldType.KF)
    ..pc<MuscleGroup>(
        6, _omitFieldNames ? '' : 'muscleGroups', $pb.PbFieldType.KE,
        valueOf: MuscleGroup.valueOf,
        enumValues: MuscleGroup.values,
        defaultEnumValue: MuscleGroup.MUSCLE_GROUP_UNSPECIFIED)
    ..aI(7, _omitFieldNames ? '' : 'defaultSets')
    ..aI(8, _omitFieldNames ? '' : 'defaultReps')
    ..aOB(9, _omitFieldNames ? '' : 'recovered')
    ..aOB(10, _omitFieldNames ? '' : 'alwaysInclude')
    ..aE<ExerciseCategory>(11, _omitFieldNames ? '' : 'category',
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
  $core.String get explanation => $_getSZ(2);
  @$pb.TagNumber(3)
  set explanation($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExplanation() => $_has(2);
  @$pb.TagNumber(3)
  void clearExplanation() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get lastPerformedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set lastPerformedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastPerformedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastPerformedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.double> get weightHistory => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<MuscleGroup> get muscleGroups => $_getList(5);

  @$pb.TagNumber(7)
  $core.int get defaultSets => $_getIZ(6);
  @$pb.TagNumber(7)
  set defaultSets($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDefaultSets() => $_has(6);
  @$pb.TagNumber(7)
  void clearDefaultSets() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get defaultReps => $_getIZ(7);
  @$pb.TagNumber(8)
  set defaultReps($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDefaultReps() => $_has(7);
  @$pb.TagNumber(8)
  void clearDefaultReps() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get recovered => $_getBF(8);
  @$pb.TagNumber(9)
  set recovered($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRecovered() => $_has(8);
  @$pb.TagNumber(9)
  void clearRecovered() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get alwaysInclude => $_getBF(9);
  @$pb.TagNumber(10)
  set alwaysInclude($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAlwaysInclude() => $_has(9);
  @$pb.TagNumber(10)
  void clearAlwaysInclude() => $_clearField(10);

  @$pb.TagNumber(11)
  ExerciseCategory get category => $_getN(10);
  @$pb.TagNumber(11)
  set category(ExerciseCategory value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCategory() => $_has(10);
  @$pb.TagNumber(11)
  void clearCategory() => $_clearField(11);
}

class ProposedExerciseGroup extends $pb.GeneratedMessage {
  factory ProposedExerciseGroup({
    $core.String? name,
    $core.int? sets,
    $core.bool? interleaveWarmups,
    $core.Iterable<ExerciseTypeConfig>? exerciseConfigs,
    RestConfig? restConfig,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (sets != null) result.sets = sets;
    if (interleaveWarmups != null) result.interleaveWarmups = interleaveWarmups;
    if (exerciseConfigs != null) result.exerciseConfigs.addAll(exerciseConfigs);
    if (restConfig != null) result.restConfig = restConfig;
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
}

class GetProposedWorkoutScheduleResponse extends $pb.GeneratedMessage {
  factory GetProposedWorkoutScheduleResponse({
    $core.Iterable<ExerciseStatus>? exerciseStatuses,
    $core.String? activeWorkoutId,
    $core.Iterable<ProposedExerciseGroup>? proposedGroups,
  }) {
    final result = create();
    if (exerciseStatuses != null)
      result.exerciseStatuses.addAll(exerciseStatuses);
    if (activeWorkoutId != null) result.activeWorkoutId = activeWorkoutId;
    if (proposedGroups != null) result.proposedGroups.addAll(proposedGroups);
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
  }) {
    final result = create();
    if (group != null) result.group = group;
    if (generatedSets != null) result.generatedSets.addAll(generatedSets);
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
  factory DeleteExerciseGroupResponse() => create();

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
  factory ReorderExerciseGroupsResponse() => create();

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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
