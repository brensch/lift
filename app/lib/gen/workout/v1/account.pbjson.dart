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
      '1': 'starting_weights',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseWeight',
      '10': 'startingWeights'
    },
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['trackers'],
};

/// Descriptor for `ImportHistory`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importHistoryDescriptor = $convert.base64Decode(
    'Cg1JbXBvcnRIaXN0b3J5EjcKCHdvcmtvdXRzGAEgAygLMhsud29ya291dC52MS5JbXBvcnRlZF'
    'dvcmtvdXRSCHdvcmtvdXRzEkUKEHN0YXJ0aW5nX3dlaWdodHMYAyADKAsyGi53b3Jrb3V0LnYx'
    'LkV4ZXJjaXNlV2VpZ2h0Ug9zdGFydGluZ1dlaWdodHNKBAgCEANSCHRyYWNrZXJz');

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
    {
      '1': 'exercise_logs',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseLog',
      '10': 'exerciseLogs'
    },
  ],
};

/// Descriptor for `ImportedWorkout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importedWorkoutDescriptor = $convert.base64Decode(
    'Cg9JbXBvcnRlZFdvcmtvdXQSLQoHd29ya291dBgBIAEoCzITLndvcmtvdXQudjEuV29ya291dF'
    'IHd29ya291dBI8Cg1wcm9wb3NlZF9zZXRzGAIgAygLMhcud29ya291dC52MS5Qcm9wb3NlZFNl'
    'dFIMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGAMgAygLMhgud29ya291dC52MS5Db2'
    '1wbGV0ZWRTZXRSDWNvbXBsZXRlZFNldHMSQAoKaGVhcnRfcmF0ZRgEIAMoCzIhLndvcmtvdXQu'
    'djEuV29ya291dEhlYXJ0UmF0ZVBvaW50UgloZWFydFJhdGUSPAoNZXhlcmNpc2VfbG9ncxgFIA'
    'MoCzIXLndvcmtvdXQudjEuRXhlcmNpc2VMb2dSDGV4ZXJjaXNlTG9ncw==');

@$core.Deprecated('Use syncRequestDescriptor instead')
const SyncRequest$json = {
  '1': 'SyncRequest',
  '2': [
    {'1': 'after_seq', '3': 3, '4': 1, '5': 3, '9': 0, '10': 'afterSeq'},
    {'1': 'events', '3': 4, '4': 1, '5': 12, '9': 0, '10': 'events'},
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
  '9': [
    {'1': 1, '2': 2},
  ],
};

/// Descriptor for `SyncRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncRequestDescriptor = $convert.base64Decode(
    'CgtTeW5jUmVxdWVzdBIdCglhZnRlcl9zZXEYAyABKANIAFIIYWZ0ZXJTZXESGAoGZXZlbnRzGA'
    'QgASgMSABSBmV2ZW50cxI1CgloZWFydGJlYXQYAiABKAsyFS53b3Jrb3V0LnYxLkhlYXJ0YmVh'
    'dEgAUgloZWFydGJlYXRCBgoEa2luZEoECAEQAg==');

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
    {
      '1': 'events',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Events',
      '9': 0,
      '10': 'events'
    },
    {'1': 'head', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'head'},
    {
      '1': 'session',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Session',
      '9': 0,
      '10': 'session'
    },
    {
      '1': 'partner_events',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.PartnerEvents',
      '9': 0,
      '10': 'partnerEvents'
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
    {
      '1': 'library',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ListTemplateLibraryResponse',
      '9': 0,
      '10': 'library'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
};

/// Descriptor for `SyncResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncResponseDescriptor = $convert.base64Decode(
    'CgxTeW5jUmVzcG9uc2USLAoGZXZlbnRzGAUgASgLMhIud29ya291dC52MS5FdmVudHNIAFIGZX'
    'ZlbnRzEhQKBGhlYWQYASABKANIAFIEaGVhZBIvCgdzZXNzaW9uGAYgASgLMhMud29ya291dC52'
    'MS5TZXNzaW9uSABSB3Nlc3Npb24SQgoOcGFydG5lcl9ldmVudHMYByABKAsyGS53b3Jrb3V0Ln'
    'YxLlBhcnRuZXJFdmVudHNIAFINcGFydG5lckV2ZW50cxJKCg1qb2luX3JlcXVlc3RzGAMgASgL'
    'MiMud29ya291dC52MS5HZXRKb2luUmVxdWVzdHNSZXNwb25zZUgAUgxqb2luUmVxdWVzdHMSQw'
    'oHbGlicmFyeRgEIAEoCzInLndvcmtvdXQudjEuTGlzdFRlbXBsYXRlTGlicmFyeVJlc3BvbnNl'
    'SABSB2xpYnJhcnlCBgoEa2luZEoECAIQAw==');

@$core.Deprecated('Use partnerEventsDescriptor instead')
const PartnerEvents$json = {
  '1': 'PartnerEvents',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'packed', '3': 2, '4': 1, '5': 12, '10': 'packed'},
    {'1': 'whole', '3': 3, '4': 1, '5': 8, '10': 'whole'},
  ],
};

/// Descriptor for `PartnerEvents`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List partnerEventsDescriptor = $convert.base64Decode(
    'Cg1QYXJ0bmVyRXZlbnRzEhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIWCgZwYWNrZWQYAiABKA'
    'xSBnBhY2tlZBIUCgV3aG9sZRgDIAEoCFIFd2hvbGU=');

@$core.Deprecated('Use eventsDescriptor instead')
const Events$json = {
  '1': 'Events',
  '2': [
    {'1': 'packed', '3': 1, '4': 1, '5': 12, '10': 'packed'},
    {'1': 'head', '3': 2, '4': 1, '5': 3, '10': 'head'},
  ],
};

/// Descriptor for `Events`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventsDescriptor = $convert.base64Decode(
    'CgZFdmVudHMSFgoGcGFja2VkGAEgASgMUgZwYWNrZWQSEgoEaGVhZBgCIAEoA1IEaGVhZA==');
