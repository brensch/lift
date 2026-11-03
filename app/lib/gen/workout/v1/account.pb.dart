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

import 'group.pb.dart' as $2;
import 'workout.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

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

enum SyncRequest_Kind { heartbeat, afterSeq, events, notSet }

class SyncRequest extends $pb.GeneratedMessage {
  factory SyncRequest({
    Heartbeat? heartbeat,
    $fixnum.Int64? afterSeq,
    $core.List<$core.int>? events,
  }) {
    final result = create();
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (afterSeq != null) result.afterSeq = afterSeq;
    if (events != null) result.events = events;
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
    2: SyncRequest_Kind.heartbeat,
    3: SyncRequest_Kind.afterSeq,
    4: SyncRequest_Kind.events,
    0: SyncRequest_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4])
    ..aOM<Heartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: Heartbeat.create)
    ..aInt64(3, _omitFieldNames ? '' : 'afterSeq')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'events', $pb.PbFieldType.OY)
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

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  SyncRequest_Kind whichKind() => _SyncRequest_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearKind() => $_clearField($_whichOneof(0));

  /// Keeps the stream (and the proxies on the way) awake; answered with the
  /// head, so a dead link shows within a heartbeat.
  @$pb.TagNumber(2)
  Heartbeat get heartbeat => $_getN(0);
  @$pb.TagNumber(2)
  set heartbeat(Heartbeat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(0);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);
  @$pb.TagNumber(2)
  Heartbeat ensureHeartbeat() => $_ensure(0);

  /// First, and only first: the last seq the device holds, 0 for none.
  @$pb.TagNumber(3)
  $fixnum.Int64 get afterSeq => $_getI64(1);
  @$pb.TagNumber(3)
  set afterSeq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(3)
  $core.bool hasAfterSeq() => $_has(1);
  @$pb.TagNumber(3)
  void clearAfterSeq() => $_clearField(3);

  /// The device's own events not yet given a place, oldest first: a
  /// zstd-compressed JSON array.
  @$pb.TagNumber(4)
  $core.List<$core.int> get events => $_getN(2);
  @$pb.TagNumber(4)
  set events($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(4)
  $core.bool hasEvents() => $_has(2);
  @$pb.TagNumber(4)
  void clearEvents() => $_clearField(4);
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

enum SyncResponse_Kind { head, session, joinRequests, library, events, notSet }

class SyncResponse extends $pb.GeneratedMessage {
  factory SyncResponse({
    $fixnum.Int64? head,
    $2.GetCurrentSessionResponse? session,
    $2.GetJoinRequestsResponse? joinRequests,
    $1.ListTemplateLibraryResponse? library,
    Events? events,
  }) {
    final result = create();
    if (head != null) result.head = head;
    if (session != null) result.session = session;
    if (joinRequests != null) result.joinRequests = joinRequests;
    if (library != null) result.library = library;
    if (events != null) result.events = events;
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
    5: SyncResponse_Kind.events,
    0: SyncResponse_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5])
    ..aInt64(1, _omitFieldNames ? '' : 'head')
    ..aOM<$2.GetCurrentSessionResponse>(2, _omitFieldNames ? '' : 'session',
        subBuilder: $2.GetCurrentSessionResponse.create)
    ..aOM<$2.GetJoinRequestsResponse>(3, _omitFieldNames ? '' : 'joinRequests',
        subBuilder: $2.GetJoinRequestsResponse.create)
    ..aOM<$1.ListTemplateLibraryResponse>(4, _omitFieldNames ? '' : 'library',
        subBuilder: $1.ListTemplateLibraryResponse.create)
    ..aOM<Events>(5, _omitFieldNames ? '' : 'events', subBuilder: Events.create)
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
  @$pb.TagNumber(5)
  SyncResponse_Kind whichKind() => _SyncResponse_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearKind() => $_clearField($_whichOneof(0));

  /// The last seq the server holds: the answer to a heartbeat.
  @$pb.TagNumber(1)
  $fixnum.Int64 get head => $_getI64(0);
  @$pb.TagNumber(1)
  set head($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHead() => $_has(0);
  @$pb.TagNumber(1)
  void clearHead() => $_clearField(1);

  /// The caller's session, whole: who's in it and where each is up to.
  /// Empty session_id when not in one.
  @$pb.TagNumber(2)
  $2.GetCurrentSessionResponse get session => $_getN(1);
  @$pb.TagNumber(2)
  set session($2.GetCurrentSessionResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSession() => $_has(1);
  @$pb.TagNumber(2)
  void clearSession() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.GetCurrentSessionResponse ensureSession() => $_ensure(1);

  /// Requests to join the caller, whole.
  @$pb.TagNumber(3)
  $2.GetJoinRequestsResponse get joinRequests => $_getN(2);
  @$pb.TagNumber(3)
  set joinRequests($2.GetJoinRequestsResponse value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasJoinRequests() => $_has(2);
  @$pb.TagNumber(3)
  void clearJoinRequests() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.GetJoinRequestsResponse ensureJoinRequests() => $_ensure(2);

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

  /// Events in the server's order, each with its seq.
  @$pb.TagNumber(5)
  Events get events => $_getN(4);
  @$pb.TagNumber(5)
  set events(Events value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEvents() => $_has(4);
  @$pb.TagNumber(5)
  void clearEvents() => $_clearField(5);
  @$pb.TagNumber(5)
  Events ensureEvents() => $_ensure(4);
}

class Events extends $pb.GeneratedMessage {
  factory Events({
    $core.List<$core.int>? packed,
    $fixnum.Int64? head,
  }) {
    final result = create();
    if (packed != null) result.packed = packed;
    if (head != null) result.head = head;
    return result;
  }

  Events._();

  factory Events.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Events.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Events',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'packed', $pb.PbFieldType.OY)
    ..aInt64(2, _omitFieldNames ? '' : 'head')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Events clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Events copyWith(void Function(Events) updates) =>
      super.copyWith((message) => updates(message as Events)) as Events;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Events create() => Events._();
  @$core.override
  Events createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Events getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Events>(create);
  static Events? _defaultInstance;

  /// A zstd-compressed JSON array.
  @$pb.TagNumber(1)
  $core.List<$core.int> get packed => $_getN(0);
  @$pb.TagNumber(1)
  set packed($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPacked() => $_has(0);
  @$pb.TagNumber(1)
  void clearPacked() => $_clearField(1);

  /// The last seq the server holds: a device that has it has caught up.
  @$pb.TagNumber(2)
  $fixnum.Int64 get head => $_getI64(1);
  @$pb.TagNumber(2)
  set head($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHead() => $_has(1);
  @$pb.TagNumber(2)
  void clearHead() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
