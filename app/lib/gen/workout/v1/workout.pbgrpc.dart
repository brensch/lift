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

@$pb.GrpcServiceName('workout.v1.WorkoutService')
class WorkoutServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  WorkoutServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.StartWorkoutResponse> startWorkout(
    $0.StartWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$startWorkout, request, options: options);
  }

  $grpc.ResponseFuture<$0.EndWorkoutResponse> endWorkout(
    $0.EndWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$endWorkout, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetWorkoutResponse> getWorkout(
    $0.GetWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getWorkout, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetActiveWorkoutResponse> getActiveWorkout(
    $0.GetActiveWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getActiveWorkout, request, options: options);
  }

  /// List all workouts for the user (user from auth context)
  $grpc.ResponseFuture<$0.ListWorkoutsResponse> listWorkouts(
    $0.ListWorkoutsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listWorkouts, request, options: options);
  }

  /// Update the proposed sets for a workout. The user has to send all proposed sets.
  $grpc.ResponseFuture<$0.ModifyProposedSetsResponse> modifyProposedSets(
    $0.ModifyProposedSetsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$modifyProposedSets, request, options: options);
  }

  $grpc.ResponseFuture<$0.StartSetResponse> startSet(
    $0.StartSetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$startSet, request, options: options);
  }

  $grpc.ResponseFuture<$0.CompleteSetResponse> completeSet(
    $0.CompleteSetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$completeSet, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteCompletedSetResponse> deleteCompletedSet(
    $0.DeleteCompletedSetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteCompletedSet, request, options: options);
  }

  /// Get the next scheduled workouts for the user according to preferences and weight progression etc
  $grpc.ResponseFuture<$0.GetProposedWorkoutScheduleResponse>
      getProposedWorkoutSchedule(
    $0.GetProposedWorkoutScheduleRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getProposedWorkoutSchedule, request,
        options: options);
  }

  // method descriptors

  static final _$startWorkout =
      $grpc.ClientMethod<$0.StartWorkoutRequest, $0.StartWorkoutResponse>(
          '/workout.v1.WorkoutService/StartWorkout',
          ($0.StartWorkoutRequest value) => value.writeToBuffer(),
          $0.StartWorkoutResponse.fromBuffer);
  static final _$endWorkout =
      $grpc.ClientMethod<$0.EndWorkoutRequest, $0.EndWorkoutResponse>(
          '/workout.v1.WorkoutService/EndWorkout',
          ($0.EndWorkoutRequest value) => value.writeToBuffer(),
          $0.EndWorkoutResponse.fromBuffer);
  static final _$getWorkout =
      $grpc.ClientMethod<$0.GetWorkoutRequest, $0.GetWorkoutResponse>(
          '/workout.v1.WorkoutService/GetWorkout',
          ($0.GetWorkoutRequest value) => value.writeToBuffer(),
          $0.GetWorkoutResponse.fromBuffer);
  static final _$getActiveWorkout = $grpc.ClientMethod<
          $0.GetActiveWorkoutRequest, $0.GetActiveWorkoutResponse>(
      '/workout.v1.WorkoutService/GetActiveWorkout',
      ($0.GetActiveWorkoutRequest value) => value.writeToBuffer(),
      $0.GetActiveWorkoutResponse.fromBuffer);
  static final _$listWorkouts =
      $grpc.ClientMethod<$0.ListWorkoutsRequest, $0.ListWorkoutsResponse>(
          '/workout.v1.WorkoutService/ListWorkouts',
          ($0.ListWorkoutsRequest value) => value.writeToBuffer(),
          $0.ListWorkoutsResponse.fromBuffer);
  static final _$modifyProposedSets = $grpc.ClientMethod<
          $0.ModifyProposedSetsRequest, $0.ModifyProposedSetsResponse>(
      '/workout.v1.WorkoutService/ModifyProposedSets',
      ($0.ModifyProposedSetsRequest value) => value.writeToBuffer(),
      $0.ModifyProposedSetsResponse.fromBuffer);
  static final _$startSet =
      $grpc.ClientMethod<$0.StartSetRequest, $0.StartSetResponse>(
          '/workout.v1.WorkoutService/StartSet',
          ($0.StartSetRequest value) => value.writeToBuffer(),
          $0.StartSetResponse.fromBuffer);
  static final _$completeSet =
      $grpc.ClientMethod<$0.CompleteSetRequest, $0.CompleteSetResponse>(
          '/workout.v1.WorkoutService/CompleteSet',
          ($0.CompleteSetRequest value) => value.writeToBuffer(),
          $0.CompleteSetResponse.fromBuffer);
  static final _$deleteCompletedSet = $grpc.ClientMethod<
          $0.DeleteCompletedSetRequest, $0.DeleteCompletedSetResponse>(
      '/workout.v1.WorkoutService/DeleteCompletedSet',
      ($0.DeleteCompletedSetRequest value) => value.writeToBuffer(),
      $0.DeleteCompletedSetResponse.fromBuffer);
  static final _$getProposedWorkoutSchedule = $grpc.ClientMethod<
          $0.GetProposedWorkoutScheduleRequest,
          $0.GetProposedWorkoutScheduleResponse>(
      '/workout.v1.WorkoutService/GetProposedWorkoutSchedule',
      ($0.GetProposedWorkoutScheduleRequest value) => value.writeToBuffer(),
      $0.GetProposedWorkoutScheduleResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.WorkoutService')
abstract class WorkoutServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.WorkoutService';

  WorkoutServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.StartWorkoutRequest, $0.StartWorkoutResponse>(
            'StartWorkout',
            startWorkout_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.StartWorkoutRequest.fromBuffer(value),
            ($0.StartWorkoutResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.EndWorkoutRequest, $0.EndWorkoutResponse>(
        'EndWorkout',
        endWorkout_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.EndWorkoutRequest.fromBuffer(value),
        ($0.EndWorkoutResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetWorkoutRequest, $0.GetWorkoutResponse>(
        'GetWorkout',
        getWorkout_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetWorkoutRequest.fromBuffer(value),
        ($0.GetWorkoutResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetActiveWorkoutRequest,
            $0.GetActiveWorkoutResponse>(
        'GetActiveWorkout',
        getActiveWorkout_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetActiveWorkoutRequest.fromBuffer(value),
        ($0.GetActiveWorkoutResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListWorkoutsRequest, $0.ListWorkoutsResponse>(
            'ListWorkouts',
            listWorkouts_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListWorkoutsRequest.fromBuffer(value),
            ($0.ListWorkoutsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ModifyProposedSetsRequest,
            $0.ModifyProposedSetsResponse>(
        'ModifyProposedSets',
        modifyProposedSets_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ModifyProposedSetsRequest.fromBuffer(value),
        ($0.ModifyProposedSetsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.StartSetRequest, $0.StartSetResponse>(
        'StartSet',
        startSet_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.StartSetRequest.fromBuffer(value),
        ($0.StartSetResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.CompleteSetRequest, $0.CompleteSetResponse>(
            'CompleteSet',
            completeSet_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CompleteSetRequest.fromBuffer(value),
            ($0.CompleteSetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteCompletedSetRequest,
            $0.DeleteCompletedSetResponse>(
        'DeleteCompletedSet',
        deleteCompletedSet_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteCompletedSetRequest.fromBuffer(value),
        ($0.DeleteCompletedSetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetProposedWorkoutScheduleRequest,
            $0.GetProposedWorkoutScheduleResponse>(
        'GetProposedWorkoutSchedule',
        getProposedWorkoutSchedule_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetProposedWorkoutScheduleRequest.fromBuffer(value),
        ($0.GetProposedWorkoutScheduleResponse value) =>
            value.writeToBuffer()));
  }

  $async.Future<$0.StartWorkoutResponse> startWorkout_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.StartWorkoutRequest> $request) async {
    return startWorkout($call, await $request);
  }

  $async.Future<$0.StartWorkoutResponse> startWorkout(
      $grpc.ServiceCall call, $0.StartWorkoutRequest request);

  $async.Future<$0.EndWorkoutResponse> endWorkout_Pre($grpc.ServiceCall $call,
      $async.Future<$0.EndWorkoutRequest> $request) async {
    return endWorkout($call, await $request);
  }

  $async.Future<$0.EndWorkoutResponse> endWorkout(
      $grpc.ServiceCall call, $0.EndWorkoutRequest request);

  $async.Future<$0.GetWorkoutResponse> getWorkout_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetWorkoutRequest> $request) async {
    return getWorkout($call, await $request);
  }

  $async.Future<$0.GetWorkoutResponse> getWorkout(
      $grpc.ServiceCall call, $0.GetWorkoutRequest request);

  $async.Future<$0.GetActiveWorkoutResponse> getActiveWorkout_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetActiveWorkoutRequest> $request) async {
    return getActiveWorkout($call, await $request);
  }

  $async.Future<$0.GetActiveWorkoutResponse> getActiveWorkout(
      $grpc.ServiceCall call, $0.GetActiveWorkoutRequest request);

  $async.Future<$0.ListWorkoutsResponse> listWorkouts_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListWorkoutsRequest> $request) async {
    return listWorkouts($call, await $request);
  }

  $async.Future<$0.ListWorkoutsResponse> listWorkouts(
      $grpc.ServiceCall call, $0.ListWorkoutsRequest request);

  $async.Future<$0.ModifyProposedSetsResponse> modifyProposedSets_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ModifyProposedSetsRequest> $request) async {
    return modifyProposedSets($call, await $request);
  }

  $async.Future<$0.ModifyProposedSetsResponse> modifyProposedSets(
      $grpc.ServiceCall call, $0.ModifyProposedSetsRequest request);

  $async.Future<$0.StartSetResponse> startSet_Pre($grpc.ServiceCall $call,
      $async.Future<$0.StartSetRequest> $request) async {
    return startSet($call, await $request);
  }

  $async.Future<$0.StartSetResponse> startSet(
      $grpc.ServiceCall call, $0.StartSetRequest request);

  $async.Future<$0.CompleteSetResponse> completeSet_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CompleteSetRequest> $request) async {
    return completeSet($call, await $request);
  }

  $async.Future<$0.CompleteSetResponse> completeSet(
      $grpc.ServiceCall call, $0.CompleteSetRequest request);

  $async.Future<$0.DeleteCompletedSetResponse> deleteCompletedSet_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteCompletedSetRequest> $request) async {
    return deleteCompletedSet($call, await $request);
  }

  $async.Future<$0.DeleteCompletedSetResponse> deleteCompletedSet(
      $grpc.ServiceCall call, $0.DeleteCompletedSetRequest request);

  $async.Future<$0.GetProposedWorkoutScheduleResponse>
      getProposedWorkoutSchedule_Pre($grpc.ServiceCall $call,
          $async.Future<$0.GetProposedWorkoutScheduleRequest> $request) async {
    return getProposedWorkoutSchedule($call, await $request);
  }

  $async.Future<$0.GetProposedWorkoutScheduleResponse>
      getProposedWorkoutSchedule(
          $grpc.ServiceCall call, $0.GetProposedWorkoutScheduleRequest request);
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

  /// Create a new user
  $grpc.ResponseFuture<$0.CreateUserResponse> createUser(
    $0.CreateUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createUser, request, options: options);
  }

  /// Get user by ID
  $grpc.ResponseFuture<$0.GetUserResponse> getUser(
    $0.GetUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUser, request, options: options);
  }

  // method descriptors

  static final _$createUser =
      $grpc.ClientMethod<$0.CreateUserRequest, $0.CreateUserResponse>(
          '/workout.v1.UserService/CreateUser',
          ($0.CreateUserRequest value) => value.writeToBuffer(),
          $0.CreateUserResponse.fromBuffer);
  static final _$getUser =
      $grpc.ClientMethod<$0.GetUserRequest, $0.GetUserResponse>(
          '/workout.v1.UserService/GetUser',
          ($0.GetUserRequest value) => value.writeToBuffer(),
          $0.GetUserResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.UserService')
abstract class UserServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.UserService';

  UserServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateUserRequest, $0.CreateUserResponse>(
        'CreateUser',
        createUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateUserRequest.fromBuffer(value),
        ($0.CreateUserResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetUserRequest, $0.GetUserResponse>(
        'GetUser',
        getUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetUserRequest.fromBuffer(value),
        ($0.GetUserResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreateUserResponse> createUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateUserRequest> $request) async {
    return createUser($call, await $request);
  }

  $async.Future<$0.CreateUserResponse> createUser(
      $grpc.ServiceCall call, $0.CreateUserRequest request);

  $async.Future<$0.GetUserResponse> getUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetUserRequest> $request) async {
    return getUser($call, await $request);
  }

  $async.Future<$0.GetUserResponse> getUser(
      $grpc.ServiceCall call, $0.GetUserRequest request);
}
