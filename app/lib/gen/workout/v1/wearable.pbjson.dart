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
    {'1': 'WEAR_ACTION_TYPE_START_SET', '2': 1},
    {'1': 'WEAR_ACTION_TYPE_COMPLETE_SET', '2': 2},
    {'1': 'WEAR_ACTION_TYPE_SKIP_WARMUP', '2': 3},
    {'1': 'WEAR_ACTION_TYPE_END_WORKOUT', '2': 4},
  ],
};

/// Descriptor for `WearActionType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wearActionTypeDescriptor = $convert.base64Decode(
    'Cg5XZWFyQWN0aW9uVHlwZRIgChxXRUFSX0FDVElPTl9UWVBFX1VOU1BFQ0lGSUVEEAASHgoaV0'
    'VBUl9BQ1RJT05fVFlQRV9TVEFSVF9TRVQQARIhCh1XRUFSX0FDVElPTl9UWVBFX0NPTVBMRVRF'
    'X1NFVBACEiAKHFdFQVJfQUNUSU9OX1RZUEVfU0tJUF9XQVJNVVAQAxIgChxXRUFSX0FDVElPTl'
    '9UWVBFX0VORF9XT1JLT1VUEAQ=');

@$core.Deprecated('Use wearActionStyleDescriptor instead')
const WearActionStyle$json = {
  '1': 'WearActionStyle',
  '2': [
    {'1': 'WEAR_ACTION_STYLE_UNSPECIFIED', '2': 0},
    {'1': 'WEAR_ACTION_STYLE_PRIMARY', '2': 1},
    {'1': 'WEAR_ACTION_STYLE_SECONDARY', '2': 2},
    {'1': 'WEAR_ACTION_STYLE_REP_OPTION', '2': 3},
  ],
};

/// Descriptor for `WearActionStyle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List wearActionStyleDescriptor = $convert.base64Decode(
    'Cg9XZWFyQWN0aW9uU3R5bGUSIQodV0VBUl9BQ1RJT05fU1RZTEVfVU5TUEVDSUZJRUQQABIdCh'
    'lXRUFSX0FDVElPTl9TVFlMRV9QUklNQVJZEAESHwobV0VBUl9BQ1RJT05fU1RZTEVfU0VDT05E'
    'QVJZEAISIAocV0VBUl9BQ1RJT05fU1RZTEVfUkVQX09QVElPThAD');

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
    {'1': 'side_label', '3': 1, '4': 1, '5': 9, '10': 'sideLabel'},
    {'1': 'header', '3': 2, '4': 1, '5': 9, '10': 'header'},
    {'1': 'state_label', '3': 3, '4': 1, '5': 9, '10': 'stateLabel'},
    {'1': 'timer_text', '3': 4, '4': 1, '5': 9, '10': 'timerText'},
    {'1': 'is_complete', '3': 5, '4': 1, '5': 8, '10': 'isComplete'},
    {
      '1': 'display_set',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'displaySet'
    },
  ],
};

/// Descriptor for `WearStatusCard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearStatusCardDescriptor = $convert.base64Decode(
    'Cg5XZWFyU3RhdHVzQ2FyZBIdCgpzaWRlX2xhYmVsGAEgASgJUglzaWRlTGFiZWwSFgoGaGVhZG'
    'VyGAIgASgJUgZoZWFkZXISHwoLc3RhdGVfbGFiZWwYAyABKAlSCnN0YXRlTGFiZWwSHQoKdGlt'
    'ZXJfdGV4dBgEIAEoCVIJdGltZXJUZXh0Eh8KC2lzX2NvbXBsZXRlGAUgASgIUgppc0NvbXBsZX'
    'RlEjgKC2Rpc3BsYXlfc2V0GAYgASgLMhcud29ya291dC52MS5Qcm9wb3NlZFNldFIKZGlzcGxh'
    'eVNldA==');

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
  ],
};

/// Descriptor for `WearAction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearActionDescriptor = $convert.base64Decode(
    'CgpXZWFyQWN0aW9uEi4KBHR5cGUYASABKA4yGi53b3Jrb3V0LnYxLldlYXJBY3Rpb25UeXBlUg'
    'R0eXBlEjEKBXN0eWxlGAIgASgOMhsud29ya291dC52MS5XZWFyQWN0aW9uU3R5bGVSBXN0eWxl'
    'EhQKBWxhYmVsGAMgASgJUgVsYWJlbBIVCgZzZXRfaWQYBCABKAlSBXNldElkEhIKBHJlcHMYBS'
    'ABKAVSBHJlcHMSIwoNYWN0dWFsX3dlaWdodBgGIAEoAlIMYWN0dWFsV2VpZ2h0');

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
    {'1': 'active_started_at', '3': 5, '4': 1, '5': 3, '10': 'activeStartedAt'},
    {'1': 'rest_until', '3': 6, '4': 1, '5': 3, '10': 'restUntil'},
    {'1': 'last_rest_end', '3': 7, '4': 1, '5': 3, '10': 'lastRestEnd'},
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
      '1': 'group_card',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WearStatusCard',
      '10': 'groupCard'
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
  ],
};

/// Descriptor for `WearWorkoutSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearWorkoutSnapshotDescriptor = $convert.base64Decode(
    'ChNXZWFyV29ya291dFNuYXBzaG90Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZBIdCg'
    'plbWl0dGVkX2F0GAIgASgDUgllbWl0dGVkQXQSLgoFc3RhdGUYAyABKA4yGC53b3Jrb3V0LnYx'
    'LldvcmtvdXRTdGF0ZVIFc3RhdGUSLAoSd29ya291dF9zdGFydF90aW1lGAQgASgDUhB3b3Jrb3'
    'V0U3RhcnRUaW1lEioKEWFjdGl2ZV9zdGFydGVkX2F0GAUgASgDUg9hY3RpdmVTdGFydGVkQXQS'
    'HQoKcmVzdF91bnRpbBgGIAEoA1IJcmVzdFVudGlsEiIKDWxhc3RfcmVzdF9lbmQYByABKANSC2'
    'xhc3RSZXN0RW5kEiEKDGVsYXBzZWRfdGV4dBgIIAEoCVILZWxhcHNlZFRleHQSNQoIeW91X2Nh'
    'cmQYCSABKAsyGi53b3Jrb3V0LnYxLldlYXJTdGF0dXNDYXJkUgd5b3VDYXJkEjkKCmdyb3VwX2'
    'NhcmQYCiABKAsyGi53b3Jrb3V0LnYxLldlYXJTdGF0dXNDYXJkUglncm91cENhcmQSMAoHYWN0'
    'aW9ucxgLIAMoCzIWLndvcmtvdXQudjEuV2VhckFjdGlvblIHYWN0aW9ucxJQChJjb21wbGV0aW'
    '9uX3N1bW1hcnkYDCABKAsyIS53b3Jrb3V0LnYxLldlYXJDb21wbGV0aW9uU3VtbWFyeVIRY29t'
    'cGxldGlvblN1bW1hcnk=');

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
  ],
};

/// Descriptor for `WearCompletionSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearCompletionSummaryDescriptor = $convert.base64Decode(
    'ChVXZWFyQ29tcGxldGlvblN1bW1hcnkSIwoNZHVyYXRpb25fdGV4dBgBIAEoCVIMZHVyYXRpb2'
    '5UZXh0EjQKFmNvbXBsZXRlZF93b3JraW5nX3NldHMYAiABKAVSFGNvbXBsZXRlZFdvcmtpbmdT'
    'ZXRzEiYKD3RvdGFsX3ZvbHVtZV9sYhgDIAEoBVINdG90YWxWb2x1bWVMYg==');

@$core.Deprecated('Use startSetIntentDescriptor instead')
const StartSetIntent$json = {
  '1': 'StartSetIntent',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'set_id', '3': 2, '4': 1, '5': 9, '10': 'setId'},
  ],
};

/// Descriptor for `StartSetIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSetIntentDescriptor = $convert.base64Decode(
    'Cg5TdGFydFNldEludGVudBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQSFQoGc2V0X2'
    'lkGAIgASgJUgVzZXRJZA==');

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
};

/// Descriptor for `CompleteSetIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetIntentDescriptor = $convert.base64Decode(
    'ChFDb21wbGV0ZVNldEludGVudBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQSFQoGc2'
    'V0X2lkGAIgASgJUgVzZXRJZBISCgRyZXBzGAMgASgFUgRyZXBzEiMKDWFjdHVhbF93ZWlnaHQY'
    'BCABKAJSDGFjdHVhbFdlaWdodBIhCgxjb21wbGV0ZWRfYXQYBSABKANSC2NvbXBsZXRlZEF0');

@$core.Deprecated('Use skipWarmupIntentDescriptor instead')
const SkipWarmupIntent$json = {
  '1': 'SkipWarmupIntent',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'set_id', '3': 2, '4': 1, '5': 9, '10': 'setId'},
  ],
};

/// Descriptor for `SkipWarmupIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skipWarmupIntentDescriptor = $convert.base64Decode(
    'ChBTa2lwV2FybXVwSW50ZW50Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZBIVCgZzZX'
    'RfaWQYAiABKAlSBXNldElk');

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
      '1': 'start_set',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StartSetIntent',
      '9': 0,
      '10': 'startSet'
    },
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
      '1': 'skip_warmup',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SkipWarmupIntent',
      '9': 0,
      '10': 'skipWarmup'
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
  ],
  '8': [
    {'1': 'intent'},
  ],
};

/// Descriptor for `WearIntent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearIntentDescriptor = $convert.base64Decode(
    'CgpXZWFySW50ZW50EhsKCWludGVudF9pZBgBIAEoCVIIaW50ZW50SWQSFwoHc2VudF9hdBgCIA'
    'EoA1IGc2VudEF0EjkKCXN0YXJ0X3NldBgKIAEoCzIaLndvcmtvdXQudjEuU3RhcnRTZXRJbnRl'
    'bnRIAFIIc3RhcnRTZXQSQgoMY29tcGxldGVfc2V0GAsgASgLMh0ud29ya291dC52MS5Db21wbG'
    'V0ZVNldEludGVudEgAUgtjb21wbGV0ZVNldBI/Cgtza2lwX3dhcm11cBgMIAEoCzIcLndvcmtv'
    'dXQudjEuU2tpcFdhcm11cEludGVudEgAUgpza2lwV2FybXVwEj8KC2VuZF93b3Jrb3V0GA0gAS'
    'gLMhwud29ya291dC52MS5FbmRXb3Jrb3V0SW50ZW50SABSCmVuZFdvcmtvdXRCCAoGaW50ZW50');

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
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'heart_rate_samples',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.HeartRateSample',
      '10': 'heartRateSamples'
    },
  ],
};

/// Descriptor for `WearSensorBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearSensorBatchDescriptor = $convert.base64Decode(
    'Cg9XZWFyU2Vuc29yQmF0Y2gSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEkkKEmhlYX'
    'J0X3JhdGVfc2FtcGxlcxgCIAMoCzIbLndvcmtvdXQudjEuSGVhcnRSYXRlU2FtcGxlUhBoZWFy'
    'dFJhdGVTYW1wbGVz');

@$core.Deprecated('Use phoneToWearEnvelopeDescriptor instead')
const PhoneToWearEnvelope$json = {
  '1': 'PhoneToWearEnvelope',
  '2': [
    {
      '1': 'snapshot',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WearWorkoutSnapshot',
      '9': 0,
      '10': 'snapshot'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `PhoneToWearEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List phoneToWearEnvelopeDescriptor = $convert.base64Decode(
    'ChNQaG9uZVRvV2VhckVudmVsb3BlEj0KCHNuYXBzaG90GAEgASgLMh8ud29ya291dC52MS5XZW'
    'FyV29ya291dFNuYXBzaG90SABSCHNuYXBzaG90QgkKB3BheWxvYWQ=');

@$core.Deprecated('Use wearToPhoneEnvelopeDescriptor instead')
const WearToPhoneEnvelope$json = {
  '1': 'WearToPhoneEnvelope',
  '2': [
    {
      '1': 'intent',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WearIntent',
      '9': 0,
      '10': 'intent'
    },
    {
      '1': 'sensor_batch',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WearSensorBatch',
      '9': 0,
      '10': 'sensorBatch'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `WearToPhoneEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List wearToPhoneEnvelopeDescriptor = $convert.base64Decode(
    'ChNXZWFyVG9QaG9uZUVudmVsb3BlEjAKBmludGVudBgBIAEoCzIWLndvcmtvdXQudjEuV2Vhck'
    'ludGVudEgAUgZpbnRlbnQSQAoMc2Vuc29yX2JhdGNoGAIgASgLMhsud29ya291dC52MS5XZWFy'
    'U2Vuc29yQmF0Y2hIAFILc2Vuc29yQmF0Y2hCCQoHcGF5bG9hZA==');
