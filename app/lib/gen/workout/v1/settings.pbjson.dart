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
    {'1': 'REGIME_TYPE_WENDLER_531_4DAY', '2': 4},
    {'1': 'REGIME_TYPE_WENDLER_531_3DAY', '2': 5},
  ],
};

/// Descriptor for `RegimeType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List regimeTypeDescriptor = $convert.base64Decode(
    'CgpSZWdpbWVUeXBlEhsKF1JFR0lNRV9UWVBFX1VOU1BFQ0lGSUVEEAASGgoWUkVHSU1FX1RZUE'
    'VfTElORUFSXzVYNRABEhUKEVJFR0lNRV9UWVBFX0daQ0xQEAISIAocUkVHSU1FX1RZUEVfV0VO'
    'RExFUl81MzFfNERBWRAEEiAKHFJFR0lNRV9UWVBFX1dFTkRMRVJfNTMxXzNEQVkQBQ==');

@$core.Deprecated('Use trainingProgramFieldKindDescriptor instead')
const TrainingProgramFieldKind$json = {
  '1': 'TrainingProgramFieldKind',
  '2': [
    {'1': 'TRAINING_PROGRAM_FIELD_KIND_UNSPECIFIED', '2': 0},
    {'1': 'TRAINING_PROGRAM_FIELD_KIND_INT32', '2': 1},
    {'1': 'TRAINING_PROGRAM_FIELD_KIND_FLOAT', '2': 2},
    {'1': 'TRAINING_PROGRAM_FIELD_KIND_BOOL', '2': 3},
  ],
};

/// Descriptor for `TrainingProgramFieldKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List trainingProgramFieldKindDescriptor = $convert.base64Decode(
    'ChhUcmFpbmluZ1Byb2dyYW1GaWVsZEtpbmQSKwonVFJBSU5JTkdfUFJPR1JBTV9GSUVMRF9LSU'
    '5EX1VOU1BFQ0lGSUVEEAASJQohVFJBSU5JTkdfUFJPR1JBTV9GSUVMRF9LSU5EX0lOVDMyEAES'
    'JQohVFJBSU5JTkdfUFJPR1JBTV9GSUVMRF9LSU5EX0ZMT0FUEAISJAogVFJBSU5JTkdfUFJPR1'
    'JBTV9GSUVMRF9LSU5EX0JPT0wQAw==');

@$core.Deprecated('Use trainingProgramFieldBindingDescriptor instead')
const TrainingProgramFieldBinding$json = {
  '1': 'TrainingProgramFieldBinding',
  '2': [
    {'1': 'TRAINING_PROGRAM_FIELD_BINDING_UNSPECIFIED', '2': 0},
    {'1': 'TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK', '2': 1},
    {'1': 'TRAINING_PROGRAM_FIELD_BINDING_ONE_REP_MAX', '2': 2},
  ],
};

/// Descriptor for `TrainingProgramFieldBinding`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List trainingProgramFieldBindingDescriptor = $convert.base64Decode(
    'ChtUcmFpbmluZ1Byb2dyYW1GaWVsZEJpbmRpbmcSLgoqVFJBSU5JTkdfUFJPR1JBTV9GSUVMRF'
    '9CSU5ESU5HX1VOU1BFQ0lGSUVEEAASMAosVFJBSU5JTkdfUFJPR1JBTV9GSUVMRF9CSU5ESU5H'
    'X0RBWVNfUEVSX1dFRUsQARIuCipUUkFJTklOR19QUk9HUkFNX0ZJRUxEX0JJTkRJTkdfT05FX1'
    'JFUF9NQVgQAg==');

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

@$core.Deprecated('Use trainingProgramAtAGlanceDescriptor instead')
const TrainingProgramAtAGlance$json = {
  '1': 'TrainingProgramAtAGlance',
  '2': [
    {'1': 'days_per_week', '3': 1, '4': 1, '5': 9, '10': 'daysPerWeek'},
    {'1': 'best_for', '3': 2, '4': 1, '5': 9, '10': 'bestFor'},
    {
      '1': 'average_session_time',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'averageSessionTime'
    },
    {
      '1': 'progression_style',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'progressionStyle'
    },
  ],
};

/// Descriptor for `TrainingProgramAtAGlance`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramAtAGlanceDescriptor = $convert.base64Decode(
    'ChhUcmFpbmluZ1Byb2dyYW1BdEFHbGFuY2USIgoNZGF5c19wZXJfd2VlaxgBIAEoCVILZGF5c1'
    'BlcldlZWsSGQoIYmVzdF9mb3IYAiABKAlSB2Jlc3RGb3ISMAoUYXZlcmFnZV9zZXNzaW9uX3Rp'
    'bWUYAyABKAlSEmF2ZXJhZ2VTZXNzaW9uVGltZRIrChFwcm9ncmVzc2lvbl9zdHlsZRgEIAEoCV'
    'IQcHJvZ3Jlc3Npb25TdHlsZQ==');

@$core.Deprecated('Use trainingProgramLinkDescriptor instead')
const TrainingProgramLink$json = {
  '1': 'TrainingProgramLink',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `TrainingProgramLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramLinkDescriptor = $convert.base64Decode(
    'ChNUcmFpbmluZ1Byb2dyYW1MaW5rEhQKBWxhYmVsGAEgASgJUgVsYWJlbBIQCgN1cmwYAiABKA'
    'lSA3VybA==');

@$core.Deprecated('Use trainingProgramIntChoiceDescriptor instead')
const TrainingProgramIntChoice$json = {
  '1': 'TrainingProgramIntChoice',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 5, '10': 'value'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
  ],
};

/// Descriptor for `TrainingProgramIntChoice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramIntChoiceDescriptor =
    $convert.base64Decode(
        'ChhUcmFpbmluZ1Byb2dyYW1JbnRDaG9pY2USFAoFdmFsdWUYASABKAVSBXZhbHVlEhQKBWxhYm'
        'VsGAIgASgJUgVsYWJlbA==');

@$core.Deprecated('Use trainingProgramConfigFieldDescriptor instead')
const TrainingProgramConfigField$json = {
  '1': 'TrainingProgramConfigField',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'help_text', '3': 3, '4': 1, '5': 9, '10': 'helpText'},
    {
      '1': 'kind',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.TrainingProgramFieldKind',
      '10': 'kind'
    },
    {
      '1': 'binding',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.TrainingProgramFieldBinding',
      '10': 'binding'
    },
    {'1': 'required', '3': 6, '4': 1, '5': 8, '10': 'required'},
    {'1': 'default_int32', '3': 7, '4': 1, '5': 5, '10': 'defaultInt32'},
    {'1': 'default_float', '3': 8, '4': 1, '5': 2, '10': 'defaultFloat'},
    {'1': 'default_bool', '3': 9, '4': 1, '5': 8, '10': 'defaultBool'},
    {'1': 'exercise_id', '3': 10, '4': 1, '5': 5, '10': 'exerciseId'},
    {
      '1': 'int_choices',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingProgramIntChoice',
      '10': 'intChoices'
    },
  ],
};

/// Descriptor for `TrainingProgramConfigField`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramConfigFieldDescriptor = $convert.base64Decode(
    'ChpUcmFpbmluZ1Byb2dyYW1Db25maWdGaWVsZBIQCgNrZXkYASABKAlSA2tleRIUCgVsYWJlbB'
    'gCIAEoCVIFbGFiZWwSGwoJaGVscF90ZXh0GAMgASgJUghoZWxwVGV4dBI4CgRraW5kGAQgASgO'
    'MiQud29ya291dC52MS5UcmFpbmluZ1Byb2dyYW1GaWVsZEtpbmRSBGtpbmQSQQoHYmluZGluZx'
    'gFIAEoDjInLndvcmtvdXQudjEuVHJhaW5pbmdQcm9ncmFtRmllbGRCaW5kaW5nUgdiaW5kaW5n'
    'EhoKCHJlcXVpcmVkGAYgASgIUghyZXF1aXJlZBIjCg1kZWZhdWx0X2ludDMyGAcgASgFUgxkZW'
    'ZhdWx0SW50MzISIwoNZGVmYXVsdF9mbG9hdBgIIAEoAlIMZGVmYXVsdEZsb2F0EiEKDGRlZmF1'
    'bHRfYm9vbBgJIAEoCFILZGVmYXVsdEJvb2wSHwoLZXhlcmNpc2VfaWQYCiABKAVSCmV4ZXJjaX'
    'NlSWQSRQoLaW50X2Nob2ljZXMYCyADKAsyJC53b3Jrb3V0LnYxLlRyYWluaW5nUHJvZ3JhbUlu'
    'dENob2ljZVIKaW50Q2hvaWNlcw==');

@$core.Deprecated('Use trainingProgramDefinitionDescriptor instead')
const TrainingProgramDefinition$json = {
  '1': 'TrainingProgramDefinition',
  '2': [
    {
      '1': 'regime_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RegimeType',
      '10': 'regimeType'
    },
    {'1': 'display_name', '3': 2, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'headline', '3': 3, '4': 1, '5': 9, '10': 'headline'},
    {'1': 'summary', '3': 4, '4': 1, '5': 9, '10': 'summary'},
    {'1': 'description', '3': 5, '4': 1, '5': 9, '10': 'description'},
    {'1': 'how_it_works', '3': 6, '4': 1, '5': 9, '10': 'howItWorks'},
    {
      '1': 'at_a_glance',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TrainingProgramAtAGlance',
      '10': 'atAGlance'
    },
    {'1': 'details', '3': 8, '4': 3, '5': 9, '10': 'details'},
    {
      '1': 'learn_more_links',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingProgramLink',
      '10': 'learnMoreLinks'
    },
    {
      '1': 'config_fields',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingProgramConfigField',
      '10': 'configFields'
    },
    {'1': 'sort_order', '3': 11, '4': 1, '5': 5, '10': 'sortOrder'},
  ],
};

/// Descriptor for `TrainingProgramDefinition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramDefinitionDescriptor = $convert.base64Decode(
    'ChlUcmFpbmluZ1Byb2dyYW1EZWZpbml0aW9uEjcKC3JlZ2ltZV90eXBlGAEgASgOMhYud29ya2'
    '91dC52MS5SZWdpbWVUeXBlUgpyZWdpbWVUeXBlEiEKDGRpc3BsYXlfbmFtZRgCIAEoCVILZGlz'
    'cGxheU5hbWUSGgoIaGVhZGxpbmUYAyABKAlSCGhlYWRsaW5lEhgKB3N1bW1hcnkYBCABKAlSB3'
    'N1bW1hcnkSIAoLZGVzY3JpcHRpb24YBSABKAlSC2Rlc2NyaXB0aW9uEiAKDGhvd19pdF93b3Jr'
    'cxgGIAEoCVIKaG93SXRXb3JrcxJECgthdF9hX2dsYW5jZRgHIAEoCzIkLndvcmtvdXQudjEuVH'
    'JhaW5pbmdQcm9ncmFtQXRBR2xhbmNlUglhdEFHbGFuY2USGAoHZGV0YWlscxgIIAMoCVIHZGV0'
    'YWlscxJJChBsZWFybl9tb3JlX2xpbmtzGAkgAygLMh8ud29ya291dC52MS5UcmFpbmluZ1Byb2'
    'dyYW1MaW5rUg5sZWFybk1vcmVMaW5rcxJLCg1jb25maWdfZmllbGRzGAogAygLMiYud29ya291'
    'dC52MS5UcmFpbmluZ1Byb2dyYW1Db25maWdGaWVsZFIMY29uZmlnRmllbGRzEh0KCnNvcnRfb3'
    'JkZXIYCyABKAVSCXNvcnRPcmRlcg==');

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

@$core.Deprecated('Use getTrainingProgramCatalogRequestDescriptor instead')
const GetTrainingProgramCatalogRequest$json = {
  '1': 'GetTrainingProgramCatalogRequest',
};

/// Descriptor for `GetTrainingProgramCatalogRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTrainingProgramCatalogRequestDescriptor =
    $convert.base64Decode('CiBHZXRUcmFpbmluZ1Byb2dyYW1DYXRhbG9nUmVxdWVzdA==');

@$core.Deprecated('Use getTrainingProgramCatalogResponseDescriptor instead')
const GetTrainingProgramCatalogResponse$json = {
  '1': 'GetTrainingProgramCatalogResponse',
  '2': [
    {
      '1': 'programs',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingProgramDefinition',
      '10': 'programs'
    },
  ],
};

/// Descriptor for `GetTrainingProgramCatalogResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTrainingProgramCatalogResponseDescriptor =
    $convert.base64Decode(
        'CiFHZXRUcmFpbmluZ1Byb2dyYW1DYXRhbG9nUmVzcG9uc2USQQoIcHJvZ3JhbXMYASADKAsyJS'
        '53b3Jrb3V0LnYxLlRyYWluaW5nUHJvZ3JhbURlZmluaXRpb25SCHByb2dyYW1z');
