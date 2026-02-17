// This is a generated file - do not edit.
//
// Generated from workout/v1/workout.proto.

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
  ],
};

/// Descriptor for `MuscleGroup`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List muscleGroupDescriptor = $convert.base64Decode(
    'CgtNdXNjbGVHcm91cBIcChhNVVNDTEVfR1JPVVBfVU5TUEVDSUZJRUQQABIWChJNVVNDTEVfR1'
    'JPVVBfUVVBRFMQARIbChdNVVNDTEVfR1JPVVBfSEFNU1RSSU5HUxACEhcKE01VU0NMRV9HUk9V'
    'UF9HTFVURVMQAxIWChJNVVNDTEVfR1JPVVBfQ0hFU1QQBBIVChFNVVNDTEVfR1JPVVBfQkFDSx'
    'AFEhoKFk1VU0NMRV9HUk9VUF9TSE9VTERFUlMQBhIXChNNVVNDTEVfR1JPVVBfQklDRVBTEAcS'
    'GAoUTVVTQ0xFX0dST1VQX1RSSUNFUFMQCA==');

@$core.Deprecated('Use exerciseCategoryDescriptor instead')
const ExerciseCategory$json = {
  '1': 'ExerciseCategory',
  '2': [
    {'1': 'EXERCISE_CATEGORY_UNSPECIFIED', '2': 0},
    {'1': 'EXERCISE_CATEGORY_COMPOUND', '2': 1},
    {'1': 'EXERCISE_CATEGORY_AUXILIARY', '2': 2},
  ],
};

/// Descriptor for `ExerciseCategory`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exerciseCategoryDescriptor = $convert.base64Decode(
    'ChBFeGVyY2lzZUNhdGVnb3J5EiEKHUVYRVJDSVNFX0NBVEVHT1JZX1VOU1BFQ0lGSUVEEAASHg'
    'oaRVhFUkNJU0VfQ0FURUdPUllfQ09NUE9VTkQQARIfChtFWEVSQ0lTRV9DQVRFR09SWV9BVVhJ'
    'TElBUlkQAg==');

@$core.Deprecated('Use exerciseDescriptor instead')
const Exercise$json = {
  '1': 'Exercise',
  '2': [
    {'1': 'EXERCISE_UNSPECIFIED', '2': 0},
    {'1': 'EXERCISE_SQUAT', '2': 1},
    {'1': 'EXERCISE_BENCH_PRESS', '2': 2},
    {'1': 'EXERCISE_DEADLIFT', '2': 3},
    {'1': 'EXERCISE_OVERHEAD_PRESS', '2': 4},
    {'1': 'EXERCISE_BARBELL_ROW', '2': 5},
    {'1': 'EXERCISE_HIP_THRUST', '2': 6},
    {'1': 'EXERCISE_BULGARIAN_SPLIT_SQUAT', '2': 7},
    {'1': 'EXERCISE_ROMANIAN_DEADLIFT', '2': 8},
    {'1': 'EXERCISE_GLUTE_BRIDGE', '2': 9},
    {'1': 'EXERCISE_LUNGE', '2': 10},
    {'1': 'EXERCISE_LEG_CURL', '2': 11},
  ],
};

/// Descriptor for `Exercise`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List exerciseDescriptor = $convert.base64Decode(
    'CghFeGVyY2lzZRIYChRFWEVSQ0lTRV9VTlNQRUNJRklFRBAAEhIKDkVYRVJDSVNFX1NRVUFUEA'
    'ESGAoURVhFUkNJU0VfQkVOQ0hfUFJFU1MQAhIVChFFWEVSQ0lTRV9ERUFETElGVBADEhsKF0VY'
    'RVJDSVNFX09WRVJIRUFEX1BSRVNTEAQSGAoURVhFUkNJU0VfQkFSQkVMTF9ST1cQBRIXChNFWE'
    'VSQ0lTRV9ISVBfVEhSVVNUEAYSIgoeRVhFUkNJU0VfQlVMR0FSSUFOX1NQTElUX1NRVUFUEAcS'
    'HgoaRVhFUkNJU0VfUk9NQU5JQU5fREVBRExJRlQQCBIZChVFWEVSQ0lTRV9HTFVURV9CUklER0'
    'UQCRISCg5FWEVSQ0lTRV9MVU5HRRAKEhUKEUVYRVJDSVNFX0xFR19DVVJMEAs=');

@$core.Deprecated('Use workoutStateDescriptor instead')
const WorkoutState$json = {
  '1': 'WorkoutState',
  '2': [
    {'1': 'WORKOUT_STATE_UNSPECIFIED', '2': 0},
    {'1': 'WORKOUT_STATE_ALL_DONE', '2': 1},
    {'1': 'WORKOUT_STATE_LIFTING', '2': 2},
    {'1': 'WORKOUT_STATE_RESTING', '2': 3},
    {'1': 'WORKOUT_STATE_READY', '2': 5},
  ],
};

/// Descriptor for `WorkoutState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List workoutStateDescriptor = $convert.base64Decode(
    'CgxXb3Jrb3V0U3RhdGUSHQoZV09SS09VVF9TVEFURV9VTlNQRUNJRklFRBAAEhoKFldPUktPVV'
    'RfU1RBVEVfQUxMX0RPTkUQARIZChVXT1JLT1VUX1NUQVRFX0xJRlRJTkcQAhIZChVXT1JLT1VU'
    'X1NUQVRFX1JFU1RJTkcQAxIXChNXT1JLT1VUX1NUQVRFX1JFQURZEAU=');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'created_at', '3': 3, '4': 1, '5': 3, '10': 'createdAt'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCmNyZWF0ZWRfYX'
    'QYAyABKANSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use workoutDescriptor instead')
const Workout$json = {
  '1': 'Workout',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'start_time', '3': 3, '4': 1, '5': 3, '10': 'startTime'},
    {'1': 'end_time', '3': 4, '4': 1, '5': 3, '10': 'endTime'},
  ],
};

/// Descriptor for `Workout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutDescriptor = $convert.base64Decode(
    'CgdXb3Jrb3V0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh0KCnN0YXJ0X3'
    'RpbWUYAyABKANSCXN0YXJ0VGltZRIZCghlbmRfdGltZRgEIAEoA1IHZW5kVGltZQ==');

@$core.Deprecated('Use exerciseTypeConfigDescriptor instead')
const ExerciseTypeConfig$json = {
  '1': 'ExerciseTypeConfig',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'start_weight', '3': 2, '4': 1, '5': 2, '10': 'startWeight'},
    {'1': 'end_weight', '3': 3, '4': 1, '5': 2, '10': 'endWeight'},
    {'1': 'reps', '3': 4, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'include_warmup', '3': 5, '4': 1, '5': 8, '10': 'includeWarmup'},
    {
      '1': 'rest_config',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
  ],
};

/// Descriptor for `ExerciseTypeConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseTypeConfigDescriptor = $convert.base64Decode(
    'ChJFeGVyY2lzZVR5cGVDb25maWcSMAoIZXhlcmNpc2UYASABKA4yFC53b3Jrb3V0LnYxLkV4ZX'
    'JjaXNlUghleGVyY2lzZRIhCgxzdGFydF93ZWlnaHQYAiABKAJSC3N0YXJ0V2VpZ2h0Eh0KCmVu'
    'ZF93ZWlnaHQYAyABKAJSCWVuZFdlaWdodBISCgRyZXBzGAQgASgFUgRyZXBzEiUKDmluY2x1ZG'
    'Vfd2FybXVwGAUgASgIUg1pbmNsdWRlV2FybXVwEjcKC3Jlc3RfY29uZmlnGAYgASgLMhYud29y'
    'a291dC52MS5SZXN0Q29uZmlnUgpyZXN0Q29uZmln');

@$core.Deprecated('Use restConfigDescriptor instead')
const RestConfig$json = {
  '1': 'RestConfig',
  '2': [
    {
      '1': 'rest_after_success',
      '3': 1,
      '4': 1,
      '5': 5,
      '10': 'restAfterSuccess'
    },
    {
      '1': 'rest_after_failure',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'restAfterFailure'
    },
    {'1': 'rest_after_warmup', '3': 3, '4': 1, '5': 5, '10': 'restAfterWarmup'},
    {
      '1': 'rest_after_last_warmup',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'restAfterLastWarmup'
    },
  ],
};

/// Descriptor for `RestConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restConfigDescriptor = $convert.base64Decode(
    'CgpSZXN0Q29uZmlnEiwKEnJlc3RfYWZ0ZXJfc3VjY2VzcxgBIAEoBVIQcmVzdEFmdGVyU3VjY2'
    'VzcxIsChJyZXN0X2FmdGVyX2ZhaWx1cmUYAiABKAVSEHJlc3RBZnRlckZhaWx1cmUSKgoRcmVz'
    'dF9hZnRlcl93YXJtdXAYAyABKAVSD3Jlc3RBZnRlcldhcm11cBIzChZyZXN0X2FmdGVyX2xhc3'
    'Rfd2FybXVwGAQgASgFUhNyZXN0QWZ0ZXJMYXN0V2FybXVw');

@$core.Deprecated('Use exerciseGroupDescriptor instead')
const ExerciseGroup$json = {
  '1': 'ExerciseGroup',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sets', '3': 4, '4': 1, '5': 5, '10': 'sets'},
    {
      '1': 'interleave_warmups',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {'1': 'workout_order', '3': 6, '4': 1, '5': 5, '10': 'workoutOrder'},
    {
      '1': 'exercise_configs',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTypeConfig',
      '10': 'exerciseConfigs'
    },
    {
      '1': 'rest_config',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
  ],
};

/// Descriptor for `ExerciseGroup`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseGroupDescriptor = $convert.base64Decode(
    'Cg1FeGVyY2lzZUdyb3VwEg4KAmlkGAEgASgJUgJpZBIdCgp3b3Jrb3V0X2lkGAIgASgJUgl3b3'
    'Jrb3V0SWQSEgoEbmFtZRgDIAEoCVIEbmFtZRISCgRzZXRzGAQgASgFUgRzZXRzEi0KEmludGVy'
    'bGVhdmVfd2FybXVwcxgFIAEoCFIRaW50ZXJsZWF2ZVdhcm11cHMSIwoNd29ya291dF9vcmRlch'
    'gGIAEoBVIMd29ya291dE9yZGVyEkkKEGV4ZXJjaXNlX2NvbmZpZ3MYByADKAsyHi53b3Jrb3V0'
    'LnYxLkV4ZXJjaXNlVHlwZUNvbmZpZ1IPZXhlcmNpc2VDb25maWdzEjcKC3Jlc3RfY29uZmlnGA'
    'ggASgLMhYud29ya291dC52MS5SZXN0Q29uZmlnUgpyZXN0Q29uZmln');

@$core.Deprecated('Use proposedSetDescriptor instead')
const ProposedSet$json = {
  '1': 'ProposedSet',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'workout_order', '3': 3, '4': 1, '5': 5, '10': 'workoutOrder'},
    {
      '1': 'exercise',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'target_reps', '3': 5, '4': 1, '5': 5, '10': 'targetReps'},
    {'1': 'target_weight', '3': 6, '4': 1, '5': 2, '10': 'targetWeight'},
    {'1': 'warmup', '3': 7, '4': 1, '5': 8, '10': 'warmup'},
    {'1': 'exercise_group_id', '3': 8, '4': 1, '5': 9, '10': 'exerciseGroupId'},
    {
      '1': 'rest_after_success',
      '3': 9,
      '4': 1,
      '5': 5,
      '10': 'restAfterSuccess'
    },
    {
      '1': 'rest_after_failure',
      '3': 10,
      '4': 1,
      '5': 5,
      '10': 'restAfterFailure'
    },
    {'1': 'cancelled', '3': 11, '4': 1, '5': 8, '10': 'cancelled'},
  ],
};

/// Descriptor for `ProposedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List proposedSetDescriptor = $convert.base64Decode(
    'CgtQcm9wb3NlZFNldBIOCgJpZBgBIAEoCVICaWQSHQoKd29ya291dF9pZBgCIAEoCVIJd29ya2'
    '91dElkEiMKDXdvcmtvdXRfb3JkZXIYAyABKAVSDHdvcmtvdXRPcmRlchIwCghleGVyY2lzZRgE'
    'IAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCGV4ZXJjaXNlEh8KC3RhcmdldF9yZXBzGAUgAS'
    'gFUgp0YXJnZXRSZXBzEiMKDXRhcmdldF93ZWlnaHQYBiABKAJSDHRhcmdldFdlaWdodBIWCgZ3'
    'YXJtdXAYByABKAhSBndhcm11cBIqChFleGVyY2lzZV9ncm91cF9pZBgIIAEoCVIPZXhlcmNpc2'
    'VHcm91cElkEiwKEnJlc3RfYWZ0ZXJfc3VjY2VzcxgJIAEoBVIQcmVzdEFmdGVyU3VjY2VzcxIs'
    'ChJyZXN0X2FmdGVyX2ZhaWx1cmUYCiABKAVSEHJlc3RBZnRlckZhaWx1cmUSHAoJY2FuY2VsbG'
    'VkGAsgASgIUgljYW5jZWxsZWQ=');

@$core.Deprecated('Use completedSetDescriptor instead')
const CompletedSet$json = {
  '1': 'CompletedSet',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 3, '4': 1, '5': 9, '10': 'proposedSetId'},
    {'1': 'actual_reps', '3': 4, '4': 1, '5': 5, '10': 'actualReps'},
    {'1': 'actual_weight', '3': 5, '4': 1, '5': 2, '10': 'actualWeight'},
    {'1': 'started_at', '3': 6, '4': 1, '5': 3, '10': 'startedAt'},
    {'1': 'ended_at', '3': 7, '4': 1, '5': 3, '10': 'endedAt'},
    {'1': 'rest_until', '3': 8, '4': 1, '5': 3, '10': 'restUntil'},
  ],
};

/// Descriptor for `CompletedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completedSetDescriptor = $convert.base64Decode(
    'CgxDb21wbGV0ZWRTZXQSDgoCaWQYASABKAlSAmlkEh0KCndvcmtvdXRfaWQYAiABKAlSCXdvcm'
    'tvdXRJZBImCg9wcm9wb3NlZF9zZXRfaWQYAyABKAlSDXByb3Bvc2VkU2V0SWQSHwoLYWN0dWFs'
    'X3JlcHMYBCABKAVSCmFjdHVhbFJlcHMSIwoNYWN0dWFsX3dlaWdodBgFIAEoAlIMYWN0dWFsV2'
    'VpZ2h0Eh0KCnN0YXJ0ZWRfYXQYBiABKANSCXN0YXJ0ZWRBdBIZCghlbmRlZF9hdBgHIAEoA1IH'
    'ZW5kZWRBdBIdCgpyZXN0X3VudGlsGAggASgDUglyZXN0VW50aWw=');

@$core.Deprecated('Use startWorkoutRequestDescriptor instead')
const StartWorkoutRequest$json = {
  '1': 'StartWorkoutRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'exercise_groups',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'exerciseGroups'
    },
  ],
};

/// Descriptor for `StartWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutRequestDescriptor = $convert.base64Decode(
    'ChNTdGFydFdvcmtvdXRSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSQgoPZXhlcmNpc2VfZ3'
    'JvdXBzGAIgAygLMhkud29ya291dC52MS5FeGVyY2lzZUdyb3VwUg5leGVyY2lzZUdyb3Vwcw==');

@$core.Deprecated('Use startWorkoutResponseDescriptor instead')
const StartWorkoutResponse$json = {
  '1': 'StartWorkoutResponse',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `StartWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutResponseDescriptor = $convert
    .base64Decode('ChRTdGFydFdvcmtvdXRSZXNwb25zZRIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use getWorkoutRequestDescriptor instead')
const GetWorkoutRequest$json = {
  '1': 'GetWorkoutRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `GetWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutRequestDescriptor = $convert.base64Decode(
    'ChFHZXRXb3Jrb3V0UmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQ=');

@$core.Deprecated('Use getWorkoutResponseDescriptor instead')
const GetWorkoutResponse$json = {
  '1': 'GetWorkoutResponse',
  '2': [
    {
      '1': 'workout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workout'
    },
    {
      '1': 'exercise_groups',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'exerciseGroups'
    },
    {
      '1': 'proposed_sets',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
    {
      '1': 'completed_sets',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSets'
    },
    {
      '1': 'next_up_set',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'plan_change_stats',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutPlanChangeStats',
      '10': 'planChangeStats'
    },
    {
      '1': 'state_snapshot',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `GetWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutResponseDescriptor = $convert.base64Decode(
    'ChJHZXRXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dBJCCg9leGVyY2lzZV9ncm91cHMYAiADKAsyGS53b3Jrb3V0LnYxLkV4ZXJj'
    'aXNlR3JvdXBSDmV4ZXJjaXNlR3JvdXBzEjwKDXByb3Bvc2VkX3NldHMYAyADKAsyFy53b3Jrb3'
    'V0LnYxLlByb3Bvc2VkU2V0Ugxwcm9wb3NlZFNldHMSPwoOY29tcGxldGVkX3NldHMYBCADKAsy'
    'GC53b3Jrb3V0LnYxLkNvbXBsZXRlZFNldFINY29tcGxldGVkU2V0cxI3CgtuZXh0X3VwX3NldB'
    'gFIAEoCzIXLndvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJOChFwbGFuX2NoYW5n'
    'ZV9zdGF0cxgGIAEoCzIiLndvcmtvdXQudjEuV29ya291dFBsYW5DaGFuZ2VTdGF0c1IPcGxhbk'
    'NoYW5nZVN0YXRzEkcKDnN0YXRlX3NuYXBzaG90GAcgASgLMiAud29ya291dC52MS5Xb3Jrb3V0'
    'U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdA==');

@$core.Deprecated('Use workoutPlanChangeStatsDescriptor instead')
const WorkoutPlanChangeStats$json = {
  '1': 'WorkoutPlanChangeStats',
  '2': [
    {'1': 'cancelled_total', '3': 1, '4': 1, '5': 5, '10': 'cancelledTotal'},
    {
      '1': 'cancelled_warmups',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'cancelledWarmups'
    },
    {
      '1': 'cancelled_working',
      '3': 3,
      '4': 1,
      '5': 5,
      '10': 'cancelledWorking'
    },
  ],
};

/// Descriptor for `WorkoutPlanChangeStats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutPlanChangeStatsDescriptor = $convert.base64Decode(
    'ChZXb3Jrb3V0UGxhbkNoYW5nZVN0YXRzEicKD2NhbmNlbGxlZF90b3RhbBgBIAEoBVIOY2FuY2'
    'VsbGVkVG90YWwSKwoRY2FuY2VsbGVkX3dhcm11cHMYAiABKAVSEGNhbmNlbGxlZFdhcm11cHMS'
    'KwoRY2FuY2VsbGVkX3dvcmtpbmcYAyABKAVSEGNhbmNlbGxlZFdvcmtpbmc=');

@$core.Deprecated('Use workoutStateSnapshotDescriptor instead')
const WorkoutStateSnapshot$json = {
  '1': 'WorkoutStateSnapshot',
  '2': [
    {
      '1': 'state',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.WorkoutState',
      '10': 'state'
    },
    {
      '1': 'display_set',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'displaySet'
    },
    {'1': 'active_started_at', '3': 3, '4': 1, '5': 3, '10': 'activeStartedAt'},
    {'1': 'rest_until', '3': 4, '4': 1, '5': 3, '10': 'restUntil'},
    {'1': 'last_rest_end', '3': 5, '4': 1, '5': 3, '10': 'lastRestEnd'},
  ],
};

/// Descriptor for `WorkoutStateSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutStateSnapshotDescriptor = $convert.base64Decode(
    'ChRXb3Jrb3V0U3RhdGVTbmFwc2hvdBIuCgVzdGF0ZRgBIAEoDjIYLndvcmtvdXQudjEuV29ya2'
    '91dFN0YXRlUgVzdGF0ZRI4CgtkaXNwbGF5X3NldBgCIAEoCzIXLndvcmtvdXQudjEuUHJvcG9z'
    'ZWRTZXRSCmRpc3BsYXlTZXQSKgoRYWN0aXZlX3N0YXJ0ZWRfYXQYAyABKANSD2FjdGl2ZVN0YX'
    'J0ZWRBdBIdCgpyZXN0X3VudGlsGAQgASgDUglyZXN0VW50aWwSIgoNbGFzdF9yZXN0X2VuZBgF'
    'IAEoA1ILbGFzdFJlc3RFbmQ=');

@$core.Deprecated('Use listWorkoutsRequestDescriptor instead')
const ListWorkoutsRequest$json = {
  '1': 'ListWorkoutsRequest',
};

/// Descriptor for `ListWorkoutsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listWorkoutsRequestDescriptor =
    $convert.base64Decode('ChNMaXN0V29ya291dHNSZXF1ZXN0');

@$core.Deprecated('Use listWorkoutsResponseDescriptor instead')
const ListWorkoutsResponse$json = {
  '1': 'ListWorkoutsResponse',
  '2': [
    {
      '1': 'workouts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workouts'
    },
  ],
};

/// Descriptor for `ListWorkoutsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listWorkoutsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0V29ya291dHNSZXNwb25zZRIvCgh3b3Jrb3V0cxgBIAMoCzITLndvcmtvdXQudjEuV2'
    '9ya291dFIId29ya291dHM=');

@$core.Deprecated('Use createExerciseGroupRequestDescriptor instead')
const CreateExerciseGroupRequest$json = {
  '1': 'CreateExerciseGroupRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sets', '3': 3, '4': 1, '5': 5, '10': 'sets'},
    {
      '1': 'interleave_warmups',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'exercise_configs',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTypeConfig',
      '10': 'exerciseConfigs'
    },
    {
      '1': 'rest_config',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
  ],
};

/// Descriptor for `CreateExerciseGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createExerciseGroupRequestDescriptor = $convert.base64Decode(
    'ChpDcmVhdGVFeGVyY2lzZUdyb3VwUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3'
    'V0SWQSEgoEbmFtZRgCIAEoCVIEbmFtZRISCgRzZXRzGAMgASgFUgRzZXRzEi0KEmludGVybGVh'
    'dmVfd2FybXVwcxgEIAEoCFIRaW50ZXJsZWF2ZVdhcm11cHMSSQoQZXhlcmNpc2VfY29uZmlncx'
    'gFIAMoCzIeLndvcmtvdXQudjEuRXhlcmNpc2VUeXBlQ29uZmlnUg9leGVyY2lzZUNvbmZpZ3MS'
    'NwoLcmVzdF9jb25maWcYBiABKAsyFi53b3Jrb3V0LnYxLlJlc3RDb25maWdSCnJlc3RDb25maW'
    'c=');

@$core.Deprecated('Use createExerciseGroupResponseDescriptor instead')
const CreateExerciseGroupResponse$json = {
  '1': 'CreateExerciseGroupResponse',
  '2': [
    {
      '1': 'group',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'group'
    },
    {
      '1': 'generated_sets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'generatedSets'
    },
    {
      '1': 'next_up_set',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `CreateExerciseGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createExerciseGroupResponseDescriptor = $convert.base64Decode(
    'ChtDcmVhdGVFeGVyY2lzZUdyb3VwUmVzcG9uc2USLwoFZ3JvdXAYASABKAsyGS53b3Jrb3V0Ln'
    'YxLkV4ZXJjaXNlR3JvdXBSBWdyb3VwEj4KDmdlbmVyYXRlZF9zZXRzGAIgAygLMhcud29ya291'
    'dC52MS5Qcm9wb3NlZFNldFINZ2VuZXJhdGVkU2V0cxI3CgtuZXh0X3VwX3NldBgDIAEoCzIXLn'
    'dvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgEIAEo'
    'CzIgLndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3Q=');

@$core.Deprecated('Use startSetRequestDescriptor instead')
const StartSetRequest$json = {
  '1': 'StartSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
  ],
};

/// Descriptor for `StartSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSetRequestDescriptor = $convert.base64Decode(
    'Cg9TdGFydFNldFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEiYKD3Byb3'
    'Bvc2VkX3NldF9pZBgCIAEoCVINcHJvcG9zZWRTZXRJZA==');

@$core.Deprecated('Use startSetResponseDescriptor instead')
const StartSetResponse$json = {
  '1': 'StartSetResponse',
  '2': [
    {
      '1': 'completed_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSet'
    },
    {
      '1': 'next_up_set',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `StartSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSetResponseDescriptor = $convert.base64Decode(
    'ChBTdGFydFNldFJlc3BvbnNlEj0KDWNvbXBsZXRlZF9zZXQYASABKAsyGC53b3Jrb3V0LnYxLk'
    'NvbXBsZXRlZFNldFIMY29tcGxldGVkU2V0EjcKC25leHRfdXBfc2V0GAIgASgLMhcud29ya291'
    'dC52MS5Qcm9wb3NlZFNldFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90GAMgASgLMiAud2'
    '9ya291dC52MS5Xb3Jrb3V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdA==');

@$core.Deprecated('Use completeSetRequestDescriptor instead')
const CompleteSetRequest$json = {
  '1': 'CompleteSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
    {'1': 'actual_reps', '3': 3, '4': 1, '5': 5, '10': 'actualReps'},
    {'1': 'actual_weight', '3': 4, '4': 1, '5': 2, '10': 'actualWeight'},
    {'1': 'completed_at', '3': 5, '4': 1, '5': 3, '10': 'completedAt'},
  ],
};

/// Descriptor for `CompleteSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetRequestDescriptor = $convert.base64Decode(
    'ChJDb21wbGV0ZVNldFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEiYKD3'
    'Byb3Bvc2VkX3NldF9pZBgCIAEoCVINcHJvcG9zZWRTZXRJZBIfCgthY3R1YWxfcmVwcxgDIAEo'
    'BVIKYWN0dWFsUmVwcxIjCg1hY3R1YWxfd2VpZ2h0GAQgASgCUgxhY3R1YWxXZWlnaHQSIQoMY2'
    '9tcGxldGVkX2F0GAUgASgDUgtjb21wbGV0ZWRBdA==');

@$core.Deprecated('Use completeSetResponseDescriptor instead')
const CompleteSetResponse$json = {
  '1': 'CompleteSetResponse',
  '2': [
    {
      '1': 'completed_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSet'
    },
    {
      '1': 'next_up_set',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `CompleteSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetResponseDescriptor = $convert.base64Decode(
    'ChNDb21wbGV0ZVNldFJlc3BvbnNlEj0KDWNvbXBsZXRlZF9zZXQYASABKAsyGC53b3Jrb3V0Ln'
    'YxLkNvbXBsZXRlZFNldFIMY29tcGxldGVkU2V0EjcKC25leHRfdXBfc2V0GAIgASgLMhcud29y'
    'a291dC52MS5Qcm9wb3NlZFNldFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90GAMgASgLMi'
    'Aud29ya291dC52MS5Xb3Jrb3V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdA==');

@$core.Deprecated('Use deleteCompletedSetRequestDescriptor instead')
const DeleteCompletedSetRequest$json = {
  '1': 'DeleteCompletedSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'completed_set_id', '3': 2, '4': 1, '5': 9, '10': 'completedSetId'},
  ],
};

/// Descriptor for `DeleteCompletedSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCompletedSetRequestDescriptor =
    $convert.base64Decode(
        'ChlEZWxldGVDb21wbGV0ZWRTZXRSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdX'
        'RJZBIoChBjb21wbGV0ZWRfc2V0X2lkGAIgASgJUg5jb21wbGV0ZWRTZXRJZA==');

@$core.Deprecated('Use deleteCompletedSetResponseDescriptor instead')
const DeleteCompletedSetResponse$json = {
  '1': 'DeleteCompletedSetResponse',
  '2': [
    {
      '1': 'next_up_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `DeleteCompletedSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCompletedSetResponseDescriptor =
    $convert.base64Decode(
        'ChpEZWxldGVDb21wbGV0ZWRTZXRSZXNwb25zZRI3CgtuZXh0X3VwX3NldBgBIAEoCzIXLndvcm'
        'tvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgCIAEoCzIg'
        'LndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3Q=');

@$core.Deprecated('Use cancelProposedSetRequestDescriptor instead')
const CancelProposedSetRequest$json = {
  '1': 'CancelProposedSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
  ],
};

/// Descriptor for `CancelProposedSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelProposedSetRequestDescriptor =
    $convert.base64Decode(
        'ChhDYW5jZWxQcm9wb3NlZFNldFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dE'
        'lkEiYKD3Byb3Bvc2VkX3NldF9pZBgCIAEoCVINcHJvcG9zZWRTZXRJZA==');

@$core.Deprecated('Use cancelProposedSetResponseDescriptor instead')
const CancelProposedSetResponse$json = {
  '1': 'CancelProposedSetResponse',
  '2': [
    {
      '1': 'next_up_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `CancelProposedSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelProposedSetResponseDescriptor = $convert.base64Decode(
    'ChlDYW5jZWxQcm9wb3NlZFNldFJlc3BvbnNlEjcKC25leHRfdXBfc2V0GAEgASgLMhcud29ya2'
    '91dC52MS5Qcm9wb3NlZFNldFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90GAIgASgLMiAu'
    'd29ya291dC52MS5Xb3Jrb3V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdA==');

@$core.Deprecated('Use endWorkoutRequestDescriptor instead')
const EndWorkoutRequest$json = {
  '1': 'EndWorkoutRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `EndWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List endWorkoutRequestDescriptor = $convert.base64Decode(
    'ChFFbmRXb3Jrb3V0UmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3V0SWQ=');

@$core.Deprecated('Use endWorkoutResponseDescriptor instead')
const EndWorkoutResponse$json = {
  '1': 'EndWorkoutResponse',
  '2': [
    {
      '1': 'workout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workout'
    },
  ],
};

/// Descriptor for `EndWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List endWorkoutResponseDescriptor = $convert.base64Decode(
    'ChJFbmRXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dA==');

@$core.Deprecated('Use getProposedWorkoutScheduleRequestDescriptor instead')
const GetProposedWorkoutScheduleRequest$json = {
  '1': 'GetProposedWorkoutScheduleRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `GetProposedWorkoutScheduleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProposedWorkoutScheduleRequestDescriptor =
    $convert.base64Decode(
        'CiFHZXRQcm9wb3NlZFdvcmtvdXRTY2hlZHVsZVJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdX'
        'Nlcklk');

@$core.Deprecated('Use exerciseStatusDescriptor instead')
const ExerciseStatus$json = {
  '1': 'ExerciseStatus',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'target_weight', '3': 2, '4': 1, '5': 2, '10': 'targetWeight'},
    {'1': 'explanation', '3': 3, '4': 1, '5': 9, '10': 'explanation'},
    {'1': 'last_performed_at', '3': 4, '4': 1, '5': 3, '10': 'lastPerformedAt'},
    {'1': 'weight_history', '3': 5, '4': 3, '5': 2, '10': 'weightHistory'},
    {
      '1': 'muscle_groups',
      '3': 6,
      '4': 3,
      '5': 14,
      '6': '.workout.v1.MuscleGroup',
      '10': 'muscleGroups'
    },
    {'1': 'default_sets', '3': 7, '4': 1, '5': 5, '10': 'defaultSets'},
    {'1': 'default_reps', '3': 8, '4': 1, '5': 5, '10': 'defaultReps'},
    {'1': 'recovered', '3': 9, '4': 1, '5': 8, '10': 'recovered'},
    {'1': 'always_include', '3': 10, '4': 1, '5': 8, '10': 'alwaysInclude'},
    {
      '1': 'category',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.ExerciseCategory',
      '10': 'category'
    },
  ],
};

/// Descriptor for `ExerciseStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseStatusDescriptor = $convert.base64Decode(
    'Cg5FeGVyY2lzZVN0YXR1cxIwCghleGVyY2lzZRgBIAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2'
    'VSCGV4ZXJjaXNlEiMKDXRhcmdldF93ZWlnaHQYAiABKAJSDHRhcmdldFdlaWdodBIgCgtleHBs'
    'YW5hdGlvbhgDIAEoCVILZXhwbGFuYXRpb24SKgoRbGFzdF9wZXJmb3JtZWRfYXQYBCABKANSD2'
    'xhc3RQZXJmb3JtZWRBdBIlCg53ZWlnaHRfaGlzdG9yeRgFIAMoAlINd2VpZ2h0SGlzdG9yeRI8'
    'Cg1tdXNjbGVfZ3JvdXBzGAYgAygOMhcud29ya291dC52MS5NdXNjbGVHcm91cFIMbXVzY2xlR3'
    'JvdXBzEiEKDGRlZmF1bHRfc2V0cxgHIAEoBVILZGVmYXVsdFNldHMSIQoMZGVmYXVsdF9yZXBz'
    'GAggASgFUgtkZWZhdWx0UmVwcxIcCglyZWNvdmVyZWQYCSABKAhSCXJlY292ZXJlZBIlCg5hbH'
    'dheXNfaW5jbHVkZRgKIAEoCFINYWx3YXlzSW5jbHVkZRI4CghjYXRlZ29yeRgLIAEoDjIcLndv'
    'cmtvdXQudjEuRXhlcmNpc2VDYXRlZ29yeVIIY2F0ZWdvcnk=');

@$core.Deprecated('Use proposedExerciseGroupDescriptor instead')
const ProposedExerciseGroup$json = {
  '1': 'ProposedExerciseGroup',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sets', '3': 2, '4': 1, '5': 5, '10': 'sets'},
    {
      '1': 'interleave_warmups',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'exercise_configs',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTypeConfig',
      '10': 'exerciseConfigs'
    },
    {
      '1': 'rest_config',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
  ],
};

/// Descriptor for `ProposedExerciseGroup`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List proposedExerciseGroupDescriptor = $convert.base64Decode(
    'ChVQcm9wb3NlZEV4ZXJjaXNlR3JvdXASEgoEbmFtZRgBIAEoCVIEbmFtZRISCgRzZXRzGAIgAS'
    'gFUgRzZXRzEi0KEmludGVybGVhdmVfd2FybXVwcxgDIAEoCFIRaW50ZXJsZWF2ZVdhcm11cHMS'
    'SQoQZXhlcmNpc2VfY29uZmlncxgEIAMoCzIeLndvcmtvdXQudjEuRXhlcmNpc2VUeXBlQ29uZm'
    'lnUg9leGVyY2lzZUNvbmZpZ3MSNwoLcmVzdF9jb25maWcYBSABKAsyFi53b3Jrb3V0LnYxLlJl'
    'c3RDb25maWdSCnJlc3RDb25maWc=');

@$core.Deprecated('Use getProposedWorkoutScheduleResponseDescriptor instead')
const GetProposedWorkoutScheduleResponse$json = {
  '1': 'GetProposedWorkoutScheduleResponse',
  '2': [
    {
      '1': 'exercise_statuses',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseStatus',
      '10': 'exerciseStatuses'
    },
    {'1': 'active_workout_id', '3': 2, '4': 1, '5': 9, '10': 'activeWorkoutId'},
    {
      '1': 'proposed_groups',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedExerciseGroup',
      '10': 'proposedGroups'
    },
  ],
};

/// Descriptor for `GetProposedWorkoutScheduleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProposedWorkoutScheduleResponseDescriptor =
    $convert.base64Decode(
        'CiJHZXRQcm9wb3NlZFdvcmtvdXRTY2hlZHVsZVJlc3BvbnNlEkcKEWV4ZXJjaXNlX3N0YXR1c2'
        'VzGAEgAygLMhoud29ya291dC52MS5FeGVyY2lzZVN0YXR1c1IQZXhlcmNpc2VTdGF0dXNlcxIq'
        'ChFhY3RpdmVfd29ya291dF9pZBgCIAEoCVIPYWN0aXZlV29ya291dElkEkoKD3Byb3Bvc2VkX2'
        'dyb3VwcxgDIAMoCzIhLndvcmtvdXQudjEuUHJvcG9zZWRFeGVyY2lzZUdyb3VwUg5wcm9wb3Nl'
        'ZEdyb3Vwcw==');

@$core.Deprecated('Use getActiveWorkoutRequestDescriptor instead')
const GetActiveWorkoutRequest$json = {
  '1': 'GetActiveWorkoutRequest',
};

/// Descriptor for `GetActiveWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getActiveWorkoutRequestDescriptor =
    $convert.base64Decode('ChdHZXRBY3RpdmVXb3Jrb3V0UmVxdWVzdA==');

@$core.Deprecated('Use getActiveWorkoutResponseDescriptor instead')
const GetActiveWorkoutResponse$json = {
  '1': 'GetActiveWorkoutResponse',
  '2': [
    {
      '1': 'workout',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'workout'
    },
  ],
};

/// Descriptor for `GetActiveWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getActiveWorkoutResponseDescriptor =
    $convert.base64Decode(
        'ChhHZXRBY3RpdmVXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudj'
        'EuV29ya291dFIHd29ya291dA==');

@$core.Deprecated('Use updateExerciseGroupRequestDescriptor instead')
const UpdateExerciseGroupRequest$json = {
  '1': 'UpdateExerciseGroupRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercise_group_id', '3': 2, '4': 1, '5': 9, '10': 'exerciseGroupId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sets', '3': 4, '4': 1, '5': 5, '10': 'sets'},
    {
      '1': 'interleave_warmups',
      '3': 5,
      '4': 1,
      '5': 8,
      '10': 'interleaveWarmups'
    },
    {
      '1': 'exercise_configs',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseTypeConfig',
      '10': 'exerciseConfigs'
    },
    {
      '1': 'rest_config',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RestConfig',
      '10': 'restConfig'
    },
  ],
};

/// Descriptor for `UpdateExerciseGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateExerciseGroupRequestDescriptor = $convert.base64Decode(
    'ChpVcGRhdGVFeGVyY2lzZUdyb3VwUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3'
    'V0SWQSKgoRZXhlcmNpc2VfZ3JvdXBfaWQYAiABKAlSD2V4ZXJjaXNlR3JvdXBJZBISCgRuYW1l'
    'GAMgASgJUgRuYW1lEhIKBHNldHMYBCABKAVSBHNldHMSLQoSaW50ZXJsZWF2ZV93YXJtdXBzGA'
    'UgASgIUhFpbnRlcmxlYXZlV2FybXVwcxJJChBleGVyY2lzZV9jb25maWdzGAYgAygLMh4ud29y'
    'a291dC52MS5FeGVyY2lzZVR5cGVDb25maWdSD2V4ZXJjaXNlQ29uZmlncxI3CgtyZXN0X2Nvbm'
    'ZpZxgHIAEoCzIWLndvcmtvdXQudjEuUmVzdENvbmZpZ1IKcmVzdENvbmZpZw==');

@$core.Deprecated('Use updateExerciseGroupResponseDescriptor instead')
const UpdateExerciseGroupResponse$json = {
  '1': 'UpdateExerciseGroupResponse',
  '2': [
    {
      '1': 'group',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'group'
    },
    {
      '1': 'generated_sets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'generatedSets'
    },
    {
      '1': 'next_up_set',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `UpdateExerciseGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateExerciseGroupResponseDescriptor = $convert.base64Decode(
    'ChtVcGRhdGVFeGVyY2lzZUdyb3VwUmVzcG9uc2USLwoFZ3JvdXAYASABKAsyGS53b3Jrb3V0Ln'
    'YxLkV4ZXJjaXNlR3JvdXBSBWdyb3VwEj4KDmdlbmVyYXRlZF9zZXRzGAIgAygLMhcud29ya291'
    'dC52MS5Qcm9wb3NlZFNldFINZ2VuZXJhdGVkU2V0cxI3CgtuZXh0X3VwX3NldBgDIAEoCzIXLn'
    'dvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgEIAEo'
    'CzIgLndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3Q=');

@$core.Deprecated('Use deleteExerciseGroupRequestDescriptor instead')
const DeleteExerciseGroupRequest$json = {
  '1': 'DeleteExerciseGroupRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'exercise_group_id', '3': 2, '4': 1, '5': 9, '10': 'exerciseGroupId'},
  ],
};

/// Descriptor for `DeleteExerciseGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteExerciseGroupRequestDescriptor =
    $convert.base64Decode(
        'ChpEZWxldGVFeGVyY2lzZUdyb3VwUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3'
        'V0SWQSKgoRZXhlcmNpc2VfZ3JvdXBfaWQYAiABKAlSD2V4ZXJjaXNlR3JvdXBJZA==');

@$core.Deprecated('Use deleteExerciseGroupResponseDescriptor instead')
const DeleteExerciseGroupResponse$json = {
  '1': 'DeleteExerciseGroupResponse',
  '2': [
    {
      '1': 'next_up_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `DeleteExerciseGroupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteExerciseGroupResponseDescriptor =
    $convert.base64Decode(
        'ChtEZWxldGVFeGVyY2lzZUdyb3VwUmVzcG9uc2USNwoLbmV4dF91cF9zZXQYASABKAsyFy53b3'
        'Jrb3V0LnYxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSRwoOc3RhdGVfc25hcHNob3QYAiABKAsy'
        'IC53b3Jrb3V0LnYxLldvcmtvdXRTdGF0ZVNuYXBzaG90Ug1zdGF0ZVNuYXBzaG90');

@$core.Deprecated('Use reorderExerciseGroupsRequestDescriptor instead')
const ReorderExerciseGroupsRequest$json = {
  '1': 'ReorderExerciseGroupsRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'exercise_group_ids',
      '3': 2,
      '4': 3,
      '5': 9,
      '10': 'exerciseGroupIds'
    },
  ],
};

/// Descriptor for `ReorderExerciseGroupsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderExerciseGroupsRequestDescriptor =
    $convert.base64Decode(
        'ChxSZW9yZGVyRXhlcmNpc2VHcm91cHNSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcm'
        'tvdXRJZBIsChJleGVyY2lzZV9ncm91cF9pZHMYAiADKAlSEGV4ZXJjaXNlR3JvdXBJZHM=');

@$core.Deprecated('Use reorderExerciseGroupsResponseDescriptor instead')
const ReorderExerciseGroupsResponse$json = {
  '1': 'ReorderExerciseGroupsResponse',
  '2': [
    {
      '1': 'next_up_set',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'state_snapshot',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
  ],
};

/// Descriptor for `ReorderExerciseGroupsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderExerciseGroupsResponseDescriptor =
    $convert.base64Decode(
        'Ch1SZW9yZGVyRXhlcmNpc2VHcm91cHNSZXNwb25zZRI3CgtuZXh0X3VwX3NldBgBIAEoCzIXLn'
        'dvcmtvdXQudjEuUHJvcG9zZWRTZXRSCW5leHRVcFNldBJHCg5zdGF0ZV9zbmFwc2hvdBgCIAEo'
        'CzIgLndvcmtvdXQudjEuV29ya291dFN0YXRlU25hcHNob3RSDXN0YXRlU25hcHNob3Q=');

@$core.Deprecated('Use workoutHeartRatePointDescriptor instead')
const WorkoutHeartRatePoint$json = {
  '1': 'WorkoutHeartRatePoint',
  '2': [
    {'1': 'sampled_at', '3': 1, '4': 1, '5': 3, '10': 'sampledAt'},
    {'1': 'bpm', '3': 2, '4': 1, '5': 2, '10': 'bpm'},
    {'1': 'availability', '3': 3, '4': 1, '5': 5, '10': 'availability'},
  ],
};

/// Descriptor for `WorkoutHeartRatePoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List workoutHeartRatePointDescriptor = $convert.base64Decode(
    'ChVXb3Jrb3V0SGVhcnRSYXRlUG9pbnQSHQoKc2FtcGxlZF9hdBgBIAEoA1IJc2FtcGxlZEF0Eh'
    'AKA2JwbRgCIAEoAlIDYnBtEiIKDGF2YWlsYWJpbGl0eRgDIAEoBVIMYXZhaWxhYmlsaXR5');

@$core.Deprecated('Use appendWorkoutHeartRateRequestDescriptor instead')
const AppendWorkoutHeartRateRequest$json = {
  '1': 'AppendWorkoutHeartRateRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'samples',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutHeartRatePoint',
      '10': 'samples'
    },
  ],
};

/// Descriptor for `AppendWorkoutHeartRateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appendWorkoutHeartRateRequestDescriptor =
    $convert.base64Decode(
        'Ch1BcHBlbmRXb3Jrb3V0SGVhcnRSYXRlUmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3'
        'Jrb3V0SWQSOwoHc2FtcGxlcxgCIAMoCzIhLndvcmtvdXQudjEuV29ya291dEhlYXJ0UmF0ZVBv'
        'aW50UgdzYW1wbGVz');

@$core.Deprecated('Use appendWorkoutHeartRateResponseDescriptor instead')
const AppendWorkoutHeartRateResponse$json = {
  '1': 'AppendWorkoutHeartRateResponse',
  '2': [
    {'1': 'stored', '3': 1, '4': 1, '5': 5, '10': 'stored'},
  ],
};

/// Descriptor for `AppendWorkoutHeartRateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appendWorkoutHeartRateResponseDescriptor =
    $convert.base64Decode(
        'Ch5BcHBlbmRXb3Jrb3V0SGVhcnRSYXRlUmVzcG9uc2USFgoGc3RvcmVkGAEgASgFUgZzdG9yZW'
        'Q=');

@$core.Deprecated('Use createUserRequestDescriptor instead')
const CreateUserRequest$json = {
  '1': 'CreateUserRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createUserRequestDescriptor = $convert
    .base64Decode('ChFDcmVhdGVVc2VyUmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1l');

@$core.Deprecated('Use createUserResponseDescriptor instead')
const CreateUserResponse$json = {
  '1': 'CreateUserResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.User',
      '10': 'user'
    },
  ],
};

/// Descriptor for `CreateUserResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createUserResponseDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVVc2VyUmVzcG9uc2USJAoEdXNlchgBIAEoCzIQLndvcmtvdXQudjEuVXNlclIEdX'
    'Nlcg==');

@$core.Deprecated('Use getUserRequestDescriptor instead')
const GetUserRequest$json = {
  '1': 'GetUserRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `GetUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserRequestDescriptor = $convert
    .base64Decode('Cg5HZXRVc2VyUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQ=');

@$core.Deprecated('Use getUserResponseDescriptor instead')
const GetUserResponse$json = {
  '1': 'GetUserResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.User',
      '10': 'user'
    },
  ],
};

/// Descriptor for `GetUserResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRVc2VyUmVzcG9uc2USJAoEdXNlchgBIAEoCzIQLndvcmtvdXQudjEuVXNlclIEdXNlcg'
    '==');
