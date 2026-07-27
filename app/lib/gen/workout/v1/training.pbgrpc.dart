// This is a generated file - do not edit.
//
// Generated from workout/v1/training.proto.

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

import 'training.pb.dart' as $0;

export 'training.pb.dart';

@$pb.GrpcServiceName('workout.v1.TrainingService')
class TrainingServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TrainingServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.WorkoutView> createWorkout(
    $0.CreateWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createWorkout, request, options: options);
  }

  $grpc.ResponseFuture<$0.WorkoutView> mutateWorkout(
    $0.MutateWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$mutateWorkout, request, options: options);
  }

  $grpc.ResponseFuture<$0.WorkoutView> getWorkoutV2(
    $0.GetWorkoutV2Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getWorkoutV2, request, options: options);
  }

  $grpc.ResponseFuture<$0.CloseWorkoutResponse> closeWorkout(
    $0.CloseWorkoutRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$closeWorkout, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetProgressionHistoryResponse> getProgressionHistory(
    $0.GetProgressionHistoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getProgressionHistory, request, options: options);
  }

  // method descriptors

  static final _$createWorkout =
      $grpc.ClientMethod<$0.CreateWorkoutRequest, $0.WorkoutView>(
          '/workout.v1.TrainingService/CreateWorkout',
          ($0.CreateWorkoutRequest value) => value.writeToBuffer(),
          $0.WorkoutView.fromBuffer);
  static final _$mutateWorkout =
      $grpc.ClientMethod<$0.MutateWorkoutRequest, $0.WorkoutView>(
          '/workout.v1.TrainingService/MutateWorkout',
          ($0.MutateWorkoutRequest value) => value.writeToBuffer(),
          $0.WorkoutView.fromBuffer);
  static final _$getWorkoutV2 =
      $grpc.ClientMethod<$0.GetWorkoutV2Request, $0.WorkoutView>(
          '/workout.v1.TrainingService/GetWorkoutV2',
          ($0.GetWorkoutV2Request value) => value.writeToBuffer(),
          $0.WorkoutView.fromBuffer);
  static final _$closeWorkout =
      $grpc.ClientMethod<$0.CloseWorkoutRequest, $0.CloseWorkoutResponse>(
          '/workout.v1.TrainingService/CloseWorkout',
          ($0.CloseWorkoutRequest value) => value.writeToBuffer(),
          $0.CloseWorkoutResponse.fromBuffer);
  static final _$getProgressionHistory = $grpc.ClientMethod<
          $0.GetProgressionHistoryRequest, $0.GetProgressionHistoryResponse>(
      '/workout.v1.TrainingService/GetProgressionHistory',
      ($0.GetProgressionHistoryRequest value) => value.writeToBuffer(),
      $0.GetProgressionHistoryResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.TrainingService')
abstract class TrainingServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.TrainingService';

  TrainingServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateWorkoutRequest, $0.WorkoutView>(
        'CreateWorkout',
        createWorkout_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateWorkoutRequest.fromBuffer(value),
        ($0.WorkoutView value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.MutateWorkoutRequest, $0.WorkoutView>(
        'MutateWorkout',
        mutateWorkout_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.MutateWorkoutRequest.fromBuffer(value),
        ($0.WorkoutView value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetWorkoutV2Request, $0.WorkoutView>(
        'GetWorkoutV2',
        getWorkoutV2_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetWorkoutV2Request.fromBuffer(value),
        ($0.WorkoutView value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.CloseWorkoutRequest, $0.CloseWorkoutResponse>(
            'CloseWorkout',
            closeWorkout_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CloseWorkoutRequest.fromBuffer(value),
            ($0.CloseWorkoutResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetProgressionHistoryRequest,
            $0.GetProgressionHistoryResponse>(
        'GetProgressionHistory',
        getProgressionHistory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetProgressionHistoryRequest.fromBuffer(value),
        ($0.GetProgressionHistoryResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.WorkoutView> createWorkout_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateWorkoutRequest> $request) async {
    return createWorkout($call, await $request);
  }

  $async.Future<$0.WorkoutView> createWorkout(
      $grpc.ServiceCall call, $0.CreateWorkoutRequest request);

  $async.Future<$0.WorkoutView> mutateWorkout_Pre($grpc.ServiceCall $call,
      $async.Future<$0.MutateWorkoutRequest> $request) async {
    return mutateWorkout($call, await $request);
  }

  $async.Future<$0.WorkoutView> mutateWorkout(
      $grpc.ServiceCall call, $0.MutateWorkoutRequest request);

  $async.Future<$0.WorkoutView> getWorkoutV2_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetWorkoutV2Request> $request) async {
    return getWorkoutV2($call, await $request);
  }

  $async.Future<$0.WorkoutView> getWorkoutV2(
      $grpc.ServiceCall call, $0.GetWorkoutV2Request request);

  $async.Future<$0.CloseWorkoutResponse> closeWorkout_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CloseWorkoutRequest> $request) async {
    return closeWorkout($call, await $request);
  }

  $async.Future<$0.CloseWorkoutResponse> closeWorkout(
      $grpc.ServiceCall call, $0.CloseWorkoutRequest request);

  $async.Future<$0.GetProgressionHistoryResponse> getProgressionHistory_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetProgressionHistoryRequest> $request) async {
    return getProgressionHistory($call, await $request);
  }

  $async.Future<$0.GetProgressionHistoryResponse> getProgressionHistory(
      $grpc.ServiceCall call, $0.GetProgressionHistoryRequest request);
}
