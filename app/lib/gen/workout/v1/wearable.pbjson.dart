// This is a generated file - do not edit.
//
// Generated from workout/v1/wearable.proto.

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

@$core.Deprecated('Use wearActionTypeDescriptor instead')
const WearActionType$json = {
  '1': 'WearActionType',
  '2': [
    {'1': 'WEAR_ACTION_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'WEAR_ACTION_TYPE_COMPLETE_SET', '2': 2},
    {'1': 'WEAR_ACTION_TYPE_END_WORKOUT', '2': 4},
    {'1': 'WEAR_ACTION_TYPE_START_SET', '2': 8},
  ],
  '4': [
    {'1': 1, '2': 1},
    {'1': 3, '2': 3},
    {'1': 5, '2': 5},
    {'1': 6, '2': 6},
    {'1': 7, '2': 7},
  ],
  '5': [
    'WEAR_ACTION_TYPE_FEWER_REPS',
    'WEAR_ACTION_TYPE_SKIP_REST',
    'WEAR_ACTION_TYPE_RATE_EXERCISE',
    'WEAR_ACTION_TYPE_SKIP_WARMUP'
  ],
};

/// Descriptor for `WearActionType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wearActionTypeDescriptor = $convert.base64Decode(
    'Cg5XZWFyQWN0aW9uVHlwZRIgChxXRUFSX0FDVElPTl9UWVBFX1VOU1BFQ0lGSUVEEAASIQodV0'
    'VBUl9BQ1RJT05fVFlQRV9DT01QTEVURV9TRVQQAhIgChxXRUFSX0FDVElPTl9UWVBFX0VORF9X'
    'T1JLT1VUEAQSHgoaV0VBUl9BQ1RJT05fVFlQRV9TVEFSVF9TRVQQCCIECAEQASIECAMQAyIECA'
    'UQBSIECAYQBiIECAcQByobV0VBUl9BQ1RJT05fVFlQRV9GRVdFUl9SRVBTKhpXRUFSX0FDVElP'
    'Tl9UWVBFX1NLSVBfUkVTVCoeV0VBUl9BQ1RJT05fVFlQRV9SQVRFX0VYRVJDSVNFKhxXRUFSX0'
    'FDVElPTl9UWVBFX1NLSVBfV0FSTVVQ');

@$core.Deprecated('Use heartRateAvailabilityDescriptor instead')
const HeartRateAvailability$json = {
  '1': 'HeartRateAvailability',
  '2': [
    {'1': 'HEART_RATE_AVAILABILITY_UNSPECIFIED', '2': 0},
    {'1': 'HEART_RATE_AVAILABILITY_AVAILABLE', '2': 1},
    {'1': 'HEART_RATE_AVAILABILITY_ACQUIRING', '2': 2},
    {'1': 'HEART_RATE_AVAILABILITY_UNAVAILABLE', '2': 3},
  ],
};

/// Descriptor for `HeartRateAvailability`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List heartRateAvailabilityDescriptor = $convert.base64Decode(
    'ChVIZWFydFJhdGVBdmFpbGFiaWxpdHkSJwojSEVBUlRfUkFURV9BVkFJTEFCSUxJVFlfVU5TUE'
    'VDSUZJRUQQABIlCiFIRUFSVF9SQVRFX0FWQUlMQUJJTElUWV9BVkFJTEFCTEUQARIlCiFIRUFS'
    'VF9SQVRFX0FWQUlMQUJJTElUWV9BQ1FVSVJJTkcQAhInCiNIRUFSVF9SQVRFX0FWQUlMQUJJTE'
    'lUWV9VTkFWQUlMQUJMRRAD');

@$core.Deprecated('Use wearCircleStateDescriptor instead')
const WearCircleState$json = {
  '1': 'WearCircleState',
  '2': [
    {'1': 'WEAR_CIRCLE_STATE_UNSPECIFIED', '2': 0},
    {'1': 'WEAR_CIRCLE_STATE_PENDING', '2': 1},
    {'1': 'WEAR_CIRCLE_STATE_NEXT', '2': 2},
    {'1': 'WEAR_CIRCLE_STATE_LIFTING', '2': 3},
    {'1': 'WEAR_CIRCLE_STATE_FULL', '2': 4},
    {'1': 'WEAR_CIRCLE_STATE_SHORT', '2': 5},
    {'1': 'WEAR_CIRCLE_STATE_ZERO', '2': 6},
    {'1': 'WEAR_CIRCLE_STATE_SKIPPED', '2': 7},
  ],
};

/// Descriptor for `WearCircleState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wearCircleStateDescriptor = $convert.base64Decode(
    'Cg9XZWFyQ2lyY2xlU3RhdGUSIQodV0VBUl9DSVJDTEVfU1RBVEVfVU5TUEVDSUZJRUQQABIdCh'
    'lXRUFSX0NJUkNMRV9TVEFURV9QRU5ESU5HEAESGgoWV0VBUl9DSVJDTEVfU1RBVEVfTkVYVBAC'
    'Eh0KGVdFQVJfQ0lSQ0xFX1NUQVRFX0xJRlRJTkcQAxIaChZXRUFSX0NJUkNMRV9TVEFURV9GVU'
    'xMEAQSGwoXV0VBUl9DSVJDTEVfU1RBVEVfU0hPUlQQBRIaChZXRUFSX0NJUkNMRV9TVEFURV9a'
    'RVJPEAYSHQoZV0VBUl9DSVJDTEVfU1RBVEVfU0tJUFBFRBAH');

@$core.Deprecated('Use wearStatusCardDescriptor instead')
const WearStatusCard$json = {
  '1': 'WearStatusCard',
  '2': [
    {'1': 'state_label', '3': 3, '4': 1, '5': 9, '10': 'stateLabel'},
    {'1': 'timer_text', '3': 4, '4': 1, '5': 9, '10': 'timerText'},
    {
      '1': 'display_set',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'displaySet'
    },
    {'1': 'exercise_name', '3': 9, '4': 1, '5': 9, '10': 'exerciseName'},
    {'1': 'set_line', '3': 10, '4': 1, '5': 9, '10': 'setLine'},
    {'1': 'set_text', '3': 11, '4': 1, '5': 9, '10': 'setText'},
    {'1': 'yapping_label', '3': 12, '4': 1, '5': 9, '10': 'yappingLabel'},
    {'1': 'weight_text', '3': 14, '4': 1, '5': 9, '10': 'weightText'},
    {'1': 'unit_text', '3': 15, '4': 1, '5': 9, '10': 'unitText'},
    {'1': 'reps_text', '3': 16, '4': 1, '5': 9, '10': 'repsText'},
    {'1': 'first_time', '3': 18, '4': 1, '5': 8, '10': 'firstTime'},
    {
      '1': 'plates',
      '3': 19,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WearPlate',
      '10': 'plates'
    },
    {'1': 'plates_text', '3': 20, '4': 1, '5': 9, '10': 'platesText'},
    {'1': 'bar_text', '3': 21, '4': 1, '5': 9, '10': 'barText'},
  ],
  '9': [
    {'1': 1, '2': 2},
    {'1': 2, '2': 3},
    {'1': 5, '2': 6},
    {'1': 7, '2': 8},
    {'1': 8, '2': 9},
    {'1': 13, '2': 14},
  ],
  '10': [
    'side_label',
    'header',
    'is_complete',
    'current_group_set',
    'total_group_sets',
    'done_label'
  ],
};

/// Descriptor for `WearStatusCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearStatusCardDescriptor = $convert.base64Decode(
    'Cg5XZWFyU3RhdHVzQ2FyZBIfCgtzdGF0ZV9sYWJlbBgDIAEoCVIKc3RhdGVMYWJlbBIdCgp0aW'
    '1lcl90ZXh0GAQgASgJUgl0aW1lclRleHQSOAoLZGlzcGxheV9zZXQYBiABKAsyFy53b3Jrb3V0'
    'LnYxLlByb3Bvc2VkU2V0UgpkaXNwbGF5U2V0EiMKDWV4ZXJjaXNlX25hbWUYCSABKAlSDGV4ZX'
    'JjaXNlTmFtZRIZCghzZXRfbGluZRgKIAEoCVIHc2V0TGluZRIZCghzZXRfdGV4dBgLIAEoCVIH'
    'c2V0VGV4dBIjCg15YXBwaW5nX2xhYmVsGAwgASgJUgx5YXBwaW5nTGFiZWwSHwoLd2VpZ2h0X3'
    'RleHQYDiABKAlSCndlaWdodFRleHQSGwoJdW5pdF90ZXh0GA8gASgJUgh1bml0VGV4dBIbCgly'
    'ZXBzX3RleHQYECABKAlSCHJlcHNUZXh0Eh0KCmZpcnN0X3RpbWUYEiABKAhSCWZpcnN0VGltZR'
    'ItCgZwbGF0ZXMYEyADKAsyFS53b3Jrb3V0LnYxLldlYXJQbGF0ZVIGcGxhdGVzEh8KC3BsYXRl'
    'c190ZXh0GBQgASgJUgpwbGF0ZXNUZXh0EhkKCGJhcl90ZXh0GBUgASgJUgdiYXJUZXh0SgQIAR'
    'ACSgQIAhADSgQIBRAGSgQIBxAISgQICBAJSgQIDRAOUgpzaWRlX2xhYmVsUgZoZWFkZXJSC2lz'
    'X2NvbXBsZXRlUhFjdXJyZW50X2dyb3VwX3NldFIQdG90YWxfZ3JvdXBfc2V0c1IKZG9uZV9sYW'
    'JlbA==');

@$core.Deprecated('Use wearAmbientCopyDescriptor instead')
const WearAmbientCopy$json = {
  '1': 'WearAmbientCopy',
  '2': [
    {'1': 'min_left', '3': 1, '4': 1, '5': 9, '10': 'minLeft'},
    {'1': 'under_a_min', '3': 2, '4': 1, '5': 9, '10': 'underAMin'},
    {'1': 'min_over', '3': 3, '4': 1, '5': 9, '10': 'minOver'},
    {'1': 'rest_until', '3': 4, '4': 1, '5': 9, '10': 'restUntil'},
  ],
};

/// Descriptor for `WearAmbientCopy`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearAmbientCopyDescriptor = $convert.base64Decode(
    'Cg9XZWFyQW1iaWVudENvcHkSGQoIbWluX2xlZnQYASABKAlSB21pbkxlZnQSHgoLdW5kZXJfYV'
    '9taW4YAiABKAlSCXVuZGVyQU1pbhIZCghtaW5fb3ZlchgDIAEoCVIHbWluT3ZlchIdCgpyZXN0'
    'X3VudGlsGAQgASgJUglyZXN0VW50aWw=');

@$core.Deprecated('Use wearSetCircleDescriptor instead')
const WearSetCircle$json = {
  '1': 'WearSetCircle',
  '2': [
    {'1': 'set_id', '3': 1, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'state',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WearCircleState',
      '10': 'state'
    },
    {'1': 'warmup', '3': 4, '4': 1, '5': 8, '10': 'warmup'},
  ],
};

/// Descriptor for `WearSetCircle`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearSetCircleDescriptor = $convert.base64Decode(
    'Cg1XZWFyU2V0Q2lyY2xlEhUKBnNldF9pZBgBIAEoCVIFc2V0SWQSEgoEdGV4dBgCIAEoCVIEdG'
    'V4dBIxCgVzdGF0ZRgDIAEoDjIbLndvcmtvdXQudjEuV2VhckNpcmNsZVN0YXRlUgVzdGF0ZRIW'
    'CgZ3YXJtdXAYBCABKAhSBndhcm11cA==');

@$core.Deprecated('Use wearPlateDescriptor instead')
const WearPlate$json = {
  '1': 'WearPlate',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'color_hex', '3': 2, '4': 1, '5': 9, '10': 'colorHex'},
    {'1': 'size', '3': 3, '4': 1, '5': 2, '10': 'size'},
  ],
};

/// Descriptor for `WearPlate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearPlateDescriptor = $convert.base64Decode(
    'CglXZWFyUGxhdGUSFAoFbGFiZWwYASABKAlSBWxhYmVsEhsKCWNvbG9yX2hleBgCIAEoCVIIY2'
    '9sb3JIZXgSEgoEc2l6ZRgDIAEoAlIEc2l6ZQ==');

@$core.Deprecated('Use wearActionDescriptor instead')
const WearAction$json = {
  '1': 'WearAction',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WearActionType',
      '10': 'type'
    },
    {'1': 'label', '3': 3, '4': 1, '5': 9, '10': 'label'},
    {'1': 'set_id', '3': 4, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'reps', '3': 5, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'actual_weight', '3': 6, '4': 1, '5': 2, '10': 'actualWeight'},
  ],
  '9': [
    {'1': 2, '2': 3},
    {'1': 7, '2': 8},
  ],
  '10': ['style', 'effort'],
};

/// Descriptor for `WearAction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearActionDescriptor = $convert.base64Decode(
    'CgpXZWFyQWN0aW9uEi4KBHR5cGUYASABKA4yGi53b3Jrb3V0LnYxLldlYXJBY3Rpb25UeXBlUg'
    'R0eXBlEhQKBWxhYmVsGAMgASgJUgVsYWJlbBIVCgZzZXRfaWQYBCABKAlSBXNldElkEhIKBHJl'
    'cHMYBSABKAVSBHJlcHMSIwoNYWN0dWFsX3dlaWdodBgGIAEoAlIMYWN0dWFsV2VpZ2h0SgQIAh'
    'ADSgQIBxAIUgVzdHlsZVIGZWZmb3J0');

@$core.Deprecated('Use wearWorkoutSnapshotDescriptor instead')
const WearWorkoutSnapshot$json = {
  '1': 'WearWorkoutSnapshot',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'emitted_at', '3': 2, '4': 1, '5': 3, '10': 'emittedAt'},
    {
      '1': 'state',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WorkoutState',
      '10': 'state'
    },
    {
      '1': 'workout_start_time',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'workoutStartTime'
    },
    {'1': 'rest_until', '3': 6, '4': 1, '5': 3, '10': 'restUntil'},
    {
      '1': 'lifting_started_at',
      '3': 15,
      '4': 1,
      '5': 3,
      '10': 'liftingStartedAt'
    },
    {'1': 'elapsed_text', '3': 8, '4': 1, '5': 9, '10': 'elapsedText'},
    {
      '1': 'you_card',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WearStatusCard',
      '10': 'youCard'
    },
    {
      '1': 'actions',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WearAction',
      '10': 'actions'
    },
    {
      '1': 'completion_summary',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WearCompletionSummary',
      '10': 'completionSummary'
    },
    {'1': 'last_set_ended_at', '3': 16, '4': 1, '5': 3, '10': 'lastSetEndedAt'},
    {
      '1': 'circles',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WearSetCircle',
      '10': 'circles'
    },
    {'1': 'up_next_text', '3': 20, '4': 1, '5': 9, '10': 'upNextText'},
    {
      '1': 'ambient_copy',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WearAmbientCopy',
      '10': 'ambientCopy'
    },
  ],
  '9': [
    {'1': 5, '2': 6},
    {'1': 7, '2': 8},
    {'1': 18, '2': 19},
    {'1': 19, '2': 20},
    {'1': 10, '2': 11},
    {'1': 13, '2': 14},
    {'1': 14, '2': 15},
  ],
  '10': [
    'active_started_at',
    'last_rest_end',
    'group_card',
    'effort_prompt',
    'next_up_emoji'
  ],
};

/// Descriptor for `WearWorkoutSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearWorkoutSnapshotDescriptor = $convert.base64Decode(
    'ChNXZWFyV29ya291dFNuYXBzaG90Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZBIdCg'
    'plbWl0dGVkX2F0GAIgASgDUgllbWl0dGVkQXQSLgoFc3RhdGUYAyABKA4yGC53b3Jrb3V0LnYx'
    'LldvcmtvdXRTdGF0ZVIFc3RhdGUSLAoSd29ya291dF9zdGFydF90aW1lGAQgASgDUhB3b3Jrb3'
    'V0U3RhcnRUaW1lEh0KCnJlc3RfdW50aWwYBiABKANSCXJlc3RVbnRpbBIsChJsaWZ0aW5nX3N0'
    'YXJ0ZWRfYXQYDyABKANSEGxpZnRpbmdTdGFydGVkQXQSIQoMZWxhcHNlZF90ZXh0GAggASgJUg'
    'tlbGFwc2VkVGV4dBI1Cgh5b3VfY2FyZBgJIAEoCzIaLndvcmtvdXQudjEuV2VhclN0YXR1c0Nh'
    'cmRSB3lvdUNhcmQSMAoHYWN0aW9ucxgLIAMoCzIWLndvcmtvdXQudjEuV2VhckFjdGlvblIHYW'
    'N0aW9ucxJQChJjb21wbGV0aW9uX3N1bW1hcnkYDCABKAsyIS53b3Jrb3V0LnYxLldlYXJDb21w'
    'bGV0aW9uU3VtbWFyeVIRY29tcGxldGlvblN1bW1hcnkSKQoRbGFzdF9zZXRfZW5kZWRfYXQYEC'
    'ABKANSDmxhc3RTZXRFbmRlZEF0EjMKB2NpcmNsZXMYESADKAsyGS53b3Jrb3V0LnYxLldlYXJT'
    'ZXRDaXJjbGVSB2NpcmNsZXMSIAoMdXBfbmV4dF90ZXh0GBQgASgJUgp1cE5leHRUZXh0Ej4KDG'
    'FtYmllbnRfY29weRgVIAEoCzIbLndvcmtvdXQudjEuV2VhckFtYmllbnRDb3B5UgthbWJpZW50'
    'Q29weUoECAUQBkoECAcQCEoECBIQE0oECBMQFEoECAoQC0oECA0QDkoECA4QD1IRYWN0aXZlX3'
    'N0YXJ0ZWRfYXRSDWxhc3RfcmVzdF9lbmRSCmdyb3VwX2NhcmRSDWVmZm9ydF9wcm9tcHRSDW5l'
    'eHRfdXBfZW1vamk=');

@$core.Deprecated('Use wearCompletionSummaryDescriptor instead')
const WearCompletionSummary$json = {
  '1': 'WearCompletionSummary',
  '2': [
    {'1': 'duration_text', '3': 1, '4': 1, '5': 9, '10': 'durationText'},
    {
      '1': 'completed_working_sets',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'completedWorkingSets'
    },
    {'1': 'total_volume_lb', '3': 3, '4': 1, '5': 5, '10': 'totalVolumeLb'},
    {'1': 'volume_text', '3': 4, '4': 1, '5': 9, '10': 'volumeText'},
  ],
};

/// Descriptor for `WearCompletionSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearCompletionSummaryDescriptor = $convert.base64Decode(
    'ChVXZWFyQ29tcGxldGlvblN1bW1hcnkSIwoNZHVyYXRpb25fdGV4dBgBIAEoCVIMZHVyYXRpb2'
    '5UZXh0EjQKFmNvbXBsZXRlZF93b3JraW5nX3NldHMYAiABKAVSFGNvbXBsZXRlZFdvcmtpbmdT'
    'ZXRzEiYKD3RvdGFsX3ZvbHVtZV9sYhgDIAEoBVINdG90YWxWb2x1bWVMYhIfCgt2b2x1bWVfdG'
    'V4dBgEIAEoCVIKdm9sdW1lVGV4dA==');

@$core.Deprecated('Use completeSetIntentDescriptor instead')
const CompleteSetIntent$json = {
  '1': 'CompleteSetIntent',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'set_id', '3': 2, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'reps', '3': 3, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'actual_weight', '3': 4, '4': 1, '5': 2, '10': 'actualWeight'},
    {'1': 'completed_at', '3': 5, '4': 1, '5': 3, '10': 'completedAt'},
  ],
  '9': [
    {'1': 6, '2': 7},
  ],
  '10': ['effort'],
};

/// Descriptor for `CompleteSetIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetIntentDescriptor = $convert.base64Decode(
    'ChFDb21wbGV0ZVNldEludGVudBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQSFQoGc2'
    'V0X2lkGAIgASgJUgVzZXRJZBISCgRyZXBzGAMgASgFUgRyZXBzEiMKDWFjdHVhbF93ZWlnaHQY'
    'BCABKAJSDGFjdHVhbFdlaWdodBIhCgxjb21wbGV0ZWRfYXQYBSABKANSC2NvbXBsZXRlZEF0Sg'
    'QIBhAHUgZlZmZvcnQ=');

@$core.Deprecated('Use startSetIntentDescriptor instead')
const StartSetIntent$json = {
  '1': 'StartSetIntent',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'set_id', '3': 2, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'started_at', '3': 3, '4': 1, '5': 3, '10': 'startedAt'},
  ],
};

/// Descriptor for `StartSetIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSetIntentDescriptor = $convert.base64Decode(
    'Cg5TdGFydFNldEludGVudBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQSFQoGc2V0X2'
    'lkGAIgASgJUgVzZXRJZBIdCgpzdGFydGVkX2F0GAMgASgDUglzdGFydGVkQXQ=');

@$core.Deprecated('Use tapSetIntentDescriptor instead')
const TapSetIntent$json = {
  '1': 'TapSetIntent',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'set_id', '3': 2, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'tapped_at', '3': 3, '4': 1, '5': 3, '10': 'tappedAt'},
  ],
};

/// Descriptor for `TapSetIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tapSetIntentDescriptor = $convert.base64Decode(
    'CgxUYXBTZXRJbnRlbnQSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEhUKBnNldF9pZB'
    'gCIAEoCVIFc2V0SWQSGwoJdGFwcGVkX2F0GAMgASgDUgh0YXBwZWRBdA==');

@$core.Deprecated('Use endWorkoutIntentDescriptor instead')
const EndWorkoutIntent$json = {
  '1': 'EndWorkoutIntent',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `EndWorkoutIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List endWorkoutIntentDescriptor = $convert.base64Decode(
    'ChBFbmRXb3Jrb3V0SW50ZW50Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZA==');

@$core.Deprecated('Use wearIntentDescriptor instead')
const WearIntent$json = {
  '1': 'WearIntent',
  '2': [
    {'1': 'intent_id', '3': 1, '4': 1, '5': 9, '10': 'intentId'},
    {'1': 'sent_at', '3': 2, '4': 1, '5': 3, '10': 'sentAt'},
    {
      '1': 'complete_set',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CompleteSetIntent',
      '9': 0,
      '10': 'completeSet'
    },
    {
      '1': 'end_workout',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.EndWorkoutIntent',
      '9': 0,
      '10': 'endWorkout'
    },
    {
      '1': 'start_set',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StartSetIntent',
      '9': 0,
      '10': 'startSet'
    },
    {
      '1': 'tap_set',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.TapSetIntent',
      '9': 0,
      '10': 'tapSet'
    },
  ],
  '8': [
    {'1': 'intent'},
  ],
  '9': [
    {'1': 10, '2': 11},
    {'1': 12, '2': 13},
    {'1': 14, '2': 15},
    {'1': 15, '2': 16},
    {'1': 16, '2': 17},
    {'1': 18, '2': 19},
  ],
  '10': [
    'fewer_reps',
    'skip_rest',
    'rate_exercise',
    'skip_warmup',
    'edit_completed_set'
  ],
};

/// Descriptor for `WearIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearIntentDescriptor = $convert.base64Decode(
    'CgpXZWFySW50ZW50EhsKCWludGVudF9pZBgBIAEoCVIIaW50ZW50SWQSFwoHc2VudF9hdBgCIA'
    'EoA1IGc2VudEF0EkIKDGNvbXBsZXRlX3NldBgLIAEoCzIdLndvcmtvdXQudjEuQ29tcGxldGVT'
    'ZXRJbnRlbnRIAFILY29tcGxldGVTZXQSPwoLZW5kX3dvcmtvdXQYDSABKAsyHC53b3Jrb3V0Ln'
    'YxLkVuZFdvcmtvdXRJbnRlbnRIAFIKZW5kV29ya291dBI5CglzdGFydF9zZXQYESABKAsyGi53'
    'b3Jrb3V0LnYxLlN0YXJ0U2V0SW50ZW50SABSCHN0YXJ0U2V0EjMKB3RhcF9zZXQYEyABKAsyGC'
    '53b3Jrb3V0LnYxLlRhcFNldEludGVudEgAUgZ0YXBTZXRCCAoGaW50ZW50SgQIChALSgQIDBAN'
    'SgQIDhAPSgQIDxAQSgQIEBARSgQIEhATUgpmZXdlcl9yZXBzUglza2lwX3Jlc3RSDXJhdGVfZX'
    'hlcmNpc2VSC3NraXBfd2FybXVwUhJlZGl0X2NvbXBsZXRlZF9zZXQ=');

@$core.Deprecated('Use heartRateSampleDescriptor instead')
const HeartRateSample$json = {
  '1': 'HeartRateSample',
  '2': [
    {'1': 'sampled_at', '3': 1, '4': 1, '5': 3, '10': 'sampledAt'},
    {'1': 'bpm', '3': 2, '4': 1, '5': 2, '10': 'bpm'},
    {
      '1': 'availability',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.HeartRateAvailability',
      '10': 'availability'
    },
  ],
};

/// Descriptor for `HeartRateSample`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartRateSampleDescriptor = $convert.base64Decode(
    'Cg9IZWFydFJhdGVTYW1wbGUSHQoKc2FtcGxlZF9hdBgBIAEoA1IJc2FtcGxlZEF0EhAKA2JwbR'
    'gCIAEoAlIDYnBtEkUKDGF2YWlsYWJpbGl0eRgDIAEoDjIhLndvcmtvdXQudjEuSGVhcnRSYXRl'
    'QXZhaWxhYmlsaXR5UgxhdmFpbGFiaWxpdHk=');

@$core.Deprecated('Use wearSensorBatchDescriptor instead')
const WearSensorBatch$json = {
  '1': 'WearSensorBatch',
  '2': [
    {'1': 'batch_id', '3': 1, '4': 1, '5': 9, '10': 'batchId'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'sent_at', '3': 3, '4': 1, '5': 3, '10': 'sentAt'},
    {
      '1': 'heart_rate_samples',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.HeartRateSample',
      '10': 'heartRateSamples'
    },
  ],
};

/// Descriptor for `WearSensorBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearSensorBatchDescriptor = $convert.base64Decode(
    'Cg9XZWFyU2Vuc29yQmF0Y2gSGQoIYmF0Y2hfaWQYASABKAlSB2JhdGNoSWQSHQoKd29ya291dF'
    '9pZBgCIAEoCVIJd29ya291dElkEhcKB3NlbnRfYXQYAyABKANSBnNlbnRBdBJJChJoZWFydF9y'
    'YXRlX3NhbXBsZXMYBCADKAsyGy53b3Jrb3V0LnYxLkhlYXJ0UmF0ZVNhbXBsZVIQaGVhcnRSYX'
    'RlU2FtcGxlcw==');

@$core.Deprecated('Use wearSensorBatchAckDescriptor instead')
const WearSensorBatchAck$json = {
  '1': 'WearSensorBatchAck',
  '2': [
    {'1': 'batch_id', '3': 1, '4': 1, '5': 9, '10': 'batchId'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'received_at', '3': 3, '4': 1, '5': 3, '10': 'receivedAt'},
  ],
};

/// Descriptor for `WearSensorBatchAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearSensorBatchAckDescriptor = $convert.base64Decode(
    'ChJXZWFyU2Vuc29yQmF0Y2hBY2sSGQoIYmF0Y2hfaWQYASABKAlSB2JhdGNoSWQSHQoKd29ya2'
    '91dF9pZBgCIAEoCVIJd29ya291dElkEh8KC3JlY2VpdmVkX2F0GAMgASgDUgpyZWNlaXZlZEF0');
