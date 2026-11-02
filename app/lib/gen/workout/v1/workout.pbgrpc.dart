// This is a generated file - do not edit.
//
// Generated from workout/v1/workout.proto.

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

import 'workout.pb.dart' as $0;

export 'workout.pb.dart';

/// What the server answers about workouts: reads for the web, from the
/// account the phone syncs. Every write is an Event (account.proto), made on
/// the phone by the core and synced.
@$pb.GrpcServiceName('workout.v1.WorkoutService')
class WorkoutServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  WorkoutServiceClient(super.channel, {super.options, super.interceptors});

  /// Finished workouts with their summaries (history).
  $grpc.ResponseFuture<$0.ListWorkoutSummariesResponse> listWorkoutSummaries(
    $0.ListWorkoutSummariesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listWorkoutSummaries, request, options: options);
  }

  /// Per-exercise progress series, everything precomputed.
  $grpc.ResponseFuture<$0.GetExerciseProgressResponse> getExerciseProgress(
    $0.GetExerciseProgressRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getExerciseProgress, request, options: options);
  }

  // method descriptors

  static final _$listWorkoutSummaries = $grpc.ClientMethod<
          $0.ListWorkoutSummariesRequest, $0.ListWorkoutSummariesResponse>(
      '/workout.v1.WorkoutService/ListWorkoutSummaries',
      ($0.ListWorkoutSummariesRequest value) => value.writeToBuffer(),
      $0.ListWorkoutSummariesResponse.fromBuffer);
  static final _$getExerciseProgress = $grpc.ClientMethod<
          $0.GetExerciseProgressRequest, $0.GetExerciseProgressResponse>(
      '/workout.v1.WorkoutService/GetExerciseProgress',
      ($0.GetExerciseProgressRequest value) => value.writeToBuffer(),
      $0.GetExerciseProgressResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.WorkoutService')
abstract class WorkoutServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.WorkoutService';

  WorkoutServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ListWorkoutSummariesRequest,
            $0.ListWorkoutSummariesResponse>(
        'ListWorkoutSummaries',
        listWorkoutSummaries_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListWorkoutSummariesRequest.fromBuffer(value),
        ($0.ListWorkoutSummariesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetExerciseProgressRequest,
            $0.GetExerciseProgressResponse>(
        'GetExerciseProgress',
        getExerciseProgress_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetExerciseProgressRequest.fromBuffer(value),
        ($0.GetExerciseProgressResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ListWorkoutSummariesResponse> listWorkoutSummaries_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListWorkoutSummariesRequest> $request) async {
    return listWorkoutSummaries($call, await $request);
  }

  $async.Future<$0.ListWorkoutSummariesResponse> listWorkoutSummaries(
      $grpc.ServiceCall call, $0.ListWorkoutSummariesRequest request);

  $async.Future<$0.GetExerciseProgressResponse> getExerciseProgress_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetExerciseProgressRequest> $request) async {
    return getExerciseProgress($call, await $request);
  }

  $async.Future<$0.GetExerciseProgressResponse> getExerciseProgress(
      $grpc.ServiceCall call, $0.GetExerciseProgressRequest request);
}

@$pb.GrpcServiceName('workout.v1.UserService')
class UserServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  UserServiceClient(super.channel, {super.options, super.interceptors});

  /// The authenticated user.
  $grpc.ResponseFuture<$0.GetUserResponse> getUser(
    $0.GetUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUser, request, options: options);
  }

  /// Update the authenticated user's profile metadata.
  $grpc.ResponseFuture<$0.UpdateMyProfileResponse> updateMyProfile(
    $0.UpdateMyProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateMyProfile, request, options: options);
  }

  // method descriptors

  static final _$getUser =
      $grpc.ClientMethod<$0.GetUserRequest, $0.GetUserResponse>(
          '/workout.v1.UserService/GetUser',
          ($0.GetUserRequest value) => value.writeToBuffer(),
          $0.GetUserResponse.fromBuffer);
  static final _$updateMyProfile =
      $grpc.ClientMethod<$0.UpdateMyProfileRequest, $0.UpdateMyProfileResponse>(
          '/workout.v1.UserService/UpdateMyProfile',
          ($0.UpdateMyProfileRequest value) => value.writeToBuffer(),
          $0.UpdateMyProfileResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.UserService')
abstract class UserServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.UserService';

  UserServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetUserRequest, $0.GetUserResponse>(
        'GetUser',
        getUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetUserRequest.fromBuffer(value),
        ($0.GetUserResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateMyProfileRequest,
            $0.UpdateMyProfileResponse>(
        'UpdateMyProfile',
        updateMyProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateMyProfileRequest.fromBuffer(value),
        ($0.UpdateMyProfileResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetUserResponse> getUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetUserRequest> $request) async {
    return getUser($call, await $request);
  }

  $async.Future<$0.GetUserResponse> getUser(
      $grpc.ServiceCall call, $0.GetUserRequest request);

  $async.Future<$0.UpdateMyProfileResponse> updateMyProfile_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateMyProfileRequest> $request) async {
    return updateMyProfile($call, await $request);
  }

  $async.Future<$0.UpdateMyProfileResponse> updateMyProfile(
      $grpc.ServiceCall call, $0.UpdateMyProfileRequest request);
}
