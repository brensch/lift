// This is a generated file - do not edit.
//
// Generated from workout/v1/account.proto.

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

import 'account.pb.dart' as $0;

export 'account.pb.dart';

@$pb.GrpcServiceName('workout.v1.SyncService')
class SyncServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SyncServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.SyncResponse> sync(
    $async.Stream<$0.SyncRequest> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$sync, request, options: options);
  }

  /// Every event of the caller's account after `after_seq`: a fresh install.
  $grpc.ResponseFuture<$0.PullEventsResponse> pullEvents(
    $0.PullEventsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pullEvents, request, options: options);
  }

  // method descriptors

  static final _$sync = $grpc.ClientMethod<$0.SyncRequest, $0.SyncResponse>(
      '/workout.v1.SyncService/Sync',
      ($0.SyncRequest value) => value.writeToBuffer(),
      $0.SyncResponse.fromBuffer);
  static final _$pullEvents =
      $grpc.ClientMethod<$0.PullEventsRequest, $0.PullEventsResponse>(
          '/workout.v1.SyncService/PullEvents',
          ($0.PullEventsRequest value) => value.writeToBuffer(),
          $0.PullEventsResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.SyncService')
abstract class SyncServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.SyncService';

  SyncServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.SyncRequest, $0.SyncResponse>(
        'Sync',
        sync,
        true,
        true,
        ($core.List<$core.int> value) => $0.SyncRequest.fromBuffer(value),
        ($0.SyncResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PullEventsRequest, $0.PullEventsResponse>(
        'PullEvents',
        pullEvents_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PullEventsRequest.fromBuffer(value),
        ($0.PullEventsResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.SyncResponse> sync(
      $grpc.ServiceCall call, $async.Stream<$0.SyncRequest> request);

  $async.Future<$0.PullEventsResponse> pullEvents_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PullEventsRequest> $request) async {
    return pullEvents($call, await $request);
  }

  $async.Future<$0.PullEventsResponse> pullEvents(
      $grpc.ServiceCall call, $0.PullEventsRequest request);
}
