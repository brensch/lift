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

  /// Finished workouts with their server-computed summaries (history screen).
  $grpc.ResponseFuture<$0.ListWorkoutSummariesResponse> listWorkoutSummaries(
    $0.ListWorkoutSummariesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listWorkoutSummaries, request, options: options);
  }

  /// Per-exercise progress series, everything precomputed (progress + detail).
  $grpc.ResponseFuture<$0.GetExerciseProgressResponse> getExerciseProgress(
    $0.GetExerciseProgressRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getExerciseProgress, request, options: options);
  }

  $grpc.ResponseFuture<$0.ReplaceExerciseGroupPlanResponse>
      replaceExerciseGroupPlan(
    $0.ReplaceExerciseGroupPlanRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$replaceExerciseGroupPlan, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.ReorderExerciseGroupsResponse> reorderExerciseGroups(
    $0.ReorderExerciseGroupsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reorderExerciseGroups, request, options: options);
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

  $grpc.ResponseFuture<$0.CancelProposedSetResponse> cancelProposedSet(
    $0.CancelProposedSetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cancelProposedSet, request, options: options);
  }

  $grpc.ResponseFuture<$0.AppendWorkoutMutationsResponse>
      appendWorkoutMutations(
    $0.AppendWorkoutMutationsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$appendWorkoutMutations, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.AppendWorkoutHeartRateResponse>
      appendWorkoutHeartRate(
    $0.AppendWorkoutHeartRateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$appendWorkoutHeartRate, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.GetWorkoutHeartRateResponse> getWorkoutHeartRate(
    $0.GetWorkoutHeartRateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getWorkoutHeartRate, request, options: options);
  }

  /// Everything the home screen needs in one round trip: templates,
  /// trackers, volume, recovery, the suggestion, and pending messages.
  $grpc.ResponseFuture<$0.GetHomeResponse> getHome(
    $0.GetHomeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getHome, request, options: options);
  }

  $grpc.ResponseFuture<$0.SaveTemplateResponse> saveTemplate(
    $0.SaveTemplateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$saveTemplate, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteTemplateResponse> deleteTemplate(
    $0.DeleteTemplateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteTemplate, request, options: options);
  }

  $grpc.ResponseFuture<$0.ReorderTemplatesResponse> reorderTemplates(
    $0.ReorderTemplatesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reorderTemplates, request, options: options);
  }

  $grpc.ResponseFuture<$0.SetExerciseTrackerResponse> setExerciseTracker(
    $0.SetExerciseTrackerRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$setExerciseTracker, request, options: options);
  }

  $grpc.ResponseFuture<$0.CompleteOnboardingResponse> completeOnboarding(
    $0.CompleteOnboardingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$completeOnboarding, request, options: options);
  }

  $grpc.ResponseFuture<$0.DismissUserMessagesResponse> dismissUserMessages(
    $0.DismissUserMessagesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$dismissUserMessages, request, options: options);
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
  static final _$replaceExerciseGroupPlan = $grpc.ClientMethod<
          $0.ReplaceExerciseGroupPlanRequest,
          $0.ReplaceExerciseGroupPlanResponse>(
      '/workout.v1.WorkoutService/ReplaceExerciseGroupPlan',
      ($0.ReplaceExerciseGroupPlanRequest value) => value.writeToBuffer(),
      $0.ReplaceExerciseGroupPlanResponse.fromBuffer);
  static final _$reorderExerciseGroups = $grpc.ClientMethod<
          $0.ReorderExerciseGroupsRequest, $0.ReorderExerciseGroupsResponse>(
      '/workout.v1.WorkoutService/ReorderExerciseGroups',
      ($0.ReorderExerciseGroupsRequest value) => value.writeToBuffer(),
      $0.ReorderExerciseGroupsResponse.fromBuffer);
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
  static final _$cancelProposedSet = $grpc.ClientMethod<
          $0.CancelProposedSetRequest, $0.CancelProposedSetResponse>(
      '/workout.v1.WorkoutService/CancelProposedSet',
      ($0.CancelProposedSetRequest value) => value.writeToBuffer(),
      $0.CancelProposedSetResponse.fromBuffer);
  static final _$appendWorkoutMutations = $grpc.ClientMethod<
          $0.AppendWorkoutMutationsRequest, $0.AppendWorkoutMutationsResponse>(
      '/workout.v1.WorkoutService/AppendWorkoutMutations',
      ($0.AppendWorkoutMutationsRequest value) => value.writeToBuffer(),
      $0.AppendWorkoutMutationsResponse.fromBuffer);
  static final _$appendWorkoutHeartRate = $grpc.ClientMethod<
          $0.AppendWorkoutHeartRateRequest, $0.AppendWorkoutHeartRateResponse>(
      '/workout.v1.WorkoutService/AppendWorkoutHeartRate',
      ($0.AppendWorkoutHeartRateRequest value) => value.writeToBuffer(),
      $0.AppendWorkoutHeartRateResponse.fromBuffer);
  static final _$getWorkoutHeartRate = $grpc.ClientMethod<
          $0.GetWorkoutHeartRateRequest, $0.GetWorkoutHeartRateResponse>(
      '/workout.v1.WorkoutService/GetWorkoutHeartRate',
      ($0.GetWorkoutHeartRateRequest value) => value.writeToBuffer(),
      $0.GetWorkoutHeartRateResponse.fromBuffer);
  static final _$getHome =
      $grpc.ClientMethod<$0.GetHomeRequest, $0.GetHomeResponse>(
          '/workout.v1.WorkoutService/GetHome',
          ($0.GetHomeRequest value) => value.writeToBuffer(),
          $0.GetHomeResponse.fromBuffer);
  static final _$saveTemplate =
      $grpc.ClientMethod<$0.SaveTemplateRequest, $0.SaveTemplateResponse>(
          '/workout.v1.WorkoutService/SaveTemplate',
          ($0.SaveTemplateRequest value) => value.writeToBuffer(),
          $0.SaveTemplateResponse.fromBuffer);
  static final _$deleteTemplate =
      $grpc.ClientMethod<$0.DeleteTemplateRequest, $0.DeleteTemplateResponse>(
          '/workout.v1.WorkoutService/DeleteTemplate',
          ($0.DeleteTemplateRequest value) => value.writeToBuffer(),
          $0.DeleteTemplateResponse.fromBuffer);
  static final _$reorderTemplates = $grpc.ClientMethod<
          $0.ReorderTemplatesRequest, $0.ReorderTemplatesResponse>(
      '/workout.v1.WorkoutService/ReorderTemplates',
      ($0.ReorderTemplatesRequest value) => value.writeToBuffer(),
      $0.ReorderTemplatesResponse.fromBuffer);
  static final _$setExerciseTracker = $grpc.ClientMethod<
          $0.SetExerciseTrackerRequest, $0.SetExerciseTrackerResponse>(
      '/workout.v1.WorkoutService/SetExerciseTracker',
      ($0.SetExerciseTrackerRequest value) => value.writeToBuffer(),
      $0.SetExerciseTrackerResponse.fromBuffer);
  static final _$completeOnboarding = $grpc.ClientMethod<
          $0.CompleteOnboardingRequest, $0.CompleteOnboardingResponse>(
      '/workout.v1.WorkoutService/CompleteOnboarding',
      ($0.CompleteOnboardingRequest value) => value.writeToBuffer(),
      $0.CompleteOnboardingResponse.fromBuffer);
  static final _$dismissUserMessages = $grpc.ClientMethod<
          $0.DismissUserMessagesRequest, $0.DismissUserMessagesResponse>(
      '/workout.v1.WorkoutService/DismissUserMessages',
      ($0.DismissUserMessagesRequest value) => value.writeToBuffer(),
      $0.DismissUserMessagesResponse.fromBuffer);
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
    $addMethod($grpc.ServiceMethod<$0.ReplaceExerciseGroupPlanRequest,
            $0.ReplaceExerciseGroupPlanResponse>(
        'ReplaceExerciseGroupPlan',
        replaceExerciseGroupPlan_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ReplaceExerciseGroupPlanRequest.fromBuffer(value),
        ($0.ReplaceExerciseGroupPlanResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ReorderExerciseGroupsRequest,
            $0.ReorderExerciseGroupsResponse>(
        'ReorderExerciseGroups',
        reorderExerciseGroups_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ReorderExerciseGroupsRequest.fromBuffer(value),
        ($0.ReorderExerciseGroupsResponse value) => value.writeToBuffer()));
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
    $addMethod($grpc.ServiceMethod<$0.CancelProposedSetRequest,
            $0.CancelProposedSetResponse>(
        'CancelProposedSet',
        cancelProposedSet_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CancelProposedSetRequest.fromBuffer(value),
        ($0.CancelProposedSetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AppendWorkoutMutationsRequest,
            $0.AppendWorkoutMutationsResponse>(
        'AppendWorkoutMutations',
        appendWorkoutMutations_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AppendWorkoutMutationsRequest.fromBuffer(value),
        ($0.AppendWorkoutMutationsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AppendWorkoutHeartRateRequest,
            $0.AppendWorkoutHeartRateResponse>(
        'AppendWorkoutHeartRate',
        appendWorkoutHeartRate_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AppendWorkoutHeartRateRequest.fromBuffer(value),
        ($0.AppendWorkoutHeartRateResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetWorkoutHeartRateRequest,
            $0.GetWorkoutHeartRateResponse>(
        'GetWorkoutHeartRate',
        getWorkoutHeartRate_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetWorkoutHeartRateRequest.fromBuffer(value),
        ($0.GetWorkoutHeartRateResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetHomeRequest, $0.GetHomeResponse>(
        'GetHome',
        getHome_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetHomeRequest.fromBuffer(value),
        ($0.GetHomeResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SaveTemplateRequest, $0.SaveTemplateResponse>(
            'SaveTemplate',
            saveTemplate_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SaveTemplateRequest.fromBuffer(value),
            ($0.SaveTemplateResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteTemplateRequest,
            $0.DeleteTemplateResponse>(
        'DeleteTemplate',
        deleteTemplate_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteTemplateRequest.fromBuffer(value),
        ($0.DeleteTemplateResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ReorderTemplatesRequest,
            $0.ReorderTemplatesResponse>(
        'ReorderTemplates',
        reorderTemplates_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ReorderTemplatesRequest.fromBuffer(value),
        ($0.ReorderTemplatesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetExerciseTrackerRequest,
            $0.SetExerciseTrackerResponse>(
        'SetExerciseTracker',
        setExerciseTracker_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SetExerciseTrackerRequest.fromBuffer(value),
        ($0.SetExerciseTrackerResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CompleteOnboardingRequest,
            $0.CompleteOnboardingResponse>(
        'CompleteOnboarding',
        completeOnboarding_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CompleteOnboardingRequest.fromBuffer(value),
        ($0.CompleteOnboardingResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DismissUserMessagesRequest,
            $0.DismissUserMessagesResponse>(
        'DismissUserMessages',
        dismissUserMessages_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DismissUserMessagesRequest.fromBuffer(value),
        ($0.DismissUserMessagesResponse value) => value.writeToBuffer()));
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

  $async.Future<$0.ReplaceExerciseGroupPlanResponse>
      replaceExerciseGroupPlan_Pre($grpc.ServiceCall $call,
          $async.Future<$0.ReplaceExerciseGroupPlanRequest> $request) async {
    return replaceExerciseGroupPlan($call, await $request);
  }

  $async.Future<$0.ReplaceExerciseGroupPlanResponse> replaceExerciseGroupPlan(
      $grpc.ServiceCall call, $0.ReplaceExerciseGroupPlanRequest request);

  $async.Future<$0.ReorderExerciseGroupsResponse> reorderExerciseGroups_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ReorderExerciseGroupsRequest> $request) async {
    return reorderExerciseGroups($call, await $request);
  }

  $async.Future<$0.ReorderExerciseGroupsResponse> reorderExerciseGroups(
      $grpc.ServiceCall call, $0.ReorderExerciseGroupsRequest request);

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

  $async.Future<$0.CancelProposedSetResponse> cancelProposedSet_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CancelProposedSetRequest> $request) async {
    return cancelProposedSet($call, await $request);
  }

  $async.Future<$0.CancelProposedSetResponse> cancelProposedSet(
      $grpc.ServiceCall call, $0.CancelProposedSetRequest request);

  $async.Future<$0.AppendWorkoutMutationsResponse> appendWorkoutMutations_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AppendWorkoutMutationsRequest> $request) async {
    return appendWorkoutMutations($call, await $request);
  }

  $async.Future<$0.AppendWorkoutMutationsResponse> appendWorkoutMutations(
      $grpc.ServiceCall call, $0.AppendWorkoutMutationsRequest request);

  $async.Future<$0.AppendWorkoutHeartRateResponse> appendWorkoutHeartRate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AppendWorkoutHeartRateRequest> $request) async {
    return appendWorkoutHeartRate($call, await $request);
  }

  $async.Future<$0.AppendWorkoutHeartRateResponse> appendWorkoutHeartRate(
      $grpc.ServiceCall call, $0.AppendWorkoutHeartRateRequest request);

  $async.Future<$0.GetWorkoutHeartRateResponse> getWorkoutHeartRate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetWorkoutHeartRateRequest> $request) async {
    return getWorkoutHeartRate($call, await $request);
  }

  $async.Future<$0.GetWorkoutHeartRateResponse> getWorkoutHeartRate(
      $grpc.ServiceCall call, $0.GetWorkoutHeartRateRequest request);

  $async.Future<$0.GetHomeResponse> getHome_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetHomeRequest> $request) async {
    return getHome($call, await $request);
  }

  $async.Future<$0.GetHomeResponse> getHome(
      $grpc.ServiceCall call, $0.GetHomeRequest request);

  $async.Future<$0.SaveTemplateResponse> saveTemplate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SaveTemplateRequest> $request) async {
    return saveTemplate($call, await $request);
  }

  $async.Future<$0.SaveTemplateResponse> saveTemplate(
      $grpc.ServiceCall call, $0.SaveTemplateRequest request);

  $async.Future<$0.DeleteTemplateResponse> deleteTemplate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DeleteTemplateRequest> $request) async {
    return deleteTemplate($call, await $request);
  }

  $async.Future<$0.DeleteTemplateResponse> deleteTemplate(
      $grpc.ServiceCall call, $0.DeleteTemplateRequest request);

  $async.Future<$0.ReorderTemplatesResponse> reorderTemplates_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ReorderTemplatesRequest> $request) async {
    return reorderTemplates($call, await $request);
  }

  $async.Future<$0.ReorderTemplatesResponse> reorderTemplates(
      $grpc.ServiceCall call, $0.ReorderTemplatesRequest request);

  $async.Future<$0.SetExerciseTrackerResponse> setExerciseTracker_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SetExerciseTrackerRequest> $request) async {
    return setExerciseTracker($call, await $request);
  }

  $async.Future<$0.SetExerciseTrackerResponse> setExerciseTracker(
      $grpc.ServiceCall call, $0.SetExerciseTrackerRequest request);

  $async.Future<$0.CompleteOnboardingResponse> completeOnboarding_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CompleteOnboardingRequest> $request) async {
    return completeOnboarding($call, await $request);
  }

  $async.Future<$0.CompleteOnboardingResponse> completeOnboarding(
      $grpc.ServiceCall call, $0.CompleteOnboardingRequest request);

  $async.Future<$0.DismissUserMessagesResponse> dismissUserMessages_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DismissUserMessagesRequest> $request) async {
    return dismissUserMessages($call, await $request);
  }

  $async.Future<$0.DismissUserMessagesResponse> dismissUserMessages(
      $grpc.ServiceCall call, $0.DismissUserMessagesRequest request);
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

  /// Update the authenticated user's profile metadata.
  $grpc.ResponseFuture<$0.UpdateMyProfileResponse> updateMyProfile(
    $0.UpdateMyProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateMyProfile, request, options: options);
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

  $async.Future<$0.UpdateMyProfileResponse> updateMyProfile_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateMyProfileRequest> $request) async {
    return updateMyProfile($call, await $request);
  }

  $async.Future<$0.UpdateMyProfileResponse> updateMyProfile(
      $grpc.ServiceCall call, $0.UpdateMyProfileRequest request);
}
