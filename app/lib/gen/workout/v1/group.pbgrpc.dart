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

  /// Join the group identified by an opaque per-user invite token (the value encoded in
  /// the target user's QR code). Resolves the token to the target user, then places both
  /// the caller and target into the same session (reusing the target's current session if
  /// present, otherwise creating a new one). Overwrites the caller's current session.
  $grpc.ResponseFuture<$0.JoinViaInviteResponse> joinViaInvite(
    $0.JoinViaInviteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$joinViaInvite, request, options: options);
  }

  /// Fetch the caller's invite token so the client can render it into a QR code. If the
  /// caller has none yet, one is generated.
  $grpc.ResponseFuture<$0.GetMyInviteTokenResponse> getMyInviteToken(
    $0.GetMyInviteTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMyInviteToken, request, options: options);
  }

  /// Rotate the caller's invite token (invalidates any previously-shared QR code).
  $grpc.ResponseFuture<$0.RotateInviteTokenResponse> rotateInviteToken(
    $0.RotateInviteTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$rotateInviteToken, request, options: options);
  }

  /// Get a specific participant's workout progress
  $grpc.ResponseFuture<$0.ParticipantStatus> getParticipantWorkout(
    $0.GetParticipantWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getParticipantWorkout, request, options: options);
  }

  /// Get the caller's current group session. Reads user_current_session — membership is
  /// independent of whether the caller has an active workout.
  $grpc.ResponseFuture<$0.GetCurrentSessionResponse> getCurrentSession(
    $0.GetCurrentSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCurrentSession, request, options: options);
  }

  /// Manually leave the caller's current session. Keeps the caller's last participant blob
  /// so peers in the session still see their historical state.
  $grpc.ResponseFuture<$0.LeaveCurrentSessionResponse> leaveCurrentSession(
    $0.LeaveCurrentSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$leaveCurrentSession, request, options: options);
  }

  /// Fetch every participant snapshot ever recorded for a specific session.
  /// Used for historical views (e.g. "who was in this past workout's session").
  $grpc.ResponseFuture<$0.GetSessionParticipantsResponse>
      getSessionParticipants(
    $0.GetSessionParticipantsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSessionParticipants, request,
        options: options);
  }

  /// Subscribe to live updates for a current multiplayer session.
  /// The server always emits a full snapshot immediately after subscribe.
  $grpc.ResponseStream<$0.SessionSubscriptionEvent> subscribeSession(
    $0.SubscribeSessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$subscribeSession, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Refresh the caller's participant snapshot in the session cache.
  $grpc.ResponseFuture<$0.UpdateActiveWorkoutResponse> updateActiveWorkout(
    $0.UpdateActiveWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateActiveWorkout, request, options: options);
  }

  // method descriptors

  static final _$joinViaInvite =
      $grpc.ClientMethod<$0.JoinViaInviteRequest, $0.JoinViaInviteResponse>(
          '/workout.v1.MultiplayerService/JoinViaInvite',
          ($0.JoinViaInviteRequest value) => value.writeToBuffer(),
          $0.JoinViaInviteResponse.fromBuffer);
  static final _$getMyInviteToken = $grpc.ClientMethod<
          $0.GetMyInviteTokenRequest, $0.GetMyInviteTokenResponse>(
      '/workout.v1.MultiplayerService/GetMyInviteToken',
      ($0.GetMyInviteTokenRequest value) => value.writeToBuffer(),
      $0.GetMyInviteTokenResponse.fromBuffer);
  static final _$rotateInviteToken = $grpc.ClientMethod<
          $0.RotateInviteTokenRequest, $0.RotateInviteTokenResponse>(
      '/workout.v1.MultiplayerService/RotateInviteToken',
      ($0.RotateInviteTokenRequest value) => value.writeToBuffer(),
      $0.RotateInviteTokenResponse.fromBuffer);
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
  static final _$leaveCurrentSession = $grpc.ClientMethod<
          $0.LeaveCurrentSessionRequest, $0.LeaveCurrentSessionResponse>(
      '/workout.v1.MultiplayerService/LeaveCurrentSession',
      ($0.LeaveCurrentSessionRequest value) => value.writeToBuffer(),
      $0.LeaveCurrentSessionResponse.fromBuffer);
  static final _$getSessionParticipants = $grpc.ClientMethod<
          $0.GetSessionParticipantsRequest, $0.GetSessionParticipantsResponse>(
      '/workout.v1.MultiplayerService/GetSessionParticipants',
      ($0.GetSessionParticipantsRequest value) => value.writeToBuffer(),
      $0.GetSessionParticipantsResponse.fromBuffer);
  static final _$subscribeSession = $grpc.ClientMethod<
          $0.SubscribeSessionRequest, $0.SessionSubscriptionEvent>(
      '/workout.v1.MultiplayerService/SubscribeSession',
      ($0.SubscribeSessionRequest value) => value.writeToBuffer(),
      $0.SessionSubscriptionEvent.fromBuffer);
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
        $grpc.ServiceMethod<$0.JoinViaInviteRequest, $0.JoinViaInviteResponse>(
            'JoinViaInvite',
            joinViaInvite_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.JoinViaInviteRequest.fromBuffer(value),
            ($0.JoinViaInviteResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetMyInviteTokenRequest,
            $0.GetMyInviteTokenResponse>(
        'GetMyInviteToken',
        getMyInviteToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetMyInviteTokenRequest.fromBuffer(value),
        ($0.GetMyInviteTokenResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RotateInviteTokenRequest,
            $0.RotateInviteTokenResponse>(
        'RotateInviteToken',
        rotateInviteToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RotateInviteTokenRequest.fromBuffer(value),
        ($0.RotateInviteTokenResponse value) => value.writeToBuffer()));
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
    $addMethod($grpc.ServiceMethod<$0.LeaveCurrentSessionRequest,
            $0.LeaveCurrentSessionResponse>(
        'LeaveCurrentSession',
        leaveCurrentSession_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.LeaveCurrentSessionRequest.fromBuffer(value),
        ($0.LeaveCurrentSessionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetSessionParticipantsRequest,
            $0.GetSessionParticipantsResponse>(
        'GetSessionParticipants',
        getSessionParticipants_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetSessionParticipantsRequest.fromBuffer(value),
        ($0.GetSessionParticipantsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SubscribeSessionRequest,
            $0.SessionSubscriptionEvent>(
        'SubscribeSession',
        subscribeSession_Pre,
        false,
        true,
        ($core.List<$core.int> value) =>
            $0.SubscribeSessionRequest.fromBuffer(value),
        ($0.SessionSubscriptionEvent value) => value.writeToBuffer()));
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

  $async.Future<$0.JoinViaInviteResponse> joinViaInvite_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.JoinViaInviteRequest> $request) async {
    return joinViaInvite($call, await $request);
  }

  $async.Future<$0.JoinViaInviteResponse> joinViaInvite(
      $grpc.ServiceCall call, $0.JoinViaInviteRequest request);

  $async.Future<$0.GetMyInviteTokenResponse> getMyInviteToken_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetMyInviteTokenRequest> $request) async {
    return getMyInviteToken($call, await $request);
  }

  $async.Future<$0.GetMyInviteTokenResponse> getMyInviteToken(
      $grpc.ServiceCall call, $0.GetMyInviteTokenRequest request);

  $async.Future<$0.RotateInviteTokenResponse> rotateInviteToken_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RotateInviteTokenRequest> $request) async {
    return rotateInviteToken($call, await $request);
  }

  $async.Future<$0.RotateInviteTokenResponse> rotateInviteToken(
      $grpc.ServiceCall call, $0.RotateInviteTokenRequest request);

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

  $async.Future<$0.LeaveCurrentSessionResponse> leaveCurrentSession_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.LeaveCurrentSessionRequest> $request) async {
    return leaveCurrentSession($call, await $request);
  }

  $async.Future<$0.LeaveCurrentSessionResponse> leaveCurrentSession(
      $grpc.ServiceCall call, $0.LeaveCurrentSessionRequest request);

  $async.Future<$0.GetSessionParticipantsResponse> getSessionParticipants_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetSessionParticipantsRequest> $request) async {
    return getSessionParticipants($call, await $request);
  }

  $async.Future<$0.GetSessionParticipantsResponse> getSessionParticipants(
      $grpc.ServiceCall call, $0.GetSessionParticipantsRequest request);

  $async.Stream<$0.SessionSubscriptionEvent> subscribeSession_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SubscribeSessionRequest> $request) async* {
    yield* subscribeSession($call, await $request);
  }

  $async.Stream<$0.SessionSubscriptionEvent> subscribeSession(
      $grpc.ServiceCall call, $0.SubscribeSessionRequest request);

  $async.Future<$0.UpdateActiveWorkoutResponse> updateActiveWorkout_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateActiveWorkoutRequest> $request) async {
    return updateActiveWorkout($call, await $request);
  }

  $async.Future<$0.UpdateActiveWorkoutResponse> updateActiveWorkout(
      $grpc.ServiceCall call, $0.UpdateActiveWorkoutRequest request);
}
