// This is a generated file - do not edit.
//
// Generated from workout/v1/auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'auth.pb.dart' as $0;

export 'auth.pb.dart';

@$pb.GrpcServiceName('workout.v1.AuthService')
class AuthServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AuthServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.RegisterStartResponse> registerStart(
    $0.RegisterStartRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$registerStart, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> registerFinish(
    $0.RegisterFinishRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$registerFinish, request, options: options);
  }

  $grpc.ResponseFuture<$0.LoginStartResponse> loginStart(
    $0.LoginStartRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$loginStart, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> loginFinish(
    $0.LoginFinishRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$loginFinish, request, options: options);
  }

  $grpc.ResponseFuture<$0.LogoutResponse> logout(
    $0.LogoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$logout, request, options: options);
  }

  $grpc.ResponseFuture<$0.AddPasskeyStartResponse> addPasskeyStart(
    $0.AddPasskeyStartRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addPasskeyStart, request, options: options);
  }

  $grpc.ResponseFuture<$0.AddPasskeyFinishResponse> addPasskeyFinish(
    $0.AddPasskeyFinishRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addPasskeyFinish, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeletePasskeyResponse> deletePasskey(
    $0.DeletePasskeyRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deletePasskey, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListPasskeysResponse> listPasskeys(
    $0.ListPasskeysRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPasskeys, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> passwordRegister(
    $0.PasswordRegisterRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$passwordRegister, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> passwordLogin(
    $0.PasswordLoginRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$passwordLogin, request, options: options);
  }

  $grpc.ResponseFuture<$0.AuthResponse> testLogin(
    $0.TestLoginRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$testLogin, request, options: options);
  }

  // method descriptors

  static final _$registerStart =
      $grpc.ClientMethod<$0.RegisterStartRequest, $0.RegisterStartResponse>(
          '/workout.v1.AuthService/RegisterStart',
          ($0.RegisterStartRequest value) => value.writeToBuffer(),
          $0.RegisterStartResponse.fromBuffer);
  static final _$registerFinish =
      $grpc.ClientMethod<$0.RegisterFinishRequest, $0.AuthResponse>(
          '/workout.v1.AuthService/RegisterFinish',
          ($0.RegisterFinishRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
  static final _$loginStart =
      $grpc.ClientMethod<$0.LoginStartRequest, $0.LoginStartResponse>(
          '/workout.v1.AuthService/LoginStart',
          ($0.LoginStartRequest value) => value.writeToBuffer(),
          $0.LoginStartResponse.fromBuffer);
  static final _$loginFinish =
      $grpc.ClientMethod<$0.LoginFinishRequest, $0.AuthResponse>(
          '/workout.v1.AuthService/LoginFinish',
          ($0.LoginFinishRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
  static final _$logout =
      $grpc.ClientMethod<$0.LogoutRequest, $0.LogoutResponse>(
          '/workout.v1.AuthService/Logout',
          ($0.LogoutRequest value) => value.writeToBuffer(),
          $0.LogoutResponse.fromBuffer);
  static final _$addPasskeyStart =
      $grpc.ClientMethod<$0.AddPasskeyStartRequest, $0.AddPasskeyStartResponse>(
          '/workout.v1.AuthService/AddPasskeyStart',
          ($0.AddPasskeyStartRequest value) => value.writeToBuffer(),
          $0.AddPasskeyStartResponse.fromBuffer);
  static final _$addPasskeyFinish = $grpc.ClientMethod<
          $0.AddPasskeyFinishRequest, $0.AddPasskeyFinishResponse>(
      '/workout.v1.AuthService/AddPasskeyFinish',
      ($0.AddPasskeyFinishRequest value) => value.writeToBuffer(),
      $0.AddPasskeyFinishResponse.fromBuffer);
  static final _$deletePasskey =
      $grpc.ClientMethod<$0.DeletePasskeyRequest, $0.DeletePasskeyResponse>(
          '/workout.v1.AuthService/DeletePasskey',
          ($0.DeletePasskeyRequest value) => value.writeToBuffer(),
          $0.DeletePasskeyResponse.fromBuffer);
  static final _$listPasskeys =
      $grpc.ClientMethod<$0.ListPasskeysRequest, $0.ListPasskeysResponse>(
          '/workout.v1.AuthService/ListPasskeys',
          ($0.ListPasskeysRequest value) => value.writeToBuffer(),
          $0.ListPasskeysResponse.fromBuffer);
  static final _$passwordRegister =
      $grpc.ClientMethod<$0.PasswordRegisterRequest, $0.AuthResponse>(
          '/workout.v1.AuthService/PasswordRegister',
          ($0.PasswordRegisterRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
  static final _$passwordLogin =
      $grpc.ClientMethod<$0.PasswordLoginRequest, $0.AuthResponse>(
          '/workout.v1.AuthService/PasswordLogin',
          ($0.PasswordLoginRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
  static final _$testLogin =
      $grpc.ClientMethod<$0.TestLoginRequest, $0.AuthResponse>(
          '/workout.v1.AuthService/TestLogin',
          ($0.TestLoginRequest value) => value.writeToBuffer(),
          $0.AuthResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.AuthService')
abstract class AuthServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.AuthService';

  AuthServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.RegisterStartRequest, $0.RegisterStartResponse>(
            'RegisterStart',
            registerStart_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RegisterStartRequest.fromBuffer(value),
            ($0.RegisterStartResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RegisterFinishRequest, $0.AuthResponse>(
        'RegisterFinish',
        registerFinish_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RegisterFinishRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LoginStartRequest, $0.LoginStartResponse>(
        'LoginStart',
        loginStart_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LoginStartRequest.fromBuffer(value),
        ($0.LoginStartResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LoginFinishRequest, $0.AuthResponse>(
        'LoginFinish',
        loginFinish_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.LoginFinishRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LogoutRequest, $0.LogoutResponse>(
        'Logout',
        logout_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LogoutRequest.fromBuffer(value),
        ($0.LogoutResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AddPasskeyStartRequest,
            $0.AddPasskeyStartResponse>(
        'AddPasskeyStart',
        addPasskeyStart_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AddPasskeyStartRequest.fromBuffer(value),
        ($0.AddPasskeyStartResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AddPasskeyFinishRequest,
            $0.AddPasskeyFinishResponse>(
        'AddPasskeyFinish',
        addPasskeyFinish_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AddPasskeyFinishRequest.fromBuffer(value),
        ($0.AddPasskeyFinishResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.DeletePasskeyRequest, $0.DeletePasskeyResponse>(
            'DeletePasskey',
            deletePasskey_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.DeletePasskeyRequest.fromBuffer(value),
            ($0.DeletePasskeyResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListPasskeysRequest, $0.ListPasskeysResponse>(
            'ListPasskeys',
            listPasskeys_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListPasskeysRequest.fromBuffer(value),
            ($0.ListPasskeysResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PasswordRegisterRequest, $0.AuthResponse>(
        'PasswordRegister',
        passwordRegister_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.PasswordRegisterRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PasswordLoginRequest, $0.AuthResponse>(
        'PasswordLogin',
        passwordLogin_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.PasswordLoginRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TestLoginRequest, $0.AuthResponse>(
        'TestLogin',
        testLogin_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TestLoginRequest.fromBuffer(value),
        ($0.AuthResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.RegisterStartResponse> registerStart_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RegisterStartRequest> $request) async {
    return registerStart($call, await $request);
  }

  $async.Future<$0.RegisterStartResponse> registerStart(
      $grpc.ServiceCall call, $0.RegisterStartRequest request);

  $async.Future<$0.AuthResponse> registerFinish_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RegisterFinishRequest> $request) async {
    return registerFinish($call, await $request);
  }

  $async.Future<$0.AuthResponse> registerFinish(
      $grpc.ServiceCall call, $0.RegisterFinishRequest request);

  $async.Future<$0.LoginStartResponse> loginStart_Pre($grpc.ServiceCall $call,
      $async.Future<$0.LoginStartRequest> $request) async {
    return loginStart($call, await $request);
  }

  $async.Future<$0.LoginStartResponse> loginStart(
      $grpc.ServiceCall call, $0.LoginStartRequest request);

  $async.Future<$0.AuthResponse> loginFinish_Pre($grpc.ServiceCall $call,
      $async.Future<$0.LoginFinishRequest> $request) async {
    return loginFinish($call, await $request);
  }

  $async.Future<$0.AuthResponse> loginFinish(
      $grpc.ServiceCall call, $0.LoginFinishRequest request);

  $async.Future<$0.LogoutResponse> logout_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.LogoutRequest> $request) async {
    return logout($call, await $request);
  }

  $async.Future<$0.LogoutResponse> logout(
      $grpc.ServiceCall call, $0.LogoutRequest request);

  $async.Future<$0.AddPasskeyStartResponse> addPasskeyStart_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AddPasskeyStartRequest> $request) async {
    return addPasskeyStart($call, await $request);
  }

  $async.Future<$0.AddPasskeyStartResponse> addPasskeyStart(
      $grpc.ServiceCall call, $0.AddPasskeyStartRequest request);

  $async.Future<$0.AddPasskeyFinishResponse> addPasskeyFinish_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AddPasskeyFinishRequest> $request) async {
    return addPasskeyFinish($call, await $request);
  }

  $async.Future<$0.AddPasskeyFinishResponse> addPasskeyFinish(
      $grpc.ServiceCall call, $0.AddPasskeyFinishRequest request);

  $async.Future<$0.DeletePasskeyResponse> deletePasskey_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeletePasskeyRequest> $request) async {
    return deletePasskey($call, await $request);
  }

  $async.Future<$0.DeletePasskeyResponse> deletePasskey(
      $grpc.ServiceCall call, $0.DeletePasskeyRequest request);

  $async.Future<$0.ListPasskeysResponse> listPasskeys_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListPasskeysRequest> $request) async {
    return listPasskeys($call, await $request);
  }

  $async.Future<$0.ListPasskeysResponse> listPasskeys(
      $grpc.ServiceCall call, $0.ListPasskeysRequest request);

  $async.Future<$0.AuthResponse> passwordRegister_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PasswordRegisterRequest> $request) async {
    return passwordRegister($call, await $request);
  }

  $async.Future<$0.AuthResponse> passwordRegister(
      $grpc.ServiceCall call, $0.PasswordRegisterRequest request);

  $async.Future<$0.AuthResponse> passwordLogin_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PasswordLoginRequest> $request) async {
    return passwordLogin($call, await $request);
  }

  $async.Future<$0.AuthResponse> passwordLogin(
      $grpc.ServiceCall call, $0.PasswordLoginRequest request);

  $async.Future<$0.AuthResponse> testLogin_Pre($grpc.ServiceCall $call,
      $async.Future<$0.TestLoginRequest> $request) async {
    return testLogin($call, await $request);
  }

  $async.Future<$0.AuthResponse> testLogin(
      $grpc.ServiceCall call, $0.TestLoginRequest request);
}
