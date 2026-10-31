// This is a generated file - do not edit.
//
// Generated from workout/v1/account.proto.

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

@$core.Deprecated('Use eventDescriptor instead')
const Event$json = {
  '1': 'Event',
  '2': [
    {'1': 'seq', '3': 1, '4': 1, '5': 3, '10': 'seq'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'at', '3': 3, '4': 1, '5': 3, '10': 'at'},
    {
      '1': 'start_workout',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.StartWorkoutRequest',
      '9': 0,
      '10': 'startWorkout'
    },
    {
      '1': 'workout',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutMutation',
      '9': 0,
      '10': 'workout'
    },
    {
      '1': 'heart_rate',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.AppendWorkoutHeartRateRequest',
      '9': 0,
      '10': 'heartRate'
    },
    {
      '1': 'save_template',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SaveTemplateRequest',
      '9': 0,
      '10': 'saveTemplate'
    },
    {
      '1': 'delete_template',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.DeleteTemplateRequest',
      '9': 0,
      '10': 'deleteTemplate'
    },
    {
      '1': 'reorder_templates',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ReorderTemplatesRequest',
      '9': 0,
      '10': 'reorderTemplates'
    },
    {
      '1': 'add_library_templates',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.AddLibraryTemplatesRequest',
      '9': 0,
      '10': 'addLibraryTemplates'
    },
    {
      '1': 'set_exercise_tracker',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SetExerciseTrackerRequest',
      '9': 0,
      '10': 'setExerciseTracker'
    },
    {
      '1': 'complete_onboarding',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.CompleteOnboardingRequest',
      '9': 0,
      '10': 'completeOnboarding'
    },
    {
      '1': 'update_setting',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.UpdateSettingRequest',
      '9': 0,
      '10': 'updateSetting'
    },
    {
      '1': 'dismiss_user_messages',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.DismissUserMessagesRequest',
      '9': 0,
      '10': 'dismissUserMessages'
    },
    {
      '1': 'import_history',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ImportHistory',
      '9': 0,
      '10': 'importHistory'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `Event`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDescriptor = $convert.base64Decode(
    'CgVFdmVudBIQCgNzZXEYASABKANSA3NlcRIOCgJpZBgCIAEoCVICaWQSDgoCYXQYAyABKANSAm'
    'F0EkYKDXN0YXJ0X3dvcmtvdXQYCiABKAsyHy53b3Jrb3V0LnYxLlN0YXJ0V29ya291dFJlcXVl'
    'c3RIAFIMc3RhcnRXb3Jrb3V0EjcKB3dvcmtvdXQYCyABKAsyGy53b3Jrb3V0LnYxLldvcmtvdX'
    'RNdXRhdGlvbkgAUgd3b3Jrb3V0EkoKCmhlYXJ0X3JhdGUYDCABKAsyKS53b3Jrb3V0LnYxLkFw'
    'cGVuZFdvcmtvdXRIZWFydFJhdGVSZXF1ZXN0SABSCWhlYXJ0UmF0ZRJGCg1zYXZlX3RlbXBsYX'
    'RlGA0gASgLMh8ud29ya291dC52MS5TYXZlVGVtcGxhdGVSZXF1ZXN0SABSDHNhdmVUZW1wbGF0'
    'ZRJMCg9kZWxldGVfdGVtcGxhdGUYDiABKAsyIS53b3Jrb3V0LnYxLkRlbGV0ZVRlbXBsYXRlUm'
    'VxdWVzdEgAUg5kZWxldGVUZW1wbGF0ZRJSChFyZW9yZGVyX3RlbXBsYXRlcxgPIAEoCzIjLndv'
    'cmtvdXQudjEuUmVvcmRlclRlbXBsYXRlc1JlcXVlc3RIAFIQcmVvcmRlclRlbXBsYXRlcxJcCh'
    'VhZGRfbGlicmFyeV90ZW1wbGF0ZXMYECABKAsyJi53b3Jrb3V0LnYxLkFkZExpYnJhcnlUZW1w'
    'bGF0ZXNSZXF1ZXN0SABSE2FkZExpYnJhcnlUZW1wbGF0ZXMSWQoUc2V0X2V4ZXJjaXNlX3RyYW'
    'NrZXIYESABKAsyJS53b3Jrb3V0LnYxLlNldEV4ZXJjaXNlVHJhY2tlclJlcXVlc3RIAFISc2V0'
    'RXhlcmNpc2VUcmFja2VyElgKE2NvbXBsZXRlX29uYm9hcmRpbmcYEiABKAsyJS53b3Jrb3V0Ln'
    'YxLkNvbXBsZXRlT25ib2FyZGluZ1JlcXVlc3RIAFISY29tcGxldGVPbmJvYXJkaW5nEkkKDnVw'
    'ZGF0ZV9zZXR0aW5nGBMgASgLMiAud29ya291dC52MS5VcGRhdGVTZXR0aW5nUmVxdWVzdEgAUg'
    '11cGRhdGVTZXR0aW5nElwKFWRpc21pc3NfdXNlcl9tZXNzYWdlcxgUIAEoCzImLndvcmtvdXQu'
    'djEuRGlzbWlzc1VzZXJNZXNzYWdlc1JlcXVlc3RIAFITZGlzbWlzc1VzZXJNZXNzYWdlcxJCCg'
    '5pbXBvcnRfaGlzdG9yeRgVIAEoCzIZLndvcmtvdXQudjEuSW1wb3J0SGlzdG9yeUgAUg1pbXBv'
    'cnRIaXN0b3J5QgYKBGtpbmQ=');

@$core.Deprecated('Use importHistoryDescriptor instead')
const ImportHistory$json = {
  '1': 'ImportHistory',
  '2': [
    {
      '1': 'workouts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ImportedWorkout',
      '10': 'workouts'
    },
    {
      '1': 'trackers',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrackerRecord',
      '10': 'trackers'
    },
  ],
};

/// Descriptor for `ImportHistory`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importHistoryDescriptor = $convert.base64Decode(
    'Cg1JbXBvcnRIaXN0b3J5EjcKCHdvcmtvdXRzGAEgAygLMhsud29ya291dC52MS5JbXBvcnRlZF'
    'dvcmtvdXRSCHdvcmtvdXRzEjUKCHRyYWNrZXJzGAIgAygLMhkud29ya291dC52MS5UcmFja2Vy'
    'UmVjb3JkUgh0cmFja2Vycw==');

@$core.Deprecated('Use importHistoryResponseDescriptor instead')
const ImportHistoryResponse$json = {
  '1': 'ImportHistoryResponse',
};

/// Descriptor for `ImportHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importHistoryResponseDescriptor =
    $convert.base64Decode('ChVJbXBvcnRIaXN0b3J5UmVzcG9uc2U=');

@$core.Deprecated('Use importedWorkoutDescriptor instead')
const ImportedWorkout$json = {
  '1': 'ImportedWorkout',
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
      '1': 'heart_rate',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.WorkoutHeartRatePoint',
      '10': 'heartRate'
    },
  ],
};

/// Descriptor for `ImportedWorkout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importedWorkoutDescriptor = $convert.base64Decode(
    'Cg9JbXBvcnRlZFdvcmtvdXQSLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya291dF'
    'IHd29ya291dBI8Cg1wcm9wb3NlZF9zZXRzGAIgAygLMhcud29ya291dC52MS5Qcm9wb3NlZFNl'
    'dFIMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGAMgAygLMhgud29ya291dC52MS5Db2'
    '1wbGV0ZWRTZXRSDWNvbXBsZXRlZFNldHMSQAoKaGVhcnRfcmF0ZRgEIAMoCzIhLndvcmtvdXQu'
    'djEuV29ya291dEhlYXJ0UmF0ZVBvaW50UgloZWFydFJhdGU=');

@$core.Deprecated('Use trackerRecordDescriptor instead')
const TrackerRecord$json = {
  '1': 'TrackerRecord',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'working_weight', '3': 2, '4': 1, '5': 2, '10': 'workingWeight'},
    {'1': 'current_reps', '3': 3, '4': 1, '5': 5, '10': 'currentReps'},
    {
      '1': 'consecutive_misses',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'consecutiveMisses'
    },
    {'1': 'last_performed_at', '3': 5, '4': 1, '5': 3, '10': 'lastPerformedAt'},
    {'1': 'override_sets', '3': 6, '4': 1, '5': 5, '10': 'overrideSets'},
    {'1': 'override_rep_low', '3': 7, '4': 1, '5': 5, '10': 'overrideRepLow'},
    {'1': 'override_rep_high', '3': 8, '4': 1, '5': 5, '10': 'overrideRepHigh'},
  ],
  '9': [
    {'1': 9, '2': 10},
  ],
  '10': ['consecutive_hard'],
};

/// Descriptor for `TrackerRecord`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trackerRecordDescriptor = $convert.base64Decode(
    'Cg1UcmFja2VyUmVjb3JkEjAKCGV4ZXJjaXNlGAEgASgOMhQud29ya291dC52MS5FeGVyY2lzZV'
    'IIZXhlcmNpc2USJQoOd29ya2luZ193ZWlnaHQYAiABKAJSDXdvcmtpbmdXZWlnaHQSIQoMY3Vy'
    'cmVudF9yZXBzGAMgASgFUgtjdXJyZW50UmVwcxItChJjb25zZWN1dGl2ZV9taXNzZXMYBCABKA'
    'VSEWNvbnNlY3V0aXZlTWlzc2VzEioKEWxhc3RfcGVyZm9ybWVkX2F0GAUgASgDUg9sYXN0UGVy'
    'Zm9ybWVkQXQSIwoNb3ZlcnJpZGVfc2V0cxgGIAEoBVIMb3ZlcnJpZGVTZXRzEigKEG92ZXJyaW'
    'RlX3JlcF9sb3cYByABKAVSDm92ZXJyaWRlUmVwTG93EioKEW92ZXJyaWRlX3JlcF9oaWdoGAgg'
    'ASgFUg9vdmVycmlkZVJlcEhpZ2hKBAgJEApSEGNvbnNlY3V0aXZlX2hhcmQ=');

@$core.Deprecated('Use syncRequestDescriptor instead')
const SyncRequest$json = {
  '1': 'SyncRequest',
  '2': [
    {'1': 'events', '3': 1, '4': 1, '5': 12, '9': 0, '10': 'events'},
    {
      '1': 'heartbeat',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Heartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `SyncRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncRequestDescriptor = $convert.base64Decode(
    'CgtTeW5jUmVxdWVzdBIYCgZldmVudHMYASABKAxIAFIGZXZlbnRzEjUKCWhlYXJ0YmVhdBgCIA'
    'EoCzIVLndvcmtvdXQudjEuSGVhcnRiZWF0SABSCWhlYXJ0YmVhdEIGCgRraW5k');

@$core.Deprecated('Use heartbeatDescriptor instead')
const Heartbeat$json = {
  '1': 'Heartbeat',
};

/// Descriptor for `Heartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatDescriptor =
    $convert.base64Decode('CglIZWFydGJlYXQ=');

@$core.Deprecated('Use syncResponseDescriptor instead')
const SyncResponse$json = {
  '1': 'SyncResponse',
  '2': [
    {'1': 'head', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'head'},
    {
      '1': 'session',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.GetCurrentSessionResponse',
      '9': 0,
      '10': 'session'
    },
    {
      '1': 'join_requests',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.GetJoinRequestsResponse',
      '9': 0,
      '10': 'joinRequests'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `SyncResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncResponseDescriptor = $convert.base64Decode(
    'CgxTeW5jUmVzcG9uc2USFAoEaGVhZBgBIAEoA0gAUgRoZWFkEkEKB3Nlc3Npb24YAiABKAsyJS'
    '53b3Jrb3V0LnYxLkdldEN1cnJlbnRTZXNzaW9uUmVzcG9uc2VIAFIHc2Vzc2lvbhJKCg1qb2lu'
    'X3JlcXVlc3RzGAMgASgLMiMud29ya291dC52MS5HZXRKb2luUmVxdWVzdHNSZXNwb25zZUgAUg'
    'xqb2luUmVxdWVzdHNCBgoEa2luZA==');

@$core.Deprecated('Use pullEventsRequestDescriptor instead')
const PullEventsRequest$json = {
  '1': 'PullEventsRequest',
  '2': [
    {'1': 'after_seq', '3': 1, '4': 1, '5': 3, '10': 'afterSeq'},
  ],
};

/// Descriptor for `PullEventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullEventsRequestDescriptor = $convert.base64Decode(
    'ChFQdWxsRXZlbnRzUmVxdWVzdBIbCglhZnRlcl9zZXEYASABKANSCGFmdGVyU2Vx');

@$core.Deprecated('Use pullEventsResponseDescriptor instead')
const PullEventsResponse$json = {
  '1': 'PullEventsResponse',
  '2': [
    {'1': 'events', '3': 1, '4': 1, '5': 12, '10': 'events'},
  ],
};

/// Descriptor for `PullEventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullEventsResponseDescriptor =
    $convert.base64Decode(
        'ChJQdWxsRXZlbnRzUmVzcG9uc2USFgoGZXZlbnRzGAEgASgMUgZldmVudHM=');

@$core.Deprecated('Use eventBatchDescriptor instead')
const EventBatch$json = {
  '1': 'EventBatch',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.Event',
      '10': 'events'
    },
  ],
};

/// Descriptor for `EventBatch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventBatchDescriptor = $convert.base64Decode(
    'CgpFdmVudEJhdGNoEikKBmV2ZW50cxgBIAMoCzIRLndvcmtvdXQudjEuRXZlbnRSBmV2ZW50cw'
    '==');
