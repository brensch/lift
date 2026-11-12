// This is a generated file - do not edit.
//
// Generated from workout/v1/auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'auth.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'auth.pbenum.dart';

class RegisterStartRequest extends $pb.GeneratedMessage {
  factory RegisterStartRequest({
    $core.String? username,
  }) {
    final result = create();
    if (username != null) result.username = username;
    return result;
  }

  RegisterStartRequest._();

  factory RegisterStartRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterStartRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterStartRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterStartRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterStartRequest copyWith(void Function(RegisterStartRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterStartRequest))
          as RegisterStartRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterStartRequest create() => RegisterStartRequest._();
  @$core.override
  RegisterStartRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterStartRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterStartRequest>(create);
  static RegisterStartRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);
}

class RegisterStartResponse extends $pb.GeneratedMessage {
  factory RegisterStartResponse({
    $core.String? userId,
    $core.String? optionsJson,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (optionsJson != null) result.optionsJson = optionsJson;
    return result;
  }

  RegisterStartResponse._();

  factory RegisterStartResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterStartResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterStartResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'optionsJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterStartResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterStartResponse copyWith(
          void Function(RegisterStartResponse) updates) =>
      super.copyWith((message) => updates(message as RegisterStartResponse))
          as RegisterStartResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterStartResponse create() => RegisterStartResponse._();
  @$core.override
  RegisterStartResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterStartResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterStartResponse>(create);
  static RegisterStartResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get optionsJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set optionsJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOptionsJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearOptionsJson() => $_clearField(2);
}

class RegisterFinishRequest extends $pb.GeneratedMessage {
  factory RegisterFinishRequest({
    $core.String? userId,
    $core.String? credentialJson,
    $core.String? name,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (credentialJson != null) result.credentialJson = credentialJson;
    if (name != null) result.name = name;
    return result;
  }

  RegisterFinishRequest._();

  factory RegisterFinishRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterFinishRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterFinishRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'credentialJson')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFinishRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFinishRequest copyWith(
          void Function(RegisterFinishRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterFinishRequest))
          as RegisterFinishRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterFinishRequest create() => RegisterFinishRequest._();
  @$core.override
  RegisterFinishRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterFinishRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterFinishRequest>(create);
  static RegisterFinishRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get credentialJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set credentialJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCredentialJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearCredentialJson() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);
}

class AuthResponse extends $pb.GeneratedMessage {
  factory AuthResponse({
    $core.String? sessionToken,
    $core.String? userId,
    $core.String? username,
  }) {
    final result = create();
    if (sessionToken != null) result.sessionToken = sessionToken;
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    return result;
  }

  AuthResponse._();

  factory AuthResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AuthResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuthResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionToken')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthResponse copyWith(void Function(AuthResponse) updates) =>
      super.copyWith((message) => updates(message as AuthResponse))
          as AuthResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AuthResponse create() => AuthResponse._();
  @$core.override
  AuthResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AuthResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuthResponse>(create);
  static AuthResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get username => $_getSZ(2);
  @$pb.TagNumber(3)
  set username($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUsername() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsername() => $_clearField(3);
}

class LoginStartRequest extends $pb.GeneratedMessage {
  factory LoginStartRequest({
    $core.String? username,
  }) {
    final result = create();
    if (username != null) result.username = username;
    return result;
  }

  LoginStartRequest._();

  factory LoginStartRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginStartRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginStartRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginStartRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginStartRequest copyWith(void Function(LoginStartRequest) updates) =>
      super.copyWith((message) => updates(message as LoginStartRequest))
          as LoginStartRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginStartRequest create() => LoginStartRequest._();
  @$core.override
  LoginStartRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoginStartRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginStartRequest>(create);
  static LoginStartRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);
}

class LoginStartResponse extends $pb.GeneratedMessage {
  factory LoginStartResponse({
    $core.String? challengeId,
    $core.String? optionsJson,
  }) {
    final result = create();
    if (challengeId != null) result.challengeId = challengeId;
    if (optionsJson != null) result.optionsJson = optionsJson;
    return result;
  }

  LoginStartResponse._();

  factory LoginStartResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginStartResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginStartResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'challengeId')
    ..aOS(2, _omitFieldNames ? '' : 'optionsJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginStartResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginStartResponse copyWith(void Function(LoginStartResponse) updates) =>
      super.copyWith((message) => updates(message as LoginStartResponse))
          as LoginStartResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginStartResponse create() => LoginStartResponse._();
  @$core.override
  LoginStartResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoginStartResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginStartResponse>(create);
  static LoginStartResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get challengeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set challengeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChallengeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChallengeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get optionsJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set optionsJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOptionsJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearOptionsJson() => $_clearField(2);
}

class LoginFinishRequest extends $pb.GeneratedMessage {
  factory LoginFinishRequest({
    $core.String? challengeId,
    $core.String? credentialJson,
  }) {
    final result = create();
    if (challengeId != null) result.challengeId = challengeId;
    if (credentialJson != null) result.credentialJson = credentialJson;
    return result;
  }

  LoginFinishRequest._();

  factory LoginFinishRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginFinishRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginFinishRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'challengeId')
    ..aOS(2, _omitFieldNames ? '' : 'credentialJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginFinishRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginFinishRequest copyWith(void Function(LoginFinishRequest) updates) =>
      super.copyWith((message) => updates(message as LoginFinishRequest))
          as LoginFinishRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginFinishRequest create() => LoginFinishRequest._();
  @$core.override
  LoginFinishRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoginFinishRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginFinishRequest>(create);
  static LoginFinishRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get challengeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set challengeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChallengeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChallengeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get credentialJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set credentialJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCredentialJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearCredentialJson() => $_clearField(2);
}

class LogoutRequest extends $pb.GeneratedMessage {
  factory LogoutRequest() => create();

  LogoutRequest._();

  factory LogoutRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogoutRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogoutRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoutRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoutRequest copyWith(void Function(LogoutRequest) updates) =>
      super.copyWith((message) => updates(message as LogoutRequest))
          as LogoutRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogoutRequest create() => LogoutRequest._();
  @$core.override
  LogoutRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogoutRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogoutRequest>(create);
  static LogoutRequest? _defaultInstance;
}

class LogoutResponse extends $pb.GeneratedMessage {
  factory LogoutResponse() => create();

  LogoutResponse._();

  factory LogoutResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LogoutResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogoutResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoutResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoutResponse copyWith(void Function(LogoutResponse) updates) =>
      super.copyWith((message) => updates(message as LogoutResponse))
          as LogoutResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LogoutResponse create() => LogoutResponse._();
  @$core.override
  LogoutResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LogoutResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogoutResponse>(create);
  static LogoutResponse? _defaultInstance;
}

class AddPasskeyStartRequest extends $pb.GeneratedMessage {
  factory AddPasskeyStartRequest() => create();

  AddPasskeyStartRequest._();

  factory AddPasskeyStartRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddPasskeyStartRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddPasskeyStartRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPasskeyStartRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPasskeyStartRequest copyWith(
          void Function(AddPasskeyStartRequest) updates) =>
      super.copyWith((message) => updates(message as AddPasskeyStartRequest))
          as AddPasskeyStartRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPasskeyStartRequest create() => AddPasskeyStartRequest._();
  @$core.override
  AddPasskeyStartRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddPasskeyStartRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddPasskeyStartRequest>(create);
  static AddPasskeyStartRequest? _defaultInstance;
}

class AddPasskeyStartResponse extends $pb.GeneratedMessage {
  factory AddPasskeyStartResponse({
    $core.String? optionsJson,
  }) {
    final result = create();
    if (optionsJson != null) result.optionsJson = optionsJson;
    return result;
  }

  AddPasskeyStartResponse._();

  factory AddPasskeyStartResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddPasskeyStartResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddPasskeyStartResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'optionsJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPasskeyStartResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPasskeyStartResponse copyWith(
          void Function(AddPasskeyStartResponse) updates) =>
      super.copyWith((message) => updates(message as AddPasskeyStartResponse))
          as AddPasskeyStartResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPasskeyStartResponse create() => AddPasskeyStartResponse._();
  @$core.override
  AddPasskeyStartResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddPasskeyStartResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddPasskeyStartResponse>(create);
  static AddPasskeyStartResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get optionsJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set optionsJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOptionsJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearOptionsJson() => $_clearField(1);
}

class AddPasskeyFinishRequest extends $pb.GeneratedMessage {
  factory AddPasskeyFinishRequest({
    $core.String? credentialJson,
    $core.String? name,
  }) {
    final result = create();
    if (credentialJson != null) result.credentialJson = credentialJson;
    if (name != null) result.name = name;
    return result;
  }

  AddPasskeyFinishRequest._();

  factory AddPasskeyFinishRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddPasskeyFinishRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddPasskeyFinishRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'credentialJson')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPasskeyFinishRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPasskeyFinishRequest copyWith(
          void Function(AddPasskeyFinishRequest) updates) =>
      super.copyWith((message) => updates(message as AddPasskeyFinishRequest))
          as AddPasskeyFinishRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPasskeyFinishRequest create() => AddPasskeyFinishRequest._();
  @$core.override
  AddPasskeyFinishRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddPasskeyFinishRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddPasskeyFinishRequest>(create);
  static AddPasskeyFinishRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get credentialJson => $_getSZ(0);
  @$pb.TagNumber(1)
  set credentialJson($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCredentialJson() => $_has(0);
  @$pb.TagNumber(1)
  void clearCredentialJson() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

class AddPasskeyFinishResponse extends $pb.GeneratedMessage {
  factory AddPasskeyFinishResponse() => create();

  AddPasskeyFinishResponse._();

  factory AddPasskeyFinishResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddPasskeyFinishResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddPasskeyFinishResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPasskeyFinishResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddPasskeyFinishResponse copyWith(
          void Function(AddPasskeyFinishResponse) updates) =>
      super.copyWith((message) => updates(message as AddPasskeyFinishResponse))
          as AddPasskeyFinishResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddPasskeyFinishResponse create() => AddPasskeyFinishResponse._();
  @$core.override
  AddPasskeyFinishResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddPasskeyFinishResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddPasskeyFinishResponse>(create);
  static AddPasskeyFinishResponse? _defaultInstance;
}

class DeletePasskeyRequest extends $pb.GeneratedMessage {
  factory DeletePasskeyRequest({
    $core.String? credentialId,
  }) {
    final result = create();
    if (credentialId != null) result.credentialId = credentialId;
    return result;
  }

  DeletePasskeyRequest._();

  factory DeletePasskeyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePasskeyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePasskeyRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'credentialId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePasskeyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePasskeyRequest copyWith(void Function(DeletePasskeyRequest) updates) =>
      super.copyWith((message) => updates(message as DeletePasskeyRequest))
          as DeletePasskeyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePasskeyRequest create() => DeletePasskeyRequest._();
  @$core.override
  DeletePasskeyRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePasskeyRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePasskeyRequest>(create);
  static DeletePasskeyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get credentialId => $_getSZ(0);
  @$pb.TagNumber(1)
  set credentialId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCredentialId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCredentialId() => $_clearField(1);
}

class DeletePasskeyResponse extends $pb.GeneratedMessage {
  factory DeletePasskeyResponse() => create();

  DeletePasskeyResponse._();

  factory DeletePasskeyResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeletePasskeyResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeletePasskeyResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePasskeyResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeletePasskeyResponse copyWith(
          void Function(DeletePasskeyResponse) updates) =>
      super.copyWith((message) => updates(message as DeletePasskeyResponse))
          as DeletePasskeyResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeletePasskeyResponse create() => DeletePasskeyResponse._();
  @$core.override
  DeletePasskeyResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeletePasskeyResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeletePasskeyResponse>(create);
  static DeletePasskeyResponse? _defaultInstance;
}

class PasskeyInfo extends $pb.GeneratedMessage {
  factory PasskeyInfo({
    $core.String? credentialId,
    $core.String? name,
    $fixnum.Int64? createdAt,
    $core.String? createdAtIp,
    $core.Iterable<$core.String>? transports,
  }) {
    final result = create();
    if (credentialId != null) result.credentialId = credentialId;
    if (name != null) result.name = name;
    if (createdAt != null) result.createdAt = createdAt;
    if (createdAtIp != null) result.createdAtIp = createdAtIp;
    if (transports != null) result.transports.addAll(transports);
    return result;
  }

  PasskeyInfo._();

  factory PasskeyInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PasskeyInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PasskeyInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'credentialId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'createdAt')
    ..aOS(4, _omitFieldNames ? '' : 'createdAtIp')
    ..pPS(5, _omitFieldNames ? '' : 'transports')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PasskeyInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PasskeyInfo copyWith(void Function(PasskeyInfo) updates) =>
      super.copyWith((message) => updates(message as PasskeyInfo))
          as PasskeyInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PasskeyInfo create() => PasskeyInfo._();
  @$core.override
  PasskeyInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PasskeyInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PasskeyInfo>(create);
  static PasskeyInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get credentialId => $_getSZ(0);
  @$pb.TagNumber(1)
  set credentialId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCredentialId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCredentialId() => $_clearField(1);

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
  $core.String get createdAtIp => $_getSZ(3);
  @$pb.TagNumber(4)
  set createdAtIp($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreatedAtIp() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreatedAtIp() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get transports => $_getList(4);
}

class ListPasskeysRequest extends $pb.GeneratedMessage {
  factory ListPasskeysRequest() => create();

  ListPasskeysRequest._();

  factory ListPasskeysRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPasskeysRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPasskeysRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPasskeysRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPasskeysRequest copyWith(void Function(ListPasskeysRequest) updates) =>
      super.copyWith((message) => updates(message as ListPasskeysRequest))
          as ListPasskeysRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPasskeysRequest create() => ListPasskeysRequest._();
  @$core.override
  ListPasskeysRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPasskeysRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPasskeysRequest>(create);
  static ListPasskeysRequest? _defaultInstance;
}

class ListPasskeysResponse extends $pb.GeneratedMessage {
  factory ListPasskeysResponse({
    $core.Iterable<PasskeyInfo>? passkeys,
  }) {
    final result = create();
    if (passkeys != null) result.passkeys.addAll(passkeys);
    return result;
  }

  ListPasskeysResponse._();

  factory ListPasskeysResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListPasskeysResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListPasskeysResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<PasskeyInfo>(1, _omitFieldNames ? '' : 'passkeys',
        subBuilder: PasskeyInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPasskeysResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListPasskeysResponse copyWith(void Function(ListPasskeysResponse) updates) =>
      super.copyWith((message) => updates(message as ListPasskeysResponse))
          as ListPasskeysResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListPasskeysResponse create() => ListPasskeysResponse._();
  @$core.override
  ListPasskeysResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListPasskeysResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListPasskeysResponse>(create);
  static ListPasskeysResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PasskeyInfo> get passkeys => $_getList(0);
}

class TestLoginRequest extends $pb.GeneratedMessage {
  factory TestLoginRequest({
    $core.String? username,
  }) {
    final result = create();
    if (username != null) result.username = username;
    return result;
  }

  TestLoginRequest._();

  factory TestLoginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TestLoginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestLoginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestLoginRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestLoginRequest copyWith(void Function(TestLoginRequest) updates) =>
      super.copyWith((message) => updates(message as TestLoginRequest))
          as TestLoginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TestLoginRequest create() => TestLoginRequest._();
  @$core.override
  TestLoginRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TestLoginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestLoginRequest>(create);
  static TestLoginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);
}

class DeleteAccountRequest extends $pb.GeneratedMessage {
  factory DeleteAccountRequest() => create();

  DeleteAccountRequest._();

  factory DeleteAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteAccountRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountRequest copyWith(void Function(DeleteAccountRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteAccountRequest))
          as DeleteAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAccountRequest create() => DeleteAccountRequest._();
  @$core.override
  DeleteAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteAccountRequest>(create);
  static DeleteAccountRequest? _defaultInstance;
}

class DeleteAccountResponse extends $pb.GeneratedMessage {
  factory DeleteAccountResponse({
    $core.String? deletedUserId,
  }) {
    final result = create();
    if (deletedUserId != null) result.deletedUserId = deletedUserId;
    return result;
  }

  DeleteAccountResponse._();

  factory DeleteAccountResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteAccountResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteAccountResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deletedUserId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountResponse copyWith(
          void Function(DeleteAccountResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteAccountResponse))
          as DeleteAccountResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAccountResponse create() => DeleteAccountResponse._();
  @$core.override
  DeleteAccountResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteAccountResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteAccountResponse>(create);
  static DeleteAccountResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deletedUserId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deletedUserId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeletedUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeletedUserId() => $_clearField(1);
}

class ReportAuthFailureRequest extends $pb.GeneratedMessage {
  factory ReportAuthFailureRequest({
    $core.String? attemptId,
    AuthFailureReason? reason,
  }) {
    final result = create();
    if (attemptId != null) result.attemptId = attemptId;
    if (reason != null) result.reason = reason;
    return result;
  }

  ReportAuthFailureRequest._();

  factory ReportAuthFailureRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReportAuthFailureRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReportAuthFailureRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'attemptId')
    ..aE<AuthFailureReason>(2, _omitFieldNames ? '' : 'reason',
        enumValues: AuthFailureReason.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportAuthFailureRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportAuthFailureRequest copyWith(
          void Function(ReportAuthFailureRequest) updates) =>
      super.copyWith((message) => updates(message as ReportAuthFailureRequest))
          as ReportAuthFailureRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReportAuthFailureRequest create() => ReportAuthFailureRequest._();
  @$core.override
  ReportAuthFailureRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReportAuthFailureRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReportAuthFailureRequest>(create);
  static ReportAuthFailureRequest? _defaultInstance;

  /// RegisterStartResponse.user_id or LoginStartResponse.challenge_id.
  @$pb.TagNumber(1)
  $core.String get attemptId => $_getSZ(0);
  @$pb.TagNumber(1)
  set attemptId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttemptId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttemptId() => $_clearField(1);

  @$pb.TagNumber(2)
  AuthFailureReason get reason => $_getN(1);
  @$pb.TagNumber(2)
  set reason(AuthFailureReason value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class ReportAuthFailureResponse extends $pb.GeneratedMessage {
  factory ReportAuthFailureResponse() => create();

  ReportAuthFailureResponse._();

  factory ReportAuthFailureResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReportAuthFailureResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReportAuthFailureResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportAuthFailureResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReportAuthFailureResponse copyWith(
          void Function(ReportAuthFailureResponse) updates) =>
      super.copyWith((message) => updates(message as ReportAuthFailureResponse))
          as ReportAuthFailureResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReportAuthFailureResponse create() => ReportAuthFailureResponse._();
  @$core.override
  ReportAuthFailureResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReportAuthFailureResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReportAuthFailureResponse>(create);
  static ReportAuthFailureResponse? _defaultInstance;
}

class RecoveryStartRequest extends $pb.GeneratedMessage {
  factory RecoveryStartRequest({
    $core.String? username,
  }) {
    final result = create();
    if (username != null) result.username = username;
    return result;
  }

  RecoveryStartRequest._();

  factory RecoveryStartRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecoveryStartRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecoveryStartRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryStartRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryStartRequest copyWith(void Function(RecoveryStartRequest) updates) =>
      super.copyWith((message) => updates(message as RecoveryStartRequest))
          as RecoveryStartRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecoveryStartRequest create() => RecoveryStartRequest._();
  @$core.override
  RecoveryStartRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecoveryStartRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecoveryStartRequest>(create);
  static RecoveryStartRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);
}

class RecoveryStartResponse extends $pb.GeneratedMessage {
  factory RecoveryStartResponse({
    $core.String? requestId,
    $core.String? optionsJson,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (optionsJson != null) result.optionsJson = optionsJson;
    return result;
  }

  RecoveryStartResponse._();

  factory RecoveryStartResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecoveryStartResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecoveryStartResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'optionsJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryStartResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryStartResponse copyWith(
          void Function(RecoveryStartResponse) updates) =>
      super.copyWith((message) => updates(message as RecoveryStartResponse))
          as RecoveryStartResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecoveryStartResponse create() => RecoveryStartResponse._();
  @$core.override
  RecoveryStartResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecoveryStartResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecoveryStartResponse>(create);
  static RecoveryStartResponse? _defaultInstance;

  /// Names the request from here on; whoever holds it can read its status.
  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get optionsJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set optionsJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOptionsJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearOptionsJson() => $_clearField(2);
}

class RecoveryFinishRequest extends $pb.GeneratedMessage {
  factory RecoveryFinishRequest({
    $core.String? requestId,
    $core.String? credentialJson,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (credentialJson != null) result.credentialJson = credentialJson;
    return result;
  }

  RecoveryFinishRequest._();

  factory RecoveryFinishRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecoveryFinishRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecoveryFinishRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'credentialJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryFinishRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryFinishRequest copyWith(
          void Function(RecoveryFinishRequest) updates) =>
      super.copyWith((message) => updates(message as RecoveryFinishRequest))
          as RecoveryFinishRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecoveryFinishRequest create() => RecoveryFinishRequest._();
  @$core.override
  RecoveryFinishRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecoveryFinishRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecoveryFinishRequest>(create);
  static RecoveryFinishRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get credentialJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set credentialJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCredentialJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearCredentialJson() => $_clearField(2);
}

class RecoveryFinishResponse extends $pb.GeneratedMessage {
  factory RecoveryFinishResponse({
    $core.String? code,
    $fixnum.Int64? expiresAt,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  RecoveryFinishResponse._();

  factory RecoveryFinishResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecoveryFinishResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecoveryFinishResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aInt64(2, _omitFieldNames ? '' : 'expiresAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryFinishResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryFinishResponse copyWith(
          void Function(RecoveryFinishResponse) updates) =>
      super.copyWith((message) => updates(message as RecoveryFinishResponse))
          as RecoveryFinishResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecoveryFinishResponse create() => RecoveryFinishResponse._();
  @$core.override
  RecoveryFinishResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecoveryFinishResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecoveryFinishResponse>(create);
  static RecoveryFinishResponse? _defaultInstance;

  /// What the person sends to an admin, who approves it.
  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expiresAt => $_getI64(1);
  @$pb.TagNumber(2)
  set expiresAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpiresAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresAt() => $_clearField(2);
}

class RecoveryStatusRequest extends $pb.GeneratedMessage {
  factory RecoveryStatusRequest({
    $core.String? requestId,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    return result;
  }

  RecoveryStatusRequest._();

  factory RecoveryStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecoveryStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecoveryStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryStatusRequest copyWith(
          void Function(RecoveryStatusRequest) updates) =>
      super.copyWith((message) => updates(message as RecoveryStatusRequest))
          as RecoveryStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecoveryStatusRequest create() => RecoveryStatusRequest._();
  @$core.override
  RecoveryStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecoveryStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecoveryStatusRequest>(create);
  static RecoveryStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);
}

class RecoveryStatusResponse extends $pb.GeneratedMessage {
  factory RecoveryStatusResponse({
    RecoveryState? state,
    $core.String? code,
    $fixnum.Int64? expiresAt,
    $core.String? username,
  }) {
    final result = create();
    if (state != null) result.state = state;
    if (code != null) result.code = code;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (username != null) result.username = username;
    return result;
  }

  RecoveryStatusResponse._();

  factory RecoveryStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecoveryStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecoveryStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<RecoveryState>(1, _omitFieldNames ? '' : 'state',
        enumValues: RecoveryState.values)
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..aInt64(3, _omitFieldNames ? '' : 'expiresAt')
    ..aOS(4, _omitFieldNames ? '' : 'username')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryStatusResponse copyWith(
          void Function(RecoveryStatusResponse) updates) =>
      super.copyWith((message) => updates(message as RecoveryStatusResponse))
          as RecoveryStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecoveryStatusResponse create() => RecoveryStatusResponse._();
  @$core.override
  RecoveryStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecoveryStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecoveryStatusResponse>(create);
  static RecoveryStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  RecoveryState get state => $_getN(0);
  @$pb.TagNumber(1)
  set state(RecoveryState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get expiresAt => $_getI64(2);
  @$pb.TagNumber(3)
  set expiresAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExpiresAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearExpiresAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get username => $_getSZ(3);
  @$pb.TagNumber(4)
  set username($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUsername() => $_has(3);
  @$pb.TagNumber(4)
  void clearUsername() => $_clearField(4);
}

/// A request to get into the caller's own account that is still waiting.
class PendingRecovery extends $pb.GeneratedMessage {
  factory PendingRecovery({
    $core.String? requestId,
    $fixnum.Int64? createdAt,
    $core.String? platform,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (createdAt != null) result.createdAt = createdAt;
    if (platform != null) result.platform = platform;
    return result;
  }

  PendingRecovery._();

  factory PendingRecovery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PendingRecovery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PendingRecovery',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aInt64(2, _omitFieldNames ? '' : 'createdAt')
    ..aOS(3, _omitFieldNames ? '' : 'platform')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PendingRecovery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PendingRecovery copyWith(void Function(PendingRecovery) updates) =>
      super.copyWith((message) => updates(message as PendingRecovery))
          as PendingRecovery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PendingRecovery create() => PendingRecovery._();
  @$core.override
  PendingRecovery createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PendingRecovery getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PendingRecovery>(create);
  static PendingRecovery? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get createdAt => $_getI64(1);
  @$pb.TagNumber(2)
  set createdAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCreatedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearCreatedAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get platform => $_getSZ(2);
  @$pb.TagNumber(3)
  set platform($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlatform() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlatform() => $_clearField(3);
}

class ListMyRecoveriesRequest extends $pb.GeneratedMessage {
  factory ListMyRecoveriesRequest() => create();

  ListMyRecoveriesRequest._();

  factory ListMyRecoveriesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListMyRecoveriesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMyRecoveriesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMyRecoveriesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMyRecoveriesRequest copyWith(
          void Function(ListMyRecoveriesRequest) updates) =>
      super.copyWith((message) => updates(message as ListMyRecoveriesRequest))
          as ListMyRecoveriesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListMyRecoveriesRequest create() => ListMyRecoveriesRequest._();
  @$core.override
  ListMyRecoveriesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListMyRecoveriesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListMyRecoveriesRequest>(create);
  static ListMyRecoveriesRequest? _defaultInstance;
}

class ListMyRecoveriesResponse extends $pb.GeneratedMessage {
  factory ListMyRecoveriesResponse({
    $core.Iterable<PendingRecovery>? recoveries,
  }) {
    final result = create();
    if (recoveries != null) result.recoveries.addAll(recoveries);
    return result;
  }

  ListMyRecoveriesResponse._();

  factory ListMyRecoveriesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListMyRecoveriesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMyRecoveriesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<PendingRecovery>(1, _omitFieldNames ? '' : 'recoveries',
        subBuilder: PendingRecovery.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMyRecoveriesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMyRecoveriesResponse copyWith(
          void Function(ListMyRecoveriesResponse) updates) =>
      super.copyWith((message) => updates(message as ListMyRecoveriesResponse))
          as ListMyRecoveriesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListMyRecoveriesResponse create() => ListMyRecoveriesResponse._();
  @$core.override
  ListMyRecoveriesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListMyRecoveriesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListMyRecoveriesResponse>(create);
  static ListMyRecoveriesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PendingRecovery> get recoveries => $_getList(0);
}

class DenyMyRecoveryRequest extends $pb.GeneratedMessage {
  factory DenyMyRecoveryRequest({
    $core.String? requestId,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    return result;
  }

  DenyMyRecoveryRequest._();

  factory DenyMyRecoveryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DenyMyRecoveryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DenyMyRecoveryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DenyMyRecoveryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DenyMyRecoveryRequest copyWith(
          void Function(DenyMyRecoveryRequest) updates) =>
      super.copyWith((message) => updates(message as DenyMyRecoveryRequest))
          as DenyMyRecoveryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DenyMyRecoveryRequest create() => DenyMyRecoveryRequest._();
  @$core.override
  DenyMyRecoveryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DenyMyRecoveryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DenyMyRecoveryRequest>(create);
  static DenyMyRecoveryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);
}

class DenyMyRecoveryResponse extends $pb.GeneratedMessage {
  factory DenyMyRecoveryResponse() => create();

  DenyMyRecoveryResponse._();

  factory DenyMyRecoveryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DenyMyRecoveryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DenyMyRecoveryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DenyMyRecoveryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DenyMyRecoveryResponse copyWith(
          void Function(DenyMyRecoveryResponse) updates) =>
      super.copyWith((message) => updates(message as DenyMyRecoveryResponse))
          as DenyMyRecoveryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DenyMyRecoveryResponse create() => DenyMyRecoveryResponse._();
  @$core.override
  DenyMyRecoveryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DenyMyRecoveryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DenyMyRecoveryResponse>(create);
  static DenyMyRecoveryResponse? _defaultInstance;
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
