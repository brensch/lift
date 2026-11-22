// This is a generated file - do not edit.
//
// Generated from workout/v1/assistant.proto.

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

import 'assistant.pb.dart' as $0;

export 'assistant.pb.dart';

@$pb.GrpcServiceName('workout.v1.AssistantService')
class AssistantServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AssistantServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.DescribeConnectResponse> describeConnect(
    $0.DescribeConnectRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$describeConnect, request, options: options);
  }

  $grpc.ResponseFuture<$0.AnswerConnectResponse> answerConnect(
    $0.AnswerConnectRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$answerConnect, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListAssistantsResponse> listAssistants(
    $0.ListAssistantsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listAssistants, request, options: options);
  }

  $grpc.ResponseFuture<$0.RevokeAssistantResponse> revokeAssistant(
    $0.RevokeAssistantRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$revokeAssistant, request, options: options);
  }

  // method descriptors

  static final _$describeConnect =
      $grpc.ClientMethod<$0.DescribeConnectRequest, $0.DescribeConnectResponse>(
          '/workout.v1.AssistantService/DescribeConnect',
          ($0.DescribeConnectRequest value) => value.writeToBuffer(),
          $0.DescribeConnectResponse.fromBuffer);
  static final _$answerConnect =
      $grpc.ClientMethod<$0.AnswerConnectRequest, $0.AnswerConnectResponse>(
          '/workout.v1.AssistantService/AnswerConnect',
          ($0.AnswerConnectRequest value) => value.writeToBuffer(),
          $0.AnswerConnectResponse.fromBuffer);
  static final _$listAssistants =
      $grpc.ClientMethod<$0.ListAssistantsRequest, $0.ListAssistantsResponse>(
          '/workout.v1.AssistantService/ListAssistants',
          ($0.ListAssistantsRequest value) => value.writeToBuffer(),
          $0.ListAssistantsResponse.fromBuffer);
  static final _$revokeAssistant =
      $grpc.ClientMethod<$0.RevokeAssistantRequest, $0.RevokeAssistantResponse>(
          '/workout.v1.AssistantService/RevokeAssistant',
          ($0.RevokeAssistantRequest value) => value.writeToBuffer(),
          $0.RevokeAssistantResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.AssistantService')
abstract class AssistantServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.AssistantService';

  AssistantServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.DescribeConnectRequest,
            $0.DescribeConnectResponse>(
        'DescribeConnect',
        describeConnect_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DescribeConnectRequest.fromBuffer(value),
        ($0.DescribeConnectResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.AnswerConnectRequest, $0.AnswerConnectResponse>(
            'AnswerConnect',
            answerConnect_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.AnswerConnectRequest.fromBuffer(value),
            ($0.AnswerConnectResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListAssistantsRequest,
            $0.ListAssistantsResponse>(
        'ListAssistants',
        listAssistants_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListAssistantsRequest.fromBuffer(value),
        ($0.ListAssistantsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RevokeAssistantRequest,
            $0.RevokeAssistantResponse>(
        'RevokeAssistant',
        revokeAssistant_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RevokeAssistantRequest.fromBuffer(value),
        ($0.RevokeAssistantResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.DescribeConnectResponse> describeConnect_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DescribeConnectRequest> $request) async {
    return describeConnect($call, await $request);
  }

  $async.Future<$0.DescribeConnectResponse> describeConnect(
      $grpc.ServiceCall call, $0.DescribeConnectRequest request);

  $async.Future<$0.AnswerConnectResponse> answerConnect_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AnswerConnectRequest> $request) async {
    return answerConnect($call, await $request);
  }

  $async.Future<$0.AnswerConnectResponse> answerConnect(
      $grpc.ServiceCall call, $0.AnswerConnectRequest request);

  $async.Future<$0.ListAssistantsResponse> listAssistants_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListAssistantsRequest> $request) async {
    return listAssistants($call, await $request);
  }

  $async.Future<$0.ListAssistantsResponse> listAssistants(
      $grpc.ServiceCall call, $0.ListAssistantsRequest request);

  $async.Future<$0.RevokeAssistantResponse> revokeAssistant_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RevokeAssistantRequest> $request) async {
    return revokeAssistant($call, await $request);
  }

  $async.Future<$0.RevokeAssistantResponse> revokeAssistant(
      $grpc.ServiceCall call, $0.RevokeAssistantRequest request);
}
