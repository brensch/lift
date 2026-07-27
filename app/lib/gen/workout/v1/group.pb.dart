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

class JoinViaInviteRequest extends $pb.GeneratedMessage {
  factory JoinViaInviteRequest({
    $core.String? inviteToken,
  }) {
    final result = create();
    if (inviteToken != null) result.inviteToken = inviteToken;
    return result;
  }

  JoinViaInviteRequest._();

  factory JoinViaInviteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinViaInviteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinViaInviteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'inviteToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinViaInviteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinViaInviteRequest copyWith(void Function(JoinViaInviteRequest) updates) =>
      super.copyWith((message) => updates(message as JoinViaInviteRequest))
          as JoinViaInviteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinViaInviteRequest create() => JoinViaInviteRequest._();
  @$core.override
  JoinViaInviteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinViaInviteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinViaInviteRequest>(create);
  static JoinViaInviteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get inviteToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set inviteToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInviteToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearInviteToken() => $_clearField(1);
}

class JoinViaInviteResponse extends $pb.GeneratedMessage {
  factory JoinViaInviteResponse({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  JoinViaInviteResponse._();

  factory JoinViaInviteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinViaInviteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinViaInviteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinViaInviteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinViaInviteResponse copyWith(
          void Function(JoinViaInviteResponse) updates) =>
      super.copyWith((message) => updates(message as JoinViaInviteResponse))
          as JoinViaInviteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinViaInviteResponse create() => JoinViaInviteResponse._();
  @$core.override
  JoinViaInviteResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinViaInviteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinViaInviteResponse>(create);
  static JoinViaInviteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class GetMyInviteTokenRequest extends $pb.GeneratedMessage {
  factory GetMyInviteTokenRequest() => create();

  GetMyInviteTokenRequest._();

  factory GetMyInviteTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMyInviteTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMyInviteTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMyInviteTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMyInviteTokenRequest copyWith(
          void Function(GetMyInviteTokenRequest) updates) =>
      super.copyWith((message) => updates(message as GetMyInviteTokenRequest))
          as GetMyInviteTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMyInviteTokenRequest create() => GetMyInviteTokenRequest._();
  @$core.override
  GetMyInviteTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMyInviteTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMyInviteTokenRequest>(create);
  static GetMyInviteTokenRequest? _defaultInstance;
}

class GetMyInviteTokenResponse extends $pb.GeneratedMessage {
  factory GetMyInviteTokenResponse({
    $core.String? inviteToken,
  }) {
    final result = create();
    if (inviteToken != null) result.inviteToken = inviteToken;
    return result;
  }

  GetMyInviteTokenResponse._();

  factory GetMyInviteTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetMyInviteTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMyInviteTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'inviteToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMyInviteTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMyInviteTokenResponse copyWith(
          void Function(GetMyInviteTokenResponse) updates) =>
      super.copyWith((message) => updates(message as GetMyInviteTokenResponse))
          as GetMyInviteTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetMyInviteTokenResponse create() => GetMyInviteTokenResponse._();
  @$core.override
  GetMyInviteTokenResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetMyInviteTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetMyInviteTokenResponse>(create);
  static GetMyInviteTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get inviteToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set inviteToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInviteToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearInviteToken() => $_clearField(1);
}

class RotateInviteTokenRequest extends $pb.GeneratedMessage {
  factory RotateInviteTokenRequest() => create();

  RotateInviteTokenRequest._();

  factory RotateInviteTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RotateInviteTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RotateInviteTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RotateInviteTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RotateInviteTokenRequest copyWith(
          void Function(RotateInviteTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RotateInviteTokenRequest))
          as RotateInviteTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RotateInviteTokenRequest create() => RotateInviteTokenRequest._();
  @$core.override
  RotateInviteTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RotateInviteTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RotateInviteTokenRequest>(create);
  static RotateInviteTokenRequest? _defaultInstance;
}

class RotateInviteTokenResponse extends $pb.GeneratedMessage {
  factory RotateInviteTokenResponse({
    $core.String? inviteToken,
  }) {
    final result = create();
    if (inviteToken != null) result.inviteToken = inviteToken;
    return result;
  }

  RotateInviteTokenResponse._();

  factory RotateInviteTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RotateInviteTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RotateInviteTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'inviteToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RotateInviteTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RotateInviteTokenResponse copyWith(
          void Function(RotateInviteTokenResponse) updates) =>
      super.copyWith((message) => updates(message as RotateInviteTokenResponse))
          as RotateInviteTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RotateInviteTokenResponse create() => RotateInviteTokenResponse._();
  @$core.override
  RotateInviteTokenResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RotateInviteTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RotateInviteTokenResponse>(create);
  static RotateInviteTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get inviteToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set inviteToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInviteToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearInviteToken() => $_clearField(1);
}

class LeaveCurrentSessionRequest extends $pb.GeneratedMessage {
  factory LeaveCurrentSessionRequest() => create();

  LeaveCurrentSessionRequest._();

  factory LeaveCurrentSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveCurrentSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveCurrentSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveCurrentSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveCurrentSessionRequest copyWith(
          void Function(LeaveCurrentSessionRequest) updates) =>
      super.copyWith(
              (message) => updates(message as LeaveCurrentSessionRequest))
          as LeaveCurrentSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveCurrentSessionRequest create() => LeaveCurrentSessionRequest._();
  @$core.override
  LeaveCurrentSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveCurrentSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveCurrentSessionRequest>(create);
  static LeaveCurrentSessionRequest? _defaultInstance;
}

class LeaveCurrentSessionResponse extends $pb.GeneratedMessage {
  factory LeaveCurrentSessionResponse() => create();

  LeaveCurrentSessionResponse._();

  factory LeaveCurrentSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LeaveCurrentSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LeaveCurrentSessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveCurrentSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LeaveCurrentSessionResponse copyWith(
          void Function(LeaveCurrentSessionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as LeaveCurrentSessionResponse))
          as LeaveCurrentSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveCurrentSessionResponse create() =>
      LeaveCurrentSessionResponse._();
  @$core.override
  LeaveCurrentSessionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LeaveCurrentSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LeaveCurrentSessionResponse>(create);
  static LeaveCurrentSessionResponse? _defaultInstance;
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
  factory GetCurrentSessionRequest() => create();

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
}

class GetSessionParticipantsRequest extends $pb.GeneratedMessage {
  factory GetSessionParticipantsRequest({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  GetSessionParticipantsRequest._();

  factory GetSessionParticipantsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSessionParticipantsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSessionParticipantsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionParticipantsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionParticipantsRequest copyWith(
          void Function(GetSessionParticipantsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetSessionParticipantsRequest))
          as GetSessionParticipantsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSessionParticipantsRequest create() =>
      GetSessionParticipantsRequest._();
  @$core.override
  GetSessionParticipantsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSessionParticipantsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSessionParticipantsRequest>(create);
  static GetSessionParticipantsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class GetSessionParticipantsResponse extends $pb.GeneratedMessage {
  factory GetSessionParticipantsResponse({
    $core.String? sessionId,
    $core.Iterable<ParticipantStatus>? participants,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (participants != null) result.participants.addAll(participants);
    return result;
  }

  GetSessionParticipantsResponse._();

  factory GetSessionParticipantsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSessionParticipantsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSessionParticipantsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..pPM<ParticipantStatus>(2, _omitFieldNames ? '' : 'participants',
        subBuilder: ParticipantStatus.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionParticipantsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSessionParticipantsResponse copyWith(
          void Function(GetSessionParticipantsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetSessionParticipantsResponse))
          as GetSessionParticipantsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSessionParticipantsResponse create() =>
      GetSessionParticipantsResponse._();
  @$core.override
  GetSessionParticipantsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSessionParticipantsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSessionParticipantsResponse>(create);
  static GetSessionParticipantsResponse? _defaultInstance;

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

/// Someone the caller has shared at least one session with.
class TrainingPartner extends $pb.GeneratedMessage {
  factory TrainingPartner({
    $1.User? user,
    $core.int? sessionsTogether,
    $fixnum.Int64? lastTrainedAt,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (sessionsTogether != null) result.sessionsTogether = sessionsTogether;
    if (lastTrainedAt != null) result.lastTrainedAt = lastTrainedAt;
    return result;
  }

  TrainingPartner._();

  factory TrainingPartner.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingPartner.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingPartner',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<$1.User>(1, _omitFieldNames ? '' : 'user', subBuilder: $1.User.create)
    ..aI(2, _omitFieldNames ? '' : 'sessionsTogether')
    ..aInt64(3, _omitFieldNames ? '' : 'lastTrainedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingPartner clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingPartner copyWith(void Function(TrainingPartner) updates) =>
      super.copyWith((message) => updates(message as TrainingPartner))
          as TrainingPartner;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingPartner create() => TrainingPartner._();
  @$core.override
  TrainingPartner createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingPartner getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingPartner>(create);
  static TrainingPartner? _defaultInstance;

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
  $core.int get sessionsTogether => $_getIZ(1);
  @$pb.TagNumber(2)
  set sessionsTogether($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionsTogether() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionsTogether() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lastTrainedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set lastTrainedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastTrainedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastTrainedAt() => $_clearField(3);
}

class GetTrainingPartnersRequest extends $pb.GeneratedMessage {
  factory GetTrainingPartnersRequest() => create();

  GetTrainingPartnersRequest._();

  factory GetTrainingPartnersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTrainingPartnersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTrainingPartnersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingPartnersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingPartnersRequest copyWith(
          void Function(GetTrainingPartnersRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetTrainingPartnersRequest))
          as GetTrainingPartnersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTrainingPartnersRequest create() => GetTrainingPartnersRequest._();
  @$core.override
  GetTrainingPartnersRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTrainingPartnersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTrainingPartnersRequest>(create);
  static GetTrainingPartnersRequest? _defaultInstance;
}

class GetTrainingPartnersResponse extends $pb.GeneratedMessage {
  factory GetTrainingPartnersResponse({
    $core.Iterable<TrainingPartner>? partners,
  }) {
    final result = create();
    if (partners != null) result.partners.addAll(partners);
    return result;
  }

  GetTrainingPartnersResponse._();

  factory GetTrainingPartnersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTrainingPartnersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTrainingPartnersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<TrainingPartner>(1, _omitFieldNames ? '' : 'partners',
        subBuilder: TrainingPartner.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingPartnersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingPartnersResponse copyWith(
          void Function(GetTrainingPartnersResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetTrainingPartnersResponse))
          as GetTrainingPartnersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTrainingPartnersResponse create() =>
      GetTrainingPartnersResponse._();
  @$core.override
  GetTrainingPartnersResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTrainingPartnersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTrainingPartnersResponse>(create);
  static GetTrainingPartnersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TrainingPartner> get partners => $_getList(0);
}

/// One session the caller and a partner were both in.
class SharedSession extends $pb.GeneratedMessage {
  factory SharedSession({
    $core.String? sessionId,
    $fixnum.Int64? trainedAt,
    $core.bool? callerWorkedOut,
    $core.bool? partnerWorkedOut,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (trainedAt != null) result.trainedAt = trainedAt;
    if (callerWorkedOut != null) result.callerWorkedOut = callerWorkedOut;
    if (partnerWorkedOut != null) result.partnerWorkedOut = partnerWorkedOut;
    return result;
  }

  SharedSession._();

  factory SharedSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SharedSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SharedSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aInt64(2, _omitFieldNames ? '' : 'trainedAt')
    ..aOB(3, _omitFieldNames ? '' : 'callerWorkedOut')
    ..aOB(4, _omitFieldNames ? '' : 'partnerWorkedOut')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SharedSession copyWith(void Function(SharedSession) updates) =>
      super.copyWith((message) => updates(message as SharedSession))
          as SharedSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SharedSession create() => SharedSession._();
  @$core.override
  SharedSession createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SharedSession getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SharedSession>(create);
  static SharedSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get trainedAt => $_getI64(1);
  @$pb.TagNumber(2)
  set trainedAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTrainedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrainedAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get callerWorkedOut => $_getBF(2);
  @$pb.TagNumber(3)
  set callerWorkedOut($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCallerWorkedOut() => $_has(2);
  @$pb.TagNumber(3)
  void clearCallerWorkedOut() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get partnerWorkedOut => $_getBF(3);
  @$pb.TagNumber(4)
  set partnerWorkedOut($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPartnerWorkedOut() => $_has(3);
  @$pb.TagNumber(4)
  void clearPartnerWorkedOut() => $_clearField(4);
}

class GetSharedSessionsRequest extends $pb.GeneratedMessage {
  factory GetSharedSessionsRequest({
    $core.String? partnerUserId,
  }) {
    final result = create();
    if (partnerUserId != null) result.partnerUserId = partnerUserId;
    return result;
  }

  GetSharedSessionsRequest._();

  factory GetSharedSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSharedSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSharedSessionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'partnerUserId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedSessionsRequest copyWith(
          void Function(GetSharedSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as GetSharedSessionsRequest))
          as GetSharedSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSharedSessionsRequest create() => GetSharedSessionsRequest._();
  @$core.override
  GetSharedSessionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSharedSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSharedSessionsRequest>(create);
  static GetSharedSessionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get partnerUserId => $_getSZ(0);
  @$pb.TagNumber(1)
  set partnerUserId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPartnerUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPartnerUserId() => $_clearField(1);
}

class GetSharedSessionsResponse extends $pb.GeneratedMessage {
  factory GetSharedSessionsResponse({
    $core.Iterable<SharedSession>? sessions,
  }) {
    final result = create();
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  GetSharedSessionsResponse._();

  factory GetSharedSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSharedSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSharedSessionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<SharedSession>(1, _omitFieldNames ? '' : 'sessions',
        subBuilder: SharedSession.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSharedSessionsResponse copyWith(
          void Function(GetSharedSessionsResponse) updates) =>
      super.copyWith((message) => updates(message as GetSharedSessionsResponse))
          as GetSharedSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSharedSessionsResponse create() => GetSharedSessionsResponse._();
  @$core.override
  GetSharedSessionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSharedSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSharedSessionsResponse>(create);
  static GetSharedSessionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SharedSession> get sessions => $_getList(0);
}

class JoinPartnerSessionRequest extends $pb.GeneratedMessage {
  factory JoinPartnerSessionRequest({
    $core.String? partnerUserId,
  }) {
    final result = create();
    if (partnerUserId != null) result.partnerUserId = partnerUserId;
    return result;
  }

  JoinPartnerSessionRequest._();

  factory JoinPartnerSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinPartnerSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinPartnerSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'partnerUserId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinPartnerSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinPartnerSessionRequest copyWith(
          void Function(JoinPartnerSessionRequest) updates) =>
      super.copyWith((message) => updates(message as JoinPartnerSessionRequest))
          as JoinPartnerSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinPartnerSessionRequest create() => JoinPartnerSessionRequest._();
  @$core.override
  JoinPartnerSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinPartnerSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinPartnerSessionRequest>(create);
  static JoinPartnerSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get partnerUserId => $_getSZ(0);
  @$pb.TagNumber(1)
  set partnerUserId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPartnerUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPartnerUserId() => $_clearField(1);
}

class JoinPartnerSessionResponse extends $pb.GeneratedMessage {
  factory JoinPartnerSessionResponse({
    $core.String? sessionId,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  JoinPartnerSessionResponse._();

  factory JoinPartnerSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory JoinPartnerSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JoinPartnerSessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinPartnerSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JoinPartnerSessionResponse copyWith(
          void Function(JoinPartnerSessionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as JoinPartnerSessionResponse))
          as JoinPartnerSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinPartnerSessionResponse create() => JoinPartnerSessionResponse._();
  @$core.override
  JoinPartnerSessionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static JoinPartnerSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JoinPartnerSessionResponse>(create);
  static JoinPartnerSessionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
