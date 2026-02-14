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
  ],
};

/// Descriptor for `ProposedSet`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List proposedSetDescriptor = $convert.base64Decode(
    'CgtQcm9wb3NlZFNldBIOCgJpZBgBIAEoCVICaWQSHQoKd29ya291dF9pZBgCIAEoCVIJd29ya2'
    '91dElkEiMKDXdvcmtvdXRfb3JkZXIYAyABKAVSDHdvcmtvdXRPcmRlchIwCghleGVyY2lzZRgE'
    'IAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCGV4ZXJjaXNlEh8KC3RhcmdldF9yZXBzGAUgAS'
    'gFUgp0YXJnZXRSZXBzEiMKDXRhcmdldF93ZWlnaHQYBiABKAJSDHRhcmdldFdlaWdodBIWCgZ3'
    'YXJtdXAYByABKAhSBndhcm11cA==');

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
      '1': 'proposed_sets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
  ],
};

/// Descriptor for `StartWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startWorkoutRequestDescriptor = $convert.base64Decode(
    'ChNTdGFydFdvcmtvdXRSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSPAoNcHJvcG9zZWRfc2'
    'V0cxgCIAMoCzIXLndvcmtvdXQudjEuUHJvcG9zZWRTZXRSDHByb3Bvc2VkU2V0cw==');

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
      '1': 'proposed_sets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
    {
      '1': 'completed_sets',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSets'
    },
  ],
};

/// Descriptor for `GetWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getWorkoutResponseDescriptor = $convert.base64Decode(
    'ChJHZXRXb3Jrb3V0UmVzcG9uc2USLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya2'
    '91dFIHd29ya291dBI8Cg1wcm9wb3NlZF9zZXRzGAIgAygLMhcud29ya291dC52MS5Qcm9wb3Nl'
    'ZFNldFIMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGAMgAygLMhgud29ya291dC52MS'
    '5Db21wbGV0ZWRTZXRSDWNvbXBsZXRlZFNldHM=');

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

@$core.Deprecated('Use modifyProposedSetsRequestDescriptor instead')
const ModifyProposedSetsRequest$json = {
  '1': 'ModifyProposedSetsRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {
      '1': 'proposed_sets',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
  ],
};

/// Descriptor for `ModifyProposedSetsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modifyProposedSetsRequestDescriptor = $convert.base64Decode(
    'ChlNb2RpZnlQcm9wb3NlZFNldHNSZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdX'
    'RJZBI8Cg1wcm9wb3NlZF9zZXRzGAIgAygLMhcud29ya291dC52MS5Qcm9wb3NlZFNldFIMcHJv'
    'cG9zZWRTZXRz');

@$core.Deprecated('Use modifyProposedSetsResponseDescriptor instead')
const ModifyProposedSetsResponse$json = {
  '1': 'ModifyProposedSetsResponse',
  '2': [
    {
      '1': 'proposed_sets',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
  ],
};

/// Descriptor for `ModifyProposedSetsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modifyProposedSetsResponseDescriptor =
    $convert.base64Decode(
        'ChpNb2RpZnlQcm9wb3NlZFNldHNSZXNwb25zZRI8Cg1wcm9wb3NlZF9zZXRzGAEgAygLMhcud2'
        '9ya291dC52MS5Qcm9wb3NlZFNldFIMcHJvcG9zZWRTZXRz');

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
  ],
};

/// Descriptor for `StartSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSetResponseDescriptor = $convert.base64Decode(
    'ChBTdGFydFNldFJlc3BvbnNlEj0KDWNvbXBsZXRlZF9zZXQYASABKAsyGC53b3Jrb3V0LnYxLk'
    'NvbXBsZXRlZFNldFIMY29tcGxldGVkU2V0');

@$core.Deprecated('Use completeSetRequestDescriptor instead')
const CompleteSetRequest$json = {
  '1': 'CompleteSetRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
    {'1': 'proposed_set_id', '3': 2, '4': 1, '5': 9, '10': 'proposedSetId'},
    {'1': 'actual_reps', '3': 3, '4': 1, '5': 5, '10': 'actualReps'},
    {'1': 'actual_weight', '3': 4, '4': 1, '5': 2, '10': 'actualWeight'},
  ],
};

/// Descriptor for `CompleteSetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetRequestDescriptor = $convert.base64Decode(
    'ChJDb21wbGV0ZVNldFJlcXVlc3QSHQoKd29ya291dF9pZBgBIAEoCVIJd29ya291dElkEiYKD3'
    'Byb3Bvc2VkX3NldF9pZBgCIAEoCVINcHJvcG9zZWRTZXRJZBIfCgthY3R1YWxfcmVwcxgDIAEo'
    'BVIKYWN0dWFsUmVwcxIjCg1hY3R1YWxfd2VpZ2h0GAQgASgCUgxhY3R1YWxXZWlnaHQ=');

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
  ],
};

/// Descriptor for `CompleteSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeSetResponseDescriptor = $convert.base64Decode(
    'ChNDb21wbGV0ZVNldFJlc3BvbnNlEj0KDWNvbXBsZXRlZF9zZXQYASABKAsyGC53b3Jrb3V0Ln'
    'YxLkNvbXBsZXRlZFNldFIMY29tcGxldGVkU2V0');

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
};

/// Descriptor for `DeleteCompletedSetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCompletedSetResponseDescriptor =
    $convert.base64Decode('ChpEZWxldGVDb21wbGV0ZWRTZXRSZXNwb25zZQ==');

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
  ],
};

/// Descriptor for `GetProposedWorkoutScheduleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProposedWorkoutScheduleResponseDescriptor =
    $convert.base64Decode(
        'CiJHZXRQcm9wb3NlZFdvcmtvdXRTY2hlZHVsZVJlc3BvbnNlEkcKEWV4ZXJjaXNlX3N0YXR1c2'
        'VzGAEgAygLMhoud29ya291dC52MS5FeGVyY2lzZVN0YXR1c1IQZXhlcmNpc2VTdGF0dXNlcxIq'
        'ChFhY3RpdmVfd29ya291dF9pZBgCIAEoCVIPYWN0aXZlV29ya291dElk');

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
