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

@$core.Deprecated('Use wearActionStyleDescriptor instead')
const WearActionStyle$json = {
  '1': 'WearActionStyle',
  '2': [
    {'1': 'WEAR_ACTION_STYLE_UNSPECIFIED', '2': 0},
    {'1': 'WEAR_ACTION_STYLE_PRIMARY', '2': 1},
    {'1': 'WEAR_ACTION_STYLE_SECONDARY', '2': 2},
  ],
  '4': [
    {'1': 3, '2': 3},
  ],
  '5': ['WEAR_ACTION_STYLE_REP_OPTION'],
};

/// Descriptor for `WearActionStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wearActionStyleDescriptor = $convert.base64Decode(
    'Cg9XZWFyQWN0aW9uU3R5bGUSIQodV0VBUl9BQ1RJT05fU1RZTEVfVU5TUEVDSUZJRUQQABIdCh'
    'lXRUFSX0FDVElPTl9TVFlMRV9QUklNQVJZEAESHwobV0VBUl9BQ1RJT05fU1RZTEVfU0VDT05E'
    'QVJZEAIiBAgDEAMqHFdFQVJfQUNUSU9OX1NUWUxFX1JFUF9PUFRJT04=');

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
    'c2V0VGV4dBIjCg15YXBwaW5nX2xhYmVsGAwgASgJUgx5YXBwaW5nTGFiZWxKBAgBEAJKBAgCEA'
    'NKBAgFEAZKBAgHEAhKBAgIEAlKBAgNEA5SCnNpZGVfbGFiZWxSBmhlYWRlclILaXNfY29tcGxl'
    'dGVSEWN1cnJlbnRfZ3JvdXBfc2V0UhB0b3RhbF9ncm91cF9zZXRzUgpkb25lX2xhYmVs');

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
    {
      '1': 'style',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WearActionStyle',
      '10': 'style'
    },
    {'1': 'label', '3': 3, '4': 1, '5': 9, '10': 'label'},
    {'1': 'set_id', '3': 4, '4': 1, '5': 9, '10': 'setId'},
    {'1': 'reps', '3': 5, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'actual_weight', '3': 6, '4': 1, '5': 2, '10': 'actualWeight'},
    {
      '1': 'effort',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Effort',
      '10': 'effort'
    },
  ],
};

/// Descriptor for `WearAction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearActionDescriptor = $convert.base64Decode(
    'CgpXZWFyQWN0aW9uEi4KBHR5cGUYASABKA4yGi53b3Jrb3V0LnYxLldlYXJBY3Rpb25UeXBlUg'
    'R0eXBlEjEKBXN0eWxlGAIgASgOMhsud29ya291dC52MS5XZWFyQWN0aW9uU3R5bGVSBXN0eWxl'
    'EhQKBWxhYmVsGAMgASgJUgVsYWJlbBIVCgZzZXRfaWQYBCABKAlSBXNldElkEhIKBHJlcHMYBS'
    'ABKAVSBHJlcHMSIwoNYWN0dWFsX3dlaWdodBgGIAEoAlIMYWN0dWFsV2VpZ2h0EioKBmVmZm9y'
    'dBgHIAEoDjISLndvcmtvdXQudjEuRWZmb3J0UgZlZmZvcnQ=');

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
    {'1': 'next_up_emoji', '3': 13, '4': 1, '5': 9, '10': 'nextUpEmoji'},
  ],
  '9': [
    {'1': 5, '2': 6},
    {'1': 7, '2': 8},
    {'1': 10, '2': 11},
    {'1': 14, '2': 15},
  ],
  '10': ['active_started_at', 'last_rest_end', 'group_card', 'effort_prompt'],
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
    'bGV0aW9uU3VtbWFyeVIRY29tcGxldGlvblN1bW1hcnkSIgoNbmV4dF91cF9lbW9qaRgNIAEoCV'
    'ILbmV4dFVwRW1vamlKBAgFEAZKBAgHEAhKBAgKEAtKBAgOEA9SEWFjdGl2ZV9zdGFydGVkX2F0'
    'Ug1sYXN0X3Jlc3RfZW5kUgpncm91cF9jYXJkUg1lZmZvcnRfcHJvbXB0');

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
    {
      '1': 'effort',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Effort',
      '10': 'effort'
    },
  ],
};

/// Descriptor for `CompleteSetIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetIntentDescriptor = $convert.base64Decode(
    'ChFDb21wbGV0ZVNldEludGVudBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQSFQoGc2'
    'V0X2lkGAIgASgJUgVzZXRJZBISCgRyZXBzGAMgASgFUgRyZXBzEiMKDWFjdHVhbF93ZWlnaHQY'
    'BCABKAJSDGFjdHVhbFdlaWdodBIhCgxjb21wbGV0ZWRfYXQYBSABKANSC2NvbXBsZXRlZEF0Ei'
    'oKBmVmZm9ydBgGIAEoDjISLndvcmtvdXQudjEuRWZmb3J0UgZlZmZvcnQ=');

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
  ],
  '10': ['fewer_reps', 'skip_rest', 'rate_exercise', 'skip_warmup'],
};

/// Descriptor for `WearIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearIntentDescriptor = $convert.base64Decode(
    'CgpXZWFySW50ZW50EhsKCWludGVudF9pZBgBIAEoCVIIaW50ZW50SWQSFwoHc2VudF9hdBgCIA'
    'EoA1IGc2VudEF0EkIKDGNvbXBsZXRlX3NldBgLIAEoCzIdLndvcmtvdXQudjEuQ29tcGxldGVT'
    'ZXRJbnRlbnRIAFILY29tcGxldGVTZXQSPwoLZW5kX3dvcmtvdXQYDSABKAsyHC53b3Jrb3V0Ln'
    'YxLkVuZFdvcmtvdXRJbnRlbnRIAFIKZW5kV29ya291dBI5CglzdGFydF9zZXQYESABKAsyGi53'
    'b3Jrb3V0LnYxLlN0YXJ0U2V0SW50ZW50SABSCHN0YXJ0U2V0QggKBmludGVudEoECAoQC0oECA'
    'wQDUoECA4QD0oECA8QEEoECBAQEVIKZmV3ZXJfcmVwc1IJc2tpcF9yZXN0Ug1yYXRlX2V4ZXJj'
    'aXNlUgtza2lwX3dhcm11cA==');

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
