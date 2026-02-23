// This is a generated file - do not edit.
//
// Generated from workout/v1/settings.proto.

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

import 'settings.pb.dart' as $0;

export 'settings.pb.dart';

@$pb.GrpcServiceName('workout.v1.SettingsService')
class SettingsServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SettingsServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.UpdateSettingResponse> updateSetting(
    $0.UpdateSettingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSetting, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetSettingsResponse> getSettings(
    $0.GetSettingsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSettings, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetTrainingProgramCatalogResponse>
      getTrainingProgramCatalog(
    $0.GetTrainingProgramCatalogRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getTrainingProgramCatalog, request,
        options: options);
  }

  // method descriptors

  static final _$updateSetting =
      $grpc.ClientMethod<$0.UpdateSettingRequest, $0.UpdateSettingResponse>(
          '/workout.v1.SettingsService/UpdateSetting',
          ($0.UpdateSettingRequest value) => value.writeToBuffer(),
          $0.UpdateSettingResponse.fromBuffer);
  static final _$getSettings =
      $grpc.ClientMethod<$0.GetSettingsRequest, $0.GetSettingsResponse>(
          '/workout.v1.SettingsService/GetSettings',
          ($0.GetSettingsRequest value) => value.writeToBuffer(),
          $0.GetSettingsResponse.fromBuffer);
  static final _$getTrainingProgramCatalog = $grpc.ClientMethod<
          $0.GetTrainingProgramCatalogRequest,
          $0.GetTrainingProgramCatalogResponse>(
      '/workout.v1.SettingsService/GetTrainingProgramCatalog',
      ($0.GetTrainingProgramCatalogRequest value) => value.writeToBuffer(),
      $0.GetTrainingProgramCatalogResponse.fromBuffer);
}

@$pb.GrpcServiceName('workout.v1.SettingsService')
abstract class SettingsServiceBase extends $grpc.Service {
  $core.String get $name => 'workout.v1.SettingsService';

  SettingsServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateSettingRequest, $0.UpdateSettingResponse>(
            'UpdateSetting',
            updateSetting_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateSettingRequest.fromBuffer(value),
            ($0.UpdateSettingResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetSettingsRequest, $0.GetSettingsResponse>(
            'GetSettings',
            getSettings_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetSettingsRequest.fromBuffer(value),
            ($0.GetSettingsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetTrainingProgramCatalogRequest,
            $0.GetTrainingProgramCatalogResponse>(
        'GetTrainingProgramCatalog',
        getTrainingProgramCatalog_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetTrainingProgramCatalogRequest.fromBuffer(value),
        ($0.GetTrainingProgramCatalogResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.UpdateSettingResponse> updateSetting_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateSettingRequest> $request) async {
    return updateSetting($call, await $request);
  }

  $async.Future<$0.UpdateSettingResponse> updateSetting(
      $grpc.ServiceCall call, $0.UpdateSettingRequest request);

  $async.Future<$0.GetSettingsResponse> getSettings_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetSettingsRequest> $request) async {
    return getSettings($call, await $request);
  }

  $async.Future<$0.GetSettingsResponse> getSettings(
      $grpc.ServiceCall call, $0.GetSettingsRequest request);

  $async.Future<$0.GetTrainingProgramCatalogResponse>
      getTrainingProgramCatalog_Pre($grpc.ServiceCall $call,
          $async.Future<$0.GetTrainingProgramCatalogRequest> $request) async {
    return getTrainingProgramCatalog($call, await $request);
  }

  $async.Future<$0.GetTrainingProgramCatalogResponse> getTrainingProgramCatalog(
      $grpc.ServiceCall call, $0.GetTrainingProgramCatalogRequest request);
}
