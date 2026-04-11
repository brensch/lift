// This is a generated file - do not edit.
//
// Generated from workout/v1/group.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'workout.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class JoinUserRequest extends $pb.GeneratedMessage {
  factory JoinUserRequest({
    $core.String? userId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    return result;
  }

  JoinUserRequest._();

  factory JoinUserRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinUserRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinUserRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinUserRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinUserRequest copyWith(void Function(JoinUserRequest) updates) =>
      super.copyWith((message) => updates(message as JoinUserRequest))
          as JoinUserRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinUserRequest create() => JoinUserRequest._();
  @$core.override
  JoinUserRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinUserRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinUserRequest>(create);
  static JoinUserRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);
}

class JoinUserResponse extends $pb.GeneratedMessage {
  factory JoinUserResponse({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  JoinUserResponse._();

  factory JoinUserResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinUserResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinUserResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinUserResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinUserResponse copyWith(void Function(JoinUserResponse) updates) =>
      super.copyWith((message) => updates(message as JoinUserResponse))
          as JoinUserResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinUserResponse create() => JoinUserResponse._();
  @$core.override
  JoinUserResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinUserResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinUserResponse>(create);
  static JoinUserResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class LeaveSessionRequest extends $pb.GeneratedMessage {
  factory LeaveSessionRequest() => create();

  LeaveSessionRequest._();

  factory LeaveSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveSessionRequest copyWith(void Function(LeaveSessionRequest) updates) =>
      super.copyWith((message) => updates(message as LeaveSessionRequest))
          as LeaveSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveSessionRequest create() => LeaveSessionRequest._();
  @$core.override
  LeaveSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveSessionRequest>(create);
  static LeaveSessionRequest? _defaultInstance;
}

class LeaveSessionResponse extends $pb.GeneratedMessage {
  factory LeaveSessionResponse() => create();

  LeaveSessionResponse._();

  factory LeaveSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveSessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveSessionResponse copyWith(void Function(LeaveSessionResponse) updates) =>
      super.copyWith((message) => updates(message as LeaveSessionResponse))
          as LeaveSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveSessionResponse create() => LeaveSessionResponse._();
  @$core.override
  LeaveSessionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveSessionResponse>(create);
  static LeaveSessionResponse? _defaultInstance;
}

class GetParticipantWorkoutRequest extends $pb.GeneratedMessage {
  factory GetParticipantWorkoutRequest({
    $core.String? userId,
    $core.String? workoutId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (workoutId != null) result.workoutId = workoutId;
    return result;
  }

  GetParticipantWorkoutRequest._();

  factory GetParticipantWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetParticipantWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetParticipantWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'workoutId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetParticipantWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetParticipantWorkoutRequest copyWith(
          void Function(GetParticipantWorkoutRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetParticipantWorkoutRequest))
          as GetParticipantWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetParticipantWorkoutRequest create() =>
      GetParticipantWorkoutRequest._();
  @$core.override
  GetParticipantWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetParticipantWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetParticipantWorkoutRequest>(create);
  static GetParticipantWorkoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set workoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkoutId() => $_clearField(2);
}

class GetCurrentSessionRequest extends $pb.GeneratedMessage {
  factory GetCurrentSessionRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  GetCurrentSessionRequest._();

  factory GetCurrentSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetCurrentSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCurrentSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCurrentSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCurrentSessionRequest copyWith(
          void Function(GetCurrentSessionRequest) updates) =>
      super.copyWith((message) => updates(message as GetCurrentSessionRequest))
          as GetCurrentSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetCurrentSessionRequest create() => GetCurrentSessionRequest._();
  @$core.override
  GetCurrentSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetCurrentSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCurrentSessionRequest>(create);
  static GetCurrentSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class GetCurrentSessionResponse extends $pb.GeneratedMessage {
  factory GetCurrentSessionResponse({
    $core.String? sessionId,
    SessionStatus? sessionStatus,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (sessionStatus != null) result.sessionStatus = sessionStatus;
    return result;
  }

  GetCurrentSessionResponse._();

  factory GetCurrentSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetCurrentSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCurrentSessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOM<SessionStatus>(2, _omitFieldNames ? '' : 'sessionStatus',
        subBuilder: SessionStatus.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCurrentSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCurrentSessionResponse copyWith(
          void Function(GetCurrentSessionResponse) updates) =>
      super.copyWith((message) => updates(message as GetCurrentSessionResponse))
          as GetCurrentSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetCurrentSessionResponse create() => GetCurrentSessionResponse._();
  @$core.override
  GetCurrentSessionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetCurrentSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCurrentSessionResponse>(create);
  static GetCurrentSessionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  SessionStatus get sessionStatus => $_getN(1);
  @$pb.TagNumber(2)
  set sessionStatus(SessionStatus value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionStatus() => $_clearField(2);
  @$pb.TagNumber(2)
  SessionStatus ensureSessionStatus() => $_ensure(1);
}

class SubscribeSessionRequest extends $pb.GeneratedMessage {
  factory SubscribeSessionRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  SubscribeSessionRequest._();

  factory SubscribeSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubscribeSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubscribeSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubscribeSessionRequest copyWith(
          void Function(SubscribeSessionRequest) updates) =>
      super.copyWith((message) => updates(message as SubscribeSessionRequest))
          as SubscribeSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeSessionRequest create() => SubscribeSessionRequest._();
  @$core.override
  SubscribeSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubscribeSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubscribeSessionRequest>(create);
  static SubscribeSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class SessionSubscriptionEvent extends $pb.GeneratedMessage {
  factory SessionSubscriptionEvent({
    $core.String? sessionId,
    $fixnum.Int64? version,
    SessionStatus? sessionStatus,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (version != null) result.version = version;
    if (sessionStatus != null) result.sessionStatus = sessionStatus;
    return result;
  }

  SessionSubscriptionEvent._();

  factory SessionSubscriptionEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionSubscriptionEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionSubscriptionEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(2, _omitFieldNames ? '' : 'version')
    ..aOM<SessionStatus>(3, _omitFieldNames ? '' : 'sessionStatus',
        subBuilder: SessionStatus.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionSubscriptionEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionSubscriptionEvent copyWith(
          void Function(SessionSubscriptionEvent) updates) =>
      super.copyWith((message) => updates(message as SessionSubscriptionEvent))
          as SessionSubscriptionEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionSubscriptionEvent create() => SessionSubscriptionEvent._();
  @$core.override
  SessionSubscriptionEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionSubscriptionEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionSubscriptionEvent>(create);
  static SessionSubscriptionEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get version => $_getI64(1);
  @$pb.TagNumber(2)
  set version($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  SessionStatus get sessionStatus => $_getN(2);
  @$pb.TagNumber(3)
  set sessionStatus(SessionStatus value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionStatus() => $_clearField(3);
  @$pb.TagNumber(3)
  SessionStatus ensureSessionStatus() => $_ensure(2);
}

class UpdateActiveWorkoutRequest extends $pb.GeneratedMessage {
  factory UpdateActiveWorkoutRequest({
    $core.String? workoutId,
  }) {
    final result = create();
    if (workoutId != null) result.workoutId = workoutId;
    return result;
  }

  UpdateActiveWorkoutRequest._();

  factory UpdateActiveWorkoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateActiveWorkoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateActiveWorkoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'workoutId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateActiveWorkoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateActiveWorkoutRequest copyWith(
          void Function(UpdateActiveWorkoutRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateActiveWorkoutRequest))
          as UpdateActiveWorkoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateActiveWorkoutRequest create() => UpdateActiveWorkoutRequest._();
  @$core.override
  UpdateActiveWorkoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateActiveWorkoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateActiveWorkoutRequest>(create);
  static UpdateActiveWorkoutRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get workoutId => $_getSZ(0);
  @$pb.TagNumber(1)
  set workoutId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWorkoutId() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorkoutId() => $_clearField(1);
}

class UpdateActiveWorkoutResponse extends $pb.GeneratedMessage {
  factory UpdateActiveWorkoutResponse() => create();

  UpdateActiveWorkoutResponse._();

  factory UpdateActiveWorkoutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateActiveWorkoutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateActiveWorkoutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateActiveWorkoutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateActiveWorkoutResponse copyWith(
          void Function(UpdateActiveWorkoutResponse) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateActiveWorkoutResponse))
          as UpdateActiveWorkoutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateActiveWorkoutResponse create() =>
      UpdateActiveWorkoutResponse._();
  @$core.override
  UpdateActiveWorkoutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateActiveWorkoutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateActiveWorkoutResponse>(create);
  static UpdateActiveWorkoutResponse? _defaultInstance;
}

class SessionStatus extends $pb.GeneratedMessage {
  factory SessionStatus({
    $core.String? sessionId,
    $core.Iterable<ParticipantStatus>? participants,
    $core.String? nextUpUserId,
    $1.ProposedSet? nextUpSet,
    $fixnum.Int64? nextUpRestUntil,
    $core.String? currentlyLiftingUserId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (participants != null) result.participants.addAll(participants);
    if (nextUpUserId != null) result.nextUpUserId = nextUpUserId;
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (nextUpRestUntil != null) result.nextUpRestUntil = nextUpRestUntil;
    if (currentlyLiftingUserId != null)
      result.currentlyLiftingUserId = currentlyLiftingUserId;
    return result;
  }

  SessionStatus._();

  factory SessionStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SessionStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SessionStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..pPM<ParticipantStatus>(2, _omitFieldNames ? '' : 'participants',
        subBuilder: ParticipantStatus.create)
    ..aOS(3, _omitFieldNames ? '' : 'nextUpUserId')
    ..aOM<$1.ProposedSet>(4, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: $1.ProposedSet.create)
    ..aInt64(5, _omitFieldNames ? '' : 'nextUpRestUntil')
    ..aOS(6, _omitFieldNames ? '' : 'currentlyLiftingUserId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SessionStatus copyWith(void Function(SessionStatus) updates) =>
      super.copyWith((message) => updates(message as SessionStatus))
          as SessionStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SessionStatus create() => SessionStatus._();
  @$core.override
  SessionStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SessionStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SessionStatus>(create);
  static SessionStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ParticipantStatus> get participants => $_getList(1);

  @$pb.TagNumber(3)
  $core.String get nextUpUserId => $_getSZ(2);
  @$pb.TagNumber(3)
  set nextUpUserId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNextUpUserId() => $_has(2);
  @$pb.TagNumber(3)
  void clearNextUpUserId() => $_clearField(3);

  @$pb.TagNumber(4)
  $1.ProposedSet get nextUpSet => $_getN(3);
  @$pb.TagNumber(4)
  set nextUpSet($1.ProposedSet value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasNextUpSet() => $_has(3);
  @$pb.TagNumber(4)
  void clearNextUpSet() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.ProposedSet ensureNextUpSet() => $_ensure(3);

  @$pb.TagNumber(5)
  $fixnum.Int64 get nextUpRestUntil => $_getI64(4);
  @$pb.TagNumber(5)
  set nextUpRestUntil($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNextUpRestUntil() => $_has(4);
  @$pb.TagNumber(5)
  void clearNextUpRestUntil() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get currentlyLiftingUserId => $_getSZ(5);
  @$pb.TagNumber(6)
  set currentlyLiftingUserId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrentlyLiftingUserId() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrentlyLiftingUserId() => $_clearField(6);
}

class ParticipantStatus extends $pb.GeneratedMessage {
  factory ParticipantStatus({
    $1.User? user,
    $core.String? activeWorkoutId,
    $1.Workout? activeWorkout,
    $core.Iterable<$1.ExerciseGroup>? exerciseGroups,
    $core.Iterable<$1.ProposedSet>? proposedSets,
    $core.Iterable<$1.CompletedSet>? completedSets,
    $1.ProposedSet? nextUpSet,
    $fixnum.Int64? restUntil,
    $core.bool? hasActiveSet,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (activeWorkoutId != null) result.activeWorkoutId = activeWorkoutId;
    if (activeWorkout != null) result.activeWorkout = activeWorkout;
    if (exerciseGroups != null) result.exerciseGroups.addAll(exerciseGroups);
    if (proposedSets != null) result.proposedSets.addAll(proposedSets);
    if (completedSets != null) result.completedSets.addAll(completedSets);
    if (nextUpSet != null) result.nextUpSet = nextUpSet;
    if (restUntil != null) result.restUntil = restUntil;
    if (hasActiveSet != null) result.hasActiveSet = hasActiveSet;
    return result;
  }

  ParticipantStatus._();

  factory ParticipantStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ParticipantStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ParticipantStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<$1.User>(1, _omitFieldNames ? '' : 'user', subBuilder: $1.User.create)
    ..aOS(2, _omitFieldNames ? '' : 'activeWorkoutId')
    ..aOM<$1.Workout>(3, _omitFieldNames ? '' : 'activeWorkout',
        subBuilder: $1.Workout.create)
    ..pPM<$1.ExerciseGroup>(4, _omitFieldNames ? '' : 'exerciseGroups',
        subBuilder: $1.ExerciseGroup.create)
    ..pPM<$1.ProposedSet>(5, _omitFieldNames ? '' : 'proposedSets',
        subBuilder: $1.ProposedSet.create)
    ..pPM<$1.CompletedSet>(6, _omitFieldNames ? '' : 'completedSets',
        subBuilder: $1.CompletedSet.create)
    ..aOM<$1.ProposedSet>(7, _omitFieldNames ? '' : 'nextUpSet',
        subBuilder: $1.ProposedSet.create)
    ..aInt64(8, _omitFieldNames ? '' : 'restUntil')
    ..aOB(9, _omitFieldNames ? '' : 'hasActiveSet')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParticipantStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ParticipantStatus copyWith(void Function(ParticipantStatus) updates) =>
      super.copyWith((message) => updates(message as ParticipantStatus))
          as ParticipantStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ParticipantStatus create() => ParticipantStatus._();
  @$core.override
  ParticipantStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ParticipantStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ParticipantStatus>(create);
  static ParticipantStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $1.User get user => $_getN(0);
  @$pb.TagNumber(1)
  set user($1.User value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.User ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get activeWorkoutId => $_getSZ(1);
  @$pb.TagNumber(2)
  set activeWorkoutId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveWorkoutId() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveWorkoutId() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.Workout get activeWorkout => $_getN(2);
  @$pb.TagNumber(3)
  set activeWorkout($1.Workout value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasActiveWorkout() => $_has(2);
  @$pb.TagNumber(3)
  void clearActiveWorkout() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Workout ensureActiveWorkout() => $_ensure(2);

  @$pb.TagNumber(4)
  $pb.PbList<$1.ExerciseGroup> get exerciseGroups => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$1.ProposedSet> get proposedSets => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$1.CompletedSet> get completedSets => $_getList(5);

  @$pb.TagNumber(7)
  $1.ProposedSet get nextUpSet => $_getN(6);
  @$pb.TagNumber(7)
  set nextUpSet($1.ProposedSet value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasNextUpSet() => $_has(6);
  @$pb.TagNumber(7)
  void clearNextUpSet() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.ProposedSet ensureNextUpSet() => $_ensure(6);

  @$pb.TagNumber(8)
  $fixnum.Int64 get restUntil => $_getI64(7);
  @$pb.TagNumber(8)
  set restUntil($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRestUntil() => $_has(7);
  @$pb.TagNumber(8)
  void clearRestUntil() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get hasActiveSet => $_getBF(8);
  @$pb.TagNumber(9)
  set hasActiveSet($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasHasActiveSet() => $_has(8);
  @$pb.TagNumber(9)
  void clearHasActiveSet() => $_clearField(9);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
