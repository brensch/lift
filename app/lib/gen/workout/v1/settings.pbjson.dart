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

@$core.Deprecated('Use muscleGroupDescriptor instead')
const MuscleGroup$json = {
  '1': 'MuscleGroup',
  '2': [
    {'1': 'MUSCLE_GROUP_UNSPECIFIED', '2': 0},
    {'1': 'MUSCLE_GROUP_QUADS', '2': 1},
    {'1': 'MUSCLE_GROUP_HAMSTRINGS', '2': 2},
    {'1': 'MUSCLE_GROUP_GLUTES', '2': 3},
    {'1': 'MUSCLE_GROUP_CHEST', '2': 4},
    {'1': 'MUSCLE_GROUP_BACK', '2': 5},
    {'1': 'MUSCLE_GROUP_SHOULDERS', '2': 6},
    {'1': 'MUSCLE_GROUP_BICEPS', '2': 7},
    {'1': 'MUSCLE_GROUP_TRICEPS', '2': 8},
    {'1': 'MUSCLE_GROUP_CALVES', '2': 9},
    {'1': 'MUSCLE_GROUP_CORE', '2': 10},
  ],
};

/// Descriptor for `MuscleGroup`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List muscleGroupDescriptor = $convert.base64Decode(
    'CgtNdXNjbGVHcm91cBIcChhNVVNDTEVfR1JPVVBfVU5TUEVDSUZJRUQQABIWChJNVVNDTEVfR1'
    'JPVVBfUVVBRFMQARIbChdNVVNDTEVfR1JPVVBfSEFNU1RSSU5HUxACEhcKE01VU0NMRV9HUk9V'
    'UF9HTFVURVMQAxIWChJNVVNDTEVfR1JPVVBfQ0hFU1QQBBIVChFNVVNDTEVfR1JPVVBfQkFDSx'
    'AFEhoKFk1VU0NMRV9HUk9VUF9TSE9VTERFUlMQBhIXChNNVVNDTEVfR1JPVVBfQklDRVBTEAcS'
    'GAoUTVVTQ0xFX0dST1VQX1RSSUNFUFMQCBIXChNNVVNDTEVfR1JPVVBfQ0FMVkVTEAkSFQoRTV'
    'VTQ0xFX0dST1VQX0NPUkUQCg==');

@$core.Deprecated('Use weightUnitDescriptor instead')
const WeightUnit$json = {
  '1': 'WeightUnit',
  '2': [
    {'1': 'WEIGHT_UNIT_UNSPECIFIED', '2': 0},
    {'1': 'WEIGHT_UNIT_LB', '2': 1},
    {'1': 'WEIGHT_UNIT_KG', '2': 2},
  ],
};

/// Descriptor for `WeightUnit`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List weightUnitDescriptor = $convert.base64Decode(
    'CgpXZWlnaHRVbml0EhsKF1dFSUdIVF9VTklUX1VOU1BFQ0lGSUVEEAASEgoOV0VJR0hUX1VOSV'
    'RfTEIQARISCg5XRUlHSFRfVU5JVF9LRxAC');

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

@$core.Deprecated('Use weightUnitConfigDescriptor instead')
const WeightUnitConfig$json = {
  '1': 'WeightUnitConfig',
  '2': [
    {
      '1': 'unit',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WeightUnit',
      '10': 'unit'
    },
  ],
};

/// Descriptor for `WeightUnitConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List weightUnitConfigDescriptor = $convert.base64Decode(
    'ChBXZWlnaHRVbml0Q29uZmlnEioKBHVuaXQYASABKA4yFi53b3Jrb3V0LnYxLldlaWdodFVuaX'
    'RSBHVuaXQ=');

@$core.Deprecated('Use ignoredMusclesConfigDescriptor instead')
const IgnoredMusclesConfig$json = {
  '1': 'IgnoredMusclesConfig',
  '2': [
    {
      '1': 'muscles',
      '3': 1,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscles'
    },
  ],
};

/// Descriptor for `IgnoredMusclesConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ignoredMusclesConfigDescriptor = $convert.base64Decode(
    'ChRJZ25vcmVkTXVzY2xlc0NvbmZpZxIxCgdtdXNjbGVzGAEgAygOMhcud29ya291dC52MS5NdX'
    'NjbGVHcm91cFIHbXVzY2xlcw==');

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
      '1': 'weight_unit',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WeightUnitConfig',
      '9': 0,
      '10': 'weightUnit'
    },
    {
      '1': 'ignored_muscles',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.IgnoredMusclesConfig',
      '9': 0,
      '10': 'ignoredMuscles'
    },
  ],
  '8': [
    {'1': 'setting'},
  ],
};

/// Descriptor for `UserSetting`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userSettingDescriptor = $convert.base64Decode(
    'CgtVc2VyU2V0dGluZxJCCgxwbGF0ZV9jb2xvcnMYCiABKAsyHS53b3Jrb3V0LnYxLlBsYXRlQ2'
    '9sb3JzQ29uZmlnSABSC3BsYXRlQ29sb3JzEj8KC3dlaWdodF91bml0GAwgASgLMhwud29ya291'
    'dC52MS5XZWlnaHRVbml0Q29uZmlnSABSCndlaWdodFVuaXQSSwoPaWdub3JlZF9tdXNjbGVzGA'
    '0gASgLMiAud29ya291dC52MS5JZ25vcmVkTXVzY2xlc0NvbmZpZ0gAUg5pZ25vcmVkTXVzY2xl'
    'c0IJCgdzZXR0aW5n');

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
