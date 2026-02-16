// This is a generated file - do not edit.
//
// Generated from workout/v1/group.proto.

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

import 'group.pb.dart' as $0;

export 'group.pb.dart';

@$pb.GrpcServiceName('workout.v1.MultiplayerService')
class MultiplayerServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  MultiplayerServiceClient(super.channel, {super.options, super.interceptors});

  /// Join a session by providing the user ID of someone already in (or starting) that session.
  /// If the target user is not in a session, a new session is created for both.
  $grpc.ResponseFuture<$0.JoinUserResponse> joinUser(
    $0.JoinUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$joinUser, request, options: options);
  }

  $grpc.ResponseFuture<$0.LeaveSessionResponse> leaveSession(
    $0.LeaveSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$leaveSession, request, options: options);
  }

  /// Get a specific participant's workout progress
  $grpc.ResponseFuture<$0.ParticipantStatus> getParticipantWorkout(
    $0.GetParticipantWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getParticipantWorkout, request, options: options);
  }

  /// Consolidated call: Get the current active session and its status for the user,
  /// OR get a specific session's status if session_id is provided.
  $grpc.ResponseFuture<$0.GetCurrentSessionResponse> getCurrentSession(
    $0.GetCurrentSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCurrentSession, request, options: options);
  }

  /// Update the active workout for the current user's session
  $grpc.ResponseFuture<$0.UpdateActiveWorkoutResponse> updateActiveWorkout(
    $0.UpdateActiveWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateActiveWorkout, request, options: options);
  }

  // method descriptors

  static final _$joinUser =
      $grpc.ClientMethod<$0.JoinUserRequest, $0.JoinUserResponse>(
          '/workout.v1.MultiplayerService/JoinUser',
          ($0.JoinUserRequest value) => value.writeToBuffer(),
          $0.JoinUserResponse.fromBuffer);
  static final _$leaveSession =
      $grpc.ClientMethod<$0.LeaveSessionRequest, $0.LeaveSessionResponse>(
          '/workout.v1.MultiplayerService/LeaveSession',
          ($0.LeaveSessionRequest value) => value.writeToBuffer(),
          $0.LeaveSessionResponse.fromBuffer);
  static final _$getParticipantWorkout =
      $grpc.ClientMethod<$0.GetParticipantWorkoutRequest, $0.ParticipantStatus>(
          '/workout.v1.MultiplayerService/GetParticipantWorkout',
          ($0.GetParticipantWorkoutRequest value) => value.writeToBuffer(),
          $0.ParticipantStatus.fromBuffer);
  static final _$getCurrentSession = $grpc.ClientMethod<
          $0.GetCurrentSessionRequest, $0.GetCurrentSessionResponse>(
      '/workout.v1.MultiplayerService/GetCurrentSession',
      ($0.GetCurrentSessionRequest value) => value.writeToBuffer(),
      $0.GetCurrentSessionResponse.fromBuffer);
  static final _$updateActiveWorkout = $grpc.ClientMethod<
          $0.UpdateActiveWorkoutRequest, $0.UpdateActiveWorkoutResponse>(
      '/workout.v1.MultiplayerService/UpdateActiveWorkout',
      ($0.UpdateActiveWorkoutRequest value) => value.writeToBuffer(),
      $0.UpdateActiveWorkoutResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.MultiplayerService')
abstract class MultiplayerServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.MultiplayerService';

  MultiplayerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.JoinUserRequest, $0.JoinUserResponse>(
        'JoinUser',
        joinUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.JoinUserRequest.fromBuffer(value),
        ($0.JoinUserResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.LeaveSessionRequest, $0.LeaveSessionResponse>(
            'LeaveSession',
            leaveSession_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.LeaveSessionRequest.fromBuffer(value),
            ($0.LeaveSessionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetParticipantWorkoutRequest,
            $0.ParticipantStatus>(
        'GetParticipantWorkout',
        getParticipantWorkout_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetParticipantWorkoutRequest.fromBuffer(value),
        ($0.ParticipantStatus value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetCurrentSessionRequest,
            $0.GetCurrentSessionResponse>(
        'GetCurrentSession',
        getCurrentSession_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetCurrentSessionRequest.fromBuffer(value),
        ($0.GetCurrentSessionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateActiveWorkoutRequest,
            $0.UpdateActiveWorkoutResponse>(
        'UpdateActiveWorkout',
        updateActiveWorkout_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateActiveWorkoutRequest.fromBuffer(value),
        ($0.UpdateActiveWorkoutResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.JoinUserResponse> joinUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.JoinUserRequest> $request) async {
    return joinUser($call, await $request);
  }

  $async.Future<$0.JoinUserResponse> joinUser(
      $grpc.ServiceCall call, $0.JoinUserRequest request);

  $async.Future<$0.LeaveSessionResponse> leaveSession_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.LeaveSessionRequest> $request) async {
    return leaveSession($call, await $request);
  }

  $async.Future<$0.LeaveSessionResponse> leaveSession(
      $grpc.ServiceCall call, $0.LeaveSessionRequest request);

  $async.Future<$0.ParticipantStatus> getParticipantWorkout_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetParticipantWorkoutRequest> $request) async {
    return getParticipantWorkout($call, await $request);
  }

  $async.Future<$0.ParticipantStatus> getParticipantWorkout(
      $grpc.ServiceCall call, $0.GetParticipantWorkoutRequest request);

  $async.Future<$0.GetCurrentSessionResponse> getCurrentSession_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetCurrentSessionRequest> $request) async {
    return getCurrentSession($call, await $request);
  }

  $async.Future<$0.GetCurrentSessionResponse> getCurrentSession(
      $grpc.ServiceCall call, $0.GetCurrentSessionRequest request);

  $async.Future<$0.UpdateActiveWorkoutResponse> updateActiveWorkout_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateActiveWorkoutRequest> $request) async {
    return updateActiveWorkout($call, await $request);
  }

  $async.Future<$0.UpdateActiveWorkoutResponse> updateActiveWorkout(
      $grpc.ServiceCall call, $0.UpdateActiveWorkoutRequest request);
}
