// This is a generated file - do not edit.
//
// Generated from workout/v1/assistant.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// A connection request, as /connect was opened with it.
class ConnectRequest extends $pb.GeneratedMessage {
  factory ConnectRequest({
    $core.String? clientId,
    $core.String? redirectUri,
    $core.String? codeChallenge,
    $core.String? codeChallengeMethod,
    $core.String? state,
    $core.String? scope,
    $core.String? resource,
  }) {
    final result = create();
    if (clientId != null) result.clientId = clientId;
    if (redirectUri != null) result.redirectUri = redirectUri;
    if (codeChallenge != null) result.codeChallenge = codeChallenge;
    if (codeChallengeMethod != null)
      result.codeChallengeMethod = codeChallengeMethod;
    if (state != null) result.state = state;
    if (scope != null) result.scope = scope;
    if (resource != null) result.resource = resource;
    return result;
  }

  ConnectRequest._();

  factory ConnectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'clientId')
    ..aOS(2, _omitFieldNames ? '' : 'redirectUri')
    ..aOS(3, _omitFieldNames ? '' : 'codeChallenge')
    ..aOS(4, _omitFieldNames ? '' : 'codeChallengeMethod')
    ..aOS(5, _omitFieldNames ? '' : 'state')
    ..aOS(6, _omitFieldNames ? '' : 'scope')
    ..aOS(7, _omitFieldNames ? '' : 'resource')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectRequest copyWith(void Function(ConnectRequest) updates) =>
      super.copyWith((message) => updates(message as ConnectRequest))
          as ConnectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectRequest create() => ConnectRequest._();
  @$core.override
  ConnectRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectRequest>(create);
  static ConnectRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get clientId => $_getSZ(0);
  @$pb.TagNumber(1)
  set clientId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get redirectUri => $_getSZ(1);
  @$pb.TagNumber(2)
  set redirectUri($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRedirectUri() => $_has(1);
  @$pb.TagNumber(2)
  void clearRedirectUri() => $_clearField(2);

  /// PKCE: base64url(SHA-256(verifier)). Only S256 is taken.
  @$pb.TagNumber(3)
  $core.String get codeChallenge => $_getSZ(2);
  @$pb.TagNumber(3)
  set codeChallenge($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCodeChallenge() => $_has(2);
  @$pb.TagNumber(3)
  void clearCodeChallenge() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get codeChallengeMethod => $_getSZ(3);
  @$pb.TagNumber(4)
  set codeChallengeMethod($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCodeChallengeMethod() => $_has(3);
  @$pb.TagNumber(4)
  void clearCodeChallengeMethod() => $_clearField(4);

  /// Handed back on the redirect unchanged.
  @$pb.TagNumber(5)
  $core.String get state => $_getSZ(4);
  @$pb.TagNumber(5)
  set state($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasState() => $_has(4);
  @$pb.TagNumber(5)
  void clearState() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get scope => $_getSZ(5);
  @$pb.TagNumber(6)
  set scope($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasScope() => $_has(5);
  @$pb.TagNumber(6)
  void clearScope() => $_clearField(6);

  /// The resource the assistant asked for (RFC 8707); empty or this server's.
  @$pb.TagNumber(7)
  $core.String get resource => $_getSZ(6);
  @$pb.TagNumber(7)
  set resource($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasResource() => $_has(6);
  @$pb.TagNumber(7)
  void clearResource() => $_clearField(7);
}

class DescribeConnectRequest extends $pb.GeneratedMessage {
  factory DescribeConnectRequest({
    ConnectRequest? request,
  }) {
    final result = create();
    if (request != null) result.request = request;
    return result;
  }

  DescribeConnectRequest._();

  factory DescribeConnectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DescribeConnectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DescribeConnectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ConnectRequest>(1, _omitFieldNames ? '' : 'request',
        subBuilder: ConnectRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DescribeConnectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DescribeConnectRequest copyWith(
          void Function(DescribeConnectRequest) updates) =>
      super.copyWith((message) => updates(message as DescribeConnectRequest))
          as DescribeConnectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DescribeConnectRequest create() => DescribeConnectRequest._();
  @$core.override
  DescribeConnectRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DescribeConnectRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DescribeConnectRequest>(create);
  static DescribeConnectRequest? _defaultInstance;

  @$pb.TagNumber(1)
  ConnectRequest get request => $_getN(0);
  @$pb.TagNumber(1)
  set request(ConnectRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRequest() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequest() => $_clearField(1);
  @$pb.TagNumber(1)
  ConnectRequest ensureRequest() => $_ensure(0);
}

class DescribeConnectResponse extends $pb.GeneratedMessage {
  factory DescribeConnectResponse({
    $core.String? clientName,
    $core.String? redirectHost,
    $core.Iterable<$core.String>? can,
  }) {
    final result = create();
    if (clientName != null) result.clientName = clientName;
    if (redirectHost != null) result.redirectHost = redirectHost;
    if (can != null) result.can.addAll(can);
    return result;
  }

  DescribeConnectResponse._();

  factory DescribeConnectResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DescribeConnectResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DescribeConnectResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'clientName')
    ..aOS(2, _omitFieldNames ? '' : 'redirectHost')
    ..pPS(3, _omitFieldNames ? '' : 'can')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DescribeConnectResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DescribeConnectResponse copyWith(
          void Function(DescribeConnectResponse) updates) =>
      super.copyWith((message) => updates(message as DescribeConnectResponse))
          as DescribeConnectResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DescribeConnectResponse create() => DescribeConnectResponse._();
  @$core.override
  DescribeConnectResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DescribeConnectResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DescribeConnectResponse>(create);
  static DescribeConnectResponse? _defaultInstance;

  /// The name the assistant registered with: what the page shows.
  @$pb.TagNumber(1)
  $core.String get clientName => $_getSZ(0);
  @$pb.TagNumber(1)
  set clientName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClientName() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientName() => $_clearField(1);

  /// Where it will be sent back to: the page shows its host.
  @$pb.TagNumber(2)
  $core.String get redirectHost => $_getSZ(1);
  @$pb.TagNumber(2)
  set redirectHost($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRedirectHost() => $_has(1);
  @$pb.TagNumber(2)
  void clearRedirectHost() => $_clearField(2);

  /// What it may do once allowed, one line each.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get can => $_getList(2);
}

/// The signed-in person's answer.
class AnswerConnectRequest extends $pb.GeneratedMessage {
  factory AnswerConnectRequest({
    ConnectRequest? request,
    $core.bool? allow,
  }) {
    final result = create();
    if (request != null) result.request = request;
    if (allow != null) result.allow = allow;
    return result;
  }

  AnswerConnectRequest._();

  factory AnswerConnectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnswerConnectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerConnectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<ConnectRequest>(1, _omitFieldNames ? '' : 'request',
        subBuilder: ConnectRequest.create)
    ..aOB(2, _omitFieldNames ? '' : 'allow')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerConnectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerConnectRequest copyWith(void Function(AnswerConnectRequest) updates) =>
      super.copyWith((message) => updates(message as AnswerConnectRequest))
          as AnswerConnectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnswerConnectRequest create() => AnswerConnectRequest._();
  @$core.override
  AnswerConnectRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AnswerConnectRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerConnectRequest>(create);
  static AnswerConnectRequest? _defaultInstance;

  @$pb.TagNumber(1)
  ConnectRequest get request => $_getN(0);
  @$pb.TagNumber(1)
  set request(ConnectRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRequest() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequest() => $_clearField(1);
  @$pb.TagNumber(1)
  ConnectRequest ensureRequest() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get allow => $_getBF(1);
  @$pb.TagNumber(2)
  set allow($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAllow() => $_has(1);
  @$pb.TagNumber(2)
  void clearAllow() => $_clearField(2);
}

class AnswerConnectResponse extends $pb.GeneratedMessage {
  factory AnswerConnectResponse({
    $core.String? redirectTo,
  }) {
    final result = create();
    if (redirectTo != null) result.redirectTo = redirectTo;
    return result;
  }

  AnswerConnectResponse._();

  factory AnswerConnectResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AnswerConnectResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerConnectResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'redirectTo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerConnectResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerConnectResponse copyWith(
          void Function(AnswerConnectResponse) updates) =>
      super.copyWith((message) => updates(message as AnswerConnectResponse))
          as AnswerConnectResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AnswerConnectResponse create() => AnswerConnectResponse._();
  @$core.override
  AnswerConnectResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AnswerConnectResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerConnectResponse>(create);
  static AnswerConnectResponse? _defaultInstance;

  /// Where the page sends the browser next: the assistant's redirect with a
  /// code (or, denied, access_denied) and the state.
  @$pb.TagNumber(1)
  $core.String get redirectTo => $_getSZ(0);
  @$pb.TagNumber(1)
  set redirectTo($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRedirectTo() => $_has(0);
  @$pb.TagNumber(1)
  void clearRedirectTo() => $_clearField(1);
}

/// One assistant the person has allowed.
class AssistantGrant extends $pb.GeneratedMessage {
  factory AssistantGrant({
    $core.String? grantId,
    $core.String? clientName,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? lastUsedAt,
    $core.String? scope,
  }) {
    final result = create();
    if (grantId != null) result.grantId = grantId;
    if (clientName != null) result.clientName = clientName;
    if (createdAt != null) result.createdAt = createdAt;
    if (lastUsedAt != null) result.lastUsedAt = lastUsedAt;
    if (scope != null) result.scope = scope;
    return result;
  }

  AssistantGrant._();

  factory AssistantGrant.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssistantGrant.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssistantGrant',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'grantId')
    ..aOS(2, _omitFieldNames ? '' : 'clientName')
    ..aInt64(3, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(4, _omitFieldNames ? '' : 'lastUsedAt')
    ..aOS(5, _omitFieldNames ? '' : 'scope')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssistantGrant clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssistantGrant copyWith(void Function(AssistantGrant) updates) =>
      super.copyWith((message) => updates(message as AssistantGrant))
          as AssistantGrant;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssistantGrant create() => AssistantGrant._();
  @$core.override
  AssistantGrant createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssistantGrant getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssistantGrant>(create);
  static AssistantGrant? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get grantId => $_getSZ(0);
  @$pb.TagNumber(1)
  set grantId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGrantId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGrantId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get clientName => $_getSZ(1);
  @$pb.TagNumber(2)
  set clientName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClientName() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get createdAt => $_getI64(2);
  @$pb.TagNumber(3)
  set createdAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedAt() => $_clearField(3);

  /// When it last used its access; 0 = never.
  @$pb.TagNumber(4)
  $fixnum.Int64 get lastUsedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set lastUsedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastUsedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastUsedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get scope => $_getSZ(4);
  @$pb.TagNumber(5)
  set scope($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScope() => $_has(4);
  @$pb.TagNumber(5)
  void clearScope() => $_clearField(5);
}

class ListAssistantsRequest extends $pb.GeneratedMessage {
  factory ListAssistantsRequest() => create();

  ListAssistantsRequest._();

  factory ListAssistantsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListAssistantsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAssistantsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAssistantsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAssistantsRequest copyWith(
          void Function(ListAssistantsRequest) updates) =>
      super.copyWith((message) => updates(message as ListAssistantsRequest))
          as ListAssistantsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAssistantsRequest create() => ListAssistantsRequest._();
  @$core.override
  ListAssistantsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListAssistantsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAssistantsRequest>(create);
  static ListAssistantsRequest? _defaultInstance;
}

class ListAssistantsResponse extends $pb.GeneratedMessage {
  factory ListAssistantsResponse({
    $core.Iterable<AssistantGrant>? grants,
  }) {
    final result = create();
    if (grants != null) result.grants.addAll(grants);
    return result;
  }

  ListAssistantsResponse._();

  factory ListAssistantsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListAssistantsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAssistantsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<AssistantGrant>(1, _omitFieldNames ? '' : 'grants',
        subBuilder: AssistantGrant.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAssistantsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAssistantsResponse copyWith(
          void Function(ListAssistantsResponse) updates) =>
      super.copyWith((message) => updates(message as ListAssistantsResponse))
          as ListAssistantsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAssistantsResponse create() => ListAssistantsResponse._();
  @$core.override
  ListAssistantsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListAssistantsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAssistantsResponse>(create);
  static ListAssistantsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AssistantGrant> get grants => $_getList(0);
}

/// Cut an assistant off: its tokens stop working at once.
class RevokeAssistantRequest extends $pb.GeneratedMessage {
  factory RevokeAssistantRequest({
    $core.String? grantId,
  }) {
    final result = create();
    if (grantId != null) result.grantId = grantId;
    return result;
  }

  RevokeAssistantRequest._();

  factory RevokeAssistantRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevokeAssistantRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeAssistantRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'grantId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeAssistantRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeAssistantRequest copyWith(
          void Function(RevokeAssistantRequest) updates) =>
      super.copyWith((message) => updates(message as RevokeAssistantRequest))
          as RevokeAssistantRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevokeAssistantRequest create() => RevokeAssistantRequest._();
  @$core.override
  RevokeAssistantRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevokeAssistantRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeAssistantRequest>(create);
  static RevokeAssistantRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get grantId => $_getSZ(0);
  @$pb.TagNumber(1)
  set grantId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGrantId() => $_has(0);
  @$pb.TagNumber(1)
  void clearGrantId() => $_clearField(1);
}

class RevokeAssistantResponse extends $pb.GeneratedMessage {
  factory RevokeAssistantResponse() => create();

  RevokeAssistantResponse._();

  factory RevokeAssistantResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevokeAssistantResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeAssistantResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeAssistantResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeAssistantResponse copyWith(
          void Function(RevokeAssistantResponse) updates) =>
      super.copyWith((message) => updates(message as RevokeAssistantResponse))
          as RevokeAssistantResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevokeAssistantResponse create() => RevokeAssistantResponse._();
  @$core.override
  RevokeAssistantResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevokeAssistantResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeAssistantResponse>(create);
  static RevokeAssistantResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
