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

enum SyncRequest_Kind { heartbeat, afterSeq, events, open, notSet }

class SyncRequest extends $pb.GeneratedMessage {
  factory SyncRequest({
    Heartbeat? heartbeat,
    $fixnum.Int64? afterSeq,
    $core.List<$core.int>? events,
    SyncOpen? open,
  }) {
    final result = create();
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (afterSeq != null) result.afterSeq = afterSeq;
    if (events != null) result.events = events;
    if (open != null) result.open = open;
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
    5: SyncRequest_Kind.open,
    0: SyncRequest_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5])
    ..aOM<Heartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: Heartbeat.create)
    ..aInt64(3, _omitFieldNames ? '' : 'afterSeq')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'events', $pb.PbFieldType.OY)
    ..aOM<SyncOpen>(5, _omitFieldNames ? '' : 'open',
        subBuilder: SyncOpen.create)
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
  @$pb.TagNumber(5)
  SyncRequest_Kind whichKind() => _SyncRequest_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
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
  /// An app from before `open` sends this; it is sent events only.
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

  /// First, and only first: where the device is (see SyncOpen).
  @$pb.TagNumber(5)
  SyncOpen get open => $_getN(3);
  @$pb.TagNumber(5)
  set open(SyncOpen value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasOpen() => $_has(3);
  @$pb.TagNumber(5)
  void clearOpen() => $_clearField(5);
  @$pb.TagNumber(5)
  SyncOpen ensureOpen() => $_ensure(3);
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

/// How a device opens its stream: the last seq it holds, the rules it folds
/// by, and the events it has waiting to be placed. The server sends what
/// costs least to make it current: nothing, the events it lacks, or (far
/// behind, new, or on rules the server's snapshot is by) the account whole
/// (`AccountState`), then events from there.
class SyncOpen extends $pb.GeneratedMessage {
  factory SyncOpen({
    $fixnum.Int64? afterSeq,
    $core.String? fold,
    $core.Iterable<$core.String>? pendingIds,
    $core.String? lastId,
  }) {
    final result = create();
    if (afterSeq != null) result.afterSeq = afterSeq;
    if (fold != null) result.fold = fold;
    if (pendingIds != null) result.pendingIds.addAll(pendingIds);
    if (lastId != null) result.lastId = lastId;
    return result;
  }

  SyncOpen._();

  factory SyncOpen.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncOpen.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncOpen',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'afterSeq')
    ..aOS(2, _omitFieldNames ? '' : 'fold')
    ..pPS(3, _omitFieldNames ? '' : 'pendingIds')
    ..aOS(4, _omitFieldNames ? '' : 'lastId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncOpen clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncOpen copyWith(void Function(SyncOpen) updates) =>
      super.copyWith((message) => updates(message as SyncOpen)) as SyncOpen;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncOpen create() => SyncOpen._();
  @$core.override
  SyncOpen createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncOpen getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncOpen>(create);
  static SyncOpen? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get afterSeq => $_getI64(0);
  @$pb.TagNumber(1)
  set afterSeq($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAfterSeq() => $_has(0);
  @$pb.TagNumber(1)
  void clearAfterSeq() => $_clearField(1);

  /// schlift_core::FOLD: a snapshot is only sent to a device folding by the
  /// same rules; one on others is sent events and folds them itself.
  @$pb.TagNumber(2)
  $core.String get fold => $_getSZ(1);
  @$pb.TagNumber(2)
  set fold($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFold() => $_has(1);
  @$pb.TagNumber(2)
  void clearFold() => $_clearField(2);

  /// The device's events not yet heard back placed, by id: of these, the
  /// ones the server holds by the snapshot it sends are named in it, so the
  /// device lets them go instead of folding them again on top.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get pendingIds => $_getList(2);

  /// The id of the event at after_seq: a server that holds another there
  /// (restored from an older backup, and placed others since) sends the
  /// account whole, so the device doesn't fold the server's events onto a
  /// history that parted from it.
  @$pb.TagNumber(4)
  $core.String get lastId => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastId() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastId() => $_clearField(4);
}

enum SyncResponse_Kind {
  head,
  joinRequests,
  events,
  session,
  partnerEvents,
  account,
  notSet
}

class SyncResponse extends $pb.GeneratedMessage {
  factory SyncResponse({
    $fixnum.Int64? head,
    $2.GetJoinRequestsResponse? joinRequests,
    Events? events,
    $2.Session? session,
    PartnerEvents? partnerEvents,
    AccountState? account,
  }) {
    final result = create();
    if (head != null) result.head = head;
    if (joinRequests != null) result.joinRequests = joinRequests;
    if (events != null) result.events = events;
    if (session != null) result.session = session;
    if (partnerEvents != null) result.partnerEvents = partnerEvents;
    if (account != null) result.account = account;
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
    3: SyncResponse_Kind.joinRequests,
    5: SyncResponse_Kind.events,
    6: SyncResponse_Kind.session,
    7: SyncResponse_Kind.partnerEvents,
    8: SyncResponse_Kind.account,
    0: SyncResponse_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 3, 5, 6, 7, 8])
    ..aInt64(1, _omitFieldNames ? '' : 'head')
    ..aOM<$2.GetJoinRequestsResponse>(3, _omitFieldNames ? '' : 'joinRequests',
        subBuilder: $2.GetJoinRequestsResponse.create)
    ..aOM<Events>(5, _omitFieldNames ? '' : 'events', subBuilder: Events.create)
    ..aOM<$2.Session>(6, _omitFieldNames ? '' : 'session',
        subBuilder: $2.Session.create)
    ..aOM<PartnerEvents>(7, _omitFieldNames ? '' : 'partnerEvents',
        subBuilder: PartnerEvents.create)
    ..aOM<AccountState>(8, _omitFieldNames ? '' : 'account',
        subBuilder: AccountState.create)
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
  @$pb.TagNumber(3)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  SyncResponse_Kind whichKind() => _SyncResponse_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(3)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
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

  /// Requests to join the caller, whole.
  @$pb.TagNumber(3)
  $2.GetJoinRequestsResponse get joinRequests => $_getN(1);
  @$pb.TagNumber(3)
  set joinRequests($2.GetJoinRequestsResponse value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasJoinRequests() => $_has(1);
  @$pb.TagNumber(3)
  void clearJoinRequests() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.GetJoinRequestsResponse ensureJoinRequests() => $_ensure(1);

  /// Events in the server's order, each with its seq.
  @$pb.TagNumber(5)
  Events get events => $_getN(2);
  @$pb.TagNumber(5)
  set events(Events value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEvents() => $_has(2);
  @$pb.TagNumber(5)
  void clearEvents() => $_clearField(5);
  @$pb.TagNumber(5)
  Events ensureEvents() => $_ensure(2);

  /// The caller's session, whole: who else is in it. Empty session_id
  /// when not in one.
  @$pb.TagNumber(6)
  $2.Session get session => $_getN(3);
  @$pb.TagNumber(6)
  set session($2.Session value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasSession() => $_has(3);
  @$pb.TagNumber(6)
  void clearSession() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Session ensureSession() => $_ensure(3);

  /// A session partner's workout, as events.
  @$pb.TagNumber(7)
  PartnerEvents get partnerEvents => $_getN(4);
  @$pb.TagNumber(7)
  set partnerEvents(PartnerEvents value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPartnerEvents() => $_has(4);
  @$pb.TagNumber(7)
  void clearPartnerEvents() => $_clearField(7);
  @$pb.TagNumber(7)
  PartnerEvents ensurePartnerEvents() => $_ensure(4);

  /// The account whole, folded by the server as of a seq: sent on opening
  /// to a device far behind or new (see SyncOpen), before any events.
  @$pb.TagNumber(8)
  AccountState get account => $_getN(5);
  @$pb.TagNumber(8)
  set account(AccountState value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasAccount() => $_has(5);
  @$pb.TagNumber(8)
  void clearAccount() => $_clearField(8);
  @$pb.TagNumber(8)
  AccountState ensureAccount() => $_ensure(5);
}

class PartnerEvents extends $pb.GeneratedMessage {
  factory PartnerEvents({
    $core.String? userId,
    $core.List<$core.int>? packed,
    $core.bool? whole,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (packed != null) result.packed = packed;
    if (whole != null) result.whole = whole;
    return result;
  }

  PartnerEvents._();

  factory PartnerEvents.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PartnerEvents.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PartnerEvents',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'packed', $pb.PbFieldType.OY)
    ..aOB(3, _omitFieldNames ? '' : 'whole')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartnerEvents clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartnerEvents copyWith(void Function(PartnerEvents) updates) =>
      super.copyWith((message) => updates(message as PartnerEvents))
          as PartnerEvents;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PartnerEvents create() => PartnerEvents._();
  @$core.override
  PartnerEvents createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PartnerEvents getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PartnerEvents>(create);
  static PartnerEvents? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  /// A zstd-compressed JSON array of the events of their workout: its start,
  /// its sets, its end. Never their heart rate, templates or anything else.
  @$pb.TagNumber(2)
  $core.List<$core.int> get packed => $_getN(1);
  @$pb.TagNumber(2)
  set packed($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPacked() => $_has(1);
  @$pb.TagNumber(2)
  void clearPacked() => $_clearField(2);

  /// Their workout so far, replacing whatever came before; otherwise more of
  /// it, as they record it.
  @$pb.TagNumber(3)
  $core.bool get whole => $_getBF(2);
  @$pb.TagNumber(3)
  set whole($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWhole() => $_has(2);
  @$pb.TagNumber(3)
  void clearWhole() => $_clearField(3);
}

class AccountState extends $pb.GeneratedMessage {
  factory AccountState({
    $core.List<$core.int>? snapshot,
    $fixnum.Int64? seq,
    $core.Iterable<$core.String>? placedIds,
    $core.String? lastId,
  }) {
    final result = create();
    if (snapshot != null) result.snapshot = snapshot;
    if (seq != null) result.seq = seq;
    if (placedIds != null) result.placedIds.addAll(placedIds);
    if (lastId != null) result.lastId = lastId;
    return result;
  }

  AccountState._();

  factory AccountState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AccountState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccountState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'snapshot', $pb.PbFieldType.OY)
    ..aInt64(2, _omitFieldNames ? '' : 'seq')
    ..pPS(3, _omitFieldNames ? '' : 'placedIds')
    ..aOS(4, _omitFieldNames ? '' : 'lastId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountState copyWith(void Function(AccountState) updates) =>
      super.copyWith((message) => updates(message as AccountState))
          as AccountState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AccountState create() => AccountState._();
  @$core.override
  AccountState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AccountState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AccountState>(create);
  static AccountState? _defaultInstance;

  /// schlift_core::snapshot: an AccountSnapshot, zstd compressed, without
  /// heart rate.
  @$pb.TagNumber(1)
  $core.List<$core.int> get snapshot => $_getN(0);
  @$pb.TagNumber(1)
  set snapshot($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSnapshot() => $_has(0);
  @$pb.TagNumber(1)
  void clearSnapshot() => $_clearField(1);

  /// The last event folded into it: events after it follow.
  @$pb.TagNumber(2)
  $fixnum.Int64 get seq => $_getI64(1);
  @$pb.TagNumber(2)
  set seq($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeq() => $_clearField(2);

  /// Of the device's pending ids (SyncOpen), those in it already: placed
  /// before it was folded.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get placedIds => $_getList(2);

  /// The id of the event at seq: what the device opens with next time.
  @$pb.TagNumber(4)
  $core.String get lastId => $_getSZ(3);
  @$pb.TagNumber(4)
  set lastId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastId() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastId() => $_clearField(4);
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
