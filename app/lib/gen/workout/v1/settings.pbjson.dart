// This is a generated file - do not edit.
//
// Generated from workout/v1/settings.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use regimeTypeDescriptor instead')
const RegimeType$json = {
  '1': 'RegimeType',
  '2': [
    {'1': 'REGIME_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'REGIME_TYPE_LINEAR_5X5', '2': 1},
    {'1': 'REGIME_TYPE_GZCLP', '2': 2},
    {'1': 'REGIME_TYPE_WENDLER_531', '2': 3},
  ],
};

/// Descriptor for `RegimeType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List regimeTypeDescriptor = $convert.base64Decode(
    'CgpSZWdpbWVUeXBlEhsKF1JFR0lNRV9UWVBFX1VOU1BFQ0lGSUVEEAASGgoWUkVHSU1FX1RZUE'
    'VfTElORUFSXzVYNRABEhUKEVJFR0lNRV9UWVBFX0daQ0xQEAISGwoXUkVHSU1FX1RZUEVfV0VO'
    'RExFUl81MzEQAw==');

@$core.Deprecated('Use plateColorDescriptor instead')
const PlateColor$json = {
  '1': 'PlateColor',
  '2': [
    {'1': 'weight_kg', '3': 1, '4': 1, '5': 2, '10': 'weightKg'},
    {'1': 'hex_color', '3': 2, '4': 1, '5': 9, '10': 'hexColor'},
  ],
};

/// Descriptor for `PlateColor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List plateColorDescriptor = $convert.base64Decode(
    'CgpQbGF0ZUNvbG9yEhsKCXdlaWdodF9rZxgBIAEoAlIId2VpZ2h0S2cSGwoJaGV4X2NvbG9yGA'
    'IgASgJUghoZXhDb2xvcg==');

@$core.Deprecated('Use plateColorsConfigDescriptor instead')
const PlateColorsConfig$json = {
  '1': 'PlateColorsConfig',
  '2': [
    {
      '1': 'plates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.PlateColor',
      '10': 'plates'
    },
    {'1': 'bar_weight_kg', '3': 2, '4': 1, '5': 2, '10': 'barWeightKg'},
  ],
};

/// Descriptor for `PlateColorsConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List plateColorsConfigDescriptor = $convert.base64Decode(
    'ChFQbGF0ZUNvbG9yc0NvbmZpZxIuCgZwbGF0ZXMYASADKAsyFi53b3Jrb3V0LnYxLlBsYXRlQ2'
    '9sb3JSBnBsYXRlcxIiCg1iYXJfd2VpZ2h0X2tnGAIgASgCUgtiYXJXZWlnaHRLZw==');

@$core.Deprecated('Use userWorkoutConfigDescriptor instead')
const UserWorkoutConfig$json = {
  '1': 'UserWorkoutConfig',
  '2': [
    {
      '1': 'regime_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RegimeType',
      '10': 'regimeType'
    },
    {'1': 'days_per_week', '3': 2, '4': 1, '5': 5, '10': 'daysPerWeek'},
    {
      '1': 'one_rep_maxes',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserWorkoutConfig.OneRepMaxesEntry',
      '10': 'oneRepMaxes'
    },
    {'1': 'regime_state_json', '3': 4, '4': 1, '5': 9, '10': 'regimeStateJson'},
  ],
  '3': [UserWorkoutConfig_OneRepMaxesEntry$json],
};

@$core.Deprecated('Use userWorkoutConfigDescriptor instead')
const UserWorkoutConfig_OneRepMaxesEntry$json = {
  '1': 'OneRepMaxesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 2, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `UserWorkoutConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userWorkoutConfigDescriptor = $convert.base64Decode(
    'ChFVc2VyV29ya291dENvbmZpZxI3CgtyZWdpbWVfdHlwZRgBIAEoDjIWLndvcmtvdXQudjEuUm'
    'VnaW1lVHlwZVIKcmVnaW1lVHlwZRIiCg1kYXlzX3Blcl93ZWVrGAIgASgFUgtkYXlzUGVyV2Vl'
    'axJSCg1vbmVfcmVwX21heGVzGAMgAygLMi4ud29ya291dC52MS5Vc2VyV29ya291dENvbmZpZy'
    '5PbmVSZXBNYXhlc0VudHJ5UgtvbmVSZXBNYXhlcxIqChFyZWdpbWVfc3RhdGVfanNvbhgEIAEo'
    'CVIPcmVnaW1lU3RhdGVKc29uGj4KEE9uZVJlcE1heGVzRW50cnkSEAoDa2V5GAEgASgFUgNrZX'
    'kSFAoFdmFsdWUYAiABKAJSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use userSettingDescriptor instead')
const UserSetting$json = {
  '1': 'UserSetting',
  '2': [
    {
      '1': 'plate_colors',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.PlateColorsConfig',
      '9': 0,
      '10': 'plateColors'
    },
    {
      '1': 'workout_config',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.UserWorkoutConfig',
      '9': 0,
      '10': 'workoutConfig'
    },
  ],
  '8': [
    {'1': 'setting'},
  ],
};

/// Descriptor for `UserSetting`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userSettingDescriptor = $convert.base64Decode(
    'CgtVc2VyU2V0dGluZxJCCgxwbGF0ZV9jb2xvcnMYCiABKAsyHS53b3Jrb3V0LnYxLlBsYXRlQ2'
    '9sb3JzQ29uZmlnSABSC3BsYXRlQ29sb3JzEkYKDndvcmtvdXRfY29uZmlnGAsgASgLMh0ud29y'
    'a291dC52MS5Vc2VyV29ya291dENvbmZpZ0gAUg13b3Jrb3V0Q29uZmlnQgkKB3NldHRpbmc=');

@$core.Deprecated('Use updateSettingRequestDescriptor instead')
const UpdateSettingRequest$json = {
  '1': 'UpdateSettingRequest',
  '2': [
    {
      '1': 'setting',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.UserSetting',
      '10': 'setting'
    },
  ],
};

/// Descriptor for `UpdateSettingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSettingRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVTZXR0aW5nUmVxdWVzdBIxCgdzZXR0aW5nGAEgASgLMhcud29ya291dC52MS5Vc2'
    'VyU2V0dGluZ1IHc2V0dGluZw==');

@$core.Deprecated('Use updateSettingResponseDescriptor instead')
const UpdateSettingResponse$json = {
  '1': 'UpdateSettingResponse',
};

/// Descriptor for `UpdateSettingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSettingResponseDescriptor =
    $convert.base64Decode('ChVVcGRhdGVTZXR0aW5nUmVzcG9uc2U=');

@$core.Deprecated('Use getSettingsRequestDescriptor instead')
const GetSettingsRequest$json = {
  '1': 'GetSettingsRequest',
};

/// Descriptor for `GetSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSettingsRequestDescriptor =
    $convert.base64Decode('ChJHZXRTZXR0aW5nc1JlcXVlc3Q=');

@$core.Deprecated('Use getSettingsResponseDescriptor instead')
const GetSettingsResponse$json = {
  '1': 'GetSettingsResponse',
  '2': [
    {
      '1': 'settings',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserSetting',
      '10': 'settings'
    },
  ],
};

/// Descriptor for `GetSettingsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSettingsResponseDescriptor = $convert.base64Decode(
    'ChNHZXRTZXR0aW5nc1Jlc3BvbnNlEjMKCHNldHRpbmdzGAEgAygLMhcud29ya291dC52MS5Vc2'
    'VyU2V0dGluZ1IIc2V0dGluZ3M=');
