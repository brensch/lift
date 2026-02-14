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

class ProposedSet extends $pb.GeneratedMessage {
  factory ProposedSet({
    $core.String? id,
    $core.String? workoutId,
    $core.int? workoutOrder,
    Exercise? exercise,
    $core.int? targetReps,
    $core.double? targetWeight,
    $core.bool? warmup,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (workoutId != null) result.workoutId = workoutId;
    if (workoutOrder != null) result.workoutOrder = workoutOrder;
    if (exercise != null) result.exercise = exercise;
    if (targetReps != null) result.targetReps = targetReps;
    if (targetWeight != null) result.targetWeight = targetWeight;
    if (warmup != null) result.warmup = warmup;
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
    $core.Iterable<ProposedSet>? proposedSets,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
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
    ..pPM<ProposedSet>(2, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: ProposedSet.create)
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
  $pb.PbList<ProposedSet> get proposedSets => $_getList(1);
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
    $core.Iterable<ProposedSet>? proposedSets,
    $core.Iterable<CompletedSet>? completedSets,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
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
    ..pPM<ProposedSet>(2, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: ProposedSet.create)
    ..pPM<CompletedSet>(3, _omitFieldNames ? '' : 'completedSets',
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
  $pb.PbList<ProposedSet> get proposedSets => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<CompletedSet> get completedSets => $_getList(2);
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

class ModifyProposedSetsRequest extends $pb.GeneratedMessage {
  factory ModifyProposedSetsRequest({
    $core.String? workoutId,
    $core.Iterable<ProposedSet>? proposedSets,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
    return result;
  }

  ModifyProposedSetsRequest._();

  factory ModifyProposedSetsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModifyProposedSetsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModifyProposedSetsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..pPM<ProposedSet>(2, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: ProposedSet.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModifyProposedSetsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModifyProposedSetsRequest copyWith(
          void Function(ModifyProposedSetsRequest) updates) =>
      super.copyWith((message) => updates(message as ModifyProposedSetsRequest))
          as ModifyProposedSetsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModifyProposedSetsRequest create() => ModifyProposedSetsRequest._();
  @$core.override
  ModifyProposedSetsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModifyProposedSetsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModifyProposedSetsRequest>(create);
  static ModifyProposedSetsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ProposedSet> get proposedSets => $_getList(1);
}

class ModifyProposedSetsResponse extends $pb.GeneratedMessage {
  factory ModifyProposedSetsResponse({
    $core.Iterable<ProposedSet>? proposedSets,
  }) {
    final result = create();
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
    return result;
  }

  ModifyProposedSetsResponse._();

  factory ModifyProposedSetsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ModifyProposedSetsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModifyProposedSetsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<ProposedSet>(1, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: ProposedSet.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModifyProposedSetsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModifyProposedSetsResponse copyWith(
          void Function(ModifyProposedSetsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ModifyProposedSetsResponse))
          as ModifyProposedSetsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ModifyProposedSetsResponse create() => ModifyProposedSetsResponse._();
  @$core.override
  ModifyProposedSetsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ModifyProposedSetsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModifyProposedSetsResponse>(create);
  static ModifyProposedSetsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ProposedSet> get proposedSets => $_getList(0);
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

class GetProposedWorkoutScheduleResponse extends $pb.GeneratedMessage {
  factory GetProposedWorkoutScheduleResponse({
    $core.Iterable<ExerciseStatus>? exerciseStatuses,
    $core.String? activeWorkoutId,
  }) {
    final result = create();
    if (exerciseStatuses != null)
      result.exerciseStatuses.addAll(exerciseStatuses);
    if (activeWorkoutId != null) result.activeWorkoutId = activeWorkoutId;
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
