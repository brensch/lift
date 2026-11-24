// This is a generated file - do not edit.
//
// Generated from workout/v1/snapshot.proto.

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

@$core.Deprecated('Use accountSnapshotDescriptor instead')
const AccountSnapshot$json = {
  '1': 'AccountSnapshot',
  '2': [
    {'1': 'fold', '3': 1, '4': 1, '5': 9, '10': 'fold'},
    {'1': 'seq', '3': 2, '4': 1, '5': 3, '10': 'seq'},
    {'1': 'programs', '3': 3, '4': 3, '5': 9, '10': 'programs'},
    {
      '1': 'settings',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserSetting',
      '10': 'settings'
    },
    {
      '1': 'versions',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SnapshotProgramVersion',
      '10': 'versions'
    },
    {'1': 'program', '3': 6, '4': 1, '5': 13, '10': 'program'},
    {
      '1': 'starting_weights',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SnapshotStartingWeight',
      '10': 'startingWeights'
    },
    {
      '1': 'overrides',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SnapshotOverride',
      '10': 'overrides'
    },
    {
      '1': 'workouts',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SnapshotWorkout',
      '10': 'workouts'
    },
    {
      '1': 'suggestions',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SnapshotSuggestion',
      '10': 'suggestions'
    },
    {
      '1': 'active_workout_id',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'activeWorkoutId'
    },
    {'1': 'onboarded', '3': 12, '4': 1, '5': 8, '10': 'onboarded'},
    {
      '1': 'without_heart_rate',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'withoutHeartRate'
    },
  ],
};

/// Descriptor for `AccountSnapshot`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accountSnapshotDescriptor = $convert.base64Decode(
    'Cg9BY2NvdW50U25hcHNob3QSEgoEZm9sZBgBIAEoCVIEZm9sZBIQCgNzZXEYAiABKANSA3NlcR'
    'IaCghwcm9ncmFtcxgDIAMoCVIIcHJvZ3JhbXMSMwoIc2V0dGluZ3MYBCADKAsyFy53b3Jrb3V0'
    'LnYxLlVzZXJTZXR0aW5nUghzZXR0aW5ncxI+Cgh2ZXJzaW9ucxgFIAMoCzIiLndvcmtvdXQudj'
    'EuU25hcHNob3RQcm9ncmFtVmVyc2lvblIIdmVyc2lvbnMSGAoHcHJvZ3JhbRgGIAEoDVIHcHJv'
    'Z3JhbRJNChBzdGFydGluZ193ZWlnaHRzGAcgAygLMiIud29ya291dC52MS5TbmFwc2hvdFN0YX'
    'J0aW5nV2VpZ2h0Ug9zdGFydGluZ1dlaWdodHMSOgoJb3ZlcnJpZGVzGAggAygLMhwud29ya291'
    'dC52MS5TbmFwc2hvdE92ZXJyaWRlUglvdmVycmlkZXMSNwoId29ya291dHMYCSADKAsyGy53b3'
    'Jrb3V0LnYxLlNuYXBzaG90V29ya291dFIId29ya291dHMSQAoLc3VnZ2VzdGlvbnMYCiADKAsy'
    'Hi53b3Jrb3V0LnYxLlNuYXBzaG90U3VnZ2VzdGlvblILc3VnZ2VzdGlvbnMSKgoRYWN0aXZlX3'
    'dvcmtvdXRfaWQYCyABKAlSD2FjdGl2ZVdvcmtvdXRJZBIcCglvbmJvYXJkZWQYDCABKAhSCW9u'
    'Ym9hcmRlZBIsChJ3aXRob3V0X2hlYXJ0X3JhdGUYDSABKAhSEHdpdGhvdXRIZWFydFJhdGU=');

@$core.Deprecated('Use snapshotProgramVersionDescriptor instead')
const SnapshotProgramVersion$json = {
  '1': 'SnapshotProgramVersion',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'at', '3': 2, '4': 1, '5': 3, '10': 'at'},
    {'1': 'author', '3': 3, '4': 1, '5': 9, '10': 'author'},
    {'1': 'note', '3': 4, '4': 1, '5': 9, '10': 'note'},
    {'1': 'program', '3': 5, '4': 1, '5': 13, '10': 'program'},
  ],
};

/// Descriptor for `SnapshotProgramVersion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotProgramVersionDescriptor = $convert.base64Decode(
    'ChZTbmFwc2hvdFByb2dyYW1WZXJzaW9uEg4KAmlkGAEgASgJUgJpZBIOCgJhdBgCIAEoA1ICYX'
    'QSFgoGYXV0aG9yGAMgASgJUgZhdXRob3ISEgoEbm90ZRgEIAEoCVIEbm90ZRIYCgdwcm9ncmFt'
    'GAUgASgNUgdwcm9ncmFt');

@$core.Deprecated('Use snapshotStartingWeightDescriptor instead')
const SnapshotStartingWeight$json = {
  '1': 'SnapshotStartingWeight',
  '2': [
    {'1': 'lift', '3': 1, '4': 1, '5': 9, '10': 'lift'},
    {'1': 'weight', '3': 2, '4': 1, '5': 2, '10': 'weight'},
  ],
};

/// Descriptor for `SnapshotStartingWeight`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotStartingWeightDescriptor =
    $convert.base64Decode(
        'ChZTbmFwc2hvdFN0YXJ0aW5nV2VpZ2h0EhIKBGxpZnQYASABKAlSBGxpZnQSFgoGd2VpZ2h0GA'
        'IgASgCUgZ3ZWlnaHQ=');

@$core.Deprecated('Use snapshotOverrideDescriptor instead')
const SnapshotOverride$json = {
  '1': 'SnapshotOverride',
  '2': [
    {'1': 'lift', '3': 1, '4': 1, '5': 9, '10': 'lift'},
    {'1': 'at', '3': 2, '4': 1, '5': 3, '10': 'at'},
    {'1': 'weight', '3': 3, '4': 1, '5': 2, '10': 'weight'},
    {'1': 'reps', '3': 4, '4': 1, '5': 5, '10': 'reps'},
    {'1': 'has_sets', '3': 5, '4': 1, '5': 8, '10': 'hasSets'},
    {'1': 'sets', '3': 6, '4': 1, '5': 5, '10': 'sets'},
  ],
};

/// Descriptor for `SnapshotOverride`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotOverrideDescriptor = $convert.base64Decode(
    'ChBTbmFwc2hvdE92ZXJyaWRlEhIKBGxpZnQYASABKAlSBGxpZnQSDgoCYXQYAiABKANSAmF0Eh'
    'YKBndlaWdodBgDIAEoAlIGd2VpZ2h0EhIKBHJlcHMYBCABKAVSBHJlcHMSGQoIaGFzX3NldHMY'
    'BSABKAhSB2hhc1NldHMSEgoEc2V0cxgGIAEoBVIEc2V0cw==');

@$core.Deprecated('Use snapshotWorkoutDescriptor instead')
const SnapshotWorkout$json = {
  '1': 'SnapshotWorkout',
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
    {
      '1': 'exercise_logs',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseLog',
      '10': 'exerciseLogs'
    },
    {'1': 'kg', '3': 5, '4': 1, '5': 8, '10': 'kg'},
    {'1': 'program', '3': 6, '4': 1, '5': 13, '10': 'program'},
    {
      '1': 'heart_rate',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutHeartRatePoint',
      '10': 'heartRate'
    },
  ],
};

/// Descriptor for `SnapshotWorkout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotWorkoutDescriptor = $convert.base64Decode(
    'Cg9TbmFwc2hvdFdvcmtvdXQSLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya291dF'
    'IHd29ya291dBI8Cg1wcm9wb3NlZF9zZXRzGAIgAygLMhcud29ya291dC52MS5Qcm9wb3NlZFNl'
    'dFIMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGAMgAygLMhgud29ya291dC52MS5Db2'
    '1wbGV0ZWRTZXRSDWNvbXBsZXRlZFNldHMSPAoNZXhlcmNpc2VfbG9ncxgEIAMoCzIXLndvcmtv'
    'dXQudjEuRXhlcmNpc2VMb2dSDGV4ZXJjaXNlTG9ncxIOCgJrZxgFIAEoCFICa2cSGAoHcHJvZ3'
    'JhbRgGIAEoDVIHcHJvZ3JhbRJACgpoZWFydF9yYXRlGAcgAygLMiEud29ya291dC52MS5Xb3Jr'
    'b3V0SGVhcnRSYXRlUG9pbnRSCWhlYXJ0UmF0ZQ==');

@$core.Deprecated('Use snapshotSuggestionDescriptor instead')
const SnapshotSuggestion$json = {
  '1': 'SnapshotSuggestion',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'at', '3': 2, '4': 1, '5': 3, '10': 'at'},
    {'1': 'suggested', '3': 3, '4': 1, '5': 9, '10': 'suggested'},
    {'1': 'answered', '3': 4, '4': 1, '5': 8, '10': 'answered'},
    {'1': 'accepted', '3': 5, '4': 1, '5': 8, '10': 'accepted'},
    {'1': 'answered_at', '3': 6, '4': 1, '5': 3, '10': 'answeredAt'},
  ],
};

/// Descriptor for `SnapshotSuggestion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List snapshotSuggestionDescriptor = $convert.base64Decode(
    'ChJTbmFwc2hvdFN1Z2dlc3Rpb24SDgoCaWQYASABKAlSAmlkEg4KAmF0GAIgASgDUgJhdBIcCg'
    'lzdWdnZXN0ZWQYAyABKAlSCXN1Z2dlc3RlZBIaCghhbnN3ZXJlZBgEIAEoCFIIYW5zd2VyZWQS'
    'GgoIYWNjZXB0ZWQYBSABKAhSCGFjY2VwdGVkEh8KC2Fuc3dlcmVkX2F0GAYgASgDUgphbnN3ZX'
    'JlZEF0');
