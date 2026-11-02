// This is a generated file - do not edit.
//
// Generated from workout/v1/account.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'group.pb.dart' as $3;
import 'settings.pb.dart' as $2;
import 'workout.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum Event_Kind {
  startWorkout,
  workout,
  heartRate,
  saveTemplate,
  deleteTemplate,
  reorderTemplates,
  addLibraryTemplates,
  completeOnboarding,
  updateSetting,
  importHistory,
  cloneTemplate,
  setOverride,
  notSet
}

class Event extends $pb.GeneratedMessage {
  factory Event({
    $fixnum.Int64? seq,
    $core.String? id,
    $fixnum.Int64? at,
    $1.StartWorkoutRequest? startWorkout,
    $1.WorkoutMutation? workout,
    $1.AppendWorkoutHeartRateRequest? heartRate,
    $1.SaveTemplateRequest? saveTemplate,
    $1.DeleteTemplateRequest? deleteTemplate,
    $1.ReorderTemplatesRequest? reorderTemplates,
    $1.AddLibraryTemplatesRequest? addLibraryTemplates,
    $1.CompleteOnboardingRequest? completeOnboarding,
    $2.UpdateSettingRequest? updateSetting,
    ImportHistory? importHistory,
    $1.CloneTemplateRequest? cloneTemplate,
    $1.SetOverrideRequest? setOverride,
  }) {
    final result = create();
    if (seq != null) result.seq = seq;
    if (id != null) result.id = id;
    if (at != null) result.at = at;
    if (startWorkout != null) result.startWorkout = startWorkout;
    if (workout != null) result.workout = workout;
    if (heartRate != null) result.heartRate = heartRate;
    if (saveTemplate != null) result.saveTemplate = saveTemplate;
    if (deleteTemplate != null) result.deleteTemplate = deleteTemplate;
    if (reorderTemplates != null) result.reorderTemplates = reorderTemplates;
    if (addLibraryTemplates != null)
      result.addLibraryTemplates = addLibraryTemplates;
    if (completeOnboarding != null)
      result.completeOnboarding = completeOnboarding;
    if (updateSetting != null) result.updateSetting = updateSetting;
    if (importHistory != null) result.importHistory = importHistory;
    if (cloneTemplate != null) result.cloneTemplate = cloneTemplate;
    if (setOverride != null) result.setOverride = setOverride;
    return result;
  }

  Event._();

  factory Event.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Event.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Event_Kind> _Event_KindByTag = {
    10: Event_Kind.startWorkout,
    11: Event_Kind.workout,
    12: Event_Kind.heartRate,
    13: Event_Kind.saveTemplate,
    14: Event_Kind.deleteTemplate,
    15: Event_Kind.reorderTemplates,
    16: Event_Kind.addLibraryTemplates,
    18: Event_Kind.completeOnboarding,
    19: Event_Kind.updateSetting,
    21: Event_Kind.importHistory,
    22: Event_Kind.cloneTemplate,
    23: Event_Kind.setOverride,
    0: Event_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Event',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 18, 19, 21, 22, 23])
    ..aInt64(1, _omitFieldNames ? '' : 'seq')
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..aInt64(3, _omitFieldNames ? '' : 'at')
    ..aOM<$1.StartWorkoutRequest>(10, _omitFieldNames ? '' : 'startWorkout',
        subBuilder: $1.StartWorkoutRequest.create)
    ..aOM<$1.WorkoutMutation>(11, _omitFieldNames ? '' : 'workout',
        subBuilder: $1.WorkoutMutation.create)
    ..aOM<$1.AppendWorkoutHeartRateRequest>(
        12, _omitFieldNames ? '' : 'heartRate',
        subBuilder: $1.AppendWorkoutHeartRateRequest.create)
    ..aOM<$1.SaveTemplateRequest>(13, _omitFieldNames ? '' : 'saveTemplate',
        subBuilder: $1.SaveTemplateRequest.create)
    ..aOM<$1.DeleteTemplateRequest>(14, _omitFieldNames ? '' : 'deleteTemplate',
        subBuilder: $1.DeleteTemplateRequest.create)
    ..aOM<$1.ReorderTemplatesRequest>(
        15, _omitFieldNames ? '' : 'reorderTemplates',
        subBuilder: $1.ReorderTemplatesRequest.create)
    ..aOM<$1.AddLibraryTemplatesRequest>(
        16, _omitFieldNames ? '' : 'addLibraryTemplates',
        subBuilder: $1.AddLibraryTemplatesRequest.create)
    ..aOM<$1.CompleteOnboardingRequest>(
        18, _omitFieldNames ? '' : 'completeOnboarding',
        subBuilder: $1.CompleteOnboardingRequest.create)
    ..aOM<$2.UpdateSettingRequest>(19, _omitFieldNames ? '' : 'updateSetting',
        subBuilder: $2.UpdateSettingRequest.create)
    ..aOM<ImportHistory>(21, _omitFieldNames ? '' : 'importHistory',
        subBuilder: ImportHistory.create)
    ..aOM<$1.CloneTemplateRequest>(22, _omitFieldNames ? '' : 'cloneTemplate',
        subBuilder: $1.CloneTemplateRequest.create)
    ..aOM<$1.SetOverrideRequest>(23, _omitFieldNames ? '' : 'setOverride',
        subBuilder: $1.SetOverrideRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event copyWith(void Function(Event) updates) =>
      super.copyWith((message) => updates(message as Event)) as Event;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Event create() => Event._();
  @$core.override
  Event createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Event getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Event>(create);
  static Event? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  Event_Kind whichKind() => _Event_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  @$pb.TagNumber(23)
  void clearKind() => $_clearField($_whichOneof(0));

  /// Position in the account's log: 1, 2, 3…, no gaps.
  @$pb.TagNumber(1)
  $fixnum.Int64 get seq => $_getI64(0);
  @$pb.TagNumber(1)
  set seq($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearSeq() => $_clearField(1);

  /// Random, made by the device. Every id the event creates (a workout, a set,
  /// a template) is derived from it, so a replay makes the same ids.
  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  /// Unix seconds on the device's clock when the write was made. The fold
  /// never reads a clock of its own.
  @$pb.TagNumber(3)
  $fixnum.Int64 get at => $_getI64(2);
  @$pb.TagNumber(3)
  set at($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearAt() => $_clearField(3);

  @$pb.TagNumber(10)
  $1.StartWorkoutRequest get startWorkout => $_getN(3);
  @$pb.TagNumber(10)
  set startWorkout($1.StartWorkoutRequest value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasStartWorkout() => $_has(3);
  @$pb.TagNumber(10)
  void clearStartWorkout() => $_clearField(10);
  @$pb.TagNumber(10)
  $1.StartWorkoutRequest ensureStartWorkout() => $_ensure(3);

  /// Everything done to a workout once it's started, ending included.
  @$pb.TagNumber(11)
  $1.WorkoutMutation get workout => $_getN(4);
  @$pb.TagNumber(11)
  set workout($1.WorkoutMutation value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasWorkout() => $_has(4);
  @$pb.TagNumber(11)
  void clearWorkout() => $_clearField(11);
  @$pb.TagNumber(11)
  $1.WorkoutMutation ensureWorkout() => $_ensure(4);

  @$pb.TagNumber(12)
  $1.AppendWorkoutHeartRateRequest get heartRate => $_getN(5);
  @$pb.TagNumber(12)
  set heartRate($1.AppendWorkoutHeartRateRequest value) =>
      $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasHeartRate() => $_has(5);
  @$pb.TagNumber(12)
  void clearHeartRate() => $_clearField(12);
  @$pb.TagNumber(12)
  $1.AppendWorkoutHeartRateRequest ensureHeartRate() => $_ensure(5);

  @$pb.TagNumber(13)
  $1.SaveTemplateRequest get saveTemplate => $_getN(6);
  @$pb.TagNumber(13)
  set saveTemplate($1.SaveTemplateRequest value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasSaveTemplate() => $_has(6);
  @$pb.TagNumber(13)
  void clearSaveTemplate() => $_clearField(13);
  @$pb.TagNumber(13)
  $1.SaveTemplateRequest ensureSaveTemplate() => $_ensure(6);

  @$pb.TagNumber(14)
  $1.DeleteTemplateRequest get deleteTemplate => $_getN(7);
  @$pb.TagNumber(14)
  set deleteTemplate($1.DeleteTemplateRequest value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasDeleteTemplate() => $_has(7);
  @$pb.TagNumber(14)
  void clearDeleteTemplate() => $_clearField(14);
  @$pb.TagNumber(14)
  $1.DeleteTemplateRequest ensureDeleteTemplate() => $_ensure(7);

  @$pb.TagNumber(15)
  $1.ReorderTemplatesRequest get reorderTemplates => $_getN(8);
  @$pb.TagNumber(15)
  set reorderTemplates($1.ReorderTemplatesRequest value) =>
      $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasReorderTemplates() => $_has(8);
  @$pb.TagNumber(15)
  void clearReorderTemplates() => $_clearField(15);
  @$pb.TagNumber(15)
  $1.ReorderTemplatesRequest ensureReorderTemplates() => $_ensure(8);

  @$pb.TagNumber(16)
  $1.AddLibraryTemplatesRequest get addLibraryTemplates => $_getN(9);
  @$pb.TagNumber(16)
  set addLibraryTemplates($1.AddLibraryTemplatesRequest value) =>
      $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasAddLibraryTemplates() => $_has(9);
  @$pb.TagNumber(16)
  void clearAddLibraryTemplates() => $_clearField(16);
  @$pb.TagNumber(16)
  $1.AddLibraryTemplatesRequest ensureAddLibraryTemplates() => $_ensure(9);

  @$pb.TagNumber(18)
  $1.CompleteOnboardingRequest get completeOnboarding => $_getN(10);
  @$pb.TagNumber(18)
  set completeOnboarding($1.CompleteOnboardingRequest value) =>
      $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasCompleteOnboarding() => $_has(10);
  @$pb.TagNumber(18)
  void clearCompleteOnboarding() => $_clearField(18);
  @$pb.TagNumber(18)
  $1.CompleteOnboardingRequest ensureCompleteOnboarding() => $_ensure(10);

  @$pb.TagNumber(19)
  $2.UpdateSettingRequest get updateSetting => $_getN(11);
  @$pb.TagNumber(19)
  set updateSetting($2.UpdateSettingRequest value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasUpdateSetting() => $_has(11);
  @$pb.TagNumber(19)
  void clearUpdateSetting() => $_clearField(19);
  @$pb.TagNumber(19)
  $2.UpdateSettingRequest ensureUpdateSetting() => $_ensure(11);

  @$pb.TagNumber(21)
  ImportHistory get importHistory => $_getN(12);
  @$pb.TagNumber(21)
  set importHistory(ImportHistory value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasImportHistory() => $_has(12);
  @$pb.TagNumber(21)
  void clearImportHistory() => $_clearField(21);
  @$pb.TagNumber(21)
  ImportHistory ensureImportHistory() => $_ensure(12);

  @$pb.TagNumber(22)
  $1.CloneTemplateRequest get cloneTemplate => $_getN(13);
  @$pb.TagNumber(22)
  set cloneTemplate($1.CloneTemplateRequest value) => $_setField(22, value);
  @$pb.TagNumber(22)
  $core.bool hasCloneTemplate() => $_has(13);
  @$pb.TagNumber(22)
  void clearCloneTemplate() => $_clearField(22);
  @$pb.TagNumber(22)
  $1.CloneTemplateRequest ensureCloneTemplate() => $_ensure(13);

  @$pb.TagNumber(23)
  $1.SetOverrideRequest get setOverride => $_getN(14);
  @$pb.TagNumber(23)
  set setOverride($1.SetOverrideRequest value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasSetOverride() => $_has(14);
  @$pb.TagNumber(23)
  void clearSetOverride() => $_clearField(23);
  @$pb.TagNumber(23)
  $1.SetOverrideRequest ensureSetOverride() => $_ensure(14);
}

/// History brought in from elsewhere, as it was: finished workouts, and the
/// starting weights of lifts never done. Plans read the workouts like any
/// others; nothing else is recomputed from it.
class ImportHistory extends $pb.GeneratedMessage {
  factory ImportHistory({
    $core.Iterable<ImportedWorkout>? workouts,
    $core.Iterable<$1.ExerciseWeight>? startingWeights,
  }) {
    final result = create();
    if (workouts != null) result.workouts.addAll(workouts);
    if (startingWeights != null) result.startingWeights.addAll(startingWeights);
    return result;
  }

  ImportHistory._();

  factory ImportHistory.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImportHistory.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportHistory',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<ImportedWorkout>(1, _omitFieldNames ? '' : 'workouts',
        subBuilder: ImportedWorkout.create)
    ..pPM<$1.ExerciseWeight>(3, _omitFieldNames ? '' : 'startingWeights',
        subBuilder: $1.ExerciseWeight.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportHistory clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportHistory copyWith(void Function(ImportHistory) updates) =>
      super.copyWith((message) => updates(message as ImportHistory))
          as ImportHistory;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImportHistory create() => ImportHistory._();
  @$core.override
  ImportHistory createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImportHistory getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportHistory>(create);
  static ImportHistory? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ImportedWorkout> get workouts => $_getList(0);

  @$pb.TagNumber(3)
  $pb.PbList<$1.ExerciseWeight> get startingWeights => $_getList(1);
}

class ImportHistoryResponse extends $pb.GeneratedMessage {
  factory ImportHistoryResponse() => create();

  ImportHistoryResponse._();

  factory ImportHistoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImportHistoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportHistoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportHistoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportHistoryResponse copyWith(
          void Function(ImportHistoryResponse) updates) =>
      super.copyWith((message) => updates(message as ImportHistoryResponse))
          as ImportHistoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImportHistoryResponse create() => ImportHistoryResponse._();
  @$core.override
  ImportHistoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImportHistoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportHistoryResponse>(create);
  static ImportHistoryResponse? _defaultInstance;
}

/// A finished workout with everything recorded in it.
class ImportedWorkout extends $pb.GeneratedMessage {
  factory ImportedWorkout({
    $1.Workout? workout,
    $core.Iterable<$1.ProposedSet>? proposedSets,
    $core.Iterable<$1.CompletedSet>? completedSets,
    $core.Iterable<$1.WorkoutHeartRatePoint>? heartRate,
    $core.Iterable<$1.ExerciseLog>? exerciseLogs,
  }) {
    final result = create();
    if (workout != null) result.workout = workout;
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
    if (completedSets != null) result.completedSets.addAll(completedSets);
    if (heartRate != null) result.heartRate.addAll(heartRate);
    if (exerciseLogs != null) result.exerciseLogs.addAll(exerciseLogs);
    return result;
  }

  ImportedWorkout._();

  factory ImportedWorkout.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImportedWorkout.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportedWorkout',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<$1.Workout>(1, _omitFieldNames ? '' : 'workout',
        subBuilder: $1.Workout.create)
    ..pPM<$1.ProposedSet>(2, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: $1.ProposedSet.create)
    ..pPM<$1.CompletedSet>(3, _omitFieldNames ? '' : 'completedSets',
        subBuilder: $1.CompletedSet.create)
    ..pPM<$1.WorkoutHeartRatePoint>(4, _omitFieldNames ? '' : 'heartRate',
        subBuilder: $1.WorkoutHeartRatePoint.create)
    ..pPM<$1.ExerciseLog>(5, _omitFieldNames ? '' : 'exerciseLogs',
        subBuilder: $1.ExerciseLog.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportedWorkout clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportedWorkout copyWith(void Function(ImportedWorkout) updates) =>
      super.copyWith((message) => updates(message as ImportedWorkout))
          as ImportedWorkout;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImportedWorkout create() => ImportedWorkout._();
  @$core.override
  ImportedWorkout createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImportedWorkout getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportedWorkout>(create);
  static ImportedWorkout? _defaultInstance;

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
  $pb.PbList<$1.WorkoutHeartRatePoint> get heartRate => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$1.ExerciseLog> get exerciseLogs => $_getList(4);
}

enum SyncRequest_Kind { events, heartbeat, notSet }

class SyncRequest extends $pb.GeneratedMessage {
  factory SyncRequest({
    $core.List<$core.int>? events,
    Heartbeat? heartbeat,
  }) {
    final result = create();
    if (events != null) result.events = events;
    if (heartbeat != null) result.heartbeat = heartbeat;
    return result;
  }

  SyncRequest._();

  factory SyncRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SyncRequest_Kind> _SyncRequest_KindByTag = {
    1: SyncRequest_Kind.events,
    2: SyncRequest_Kind.heartbeat,
    0: SyncRequest_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'events', $pb.PbFieldType.OY)
    ..aOM<Heartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: Heartbeat.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncRequest copyWith(void Function(SyncRequest) updates) =>
      super.copyWith((message) => updates(message as SyncRequest))
          as SyncRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncRequest create() => SyncRequest._();
  @$core.override
  SyncRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncRequest>(create);
  static SyncRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  SyncRequest_Kind whichKind() => _SyncRequest_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearKind() => $_clearField($_whichOneof(0));

  /// zstd-compressed EventBatch: the outbox, oldest first. Idempotent by
  /// seq — events the server already holds are skipped.
  @$pb.TagNumber(1)
  $core.List<$core.int> get events => $_getN(0);
  @$pb.TagNumber(1)
  set events($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEvents() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvents() => $_clearField(1);

  /// Keeps the stream (and the proxies on the way) awake; answered by an
  /// ack, so a dead link shows within a heartbeat.
  @$pb.TagNumber(2)
  Heartbeat get heartbeat => $_getN(1);
  @$pb.TagNumber(2)
  set heartbeat(Heartbeat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);
  @$pb.TagNumber(2)
  Heartbeat ensureHeartbeat() => $_ensure(1);
}

class Heartbeat extends $pb.GeneratedMessage {
  factory Heartbeat() => create();

  Heartbeat._();

  factory Heartbeat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Heartbeat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Heartbeat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat copyWith(void Function(Heartbeat) updates) =>
      super.copyWith((message) => updates(message as Heartbeat)) as Heartbeat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Heartbeat create() => Heartbeat._();
  @$core.override
  Heartbeat createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Heartbeat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Heartbeat>(create);
  static Heartbeat? _defaultInstance;
}

enum SyncResponse_Kind { head, session, joinRequests, library, notSet }

class SyncResponse extends $pb.GeneratedMessage {
  factory SyncResponse({
    $fixnum.Int64? head,
    $3.GetCurrentSessionResponse? session,
    $3.GetJoinRequestsResponse? joinRequests,
    $1.ListTemplateLibraryResponse? library,
  }) {
    final result = create();
    if (head != null) result.head = head;
    if (session != null) result.session = session;
    if (joinRequests != null) result.joinRequests = joinRequests;
    if (library != null) result.library = library;
    return result;
  }

  SyncResponse._();

  factory SyncResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, SyncResponse_Kind> _SyncResponse_KindByTag =
      {
    1: SyncResponse_Kind.head,
    2: SyncResponse_Kind.session,
    3: SyncResponse_Kind.joinRequests,
    4: SyncResponse_Kind.library,
    0: SyncResponse_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4])
    ..aInt64(1, _omitFieldNames ? '' : 'head')
    ..aOM<$3.GetCurrentSessionResponse>(2, _omitFieldNames ? '' : 'session',
        subBuilder: $3.GetCurrentSessionResponse.create)
    ..aOM<$3.GetJoinRequestsResponse>(3, _omitFieldNames ? '' : 'joinRequests',
        subBuilder: $3.GetJoinRequestsResponse.create)
    ..aOM<$1.ListTemplateLibraryResponse>(4, _omitFieldNames ? '' : 'library',
        subBuilder: $1.ListTemplateLibraryResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncResponse copyWith(void Function(SyncResponse) updates) =>
      super.copyWith((message) => updates(message as SyncResponse))
          as SyncResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncResponse create() => SyncResponse._();
  @$core.override
  SyncResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncResponse>(create);
  static SyncResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  SyncResponse_Kind whichKind() => _SyncResponse_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearKind() => $_clearField($_whichOneof(0));

  /// The last seq the server holds for this account.
  @$pb.TagNumber(1)
  $fixnum.Int64 get head => $_getI64(0);
  @$pb.TagNumber(1)
  set head($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHead() => $_has(0);
  @$pb.TagNumber(1)
  void clearHead() => $_clearField(1);

  /// The caller's session, whole: who's in it and where each is up to.
  /// Empty session_id when not in one. Sent on connect and on every change.
  @$pb.TagNumber(2)
  $3.GetCurrentSessionResponse get session => $_getN(1);
  @$pb.TagNumber(2)
  set session($3.GetCurrentSessionResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSession() => $_has(1);
  @$pb.TagNumber(2)
  void clearSession() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.GetCurrentSessionResponse ensureSession() => $_ensure(1);

  /// Requests to join the caller, whole. Sent on connect and on every change.
  @$pb.TagNumber(3)
  $3.GetJoinRequestsResponse get joinRequests => $_getN(2);
  @$pb.TagNumber(3)
  set joinRequests($3.GetJoinRequestsResponse value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasJoinRequests() => $_has(2);
  @$pb.TagNumber(3)
  void clearJoinRequests() => $_clearField(3);
  @$pb.TagNumber(3)
  $3.GetJoinRequestsResponse ensureJoinRequests() => $_ensure(2);

  /// The template library as the server has it: what coupled templates
  /// follow. Sent on connect.
  @$pb.TagNumber(4)
  $1.ListTemplateLibraryResponse get library => $_getN(3);
  @$pb.TagNumber(4)
  set library($1.ListTemplateLibraryResponse value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLibrary() => $_has(3);
  @$pb.TagNumber(4)
  void clearLibrary() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.ListTemplateLibraryResponse ensureLibrary() => $_ensure(3);
}

class PullEventsRequest extends $pb.GeneratedMessage {
  factory PullEventsRequest({
    $fixnum.Int64? afterSeq,
  }) {
    final result = create();
    if (afterSeq != null) result.afterSeq = afterSeq;
    return result;
  }

  PullEventsRequest._();

  factory PullEventsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PullEventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullEventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'afterSeq')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsRequest copyWith(void Function(PullEventsRequest) updates) =>
      super.copyWith((message) => updates(message as PullEventsRequest))
          as PullEventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullEventsRequest create() => PullEventsRequest._();
  @$core.override
  PullEventsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PullEventsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullEventsRequest>(create);
  static PullEventsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get afterSeq => $_getI64(0);
  @$pb.TagNumber(1)
  set afterSeq($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAfterSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearAfterSeq() => $_clearField(1);
}

class PullEventsResponse extends $pb.GeneratedMessage {
  factory PullEventsResponse({
    $core.List<$core.int>? events,
  }) {
    final result = create();
    if (events != null) result.events = events;
    return result;
  }

  PullEventsResponse._();

  factory PullEventsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PullEventsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullEventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'events', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullEventsResponse copyWith(void Function(PullEventsResponse) updates) =>
      super.copyWith((message) => updates(message as PullEventsResponse))
          as PullEventsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullEventsResponse create() => PullEventsResponse._();
  @$core.override
  PullEventsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PullEventsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullEventsResponse>(create);
  static PullEventsResponse? _defaultInstance;

  /// zstd-compressed EventBatch.
  @$pb.TagNumber(1)
  $core.List<$core.int> get events => $_getN(0);
  @$pb.TagNumber(1)
  set events($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEvents() => $_has(0);
  @$pb.TagNumber(1)
  void clearEvents() => $_clearField(1);
}

class EventBatch extends $pb.GeneratedMessage {
  factory EventBatch({
    $core.Iterable<Event>? events,
  }) {
    final result = create();
    if (events != null) result.events.addAll(events);
    return result;
  }

  EventBatch._();

  factory EventBatch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EventBatch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventBatch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<Event>(1, _omitFieldNames ? '' : 'events', subBuilder: Event.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventBatch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventBatch copyWith(void Function(EventBatch) updates) =>
      super.copyWith((message) => updates(message as EventBatch)) as EventBatch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EventBatch create() => EventBatch._();
  @$core.override
  EventBatch createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EventBatch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EventBatch>(create);
  static EventBatch? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Event> get events => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
