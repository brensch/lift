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
    {
      '1': 'state_snapshot',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.WorkoutStateSnapshot',
      '10': 'stateSnapshot'
    },
    {
      '1': 'passed_warmup_ids',
      '3': 11,
      '4': 3,
      '5': 9,
      '10': 'passedWarmupIds'
    },
  ],
  '9': [
    {'1': 4, '2': 5},
    {'1': 8, '2': 9},
    {'1': 9, '2': 10},
  ],
  '10': ['exercise_groups', 'rest_until', 'has_active_set'],
};

/// Descriptor for `ParticipantStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List participantStatusDescriptor = $convert.base64Decode(
    'ChFQYXJ0aWNpcGFudFN0YXR1cxIkCgR1c2VyGAEgASgLMhAud29ya291dC52MS5Vc2VyUgR1c2'
    'VyEioKEWFjdGl2ZV93b3Jrb3V0X2lkGAIgASgJUg9hY3RpdmVXb3Jrb3V0SWQSOgoOYWN0aXZl'
    'X3dvcmtvdXQYAyABKAsyEy53b3Jrb3V0LnYxLldvcmtvdXRSDWFjdGl2ZVdvcmtvdXQSPAoNcH'
    'JvcG9zZWRfc2V0cxgFIAMoCzIXLndvcmtvdXQudjEuUHJvcG9zZWRTZXRSDHByb3Bvc2VkU2V0'
    'cxI/Cg5jb21wbGV0ZWRfc2V0cxgGIAMoCzIYLndvcmtvdXQudjEuQ29tcGxldGVkU2V0Ug1jb2'
    '1wbGV0ZWRTZXRzEjcKC25leHRfdXBfc2V0GAcgASgLMhcud29ya291dC52MS5Qcm9wb3NlZFNl'
    'dFIJbmV4dFVwU2V0EkcKDnN0YXRlX3NuYXBzaG90GAogASgLMiAud29ya291dC52MS5Xb3Jrb3'
    'V0U3RhdGVTbmFwc2hvdFINc3RhdGVTbmFwc2hvdBIqChFwYXNzZWRfd2FybXVwX2lkcxgLIAMo'
    'CVIPcGFzc2VkV2FybXVwSWRzSgQIBBAFSgQICBAJSgQICRAKUg9leGVyY2lzZV9ncm91cHNSCn'
    'Jlc3RfdW50aWxSDmhhc19hY3RpdmVfc2V0');

@$core.Deprecated('Use trainingPartnerDescriptor instead')
const TrainingPartner$json = {
  '1': 'TrainingPartner',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.User',
      '10': 'user'
    },
    {
      '1': 'sessions_together',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'sessionsTogether'
    },
    {'1': 'last_trained_at', '3': 3, '4': 1, '5': 3, '10': 'lastTrainedAt'},
  ],
};

/// Descriptor for `TrainingPartner`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingPartnerDescriptor = $convert.base64Decode(
    'Cg9UcmFpbmluZ1BhcnRuZXISJAoEdXNlchgBIAEoCzIQLndvcmtvdXQudjEuVXNlclIEdXNlch'
    'IrChFzZXNzaW9uc190b2dldGhlchgCIAEoBVIQc2Vzc2lvbnNUb2dldGhlchImCg9sYXN0X3Ry'
    'YWluZWRfYXQYAyABKANSDWxhc3RUcmFpbmVkQXQ=');

@$core.Deprecated('Use getTrainingPartnersRequestDescriptor instead')
const GetTrainingPartnersRequest$json = {
  '1': 'GetTrainingPartnersRequest',
};

/// Descriptor for `GetTrainingPartnersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTrainingPartnersRequestDescriptor =
    $convert.base64Decode('ChpHZXRUcmFpbmluZ1BhcnRuZXJzUmVxdWVzdA==');

@$core.Deprecated('Use getTrainingPartnersResponseDescriptor instead')
const GetTrainingPartnersResponse$json = {
  '1': 'GetTrainingPartnersResponse',
  '2': [
    {
      '1': 'partners',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingPartner',
      '10': 'partners'
    },
  ],
};

/// Descriptor for `GetTrainingPartnersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTrainingPartnersResponseDescriptor =
    $convert.base64Decode(
        'ChtHZXRUcmFpbmluZ1BhcnRuZXJzUmVzcG9uc2USNwoIcGFydG5lcnMYASADKAsyGy53b3Jrb3'
        'V0LnYxLlRyYWluaW5nUGFydG5lclIIcGFydG5lcnM=');

@$core.Deprecated('Use sharedSessionDescriptor instead')
const SharedSession$json = {
  '1': 'SharedSession',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'trained_at', '3': 2, '4': 1, '5': 3, '10': 'trainedAt'},
    {'1': 'caller_worked_out', '3': 3, '4': 1, '5': 8, '10': 'callerWorkedOut'},
    {
      '1': 'partner_worked_out',
      '3': 4,
      '4': 1,
      '5': 8,
      '10': 'partnerWorkedOut'
    },
  ],
};

/// Descriptor for `SharedSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sharedSessionDescriptor = $convert.base64Decode(
    'Cg1TaGFyZWRTZXNzaW9uEh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZBIdCgp0cmFpbm'
    'VkX2F0GAIgASgDUgl0cmFpbmVkQXQSKgoRY2FsbGVyX3dvcmtlZF9vdXQYAyABKAhSD2NhbGxl'
    'cldvcmtlZE91dBIsChJwYXJ0bmVyX3dvcmtlZF9vdXQYBCABKAhSEHBhcnRuZXJXb3JrZWRPdX'
    'Q=');

@$core.Deprecated('Use getSharedSessionsRequestDescriptor instead')
const GetSharedSessionsRequest$json = {
  '1': 'GetSharedSessionsRequest',
  '2': [
    {'1': 'partner_user_id', '3': 1, '4': 1, '5': 9, '10': 'partnerUserId'},
  ],
};

/// Descriptor for `GetSharedSessionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSharedSessionsRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRTaGFyZWRTZXNzaW9uc1JlcXVlc3QSJgoPcGFydG5lcl91c2VyX2lkGAEgASgJUg1wYX'
        'J0bmVyVXNlcklk');

@$core.Deprecated('Use getSharedSessionsResponseDescriptor instead')
const GetSharedSessionsResponse$json = {
  '1': 'GetSharedSessionsResponse',
  '2': [
    {
      '1': 'sessions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.SharedSession',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `GetSharedSessionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSharedSessionsResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRTaGFyZWRTZXNzaW9uc1Jlc3BvbnNlEjUKCHNlc3Npb25zGAEgAygLMhkud29ya291dC'
        '52MS5TaGFyZWRTZXNzaW9uUghzZXNzaW9ucw==');

@$core.Deprecated('Use requestJoinPartnerRequestDescriptor instead')
const RequestJoinPartnerRequest$json = {
  '1': 'RequestJoinPartnerRequest',
  '2': [
    {'1': 'partner_user_id', '3': 1, '4': 1, '5': 9, '10': 'partnerUserId'},
  ],
};

/// Descriptor for `RequestJoinPartnerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestJoinPartnerRequestDescriptor =
    $convert.base64Decode(
        'ChlSZXF1ZXN0Sm9pblBhcnRuZXJSZXF1ZXN0EiYKD3BhcnRuZXJfdXNlcl9pZBgBIAEoCVINcG'
        'FydG5lclVzZXJJZA==');

@$core.Deprecated('Use requestJoinPartnerResponseDescriptor instead')
const RequestJoinPartnerResponse$json = {
  '1': 'RequestJoinPartnerResponse',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
  ],
};

/// Descriptor for `RequestJoinPartnerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestJoinPartnerResponseDescriptor =
    $convert.base64Decode(
        'ChpSZXF1ZXN0Sm9pblBhcnRuZXJSZXNwb25zZRIdCgpyZXF1ZXN0X2lkGAEgASgJUglyZXF1ZX'
        'N0SWQ=');

@$core.Deprecated('Use joinRequestDescriptor instead')
const JoinRequest$json = {
  '1': 'JoinRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {
      '1': 'from_user',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.User',
      '10': 'fromUser'
    },
    {'1': 'created_at', '3': 3, '4': 1, '5': 3, '10': 'createdAt'},
  ],
};

/// Descriptor for `JoinRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinRequestDescriptor = $convert.base64Decode(
    'CgtKb2luUmVxdWVzdBIdCgpyZXF1ZXN0X2lkGAEgASgJUglyZXF1ZXN0SWQSLQoJZnJvbV91c2'
    'VyGAIgASgLMhAud29ya291dC52MS5Vc2VyUghmcm9tVXNlchIdCgpjcmVhdGVkX2F0GAMgASgD'
    'UgljcmVhdGVkQXQ=');

@$core.Deprecated('Use getJoinRequestsRequestDescriptor instead')
const GetJoinRequestsRequest$json = {
  '1': 'GetJoinRequestsRequest',
};

/// Descriptor for `GetJoinRequestsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJoinRequestsRequestDescriptor =
    $convert.base64Decode('ChZHZXRKb2luUmVxdWVzdHNSZXF1ZXN0');

@$core.Deprecated('Use getJoinRequestsResponseDescriptor instead')
const GetJoinRequestsResponse$json = {
  '1': 'GetJoinRequestsResponse',
  '2': [
    {
      '1': 'requests',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.JoinRequest',
      '10': 'requests'
    },
  ],
};

/// Descriptor for `GetJoinRequestsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJoinRequestsResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRKb2luUmVxdWVzdHNSZXNwb25zZRIzCghyZXF1ZXN0cxgBIAMoCzIXLndvcmtvdXQudj'
        'EuSm9pblJlcXVlc3RSCHJlcXVlc3Rz');

@$core.Deprecated('Use respondJoinRequestRequestDescriptor instead')
const RespondJoinRequestRequest$json = {
  '1': 'RespondJoinRequestRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'accept', '3': 2, '4': 1, '5': 8, '10': 'accept'},
  ],
};

/// Descriptor for `RespondJoinRequestRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List respondJoinRequestRequestDescriptor =
    $convert.base64Decode(
        'ChlSZXNwb25kSm9pblJlcXVlc3RSZXF1ZXN0Eh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3'
        'RJZBIWCgZhY2NlcHQYAiABKAhSBmFjY2VwdA==');

@$core.Deprecated('Use respondJoinRequestResponseDescriptor instead')
const RespondJoinRequestResponse$json = {
  '1': 'RespondJoinRequestResponse',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `RespondJoinRequestResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List respondJoinRequestResponseDescriptor =
    $convert.base64Decode(
        'ChpSZXNwb25kSm9pblJlcXVlc3RSZXNwb25zZRIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW'
        '9uSWQ=');
