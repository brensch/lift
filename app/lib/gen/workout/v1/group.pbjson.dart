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

@$core.Deprecated('Use joinViaInviteRequestDescriptor instead')
const JoinViaInviteRequest$json = {
  '1': 'JoinViaInviteRequest',
  '2': [
    {'1': 'invite_token', '3': 1, '4': 1, '5': 9, '10': 'inviteToken'},
  ],
};

/// Descriptor for `JoinViaInviteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinViaInviteRequestDescriptor = $convert.base64Decode(
    'ChRKb2luVmlhSW52aXRlUmVxdWVzdBIhCgxpbnZpdGVfdG9rZW4YASABKAlSC2ludml0ZVRva2'
    'Vu');

@$core.Deprecated('Use joinViaInviteResponseDescriptor instead')
const JoinViaInviteResponse$json = {
  '1': 'JoinViaInviteResponse',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `JoinViaInviteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinViaInviteResponseDescriptor = $convert.base64Decode(
    'ChVKb2luVmlhSW52aXRlUmVzcG9uc2USHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklk');

@$core.Deprecated('Use getMyInviteTokenRequestDescriptor instead')
const GetMyInviteTokenRequest$json = {
  '1': 'GetMyInviteTokenRequest',
};

/// Descriptor for `GetMyInviteTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMyInviteTokenRequestDescriptor =
    $convert.base64Decode('ChdHZXRNeUludml0ZVRva2VuUmVxdWVzdA==');

@$core.Deprecated('Use getMyInviteTokenResponseDescriptor instead')
const GetMyInviteTokenResponse$json = {
  '1': 'GetMyInviteTokenResponse',
  '2': [
    {'1': 'invite_token', '3': 1, '4': 1, '5': 9, '10': 'inviteToken'},
  ],
};

/// Descriptor for `GetMyInviteTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMyInviteTokenResponseDescriptor =
    $convert.base64Decode(
        'ChhHZXRNeUludml0ZVRva2VuUmVzcG9uc2USIQoMaW52aXRlX3Rva2VuGAEgASgJUgtpbnZpdG'
        'VUb2tlbg==');

@$core.Deprecated('Use rotateInviteTokenRequestDescriptor instead')
const RotateInviteTokenRequest$json = {
  '1': 'RotateInviteTokenRequest',
};

/// Descriptor for `RotateInviteTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rotateInviteTokenRequestDescriptor =
    $convert.base64Decode('ChhSb3RhdGVJbnZpdGVUb2tlblJlcXVlc3Q=');

@$core.Deprecated('Use rotateInviteTokenResponseDescriptor instead')
const RotateInviteTokenResponse$json = {
  '1': 'RotateInviteTokenResponse',
  '2': [
    {'1': 'invite_token', '3': 1, '4': 1, '5': 9, '10': 'inviteToken'},
  ],
};

/// Descriptor for `RotateInviteTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rotateInviteTokenResponseDescriptor =
    $convert.base64Decode(
        'ChlSb3RhdGVJbnZpdGVUb2tlblJlc3BvbnNlEiEKDGludml0ZV90b2tlbhgBIAEoCVILaW52aX'
        'RlVG9rZW4=');

@$core.Deprecated('Use leaveCurrentSessionRequestDescriptor instead')
const LeaveCurrentSessionRequest$json = {
  '1': 'LeaveCurrentSessionRequest',
};

/// Descriptor for `LeaveCurrentSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveCurrentSessionRequestDescriptor =
    $convert.base64Decode('ChpMZWF2ZUN1cnJlbnRTZXNzaW9uUmVxdWVzdA==');

@$core.Deprecated('Use leaveCurrentSessionResponseDescriptor instead')
const LeaveCurrentSessionResponse$json = {
  '1': 'LeaveCurrentSessionResponse',
};

/// Descriptor for `LeaveCurrentSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveCurrentSessionResponseDescriptor =
    $convert.base64Decode('ChtMZWF2ZUN1cnJlbnRTZXNzaW9uUmVzcG9uc2U=');

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
};

/// Descriptor for `GetCurrentSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCurrentSessionRequestDescriptor =
    $convert.base64Decode('ChhHZXRDdXJyZW50U2Vzc2lvblJlcXVlc3Q=');

@$core.Deprecated('Use getSessionParticipantsRequestDescriptor instead')
const GetSessionParticipantsRequest$json = {
  '1': 'GetSessionParticipantsRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `GetSessionParticipantsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSessionParticipantsRequestDescriptor =
    $convert.base64Decode(
        'Ch1HZXRTZXNzaW9uUGFydGljaXBhbnRzUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZX'
        'NzaW9uSWQ=');

@$core.Deprecated('Use getSessionParticipantsResponseDescriptor instead')
const GetSessionParticipantsResponse$json = {
  '1': 'GetSessionParticipantsResponse',
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

/// Descriptor for `GetSessionParticipantsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSessionParticipantsResponseDescriptor =
    $convert.base64Decode(
        'Ch5HZXRTZXNzaW9uUGFydGljaXBhbnRzUmVzcG9uc2USHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2'
        'Vzc2lvbklkEkEKDHBhcnRpY2lwYW50cxgCIAMoCzIdLndvcmtvdXQudjEuUGFydGljaXBhbnRT'
        'dGF0dXNSDHBhcnRpY2lwYW50cw==');

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

@$core.Deprecated('Use subscribeSessionRequestDescriptor instead')
const SubscribeSessionRequest$json = {
  '1': 'SubscribeSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `SubscribeSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscribeSessionRequestDescriptor =
    $convert.base64Decode(
        'ChdTdWJzY3JpYmVTZXNzaW9uUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSW'
        'Q=');

@$core.Deprecated('Use sessionSubscriptionEventDescriptor instead')
const SessionSubscriptionEvent$json = {
  '1': 'SessionSubscriptionEvent',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'version', '3': 2, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'session_status',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.SessionStatus',
      '10': 'sessionStatus'
    },
  ],
};

/// Descriptor for `SessionSubscriptionEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionSubscriptionEventDescriptor = $convert.base64Decode(
    'ChhTZXNzaW9uU3Vic2NyaXB0aW9uRXZlbnQSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbk'
    'lkEhgKB3ZlcnNpb24YAiABKANSB3ZlcnNpb24SQAoOc2Vzc2lvbl9zdGF0dXMYAyABKAsyGS53'
    'b3Jrb3V0LnYxLlNlc3Npb25TdGF0dXNSDXNlc3Npb25TdGF0dXM=');

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
    {'1': 'next_up_user_id', '3': 3, '4': 1, '5': 9, '10': 'nextUpUserId'},
    {
      '1': 'next_up_set',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {
      '1': 'next_up_rest_until',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'nextUpRestUntil'
    },
    {
      '1': 'currently_lifting_user_id',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'currentlyLiftingUserId'
    },
  ],
};

/// Descriptor for `SessionStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionStatusDescriptor = $convert.base64Decode(
    'Cg1TZXNzaW9uU3RhdHVzEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBJBCgxwYXJ0aW'
    'NpcGFudHMYAiADKAsyHS53b3Jrb3V0LnYxLlBhcnRpY2lwYW50U3RhdHVzUgxwYXJ0aWNpcGFu'
    'dHMSJQoPbmV4dF91cF91c2VyX2lkGAMgASgJUgxuZXh0VXBVc2VySWQSNwoLbmV4dF91cF9zZX'
    'QYBCABKAsyFy53b3Jrb3V0LnYxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSKwoSbmV4dF91cF9y'
    'ZXN0X3VudGlsGAUgASgDUg9uZXh0VXBSZXN0VW50aWwSOQoZY3VycmVudGx5X2xpZnRpbmdfdX'
    'Nlcl9pZBgGIAEoCVIWY3VycmVudGx5TGlmdGluZ1VzZXJJZA==');

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
      '1': 'exercise_groups',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseGroup',
      '10': 'exerciseGroups'
    },
    {
      '1': 'proposed_sets',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'proposedSets'
    },
    {
      '1': 'completed_sets',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.CompletedSet',
      '10': 'completedSets'
    },
    {
      '1': 'next_up_set',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ProposedSet',
      '10': 'nextUpSet'
    },
    {'1': 'rest_until', '3': 8, '4': 1, '5': 3, '10': 'restUntil'},
    {'1': 'has_active_set', '3': 9, '4': 1, '5': 8, '10': 'hasActiveSet'},
  ],
};

/// Descriptor for `ParticipantStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List participantStatusDescriptor = $convert.base64Decode(
    'ChFQYXJ0aWNpcGFudFN0YXR1cxIkCgR1c2VyGAEgASgLMhAud29ya291dC52MS5Vc2VyUgR1c2'
    'VyEioKEWFjdGl2ZV93b3Jrb3V0X2lkGAIgASgJUg9hY3RpdmVXb3Jrb3V0SWQSOgoOYWN0aXZl'
    'X3dvcmtvdXQYAyABKAsyEy53b3Jrb3V0LnYxLldvcmtvdXRSDWFjdGl2ZVdvcmtvdXQSQgoPZX'
    'hlcmNpc2VfZ3JvdXBzGAQgAygLMhkud29ya291dC52MS5FeGVyY2lzZUdyb3VwUg5leGVyY2lz'
    'ZUdyb3VwcxI8Cg1wcm9wb3NlZF9zZXRzGAUgAygLMhcud29ya291dC52MS5Qcm9wb3NlZFNldF'
    'IMcHJvcG9zZWRTZXRzEj8KDmNvbXBsZXRlZF9zZXRzGAYgAygLMhgud29ya291dC52MS5Db21w'
    'bGV0ZWRTZXRSDWNvbXBsZXRlZFNldHMSNwoLbmV4dF91cF9zZXQYByABKAsyFy53b3Jrb3V0Ln'
    'YxLlByb3Bvc2VkU2V0UgluZXh0VXBTZXQSHQoKcmVzdF91bnRpbBgIIAEoA1IJcmVzdFVudGls'
    'EiQKDmhhc19hY3RpdmVfc2V0GAkgASgIUgxoYXNBY3RpdmVTZXQ=');
