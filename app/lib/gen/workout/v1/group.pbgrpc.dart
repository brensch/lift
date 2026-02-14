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

  /// Start a new session
  $grpc.ResponseFuture<$0.StartSessionResponse> startSession(
    $0.StartSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$startSession, request, options: options);
  }

  /// Join someone's session via a session ID
  $grpc.ResponseFuture<$0.JoinSessionResponse> joinSession(
    $0.JoinSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$joinSession, request, options: options);
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

  static final _$startSession =
      $grpc.ClientMethod<$0.StartSessionRequest, $0.StartSessionResponse>(
          '/workout.v1.MultiplayerService/StartSession',
          ($0.StartSessionRequest value) => value.writeToBuffer(),
          $0.StartSessionResponse.fromBuffer);
  static final _$joinSession =
      $grpc.ClientMethod<$0.JoinSessionRequest, $0.JoinSessionResponse>(
          '/workout.v1.MultiplayerService/JoinSession',
          ($0.JoinSessionRequest value) => value.writeToBuffer(),
          $0.JoinSessionResponse.fromBuffer);
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
    $addMethod(
        $grpc.ServiceMethod<$0.StartSessionRequest, $0.StartSessionResponse>(
            'StartSession',
            startSession_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.StartSessionRequest.fromBuffer(value),
            ($0.StartSessionResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.JoinSessionRequest, $0.JoinSessionResponse>(
            'JoinSession',
            joinSession_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.JoinSessionRequest.fromBuffer(value),
            ($0.JoinSessionResponse value) => value.writeToBuffer()));
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

  $async.Future<$0.StartSessionResponse> startSession_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.StartSessionRequest> $request) async {
    return startSession($call, await $request);
  }

  $async.Future<$0.StartSessionResponse> startSession(
      $grpc.ServiceCall call, $0.StartSessionRequest request);

  $async.Future<$0.JoinSessionResponse> joinSession_Pre($grpc.ServiceCall $call,
      $async.Future<$0.JoinSessionRequest> $request) async {
    return joinSession($call, await $request);
  }

  $async.Future<$0.JoinSessionResponse> joinSession(
      $grpc.ServiceCall call, $0.JoinSessionRequest request);

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
