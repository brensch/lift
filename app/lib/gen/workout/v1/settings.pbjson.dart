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
  ],
  '8': [
    {'1': 'setting'},
  ],
};

/// Descriptor for `UserSetting`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userSettingDescriptor = $convert.base64Decode(
    'CgtVc2VyU2V0dGluZxJCCgxwbGF0ZV9jb2xvcnMYCiABKAsyHS53b3Jrb3V0LnYxLlBsYXRlQ2'
    '9sb3JzQ29uZmlnSABSC3BsYXRlQ29sb3JzQgkKB3NldHRpbmc=');

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
