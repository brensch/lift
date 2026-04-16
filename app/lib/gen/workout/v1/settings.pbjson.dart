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

@$core.Deprecated('Use stateFieldKindDescriptor instead')
const StateFieldKind$json = {
  '1': 'StateFieldKind',
  '2': [
    {'1': 'STATE_FIELD_KIND_UNSPECIFIED', '2': 0},
    {'1': 'STATE_FIELD_KIND_INT', '2': 1},
    {'1': 'STATE_FIELD_KIND_FLOAT', '2': 2},
    {'1': 'STATE_FIELD_KIND_BOOL', '2': 3},
    {'1': 'STATE_FIELD_KIND_STRING', '2': 4},
    {'1': 'STATE_FIELD_KIND_ENUM', '2': 5},
  ],
};

/// Descriptor for `StateFieldKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List stateFieldKindDescriptor = $convert.base64Decode(
    'Cg5TdGF0ZUZpZWxkS2luZBIgChxTVEFURV9GSUVMRF9LSU5EX1VOU1BFQ0lGSUVEEAASGAoUU1'
    'RBVEVfRklFTERfS0lORF9JTlQQARIaChZTVEFURV9GSUVMRF9LSU5EX0ZMT0FUEAISGQoVU1RB'
    'VEVfRklFTERfS0lORF9CT09MEAMSGwoXU1RBVEVfRklFTERfS0lORF9TVFJJTkcQBBIZChVTVE'
    'FURV9GSUVMRF9LSU5EX0VOVU0QBQ==');

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
    {'1': 'sort_order', '3': 11, '4': 1, '5': 5, '10': 'sortOrder'},
    {
      '1': 'state_schema',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TrainingProgramStateSchema',
      '10': 'stateSchema'
    },
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
    'dyYW1MaW5rUg5sZWFybk1vcmVMaW5rcxIdCgpzb3J0X29yZGVyGAsgASgFUglzb3J0T3JkZXIS'
    'SQoMc3RhdGVfc2NoZW1hGAwgASgLMiYud29ya291dC52MS5UcmFpbmluZ1Byb2dyYW1TdGF0ZV'
    'NjaGVtYVILc3RhdGVTY2hlbWE=');

@$core.Deprecated('Use stateEnumOptionDescriptor instead')
const StateEnumOption$json = {
  '1': 'StateEnumOption',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
  ],
};

/// Descriptor for `StateEnumOption`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stateEnumOptionDescriptor = $convert.base64Decode(
    'Cg9TdGF0ZUVudW1PcHRpb24SFAoFdmFsdWUYASABKAlSBXZhbHVlEhQKBWxhYmVsGAIgASgJUg'
    'VsYWJlbA==');

@$core.Deprecated('Use trainingProgramStateFieldSchemaDescriptor instead')
const TrainingProgramStateFieldSchema$json = {
  '1': 'TrainingProgramStateFieldSchema',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'help_text', '3': 3, '4': 1, '5': 9, '10': 'helpText'},
    {'1': 'section', '3': 4, '4': 1, '5': 9, '10': 'section'},
    {'1': 'order', '3': 5, '4': 1, '5': 5, '10': 'order'},
    {
      '1': 'kind',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.StateFieldKind',
      '10': 'kind'
    },
    {'1': 'required', '3': 7, '4': 1, '5': 8, '10': 'required'},
    {'1': 'min_value', '3': 8, '4': 1, '5': 1, '10': 'minValue'},
    {'1': 'max_value', '3': 9, '4': 1, '5': 1, '10': 'maxValue'},
    {'1': 'step', '3': 10, '4': 1, '5': 1, '10': 'step'},
    {
      '1': 'enum_options',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.StateEnumOption',
      '10': 'enumOptions'
    },
    {'1': 'onboarding_field', '3': 12, '4': 1, '5': 8, '10': 'onboardingField'},
  ],
};

/// Descriptor for `TrainingProgramStateFieldSchema`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramStateFieldSchemaDescriptor = $convert.base64Decode(
    'Ch9UcmFpbmluZ1Byb2dyYW1TdGF0ZUZpZWxkU2NoZW1hEhAKA2tleRgBIAEoCVIDa2V5EhQKBW'
    'xhYmVsGAIgASgJUgVsYWJlbBIbCgloZWxwX3RleHQYAyABKAlSCGhlbHBUZXh0EhgKB3NlY3Rp'
    'b24YBCABKAlSB3NlY3Rpb24SFAoFb3JkZXIYBSABKAVSBW9yZGVyEi4KBGtpbmQYBiABKA4yGi'
    '53b3Jrb3V0LnYxLlN0YXRlRmllbGRLaW5kUgRraW5kEhoKCHJlcXVpcmVkGAcgASgIUghyZXF1'
    'aXJlZBIbCgltaW5fdmFsdWUYCCABKAFSCG1pblZhbHVlEhsKCW1heF92YWx1ZRgJIAEoAVIIbW'
    'F4VmFsdWUSEgoEc3RlcBgKIAEoAVIEc3RlcBI+CgxlbnVtX29wdGlvbnMYCyADKAsyGy53b3Jr'
    'b3V0LnYxLlN0YXRlRW51bU9wdGlvblILZW51bU9wdGlvbnMSKQoQb25ib2FyZGluZ19maWVsZB'
    'gMIAEoCFIPb25ib2FyZGluZ0ZpZWxk');

@$core.Deprecated('Use trainingProgramStateSchemaDescriptor instead')
const TrainingProgramStateSchema$json = {
  '1': 'TrainingProgramStateSchema',
  '2': [
    {
      '1': 'fields',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingProgramStateFieldSchema',
      '10': 'fields'
    },
  ],
};

/// Descriptor for `TrainingProgramStateSchema`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramStateSchemaDescriptor =
    $convert.base64Decode(
        'ChpUcmFpbmluZ1Byb2dyYW1TdGF0ZVNjaGVtYRJDCgZmaWVsZHMYASADKAsyKy53b3Jrb3V0Ln'
        'YxLlRyYWluaW5nUHJvZ3JhbVN0YXRlRmllbGRTY2hlbWFSBmZpZWxkcw==');

@$core.Deprecated('Use stateFieldValueDescriptor instead')
const StateFieldValue$json = {
  '1': 'StateFieldValue',
  '2': [
    {'1': 'int_val', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'intVal'},
    {'1': 'float_val', '3': 2, '4': 1, '5': 1, '9': 0, '10': 'floatVal'},
    {'1': 'bool_val', '3': 3, '4': 1, '5': 8, '9': 0, '10': 'boolVal'},
    {'1': 'string_val', '3': 4, '4': 1, '5': 9, '9': 0, '10': 'stringVal'},
  ],
  '8': [
    {'1': 'value'},
  ],
};

/// Descriptor for `StateFieldValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stateFieldValueDescriptor = $convert.base64Decode(
    'Cg9TdGF0ZUZpZWxkVmFsdWUSGQoHaW50X3ZhbBgBIAEoA0gAUgZpbnRWYWwSHQoJZmxvYXRfdm'
    'FsGAIgASgBSABSCGZsb2F0VmFsEhsKCGJvb2xfdmFsGAMgASgISABSB2Jvb2xWYWwSHwoKc3Ry'
    'aW5nX3ZhbBgEIAEoCUgAUglzdHJpbmdWYWxCBwoFdmFsdWU=');

@$core.Deprecated('Use trainingProgramStateDescriptor instead')
const TrainingProgramState$json = {
  '1': 'TrainingProgramState',
  '2': [
    {
      '1': 'regime_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RegimeType',
      '10': 'regimeType'
    },
    {
      '1': 'fields',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingProgramState.FieldsEntry',
      '10': 'fields'
    },
    {'1': 'updated_at', '3': 3, '4': 1, '5': 3, '10': 'updatedAt'},
    {'1': 'source', '3': 4, '4': 1, '5': 9, '10': 'source'},
  ],
  '3': [TrainingProgramState_FieldsEntry$json],
};

@$core.Deprecated('Use trainingProgramStateDescriptor instead')
const TrainingProgramState_FieldsEntry$json = {
  '1': 'FieldsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StateFieldValue',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `TrainingProgramState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramStateDescriptor = $convert.base64Decode(
    'ChRUcmFpbmluZ1Byb2dyYW1TdGF0ZRI3CgtyZWdpbWVfdHlwZRgBIAEoDjIWLndvcmtvdXQudj'
    'EuUmVnaW1lVHlwZVIKcmVnaW1lVHlwZRJECgZmaWVsZHMYAiADKAsyLC53b3Jrb3V0LnYxLlRy'
    'YWluaW5nUHJvZ3JhbVN0YXRlLkZpZWxkc0VudHJ5UgZmaWVsZHMSHQoKdXBkYXRlZF9hdBgDIA'
    'EoA1IJdXBkYXRlZEF0EhYKBnNvdXJjZRgEIAEoCVIGc291cmNlGlYKC0ZpZWxkc0VudHJ5EhAK'
    'A2tleRgBIAEoCVIDa2V5EjEKBXZhbHVlGAIgASgLMhsud29ya291dC52MS5TdGF0ZUZpZWxkVm'
    'FsdWVSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use trainingProgramStateEventDescriptor instead')
const TrainingProgramStateEvent$json = {
  '1': 'TrainingProgramStateEvent',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {
      '1': 'regime_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RegimeType',
      '10': 'regimeType'
    },
    {'1': 'effective_at', '3': 3, '4': 1, '5': 3, '10': 'effectiveAt'},
    {'1': 'recorded_at', '3': 4, '4': 1, '5': 3, '10': 'recordedAt'},
    {'1': 'source', '3': 5, '4': 1, '5': 9, '10': 'source'},
    {
      '1': 'fields',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingProgramStateEvent.FieldsEntry',
      '10': 'fields'
    },
    {'1': 'source_workout_id', '3': 7, '4': 1, '5': 9, '10': 'sourceWorkoutId'},
  ],
  '3': [TrainingProgramStateEvent_FieldsEntry$json],
};

@$core.Deprecated('Use trainingProgramStateEventDescriptor instead')
const TrainingProgramStateEvent_FieldsEntry$json = {
  '1': 'FieldsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StateFieldValue',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `TrainingProgramStateEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingProgramStateEventDescriptor = $convert.base64Decode(
    'ChlUcmFpbmluZ1Byb2dyYW1TdGF0ZUV2ZW50EhkKCGV2ZW50X2lkGAEgASgJUgdldmVudElkEj'
    'cKC3JlZ2ltZV90eXBlGAIgASgOMhYud29ya291dC52MS5SZWdpbWVUeXBlUgpyZWdpbWVUeXBl'
    'EiEKDGVmZmVjdGl2ZV9hdBgDIAEoA1ILZWZmZWN0aXZlQXQSHwoLcmVjb3JkZWRfYXQYBCABKA'
    'NSCnJlY29yZGVkQXQSFgoGc291cmNlGAUgASgJUgZzb3VyY2USSQoGZmllbGRzGAYgAygLMjEu'
    'd29ya291dC52MS5UcmFpbmluZ1Byb2dyYW1TdGF0ZUV2ZW50LkZpZWxkc0VudHJ5UgZmaWVsZH'
    'MSKgoRc291cmNlX3dvcmtvdXRfaWQYByABKAlSD3NvdXJjZVdvcmtvdXRJZBpWCgtGaWVsZHNF'
    'bnRyeRIQCgNrZXkYASABKAlSA2tleRIxCgV2YWx1ZRgCIAEoCzIbLndvcmtvdXQudjEuU3RhdG'
    'VGaWVsZFZhbHVlUgV2YWx1ZToCOAE=');

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
  ],
  '8': [
    {'1': 'setting'},
  ],
};

/// Descriptor for `UserSetting`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userSettingDescriptor = $convert.base64Decode(
    'CgtVc2VyU2V0dGluZxJCCgxwbGF0ZV9jb2xvcnMYCiABKAsyHS53b3Jrb3V0LnYxLlBsYXRlQ2'
    '9sb3JzQ29uZmlnSABSC3BsYXRlQ29sb3JzEj8KC3dlaWdodF91bml0GAwgASgLMhwud29ya291'
    'dC52MS5XZWlnaHRVbml0Q29uZmlnSABSCndlaWdodFVuaXRCCQoHc2V0dGluZw==');

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

@$core.Deprecated('Use getActiveTrainingProgramStateRequestDescriptor instead')
const GetActiveTrainingProgramStateRequest$json = {
  '1': 'GetActiveTrainingProgramStateRequest',
};

/// Descriptor for `GetActiveTrainingProgramStateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getActiveTrainingProgramStateRequestDescriptor =
    $convert
        .base64Decode('CiRHZXRBY3RpdmVUcmFpbmluZ1Byb2dyYW1TdGF0ZVJlcXVlc3Q=');

@$core.Deprecated('Use getActiveTrainingProgramStateResponseDescriptor instead')
const GetActiveTrainingProgramStateResponse$json = {
  '1': 'GetActiveTrainingProgramStateResponse',
  '2': [
    {
      '1': 'state',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TrainingProgramState',
      '10': 'state'
    },
    {
      '1': 'schema',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TrainingProgramStateSchema',
      '10': 'schema'
    },
  ],
};

/// Descriptor for `GetActiveTrainingProgramStateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getActiveTrainingProgramStateResponseDescriptor =
    $convert.base64Decode(
        'CiVHZXRBY3RpdmVUcmFpbmluZ1Byb2dyYW1TdGF0ZVJlc3BvbnNlEjYKBXN0YXRlGAEgASgLMi'
        'Aud29ya291dC52MS5UcmFpbmluZ1Byb2dyYW1TdGF0ZVIFc3RhdGUSPgoGc2NoZW1hGAIgASgL'
        'MiYud29ya291dC52MS5UcmFpbmluZ1Byb2dyYW1TdGF0ZVNjaGVtYVIGc2NoZW1h');

@$core.Deprecated('Use setActiveTrainingProgramStateRequestDescriptor instead')
const SetActiveTrainingProgramStateRequest$json = {
  '1': 'SetActiveTrainingProgramStateRequest',
  '2': [
    {
      '1': 'regime_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.RegimeType',
      '10': 'regimeType'
    },
    {
      '1': 'fields',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SetActiveTrainingProgramStateRequest.FieldsEntry',
      '10': 'fields'
    },
    {'1': 'source', '3': 3, '4': 1, '5': 9, '10': 'source'},
  ],
  '3': [SetActiveTrainingProgramStateRequest_FieldsEntry$json],
};

@$core.Deprecated('Use setActiveTrainingProgramStateRequestDescriptor instead')
const SetActiveTrainingProgramStateRequest_FieldsEntry$json = {
  '1': 'FieldsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StateFieldValue',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `SetActiveTrainingProgramStateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setActiveTrainingProgramStateRequestDescriptor = $convert.base64Decode(
    'CiRTZXRBY3RpdmVUcmFpbmluZ1Byb2dyYW1TdGF0ZVJlcXVlc3QSNwoLcmVnaW1lX3R5cGUYAS'
    'ABKA4yFi53b3Jrb3V0LnYxLlJlZ2ltZVR5cGVSCnJlZ2ltZVR5cGUSVAoGZmllbGRzGAIgAygL'
    'Mjwud29ya291dC52MS5TZXRBY3RpdmVUcmFpbmluZ1Byb2dyYW1TdGF0ZVJlcXVlc3QuRmllbG'
    'RzRW50cnlSBmZpZWxkcxIWCgZzb3VyY2UYAyABKAlSBnNvdXJjZRpWCgtGaWVsZHNFbnRyeRIQ'
    'CgNrZXkYASABKAlSA2tleRIxCgV2YWx1ZRgCIAEoCzIbLndvcmtvdXQudjEuU3RhdGVGaWVsZF'
    'ZhbHVlUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use setActiveTrainingProgramStateResponseDescriptor instead')
const SetActiveTrainingProgramStateResponse$json = {
  '1': 'SetActiveTrainingProgramStateResponse',
  '2': [
    {
      '1': 'state',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TrainingProgramState',
      '10': 'state'
    },
    {
      '1': 'validation_warnings',
      '3': 2,
      '4': 3,
      '5': 9,
      '10': 'validationWarnings'
    },
  ],
};

/// Descriptor for `SetActiveTrainingProgramStateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setActiveTrainingProgramStateResponseDescriptor =
    $convert.base64Decode(
        'CiVTZXRBY3RpdmVUcmFpbmluZ1Byb2dyYW1TdGF0ZVJlc3BvbnNlEjYKBXN0YXRlGAEgASgLMi'
        'Aud29ya291dC52MS5UcmFpbmluZ1Byb2dyYW1TdGF0ZVIFc3RhdGUSLwoTdmFsaWRhdGlvbl93'
        'YXJuaW5ncxgCIAMoCVISdmFsaWRhdGlvbldhcm5pbmdz');

@$core.Deprecated('Use getTrainingProgramStateHistoryRequestDescriptor instead')
const GetTrainingProgramStateHistoryRequest$json = {
  '1': 'GetTrainingProgramStateHistoryRequest',
};

/// Descriptor for `GetTrainingProgramStateHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTrainingProgramStateHistoryRequestDescriptor =
    $convert
        .base64Decode('CiVHZXRUcmFpbmluZ1Byb2dyYW1TdGF0ZUhpc3RvcnlSZXF1ZXN0');

@$core
    .Deprecated('Use getTrainingProgramStateHistoryResponseDescriptor instead')
const GetTrainingProgramStateHistoryResponse$json = {
  '1': 'GetTrainingProgramStateHistoryResponse',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingProgramStateEvent',
      '10': 'events'
    },
  ],
};

/// Descriptor for `GetTrainingProgramStateHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTrainingProgramStateHistoryResponseDescriptor =
    $convert.base64Decode(
        'CiZHZXRUcmFpbmluZ1Byb2dyYW1TdGF0ZUhpc3RvcnlSZXNwb25zZRI9CgZldmVudHMYASADKA'
        'syJS53b3Jrb3V0LnYxLlRyYWluaW5nUHJvZ3JhbVN0YXRlRXZlbnRSBmV2ZW50cw==');
