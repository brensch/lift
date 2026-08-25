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

import 'settings.pbenum.dart' as $1;
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
    $core.String? templateId,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    if (sessionId != null) result.sessionId = sessionId;
    if (templateId != null) result.templateId = templateId;
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
    ..aOS(6, _omitFieldNames ? '' : 'templateId')
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

  /// The template this workout was started from ("" = started empty). Lets
  /// the app offer "update your template?" when the session diverged.
  @$pb.TagNumber(6)
  $core.String get templateId => $_getSZ(5);
  @$pb.TagNumber(6)
  set templateId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTemplateId() => $_has(5);
  @$pb.TagNumber(6)
  void clearTemplateId() => $_clearField(6);
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
  }) {
    final result = create();
    if (targetWeight != null) result.targetWeight = targetWeight;
    if (targetReps != null) result.targetReps = targetReps;
    if (isAmrap != null) result.isAmrap = isAmrap;
    if (instruction != null) result.instruction = instruction;
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
    $core.String? templateId,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (exerciseGroups != null) result.exerciseGroups.addAll(exerciseGroups);
    if (startedAt != null) result.startedAt = startedAt;
    if (templateId != null) result.templateId = templateId;
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
    ..aOS(4, _omitFieldNames ? '' : 'templateId')
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

  /// When set, the server builds the groups itself: one group per template
  /// exercise, weights from the trackers, sets/reps/rest from the
  /// prescription, warmups where prescribed. `exercise_groups` is ignored.
  @$pb.TagNumber(4)
  $core.String get templateId => $_getSZ(3);
  @$pb.TagNumber(4)
  set templateId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTemplateId() => $_has(3);
  @$pb.TagNumber(4)
  void clearTemplateId() => $_clearField(4);
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

  @$pb.TagNumber(10)
  $core.String get clientSetId => $_getSZ(8);
  @$pb.TagNumber(10)
  set clientSetId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(10)
  $core.bool hasClientSetId() => $_has(8);
  @$pb.TagNumber(10)
  void clearClientSetId() => $_clearField(10);
}

/// Which exercises in a group plan should get a server-generated warmup ladder.
/// Wrapped in a message so presence is meaningful: an unset `warmup_plan` means
/// "the client didn't say" (keep whatever warmups the group already has), while a
/// set-but-empty `exercises` means "no warmups at all". A bare repeated field
/// couldn't tell those apart.
class GroupWarmupPlan extends $pb.GeneratedMessage {
  factory GroupWarmupPlan({
    $core.Iterable<Exercise>? exercises,
  }) {
    final result = create();
    if (exercises != null) result.exercises.addAll(exercises);
    return result;
  }

  GroupWarmupPlan._();

  factory GroupWarmupPlan.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GroupWarmupPlan.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GroupWarmupPlan',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pc<Exercise>(1, _omitFieldNames ? '' : 'exercises', $pb.PbFieldType.KE,
        valueOf: Exercise.valueOf,
        enumValues: Exercise.values,
        defaultEnumValue: Exercise.EXERCISE_UNSPECIFIED)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupWarmupPlan clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GroupWarmupPlan copyWith(void Function(GroupWarmupPlan) updates) =>
      super.copyWith((message) => updates(message as GroupWarmupPlan))
          as GroupWarmupPlan;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GroupWarmupPlan create() => GroupWarmupPlan._();
  @$core.override
  GroupWarmupPlan createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GroupWarmupPlan getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GroupWarmupPlan>(create);
  static GroupWarmupPlan? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Exercise> get exercises => $_getList(0);
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
    GroupWarmupPlan? warmupPlan,
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
    if (warmupPlan != null) result.warmupPlan = warmupPlan;
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
    ..aOM<GroupWarmupPlan>(10, _omitFieldNames ? '' : 'warmupPlan',
        subBuilder: GroupWarmupPlan.create)
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

  /// Warmup intent. The client sends working sets only; the server materializes
  /// the ladders for the exercises named here (both when creating a group and
  /// when editing one).
  @$pb.TagNumber(10)
  GroupWarmupPlan get warmupPlan => $_getN(9);
  @$pb.TagNumber(10)
  set warmupPlan(GroupWarmupPlan value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasWarmupPlan() => $_has(9);
  @$pb.TagNumber(10)
  void clearWarmupPlan() => $_clearField(10);
  @$pb.TagNumber(10)
  GroupWarmupPlan ensureWarmupPlan() => $_ensure(9);
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

/// A named, ordered list of exercises. Nothing else: sets, reps, rest and
/// weight all derive from the prescription and the tracker, so every
/// template that contains an exercise shows the same current weight.
class WorkoutTemplate extends $pb.GeneratedMessage {
  factory WorkoutTemplate({
    $core.String? id,
    $core.String? name,
    $core.int? order,
    $core.Iterable<Exercise>? exercises,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (order != null) result.order = order;
    if (exercises != null) result.exercises.addAll(exercises);
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  WorkoutTemplate._();

  factory WorkoutTemplate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WorkoutTemplate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorkoutTemplate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aI(3, _omitFieldNames ? '' : 'order')
    ..pc<Exercise>(4, _omitFieldNames ? '' : 'exercises', $pb.PbFieldType.KE,
        valueOf: Exercise.valueOf,
        enumValues: Exercise.values,
        defaultEnumValue: Exercise.EXERCISE_UNSPECIFIED)
    ..aInt64(5, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(6, _omitFieldNames ? '' : 'updatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutTemplate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorkoutTemplate copyWith(void Function(WorkoutTemplate) updates) =>
      super.copyWith((message) => updates(message as WorkoutTemplate))
          as WorkoutTemplate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WorkoutTemplate create() => WorkoutTemplate._();
  @$core.override
  WorkoutTemplate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WorkoutTemplate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WorkoutTemplate>(create);
  static WorkoutTemplate? _defaultInstance;

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
  $core.int get order => $_getIZ(2);
  @$pb.TagNumber(3)
  set order($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOrder() => $_has(2);
  @$pb.TagNumber(3)
  void clearOrder() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<Exercise> get exercises => $_getList(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get createdAt => $_getI64(4);
  @$pb.TagNumber(5)
  set createdAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedAt() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get updatedAt => $_getI64(5);
  @$pb.TagNumber(6)
  set updatedAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUpdatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearUpdatedAt() => $_clearField(6);
}

/// The resolved state of one exercise for one user: the weight and the
/// prescription the next workout will use. GetHome returns one for every
/// exercise in the catalog, so the client never needs a fallback table.
class ExerciseTracker extends $pb.GeneratedMessage {
  factory ExerciseTracker({
    Exercise? exercise,
    $core.double? workingWeight,
    $core.int? sets,
    $core.int? targetReps,
    $core.int? repRangeLow,
    $core.int? repRangeHigh,
    $core.int? restSeconds,
    $core.int? restSecondsFailure,
    $core.bool? includeWarmup,
    $fixnum.Int64? lastPerformedAt,
    $core.Iterable<$core.double>? weightHistory,
    $core.bool? overridden,
    MuscleGroup? primaryMuscle,
    ExerciseCategory? category,
    EquipmentKind? equipment,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (workingWeight != null) result.workingWeight = workingWeight;
    if (sets != null) result.sets = sets;
    if (targetReps != null) result.targetReps = targetReps;
    if (repRangeLow != null) result.repRangeLow = repRangeLow;
    if (repRangeHigh != null) result.repRangeHigh = repRangeHigh;
    if (restSeconds != null) result.restSeconds = restSeconds;
    if (restSecondsFailure != null)
      result.restSecondsFailure = restSecondsFailure;
    if (includeWarmup != null) result.includeWarmup = includeWarmup;
    if (lastPerformedAt != null) result.lastPerformedAt = lastPerformedAt;
    if (weightHistory != null) result.weightHistory.addAll(weightHistory);
    if (overridden != null) result.overridden = overridden;
    if (primaryMuscle != null) result.primaryMuscle = primaryMuscle;
    if (category != null) result.category = category;
    if (equipment != null) result.equipment = equipment;
    return result;
  }

  ExerciseTracker._();

  factory ExerciseTracker.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseTracker.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseTracker',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..aD(2, _omitFieldNames ? '' : 'workingWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'sets')
    ..aI(4, _omitFieldNames ? '' : 'targetReps')
    ..aI(5, _omitFieldNames ? '' : 'repRangeLow')
    ..aI(6, _omitFieldNames ? '' : 'repRangeHigh')
    ..aI(7, _omitFieldNames ? '' : 'restSeconds')
    ..aI(8, _omitFieldNames ? '' : 'restSecondsFailure')
    ..aOB(9, _omitFieldNames ? '' : 'includeWarmup')
    ..aInt64(10, _omitFieldNames ? '' : 'lastPerformedAt')
    ..p<$core.double>(
        11, _omitFieldNames ? '' : 'weightHistory', $pb.PbFieldType.KF)
    ..aOB(12, _omitFieldNames ? '' : 'overridden')
    ..aE<MuscleGroup>(13, _omitFieldNames ? '' : 'primaryMuscle',
        enumValues: MuscleGroup.values)
    ..aE<ExerciseCategory>(14, _omitFieldNames ? '' : 'category',
        enumValues: ExerciseCategory.values)
    ..aE<EquipmentKind>(15, _omitFieldNames ? '' : 'equipment',
        enumValues: EquipmentKind.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseTracker clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseTracker copyWith(void Function(ExerciseTracker) updates) =>
      super.copyWith((message) => updates(message as ExerciseTracker))
          as ExerciseTracker;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseTracker create() => ExerciseTracker._();
  @$core.override
  ExerciseTracker createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseTracker getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseTracker>(create);
  static ExerciseTracker? _defaultInstance;

  @$pb.TagNumber(1)
  Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise(Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get workingWeight => $_getN(1);
  @$pb.TagNumber(2)
  set workingWeight($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkingWeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkingWeight() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get sets => $_getIZ(2);
  @$pb.TagNumber(3)
  set sets($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSets() => $_has(2);
  @$pb.TagNumber(3)
  void clearSets() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get targetReps => $_getIZ(3);
  @$pb.TagNumber(4)
  set targetReps($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTargetReps() => $_has(3);
  @$pb.TagNumber(4)
  void clearTargetReps() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get repRangeLow => $_getIZ(4);
  @$pb.TagNumber(5)
  set repRangeLow($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRepRangeLow() => $_has(4);
  @$pb.TagNumber(5)
  void clearRepRangeLow() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get repRangeHigh => $_getIZ(5);
  @$pb.TagNumber(6)
  set repRangeHigh($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRepRangeHigh() => $_has(5);
  @$pb.TagNumber(6)
  void clearRepRangeHigh() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get restSeconds => $_getIZ(6);
  @$pb.TagNumber(7)
  set restSeconds($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRestSeconds() => $_has(6);
  @$pb.TagNumber(7)
  void clearRestSeconds() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get restSecondsFailure => $_getIZ(7);
  @$pb.TagNumber(8)
  set restSecondsFailure($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRestSecondsFailure() => $_has(7);
  @$pb.TagNumber(8)
  void clearRestSecondsFailure() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get includeWarmup => $_getBF(8);
  @$pb.TagNumber(9)
  set includeWarmup($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIncludeWarmup() => $_has(8);
  @$pb.TagNumber(9)
  void clearIncludeWarmup() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get lastPerformedAt => $_getI64(9);
  @$pb.TagNumber(10)
  set lastPerformedAt($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLastPerformedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearLastPerformedAt() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.double> get weightHistory => $_getList(10);

  @$pb.TagNumber(12)
  $core.bool get overridden => $_getBF(11);
  @$pb.TagNumber(12)
  set overridden($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasOverridden() => $_has(11);
  @$pb.TagNumber(12)
  void clearOverridden() => $_clearField(12);

  @$pb.TagNumber(13)
  MuscleGroup get primaryMuscle => $_getN(12);
  @$pb.TagNumber(13)
  set primaryMuscle(MuscleGroup value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasPrimaryMuscle() => $_has(12);
  @$pb.TagNumber(13)
  void clearPrimaryMuscle() => $_clearField(13);

  @$pb.TagNumber(14)
  ExerciseCategory get category => $_getN(13);
  @$pb.TagNumber(14)
  set category(ExerciseCategory value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCategory() => $_has(13);
  @$pb.TagNumber(14)
  void clearCategory() => $_clearField(14);

  @$pb.TagNumber(15)
  EquipmentKind get equipment => $_getN(14);
  @$pb.TagNumber(15)
  set equipment(EquipmentKind value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasEquipment() => $_has(14);
  @$pb.TagNumber(15)
  void clearEquipment() => $_clearField(15);
}

/// Weighted hard sets for one muscle over the rolling last 7 days.
/// A completed working set counts 1.0 for the exercise's primary muscle
/// and 0.5 for each secondary; warmups and cancelled sets count 0.
class MuscleVolume extends $pb.GeneratedMessage {
  factory MuscleVolume({
    MuscleGroup? muscle,
    $core.double? completedSets7d,
    $core.int? targetLow,
    $core.int? targetHigh,
  }) {
    final result = create();
    if (muscle != null) result.muscle = muscle;
    if (completedSets7d != null) result.completedSets7d = completedSets7d;
    if (targetLow != null) result.targetLow = targetLow;
    if (targetHigh != null) result.targetHigh = targetHigh;
    return result;
  }

  MuscleVolume._();

  factory MuscleVolume.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MuscleVolume.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MuscleVolume',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<MuscleGroup>(1, _omitFieldNames ? '' : 'muscle',
        enumValues: MuscleGroup.values)
    ..aD(2, _omitFieldNames ? '' : 'completedSets7d',
        protoName: 'completed_sets_7d', fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'targetLow')
    ..aI(4, _omitFieldNames ? '' : 'targetHigh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MuscleVolume clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MuscleVolume copyWith(void Function(MuscleVolume) updates) =>
      super.copyWith((message) => updates(message as MuscleVolume))
          as MuscleVolume;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MuscleVolume create() => MuscleVolume._();
  @$core.override
  MuscleVolume createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MuscleVolume getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MuscleVolume>(create);
  static MuscleVolume? _defaultInstance;

  @$pb.TagNumber(1)
  MuscleGroup get muscle => $_getN(0);
  @$pb.TagNumber(1)
  set muscle(MuscleGroup value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMuscle() => $_has(0);
  @$pb.TagNumber(1)
  void clearMuscle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get completedSets7d => $_getN(1);
  @$pb.TagNumber(2)
  set completedSets7d($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCompletedSets7d() => $_has(1);
  @$pb.TagNumber(2)
  void clearCompletedSets7d() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get targetLow => $_getIZ(2);
  @$pb.TagNumber(3)
  set targetLow($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTargetLow() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetLow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get targetHigh => $_getIZ(3);
  @$pb.TagNumber(4)
  set targetHigh($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTargetHigh() => $_has(3);
  @$pb.TagNumber(4)
  void clearTargetHigh() => $_clearField(4);
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
  }) {
    final result = create();
    if (muscleKey != null) result.muscleKey = muscleKey;
    if (label != null) result.label = label;
    if (lastTrainedAt != null) result.lastTrainedAt = lastTrainedAt;
    if (recoveredAt != null) result.recoveredAt = recoveredAt;
    if (fraction != null) result.fraction = fraction;
    if (hoursRemaining != null) result.hoursRemaining = hoursRemaining;
    if (recovered != null) result.recovered = recovered;
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
}

class GetHomeRequest extends $pb.GeneratedMessage {
  factory GetHomeRequest() => create();

  GetHomeRequest._();

  factory GetHomeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetHomeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetHomeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHomeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHomeRequest copyWith(void Function(GetHomeRequest) updates) =>
      super.copyWith((message) => updates(message as GetHomeRequest))
          as GetHomeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetHomeRequest create() => GetHomeRequest._();
  @$core.override
  GetHomeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetHomeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetHomeRequest>(create);
  static GetHomeRequest? _defaultInstance;
}

class GetHomeResponse extends $pb.GeneratedMessage {
  factory GetHomeResponse({
    $core.Iterable<WorkoutTemplate>? templates,
    $core.Iterable<ExerciseTracker>? trackers,
    $core.String? activeWorkoutId,
    $core.Iterable<UserMessage>? userMessages,
    $core.Iterable<MuscleVolume>? volume,
    $core.Iterable<MuscleRecoveryStatus>? recovery,
    $core.String? suggestedTemplateId,
    $core.String? suggestionReason,
    $core.bool? onboarded,
  }) {
    final result = create();
    if (templates != null) result.templates.addAll(templates);
    if (trackers != null) result.trackers.addAll(trackers);
    if (activeWorkoutId != null) result.activeWorkoutId = activeWorkoutId;
    if (userMessages != null) result.userMessages.addAll(userMessages);
    if (volume != null) result.volume.addAll(volume);
    if (recovery != null) result.recovery.addAll(recovery);
    if (suggestedTemplateId != null)
      result.suggestedTemplateId = suggestedTemplateId;
    if (suggestionReason != null) result.suggestionReason = suggestionReason;
    if (onboarded != null) result.onboarded = onboarded;
    return result;
  }

  GetHomeResponse._();

  factory GetHomeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetHomeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetHomeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<WorkoutTemplate>(1, _omitFieldNames ? '' : 'templates',
        subBuilder: WorkoutTemplate.create)
    ..pPM<ExerciseTracker>(2, _omitFieldNames ? '' : 'trackers',
        subBuilder: ExerciseTracker.create)
    ..aOS(3, _omitFieldNames ? '' : 'activeWorkoutId')
    ..pPM<UserMessage>(4, _omitFieldNames ? '' : 'userMessages',
        subBuilder: UserMessage.create)
    ..pPM<MuscleVolume>(5, _omitFieldNames ? '' : 'volume',
        subBuilder: MuscleVolume.create)
    ..pPM<MuscleRecoveryStatus>(6, _omitFieldNames ? '' : 'recovery',
        subBuilder: MuscleRecoveryStatus.create)
    ..aOS(7, _omitFieldNames ? '' : 'suggestedTemplateId')
    ..aOS(8, _omitFieldNames ? '' : 'suggestionReason')
    ..aOB(9, _omitFieldNames ? '' : 'onboarded')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHomeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetHomeResponse copyWith(void Function(GetHomeResponse) updates) =>
      super.copyWith((message) => updates(message as GetHomeResponse))
          as GetHomeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetHomeResponse create() => GetHomeResponse._();
  @$core.override
  GetHomeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetHomeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetHomeResponse>(create);
  static GetHomeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<WorkoutTemplate> get templates => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<ExerciseTracker> get trackers => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get activeWorkoutId => $_getSZ(2);
  @$pb.TagNumber(3)
  set activeWorkoutId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveWorkoutId() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveWorkoutId() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<UserMessage> get userMessages => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<MuscleVolume> get volume => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<MuscleRecoveryStatus> get recovery => $_getList(5);

  /// A stateless suggestion: the template whose muscles are furthest
  /// below the volume band, ties broken toward the least recently
  /// started. Never a gate — any template can be started.
  @$pb.TagNumber(7)
  $core.String get suggestedTemplateId => $_getSZ(6);
  @$pb.TagNumber(7)
  set suggestedTemplateId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSuggestedTemplateId() => $_has(6);
  @$pb.TagNumber(7)
  void clearSuggestedTemplateId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get suggestionReason => $_getSZ(7);
  @$pb.TagNumber(8)
  set suggestionReason($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSuggestionReason() => $_has(7);
  @$pb.TagNumber(8)
  void clearSuggestionReason() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get onboarded => $_getBF(8);
  @$pb.TagNumber(9)
  set onboarded($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOnboarded() => $_has(8);
  @$pb.TagNumber(9)
  void clearOnboarded() => $_clearField(9);
}

/// Create when id is empty; update when it exists.
class SaveTemplateRequest extends $pb.GeneratedMessage {
  factory SaveTemplateRequest({
    WorkoutTemplate? template,
  }) {
    final result = create();
    if (template != null) result.template = template;
    return result;
  }

  SaveTemplateRequest._();

  factory SaveTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaveTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveTemplateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<WorkoutTemplate>(1, _omitFieldNames ? '' : 'template',
        subBuilder: WorkoutTemplate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveTemplateRequest copyWith(void Function(SaveTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as SaveTemplateRequest))
          as SaveTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaveTemplateRequest create() => SaveTemplateRequest._();
  @$core.override
  SaveTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SaveTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveTemplateRequest>(create);
  static SaveTemplateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  WorkoutTemplate get template => $_getN(0);
  @$pb.TagNumber(1)
  set template(WorkoutTemplate value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTemplate() => $_has(0);
  @$pb.TagNumber(1)
  void clearTemplate() => $_clearField(1);
  @$pb.TagNumber(1)
  WorkoutTemplate ensureTemplate() => $_ensure(0);
}

class SaveTemplateResponse extends $pb.GeneratedMessage {
  factory SaveTemplateResponse({
    WorkoutTemplate? template,
  }) {
    final result = create();
    if (template != null) result.template = template;
    return result;
  }

  SaveTemplateResponse._();

  factory SaveTemplateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaveTemplateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveTemplateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<WorkoutTemplate>(1, _omitFieldNames ? '' : 'template',
        subBuilder: WorkoutTemplate.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveTemplateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveTemplateResponse copyWith(void Function(SaveTemplateResponse) updates) =>
      super.copyWith((message) => updates(message as SaveTemplateResponse))
          as SaveTemplateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaveTemplateResponse create() => SaveTemplateResponse._();
  @$core.override
  SaveTemplateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SaveTemplateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveTemplateResponse>(create);
  static SaveTemplateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  WorkoutTemplate get template => $_getN(0);
  @$pb.TagNumber(1)
  set template(WorkoutTemplate value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTemplate() => $_has(0);
  @$pb.TagNumber(1)
  void clearTemplate() => $_clearField(1);
  @$pb.TagNumber(1)
  WorkoutTemplate ensureTemplate() => $_ensure(0);
}

class DeleteTemplateRequest extends $pb.GeneratedMessage {
  factory DeleteTemplateRequest({
    $core.String? templateId,
  }) {
    final result = create();
    if (templateId != null) result.templateId = templateId;
    return result;
  }

  DeleteTemplateRequest._();

  factory DeleteTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTemplateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'templateId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTemplateRequest copyWith(
          void Function(DeleteTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteTemplateRequest))
          as DeleteTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTemplateRequest create() => DeleteTemplateRequest._();
  @$core.override
  DeleteTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTemplateRequest>(create);
  static DeleteTemplateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get templateId => $_getSZ(0);
  @$pb.TagNumber(1)
  set templateId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTemplateId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTemplateId() => $_clearField(1);
}

class DeleteTemplateResponse extends $pb.GeneratedMessage {
  factory DeleteTemplateResponse() => create();

  DeleteTemplateResponse._();

  factory DeleteTemplateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTemplateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTemplateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTemplateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTemplateResponse copyWith(
          void Function(DeleteTemplateResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteTemplateResponse))
          as DeleteTemplateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTemplateResponse create() => DeleteTemplateResponse._();
  @$core.override
  DeleteTemplateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTemplateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTemplateResponse>(create);
  static DeleteTemplateResponse? _defaultInstance;
}

class ReorderTemplatesRequest extends $pb.GeneratedMessage {
  factory ReorderTemplatesRequest({
    $core.Iterable<$core.String>? templateIds,
  }) {
    final result = create();
    if (templateIds != null) result.templateIds.addAll(templateIds);
    return result;
  }

  ReorderTemplatesRequest._();

  factory ReorderTemplatesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderTemplatesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderTemplatesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'templateIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderTemplatesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderTemplatesRequest copyWith(
          void Function(ReorderTemplatesRequest) updates) =>
      super.copyWith((message) => updates(message as ReorderTemplatesRequest))
          as ReorderTemplatesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderTemplatesRequest create() => ReorderTemplatesRequest._();
  @$core.override
  ReorderTemplatesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderTemplatesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderTemplatesRequest>(create);
  static ReorderTemplatesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get templateIds => $_getList(0);
}

class ReorderTemplatesResponse extends $pb.GeneratedMessage {
  factory ReorderTemplatesResponse() => create();

  ReorderTemplatesResponse._();

  factory ReorderTemplatesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReorderTemplatesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReorderTemplatesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderTemplatesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReorderTemplatesResponse copyWith(
          void Function(ReorderTemplatesResponse) updates) =>
      super.copyWith((message) => updates(message as ReorderTemplatesResponse))
          as ReorderTemplatesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReorderTemplatesResponse create() => ReorderTemplatesResponse._();
  @$core.override
  ReorderTemplatesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReorderTemplatesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReorderTemplatesResponse>(create);
  static ReorderTemplatesResponse? _defaultInstance;
}

/// Manual correction / override for one exercise. working_weight is the
/// full new value (send the current one to keep it). Overrides of 0 mean
/// "derived". current_reps resets to the resolved range bottom.
class SetExerciseTrackerRequest extends $pb.GeneratedMessage {
  factory SetExerciseTrackerRequest({
    Exercise? exercise,
    $core.double? workingWeight,
    $core.int? overrideSets,
    $core.int? overrideRepLow,
    $core.int? overrideRepHigh,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (workingWeight != null) result.workingWeight = workingWeight;
    if (overrideSets != null) result.overrideSets = overrideSets;
    if (overrideRepLow != null) result.overrideRepLow = overrideRepLow;
    if (overrideRepHigh != null) result.overrideRepHigh = overrideRepHigh;
    return result;
  }

  SetExerciseTrackerRequest._();

  factory SetExerciseTrackerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetExerciseTrackerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetExerciseTrackerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: Exercise.values)
    ..aD(2, _omitFieldNames ? '' : 'workingWeight',
        fieldType: $pb.PbFieldType.OF)
    ..aI(3, _omitFieldNames ? '' : 'overrideSets')
    ..aI(4, _omitFieldNames ? '' : 'overrideRepLow')
    ..aI(5, _omitFieldNames ? '' : 'overrideRepHigh')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetExerciseTrackerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetExerciseTrackerRequest copyWith(
          void Function(SetExerciseTrackerRequest) updates) =>
      super.copyWith((message) => updates(message as SetExerciseTrackerRequest))
          as SetExerciseTrackerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetExerciseTrackerRequest create() => SetExerciseTrackerRequest._();
  @$core.override
  SetExerciseTrackerRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetExerciseTrackerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetExerciseTrackerRequest>(create);
  static SetExerciseTrackerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise(Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get workingWeight => $_getN(1);
  @$pb.TagNumber(2)
  set workingWeight($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkingWeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkingWeight() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get overrideSets => $_getIZ(2);
  @$pb.TagNumber(3)
  set overrideSets($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOverrideSets() => $_has(2);
  @$pb.TagNumber(3)
  void clearOverrideSets() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get overrideRepLow => $_getIZ(3);
  @$pb.TagNumber(4)
  set overrideRepLow($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOverrideRepLow() => $_has(3);
  @$pb.TagNumber(4)
  void clearOverrideRepLow() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get overrideRepHigh => $_getIZ(4);
  @$pb.TagNumber(5)
  set overrideRepHigh($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOverrideRepHigh() => $_has(4);
  @$pb.TagNumber(5)
  void clearOverrideRepHigh() => $_clearField(5);
}

class SetExerciseTrackerResponse extends $pb.GeneratedMessage {
  factory SetExerciseTrackerResponse({
    ExerciseTracker? tracker,
  }) {
    final result = create();
    if (tracker != null) result.tracker = tracker;
    return result;
  }

  SetExerciseTrackerResponse._();

  factory SetExerciseTrackerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetExerciseTrackerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetExerciseTrackerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ExerciseTracker>(1, _omitFieldNames ? '' : 'tracker',
        subBuilder: ExerciseTracker.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetExerciseTrackerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetExerciseTrackerResponse copyWith(
          void Function(SetExerciseTrackerResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SetExerciseTrackerResponse))
          as SetExerciseTrackerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetExerciseTrackerResponse create() => SetExerciseTrackerResponse._();
  @$core.override
  SetExerciseTrackerResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetExerciseTrackerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetExerciseTrackerResponse>(create);
  static SetExerciseTrackerResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ExerciseTracker get tracker => $_getN(0);
  @$pb.TagNumber(1)
  set tracker(ExerciseTracker value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTracker() => $_has(0);
  @$pb.TagNumber(1)
  void clearTracker() => $_clearField(1);
  @$pb.TagNumber(1)
  ExerciseTracker ensureTracker() => $_ensure(0);
}

/// Finishes setup: saves the unit, seeds trackers for the main lifts from
/// bodyweight and experience (catalog openers when skipped), and copies
/// the default templates. Does nothing when templates already exist.
class CompleteOnboardingRequest extends $pb.GeneratedMessage {
  factory CompleteOnboardingRequest({
    $core.double? bodyWeightKg,
    ExperienceLevel? experience,
    $1.WeightUnit? unit,
    Gender? gender,
  }) {
    final result = create();
    if (bodyWeightKg != null) result.bodyWeightKg = bodyWeightKg;
    if (experience != null) result.experience = experience;
    if (unit != null) result.unit = unit;
    if (gender != null) result.gender = gender;
    return result;
  }

  CompleteOnboardingRequest._();

  factory CompleteOnboardingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteOnboardingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteOnboardingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'bodyWeightKg',
        fieldType: $pb.PbFieldType.OF)
    ..aE<ExperienceLevel>(2, _omitFieldNames ? '' : 'experience',
        enumValues: ExperienceLevel.values)
    ..aE<$1.WeightUnit>(3, _omitFieldNames ? '' : 'unit',
        enumValues: $1.WeightUnit.values)
    ..aE<Gender>(4, _omitFieldNames ? '' : 'gender', enumValues: Gender.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteOnboardingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteOnboardingRequest copyWith(
          void Function(CompleteOnboardingRequest) updates) =>
      super.copyWith((message) => updates(message as CompleteOnboardingRequest))
          as CompleteOnboardingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteOnboardingRequest create() => CompleteOnboardingRequest._();
  @$core.override
  CompleteOnboardingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteOnboardingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteOnboardingRequest>(create);
  static CompleteOnboardingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get bodyWeightKg => $_getN(0);
  @$pb.TagNumber(1)
  set bodyWeightKg($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBodyWeightKg() => $_has(0);
  @$pb.TagNumber(1)
  void clearBodyWeightKg() => $_clearField(1);

  @$pb.TagNumber(2)
  ExperienceLevel get experience => $_getN(1);
  @$pb.TagNumber(2)
  set experience(ExperienceLevel value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasExperience() => $_has(1);
  @$pb.TagNumber(2)
  void clearExperience() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.WeightUnit get unit => $_getN(2);
  @$pb.TagNumber(3)
  set unit($1.WeightUnit value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUnit() => $_has(2);
  @$pb.TagNumber(3)
  void clearUnit() => $_clearField(3);

  @$pb.TagNumber(4)
  Gender get gender => $_getN(3);
  @$pb.TagNumber(4)
  set gender(Gender value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasGender() => $_has(3);
  @$pb.TagNumber(4)
  void clearGender() => $_clearField(4);
}

class CompleteOnboardingResponse extends $pb.GeneratedMessage {
  factory CompleteOnboardingResponse({
    GetHomeResponse? home,
  }) {
    final result = create();
    if (home != null) result.home = home;
    return result;
  }

  CompleteOnboardingResponse._();

  factory CompleteOnboardingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteOnboardingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteOnboardingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<GetHomeResponse>(1, _omitFieldNames ? '' : 'home',
        subBuilder: GetHomeResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteOnboardingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteOnboardingResponse copyWith(
          void Function(CompleteOnboardingResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CompleteOnboardingResponse))
          as CompleteOnboardingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteOnboardingResponse create() => CompleteOnboardingResponse._();
  @$core.override
  CompleteOnboardingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteOnboardingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteOnboardingResponse>(create);
  static CompleteOnboardingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GetHomeResponse get home => $_getN(0);
  @$pb.TagNumber(1)
  set home(GetHomeResponse value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHome() => $_has(0);
  @$pb.TagNumber(1)
  void clearHome() => $_clearField(1);
  @$pb.TagNumber(1)
  GetHomeResponse ensureHome() => $_ensure(0);
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
