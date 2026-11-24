// This is a generated file - do not edit.
//
// Generated from workout/v1/snapshot.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'settings.pb.dart' as $0;
import 'workout.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class AccountSnapshot extends $pb.GeneratedMessage {
  factory AccountSnapshot({
    $core.String? fold,
    $fixnum.Int64? seq,
    $core.Iterable<$core.String>? programs,
    $core.Iterable<$0.UserSetting>? settings,
    $core.Iterable<SnapshotProgramVersion>? versions,
    $core.int? program,
    $core.Iterable<SnapshotStartingWeight>? startingWeights,
    $core.Iterable<SnapshotOverride>? overrides,
    $core.Iterable<SnapshotWorkout>? workouts,
    $core.Iterable<SnapshotSuggestion>? suggestions,
    $core.String? activeWorkoutId,
    $core.bool? onboarded,
    $core.bool? withoutHeartRate,
  }) {
    final result = create();
    if (fold != null) result.fold = fold;
    if (seq != null) result.seq = seq;
    if (programs != null) result.programs.addAll(programs);
    if (settings != null) result.settings.addAll(settings);
    if (versions != null) result.versions.addAll(versions);
    if (program != null) result.program = program;
    if (startingWeights != null) result.startingWeights.addAll(startingWeights);
    if (overrides != null) result.overrides.addAll(overrides);
    if (workouts != null) result.workouts.addAll(workouts);
    if (suggestions != null) result.suggestions.addAll(suggestions);
    if (activeWorkoutId != null) result.activeWorkoutId = activeWorkoutId;
    if (onboarded != null) result.onboarded = onboarded;
    if (withoutHeartRate != null) result.withoutHeartRate = withoutHeartRate;
    return result;
  }

  AccountSnapshot._();

  factory AccountSnapshot.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AccountSnapshot.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccountSnapshot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'fold')
    ..aInt64(2, _omitFieldNames ? '' : 'seq')
    ..pPS(3, _omitFieldNames ? '' : 'programs')
    ..pPM<$0.UserSetting>(4, _omitFieldNames ? '' : 'settings',
        subBuilder: $0.UserSetting.create)
    ..pPM<SnapshotProgramVersion>(5, _omitFieldNames ? '' : 'versions',
        subBuilder: SnapshotProgramVersion.create)
    ..aI(6, _omitFieldNames ? '' : 'program', fieldType: $pb.PbFieldType.OU3)
    ..pPM<SnapshotStartingWeight>(7, _omitFieldNames ? '' : 'startingWeights',
        subBuilder: SnapshotStartingWeight.create)
    ..pPM<SnapshotOverride>(8, _omitFieldNames ? '' : 'overrides',
        subBuilder: SnapshotOverride.create)
    ..pPM<SnapshotWorkout>(9, _omitFieldNames ? '' : 'workouts',
        subBuilder: SnapshotWorkout.create)
    ..pPM<SnapshotSuggestion>(10, _omitFieldNames ? '' : 'suggestions',
        subBuilder: SnapshotSuggestion.create)
    ..aOS(11, _omitFieldNames ? '' : 'activeWorkoutId')
    ..aOB(12, _omitFieldNames ? '' : 'onboarded')
    ..aOB(13, _omitFieldNames ? '' : 'withoutHeartRate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountSnapshot clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountSnapshot copyWith(void Function(AccountSnapshot) updates) =>
      super.copyWith((message) => updates(message as AccountSnapshot))
          as AccountSnapshot;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AccountSnapshot create() => AccountSnapshot._();
  @$core.override
  AccountSnapshot createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AccountSnapshot getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AccountSnapshot>(create);
  static AccountSnapshot? _defaultInstance;

  /// The rules that folded it: schlift_core::FOLD.
  @$pb.TagNumber(1)
  $core.String get fold => $_getSZ(0);
  @$pb.TagNumber(1)
  set fold($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFold() => $_has(0);
  @$pb.TagNumber(1)
  void clearFold() => $_clearField(1);

  /// The last event folded into it.
  @$pb.TagNumber(2)
  $fixnum.Int64 get seq => $_getI64(1);
  @$pb.TagNumber(2)
  set seq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeq() => $_clearField(2);

  /// Each program the account holds, once, as its JSON document: the
  /// workouts and versions below name them by their place here.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get programs => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$0.UserSetting> get settings => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<SnapshotProgramVersion> get versions => $_getList(4);

  @$pb.TagNumber(6)
  $core.int get program => $_getIZ(5);
  @$pb.TagNumber(6)
  set program($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasProgram() => $_has(5);
  @$pb.TagNumber(6)
  void clearProgram() => $_clearField(6);

  /// In lift order.
  @$pb.TagNumber(7)
  $pb.PbList<SnapshotStartingWeight> get startingWeights => $_getList(6);

  @$pb.TagNumber(8)
  $pb.PbList<SnapshotOverride> get overrides => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<SnapshotWorkout> get workouts => $_getList(8);

  @$pb.TagNumber(10)
  $pb.PbList<SnapshotSuggestion> get suggestions => $_getList(9);

  @$pb.TagNumber(11)
  $core.String get activeWorkoutId => $_getSZ(10);
  @$pb.TagNumber(11)
  set activeWorkoutId($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasActiveWorkoutId() => $_has(10);
  @$pb.TagNumber(11)
  void clearActiveWorkoutId() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get onboarded => $_getBF(11);
  @$pb.TagNumber(12)
  set onboarded($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasOnboarded() => $_has(11);
  @$pb.TagNumber(12)
  void clearOnboarded() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get withoutHeartRate => $_getBF(12);
  @$pb.TagNumber(13)
  set withoutHeartRate($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasWithoutHeartRate() => $_has(12);
  @$pb.TagNumber(13)
  void clearWithoutHeartRate() => $_clearField(13);
}

class SnapshotProgramVersion extends $pb.GeneratedMessage {
  factory SnapshotProgramVersion({
    $core.String? id,
    $fixnum.Int64? at,
    $core.String? author,
    $core.String? note,
    $core.int? program,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (at != null) result.at = at;
    if (author != null) result.author = author;
    if (note != null) result.note = note;
    if (program != null) result.program = program;
    return result;
  }

  SnapshotProgramVersion._();

  factory SnapshotProgramVersion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SnapshotProgramVersion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SnapshotProgramVersion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'at')
    ..aOS(3, _omitFieldNames ? '' : 'author')
    ..aOS(4, _omitFieldNames ? '' : 'note')
    ..aI(5, _omitFieldNames ? '' : 'program', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotProgramVersion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotProgramVersion copyWith(
          void Function(SnapshotProgramVersion) updates) =>
      super.copyWith((message) => updates(message as SnapshotProgramVersion))
          as SnapshotProgramVersion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SnapshotProgramVersion create() => SnapshotProgramVersion._();
  @$core.override
  SnapshotProgramVersion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SnapshotProgramVersion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SnapshotProgramVersion>(create);
  static SnapshotProgramVersion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get at => $_getI64(1);
  @$pb.TagNumber(2)
  set at($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get author => $_getSZ(2);
  @$pb.TagNumber(3)
  set author($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAuthor() => $_has(2);
  @$pb.TagNumber(3)
  void clearAuthor() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get note => $_getSZ(3);
  @$pb.TagNumber(4)
  set note($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNote() => $_has(3);
  @$pb.TagNumber(4)
  void clearNote() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get program => $_getIZ(4);
  @$pb.TagNumber(5)
  set program($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasProgram() => $_has(4);
  @$pb.TagNumber(5)
  void clearProgram() => $_clearField(5);
}

class SnapshotStartingWeight extends $pb.GeneratedMessage {
  factory SnapshotStartingWeight({
    $core.String? lift,
    $core.double? weight,
  }) {
    final result = create();
    if (lift != null) result.lift = lift;
    if (weight != null) result.weight = weight;
    return result;
  }

  SnapshotStartingWeight._();

  factory SnapshotStartingWeight.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SnapshotStartingWeight.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SnapshotStartingWeight',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'lift')
    ..aD(2, _omitFieldNames ? '' : 'weight', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotStartingWeight clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotStartingWeight copyWith(
          void Function(SnapshotStartingWeight) updates) =>
      super.copyWith((message) => updates(message as SnapshotStartingWeight))
          as SnapshotStartingWeight;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SnapshotStartingWeight create() => SnapshotStartingWeight._();
  @$core.override
  SnapshotStartingWeight createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SnapshotStartingWeight getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SnapshotStartingWeight>(create);
  static SnapshotStartingWeight? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get lift => $_getSZ(0);
  @$pb.TagNumber(1)
  set lift($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLift() => $_has(0);
  @$pb.TagNumber(1)
  void clearLift() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get weight => $_getN(1);
  @$pb.TagNumber(2)
  set weight($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWeight() => $_has(1);
  @$pb.TagNumber(2)
  void clearWeight() => $_clearField(2);
}

class SnapshotOverride extends $pb.GeneratedMessage {
  factory SnapshotOverride({
    $core.String? lift,
    $fixnum.Int64? at,
    $core.double? weight,
    $core.int? reps,
    $core.bool? hasSets,
    $core.int? sets_6,
  }) {
    final result = create();
    if (lift != null) result.lift = lift;
    if (at != null) result.at = at;
    if (weight != null) result.weight = weight;
    if (reps != null) result.reps = reps;
    if (hasSets != null) result.hasSets = hasSets;
    if (sets_6 != null) result.sets_6 = sets_6;
    return result;
  }

  SnapshotOverride._();

  factory SnapshotOverride.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SnapshotOverride.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SnapshotOverride',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'lift')
    ..aInt64(2, _omitFieldNames ? '' : 'at')
    ..aD(3, _omitFieldNames ? '' : 'weight', fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'reps')
    ..aOB(5, _omitFieldNames ? '' : 'hasSets')
    ..aI(6, _omitFieldNames ? '' : 'sets')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotOverride clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotOverride copyWith(void Function(SnapshotOverride) updates) =>
      super.copyWith((message) => updates(message as SnapshotOverride))
          as SnapshotOverride;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SnapshotOverride create() => SnapshotOverride._();
  @$core.override
  SnapshotOverride createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SnapshotOverride getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SnapshotOverride>(create);
  static SnapshotOverride? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get lift => $_getSZ(0);
  @$pb.TagNumber(1)
  set lift($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLift() => $_has(0);
  @$pb.TagNumber(1)
  void clearLift() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get at => $_getI64(1);
  @$pb.TagNumber(2)
  set at($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get weight => $_getN(2);
  @$pb.TagNumber(3)
  set weight($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWeight() => $_has(2);
  @$pb.TagNumber(3)
  void clearWeight() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get reps => $_getIZ(3);
  @$pb.TagNumber(4)
  set reps($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReps() => $_has(3);
  @$pb.TagNumber(4)
  void clearReps() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get hasSets => $_getBF(4);
  @$pb.TagNumber(5)
  set hasSets($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasHasSets() => $_has(4);
  @$pb.TagNumber(5)
  void clearHasSets() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get sets_6 => $_getIZ(5);
  @$pb.TagNumber(6)
  set sets_6($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSets_6() => $_has(5);
  @$pb.TagNumber(6)
  void clearSets_6() => $_clearField(6);
}

class SnapshotWorkout extends $pb.GeneratedMessage {
  factory SnapshotWorkout({
    $1.Workout? workout,
    $core.Iterable<$1.ProposedSet>? proposedSets,
    $core.Iterable<$1.CompletedSet>? completedSets,
    $core.Iterable<$1.ExerciseLog>? exerciseLogs,
    $core.bool? kg,
    $core.int? program,
    $core.Iterable<$1.WorkoutHeartRatePoint>? heartRate,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
    if (completedSets != null) result.completedSets.addAll(completedSets);
    if (exerciseLogs != null) result.exerciseLogs.addAll(exerciseLogs);
    if (kg != null) result.kg = kg;
    if (program != null) result.program = program;
    if (heartRate != null) result.heartRate.addAll(heartRate);
    return result;
  }

  SnapshotWorkout._();

  factory SnapshotWorkout.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SnapshotWorkout.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SnapshotWorkout',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<$1.Workout>(1, _omitFieldNames ? '' : 'workout',
        subBuilder: $1.Workout.create)
    ..pPM<$1.ProposedSet>(2, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: $1.ProposedSet.create)
    ..pPM<$1.CompletedSet>(3, _omitFieldNames ? '' : 'completedSets',
        subBuilder: $1.CompletedSet.create)
    ..pPM<$1.ExerciseLog>(4, _omitFieldNames ? '' : 'exerciseLogs',
        subBuilder: $1.ExerciseLog.create)
    ..aOB(5, _omitFieldNames ? '' : 'kg')
    ..aI(6, _omitFieldNames ? '' : 'program', fieldType: $pb.PbFieldType.OU3)
    ..pPM<$1.WorkoutHeartRatePoint>(7, _omitFieldNames ? '' : 'heartRate',
        subBuilder: $1.WorkoutHeartRatePoint.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotWorkout clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotWorkout copyWith(void Function(SnapshotWorkout) updates) =>
      super.copyWith((message) => updates(message as SnapshotWorkout))
          as SnapshotWorkout;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SnapshotWorkout create() => SnapshotWorkout._();
  @$core.override
  SnapshotWorkout createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SnapshotWorkout getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SnapshotWorkout>(create);
  static SnapshotWorkout? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Workout get workout => $_getN(0);
  @$pb.TagNumber(1)
  set workout($1.Workout value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkout() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkout() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Workout ensureWorkout() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<$1.ProposedSet> get proposedSets => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$1.CompletedSet> get completedSets => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$1.ExerciseLog> get exerciseLogs => $_getList(3);

  @$pb.TagNumber(5)
  $core.bool get kg => $_getBF(4);
  @$pb.TagNumber(5)
  set kg($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasKg() => $_has(4);
  @$pb.TagNumber(5)
  void clearKg() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get program => $_getIZ(5);
  @$pb.TagNumber(6)
  set program($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasProgram() => $_has(5);
  @$pb.TagNumber(6)
  void clearProgram() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$1.WorkoutHeartRatePoint> get heartRate => $_getList(6);
}

class SnapshotSuggestion extends $pb.GeneratedMessage {
  factory SnapshotSuggestion({
    $core.String? id,
    $fixnum.Int64? at,
    $core.String? suggested,
    $core.bool? answered,
    $core.bool? accepted,
    $fixnum.Int64? answeredAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (at != null) result.at = at;
    if (suggested != null) result.suggested = suggested;
    if (answered != null) result.answered = answered;
    if (accepted != null) result.accepted = accepted;
    if (answeredAt != null) result.answeredAt = answeredAt;
    return result;
  }

  SnapshotSuggestion._();

  factory SnapshotSuggestion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SnapshotSuggestion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SnapshotSuggestion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'at')
    ..aOS(3, _omitFieldNames ? '' : 'suggested')
    ..aOB(4, _omitFieldNames ? '' : 'answered')
    ..aOB(5, _omitFieldNames ? '' : 'accepted')
    ..aInt64(6, _omitFieldNames ? '' : 'answeredAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotSuggestion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SnapshotSuggestion copyWith(void Function(SnapshotSuggestion) updates) =>
      super.copyWith((message) => updates(message as SnapshotSuggestion))
          as SnapshotSuggestion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SnapshotSuggestion create() => SnapshotSuggestion._();
  @$core.override
  SnapshotSuggestion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SnapshotSuggestion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SnapshotSuggestion>(create);
  static SnapshotSuggestion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get at => $_getI64(1);
  @$pb.TagNumber(2)
  set at($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearAt() => $_clearField(2);

  /// The ProgramSuggested fact, as JSON.
  @$pb.TagNumber(3)
  $core.String get suggested => $_getSZ(2);
  @$pb.TagNumber(3)
  set suggested($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSuggested() => $_has(2);
  @$pb.TagNumber(3)
  void clearSuggested() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get answered => $_getBF(3);
  @$pb.TagNumber(4)
  set answered($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAnswered() => $_has(3);
  @$pb.TagNumber(4)
  void clearAnswered() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get accepted => $_getBF(4);
  @$pb.TagNumber(5)
  set accepted($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAccepted() => $_has(4);
  @$pb.TagNumber(5)
  void clearAccepted() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get answeredAt => $_getI64(5);
  @$pb.TagNumber(6)
  set answeredAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAnsweredAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearAnsweredAt() => $_clearField(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
