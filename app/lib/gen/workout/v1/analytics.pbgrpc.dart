// This is a generated file - do not edit.
//
// Generated from workout/v1/analytics.proto.

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

import 'analytics.pb.dart' as $0;

export 'analytics.pb.dart';

@$pb.GrpcServiceName('workout.v1.AnalyticsService')
class AnalyticsServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AnalyticsServiceClient(super.channel, {super.options, super.interceptors});

  /// Batched upload from the app's page tracker. Authenticated like every
  /// other write: views seen before login are held on-device until a session
  /// exists.
  $grpc.ResponseFuture<$0.RecordPageViewsResponse> recordPageViews(
    $0.RecordPageViewsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$recordPageViews, request, options: options);
  }

  // method descriptors

  static final _$recordPageViews =
      $grpc.ClientMethod<$0.RecordPageViewsRequest, $0.RecordPageViewsResponse>(
          '/workout.v1.AnalyticsService/RecordPageViews',
          ($0.RecordPageViewsRequest value) => value.writeToBuffer(),
          $0.RecordPageViewsResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.AnalyticsService')
abstract class AnalyticsServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.AnalyticsService';

  AnalyticsServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RecordPageViewsRequest,
            $0.RecordPageViewsResponse>(
        'RecordPageViews',
        recordPageViews_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RecordPageViewsRequest.fromBuffer(value),
        ($0.RecordPageViewsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.RecordPageViewsResponse> recordPageViews_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RecordPageViewsRequest> $request) async {
    return recordPageViews($call, await $request);
  }

  $async.Future<$0.RecordPageViewsResponse> recordPageViews(
      $grpc.ServiceCall call, $0.RecordPageViewsRequest request);
}

@$pb.GrpcServiceName('workout.v1.AdminService')
class AdminServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AdminServiceClient(super.channel, {super.options, super.interceptors});

  /// Whether the caller is an admin. Lets the website decide whether to show
  /// the stats link; the real gate is on GetStats.
  $grpc.ResponseFuture<$0.GetAdminStatusResponse> getAdminStatus(
    $0.GetAdminStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAdminStatus, request, options: options);
  }

  /// Admin only: PERMISSION_DENIED for everyone else.
  $grpc.ResponseFuture<$0.GetStatsResponse> getStats(
    $0.GetStatsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStats, request, options: options);
  }

  // method descriptors

  static final _$getAdminStatus =
      $grpc.ClientMethod<$0.GetAdminStatusRequest, $0.GetAdminStatusResponse>(
          '/workout.v1.AdminService/GetAdminStatus',
          ($0.GetAdminStatusRequest value) => value.writeToBuffer(),
          $0.GetAdminStatusResponse.fromBuffer);
  static final _$getStats =
      $grpc.ClientMethod<$0.GetStatsRequest, $0.GetStatsResponse>(
          '/workout.v1.AdminService/GetStats',
          ($0.GetStatsRequest value) => value.writeToBuffer(),
          $0.GetStatsResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.AdminService')
abstract class AdminServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.AdminService';

  AdminServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetAdminStatusRequest,
            $0.GetAdminStatusResponse>(
        'GetAdminStatus',
        getAdminStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetAdminStatusRequest.fromBuffer(value),
        ($0.GetAdminStatusResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetStatsRequest, $0.GetStatsResponse>(
        'GetStats',
        getStats_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetStatsRequest.fromBuffer(value),
        ($0.GetStatsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetAdminStatusResponse> getAdminStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetAdminStatusRequest> $request) async {
    return getAdminStatus($call, await $request);
  }

  $async.Future<$0.GetAdminStatusResponse> getAdminStatus(
      $grpc.ServiceCall call, $0.GetAdminStatusRequest request);

  $async.Future<$0.GetStatsResponse> getStats_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetStatsRequest> $request) async {
    return getStats($call, await $request);
  }

  $async.Future<$0.GetStatsResponse> getStats(
      $grpc.ServiceCall call, $0.GetStatsRequest request);
}
