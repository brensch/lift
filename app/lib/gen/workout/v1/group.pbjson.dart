// This is a generated file - do not edit.
//
// Generated from workout/v1/group.proto.

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

@$core.Deprecated('Use startSessionRequestDescriptor instead')
const StartSessionRequest$json = {
  '1': 'StartSessionRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `StartSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSessionRequestDescriptor = $convert.base64Decode(
    'ChNTdGFydFNlc3Npb25SZXF1ZXN0Eh0KCndvcmtvdXRfaWQYASABKAlSCXdvcmtvdXRJZA==');

@$core.Deprecated('Use startSessionResponseDescriptor instead')
const StartSessionResponse$json = {
  '1': 'StartSessionResponse',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `StartSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startSessionResponseDescriptor = $convert.base64Decode(
    'ChRTdGFydFNlc3Npb25SZXNwb25zZRIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQ=');

@$core.Deprecated('Use joinSessionRequestDescriptor instead')
const JoinSessionRequest$json = {
  '1': 'JoinSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `JoinSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinSessionRequestDescriptor = $convert.base64Decode(
    'ChJKb2luU2Vzc2lvblJlcXVlc3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEh0KCn'
    'dvcmtvdXRfaWQYAiABKAlSCXdvcmtvdXRJZA==');

@$core.Deprecated('Use joinSessionResponseDescriptor instead')
const JoinSessionResponse$json = {
  '1': 'JoinSessionResponse',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `JoinSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinSessionResponseDescriptor = $convert.base64Decode(
    'ChNKb2luU2Vzc2lvblJlc3BvbnNlEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZA==');

@$core.Deprecated('Use leaveSessionRequestDescriptor instead')
const LeaveSessionRequest$json = {
  '1': 'LeaveSessionRequest',
};

/// Descriptor for `LeaveSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveSessionRequestDescriptor =
    $convert.base64Decode('ChNMZWF2ZVNlc3Npb25SZXF1ZXN0');

@$core.Deprecated('Use leaveSessionResponseDescriptor instead')
const LeaveSessionResponse$json = {
  '1': 'LeaveSessionResponse',
};

/// Descriptor for `LeaveSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveSessionResponseDescriptor =
    $convert.base64Decode('ChRMZWF2ZVNlc3Npb25SZXNwb25zZQ==');

@$core.Deprecated('Use getParticipantWorkoutRequestDescriptor instead')
const GetParticipantWorkoutRequest$json = {
  '1': 'GetParticipantWorkoutRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'workout_id', '3': 2, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `GetParticipantWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getParticipantWorkoutRequestDescriptor =
    $convert.base64Decode(
        'ChxHZXRQYXJ0aWNpcGFudFdvcmtvdXRSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZB'
        'IdCgp3b3Jrb3V0X2lkGAIgASgJUgl3b3Jrb3V0SWQ=');

@$core.Deprecated('Use getCurrentSessionRequestDescriptor instead')
const GetCurrentSessionRequest$json = {
  '1': 'GetCurrentSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `GetCurrentSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCurrentSessionRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRDdXJyZW50U2Vzc2lvblJlcXVlc3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbk'
        'lk');

@$core.Deprecated('Use getCurrentSessionResponseDescriptor instead')
const GetCurrentSessionResponse$json = {
  '1': 'GetCurrentSessionResponse',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'session_status',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SessionStatus',
      '10': 'sessionStatus'
    },
  ],
};

/// Descriptor for `GetCurrentSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCurrentSessionResponseDescriptor = $convert.base64Decode(
    'ChlHZXRDdXJyZW50U2Vzc2lvblJlc3BvbnNlEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb2'
    '5JZBJACg5zZXNzaW9uX3N0YXR1cxgCIAEoCzIZLndvcmtvdXQudjEuU2Vzc2lvblN0YXR1c1IN'
    'c2Vzc2lvblN0YXR1cw==');

@$core.Deprecated('Use updateActiveWorkoutRequestDescriptor instead')
const UpdateActiveWorkoutRequest$json = {
  '1': 'UpdateActiveWorkoutRequest',
  '2': [
    {'1': 'workout_id', '3': 1, '4': 1, '5': 9, '10': 'workoutId'},
  ],
};

/// Descriptor for `UpdateActiveWorkoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateActiveWorkoutRequestDescriptor =
    $convert.base64Decode(
        'ChpVcGRhdGVBY3RpdmVXb3Jrb3V0UmVxdWVzdBIdCgp3b3Jrb3V0X2lkGAEgASgJUgl3b3Jrb3'
        'V0SWQ=');

@$core.Deprecated('Use updateActiveWorkoutResponseDescriptor instead')
const UpdateActiveWorkoutResponse$json = {
  '1': 'UpdateActiveWorkoutResponse',
};

/// Descriptor for `UpdateActiveWorkoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateActiveWorkoutResponseDescriptor =
    $convert.base64Decode('ChtVcGRhdGVBY3RpdmVXb3Jrb3V0UmVzcG9uc2U=');

@$core.Deprecated('Use sessionStatusDescriptor instead')
const SessionStatus$json = {
  '1': 'SessionStatus',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'participants',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ParticipantStatus',
      '10': 'participants'
    },
  ],
};

/// Descriptor for `SessionStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionStatusDescriptor = $convert.base64Decode(
    'Cg1TZXNzaW9uU3RhdHVzEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBJBCgxwYXJ0aW'
    'NpcGFudHMYAiADKAsyHS53b3Jrb3V0LnYxLlBhcnRpY2lwYW50U3RhdHVzUgxwYXJ0aWNpcGFu'
    'dHM=');

@$core.Deprecated('Use participantStatusDescriptor instead')
const ParticipantStatus$json = {
  '1': 'ParticipantStatus',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.User',
      '10': 'user'
    },
    {'1': 'active_workout_id', '3': 2, '4': 1, '5': 9, '10': 'activeWorkoutId'},
    {
      '1': 'active_workout',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.Workout',
      '10': 'activeWorkout'
    },
    {
      '1': 'proposed_sets',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
    {
      '1': 'completed_sets',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSets'
    },
  ],
};

/// Descriptor for `ParticipantStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List participantStatusDescriptor = $convert.base64Decode(
    'ChFQYXJ0aWNpcGFudFN0YXR1cxIkCgR1c2VyGAEgASgLMhAud29ya291dC52MS5Vc2VyUgR1c2'
    'VyEioKEWFjdGl2ZV93b3Jrb3V0X2lkGAIgASgJUg9hY3RpdmVXb3Jrb3V0SWQSOgoOYWN0aXZl'
    'X3dvcmtvdXQYAyABKAsyEy53b3Jrb3V0LnYxLldvcmtvdXRSDWFjdGl2ZVdvcmtvdXQSPAoNcH'
    'JvcG9zZWRfc2V0cxgEIAMoCzIXLndvcmtvdXQudjEuUHJvcG9zZWRTZXRSDHByb3Bvc2VkU2V0'
    'cxI/Cg5jb21wbGV0ZWRfc2V0cxgFIAMoCzIYLndvcmtvdXQudjEuQ29tcGxldGVkU2V0Ug1jb2'
    '1wbGV0ZWRTZXRz');
