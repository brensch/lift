// This is a generated file - do not edit.
//
// Generated from workout/v1/analytics.proto.

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

@$core.Deprecated('Use pageViewDescriptor instead')
const PageView$json = {
  '1': 'PageView',
  '2': [
    {'1': 'app_session_id', '3': 1, '4': 1, '5': 9, '10': 'appSessionId'},
    {'1': 'seq', '3': 2, '4': 1, '5': 5, '10': 'seq'},
    {'1': 'page', '3': 3, '4': 1, '5': 9, '10': 'page'},
    {'1': 'entered_at_ms', '3': 4, '4': 1, '5': 3, '10': 'enteredAtMs'},
    {'1': 'duration_ms', '3': 5, '4': 1, '5': 3, '10': 'durationMs'},
  ],
};

/// Descriptor for `PageView`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageViewDescriptor = $convert.base64Decode(
    'CghQYWdlVmlldxIkCg5hcHBfc2Vzc2lvbl9pZBgBIAEoCVIMYXBwU2Vzc2lvbklkEhAKA3NlcR'
    'gCIAEoBVIDc2VxEhIKBHBhZ2UYAyABKAlSBHBhZ2USIgoNZW50ZXJlZF9hdF9tcxgEIAEoA1IL'
    'ZW50ZXJlZEF0TXMSHwoLZHVyYXRpb25fbXMYBSABKANSCmR1cmF0aW9uTXM=');

@$core.Deprecated('Use recordPageViewsRequestDescriptor instead')
const RecordPageViewsRequest$json = {
  '1': 'RecordPageViewsRequest',
  '2': [
    {
      '1': 'views',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.PageView',
      '10': 'views'
    },
  ],
};

/// Descriptor for `RecordPageViewsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordPageViewsRequestDescriptor =
    $convert.base64Decode(
        'ChZSZWNvcmRQYWdlVmlld3NSZXF1ZXN0EioKBXZpZXdzGAEgAygLMhQud29ya291dC52MS5QYW'
        'dlVmlld1IFdmlld3M=');

@$core.Deprecated('Use recordPageViewsResponseDescriptor instead')
const RecordPageViewsResponse$json = {
  '1': 'RecordPageViewsResponse',
  '2': [
    {'1': 'accepted', '3': 1, '4': 1, '5': 5, '10': 'accepted'},
  ],
};

/// Descriptor for `RecordPageViewsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordPageViewsResponseDescriptor =
    $convert.base64Decode(
        'ChdSZWNvcmRQYWdlVmlld3NSZXNwb25zZRIaCghhY2NlcHRlZBgBIAEoBVIIYWNjZXB0ZWQ=');

@$core.Deprecated('Use getAdminStatusRequestDescriptor instead')
const GetAdminStatusRequest$json = {
  '1': 'GetAdminStatusRequest',
};

/// Descriptor for `GetAdminStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAdminStatusRequestDescriptor =
    $convert.base64Decode('ChVHZXRBZG1pblN0YXR1c1JlcXVlc3Q=');

@$core.Deprecated('Use getAdminStatusResponseDescriptor instead')
const GetAdminStatusResponse$json = {
  '1': 'GetAdminStatusResponse',
  '2': [
    {'1': 'is_admin', '3': 1, '4': 1, '5': 8, '10': 'isAdmin'},
  ],
};

/// Descriptor for `GetAdminStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAdminStatusResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRBZG1pblN0YXR1c1Jlc3BvbnNlEhkKCGlzX2FkbWluGAEgASgIUgdpc0FkbWlu');

@$core.Deprecated('Use getStatsRequestDescriptor instead')
const GetStatsRequest$json = {
  '1': 'GetStatsRequest',
  '2': [
    {'1': 'days', '3': 1, '4': 1, '5': 5, '10': 'days'},
    {'1': 'trail_username', '3': 2, '4': 1, '5': 9, '10': 'trailUsername'},
  ],
};

/// Descriptor for `GetStatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStatsRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRTdGF0c1JlcXVlc3QSEgoEZGF5cxgBIAEoBVIEZGF5cxIlCg50cmFpbF91c2VybmFtZR'
    'gCIAEoCVINdHJhaWxVc2VybmFtZQ==');

@$core.Deprecated('Use pageStatDescriptor instead')
const PageStat$json = {
  '1': 'PageStat',
  '2': [
    {'1': 'page', '3': 1, '4': 1, '5': 9, '10': 'page'},
    {'1': 'views', '3': 2, '4': 1, '5': 3, '10': 'views'},
    {'1': 'unique_users', '3': 3, '4': 1, '5': 3, '10': 'uniqueUsers'},
    {
      '1': 'median_duration_ms',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'medianDurationMs'
    },
    {'1': 'total_duration_ms', '3': 5, '4': 1, '5': 3, '10': 'totalDurationMs'},
  ],
};

/// Descriptor for `PageStat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageStatDescriptor = $convert.base64Decode(
    'CghQYWdlU3RhdBISCgRwYWdlGAEgASgJUgRwYWdlEhQKBXZpZXdzGAIgASgDUgV2aWV3cxIhCg'
    'x1bmlxdWVfdXNlcnMYAyABKANSC3VuaXF1ZVVzZXJzEiwKEm1lZGlhbl9kdXJhdGlvbl9tcxgE'
    'IAEoA1IQbWVkaWFuRHVyYXRpb25NcxIqChF0b3RhbF9kdXJhdGlvbl9tcxgFIAEoA1IPdG90YW'
    'xEdXJhdGlvbk1z');

@$core.Deprecated('Use dailyStatDescriptor instead')
const DailyStat$json = {
  '1': 'DailyStat',
  '2': [
    {'1': 'day', '3': 1, '4': 1, '5': 9, '10': 'day'},
    {'1': 'views', '3': 2, '4': 1, '5': 3, '10': 'views'},
    {'1': 'unique_users', '3': 3, '4': 1, '5': 3, '10': 'uniqueUsers'},
  ],
};

/// Descriptor for `DailyStat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dailyStatDescriptor = $convert.base64Decode(
    'CglEYWlseVN0YXQSEAoDZGF5GAEgASgJUgNkYXkSFAoFdmlld3MYAiABKANSBXZpZXdzEiEKDH'
    'VuaXF1ZV91c2VycxgDIAEoA1ILdW5pcXVlVXNlcnM=');

@$core.Deprecated('Use authAttemptStatDescriptor instead')
const AuthAttemptStat$json = {
  '1': 'AuthAttemptStat',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'platform', '3': 2, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'app_version', '3': 3, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'outcome', '3': 4, '4': 1, '5': 9, '10': 'outcome'},
    {'1': 'reason', '3': 5, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'count', '3': 6, '4': 1, '5': 3, '10': 'count'},
  ],
};

/// Descriptor for `AuthAttemptStat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authAttemptStatDescriptor = $convert.base64Decode(
    'Cg9BdXRoQXR0ZW1wdFN0YXQSEgoEa2luZBgBIAEoCVIEa2luZBIaCghwbGF0Zm9ybRgCIAEoCV'
    'IIcGxhdGZvcm0SHwoLYXBwX3ZlcnNpb24YAyABKAlSCmFwcFZlcnNpb24SGAoHb3V0Y29tZRgE'
    'IAEoCVIHb3V0Y29tZRIWCgZyZWFzb24YBSABKAlSBnJlYXNvbhIUCgVjb3VudBgGIAEoA1IFY2'
    '91bnQ=');

@$core.Deprecated('Use userActivityDescriptor instead')
const UserActivity$json = {
  '1': 'UserActivity',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'views', '3': 2, '4': 1, '5': 3, '10': 'views'},
    {'1': 'last_seen_ms', '3': 3, '4': 1, '5': 3, '10': 'lastSeenMs'},
  ],
};

/// Descriptor for `UserActivity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userActivityDescriptor = $convert.base64Decode(
    'CgxVc2VyQWN0aXZpdHkSGgoIdXNlcm5hbWUYASABKAlSCHVzZXJuYW1lEhQKBXZpZXdzGAIgAS'
    'gDUgV2aWV3cxIgCgxsYXN0X3NlZW5fbXMYAyABKANSCmxhc3RTZWVuTXM=');

@$core.Deprecated('Use trailEntryDescriptor instead')
const TrailEntry$json = {
  '1': 'TrailEntry',
  '2': [
    {'1': 'page', '3': 1, '4': 1, '5': 9, '10': 'page'},
    {'1': 'entered_at_ms', '3': 2, '4': 1, '5': 3, '10': 'enteredAtMs'},
    {'1': 'duration_ms', '3': 3, '4': 1, '5': 3, '10': 'durationMs'},
    {'1': 'app_session_id', '3': 4, '4': 1, '5': 9, '10': 'appSessionId'},
    {'1': 'platform', '3': 5, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'app_version', '3': 6, '4': 1, '5': 9, '10': 'appVersion'},
  ],
};

/// Descriptor for `TrailEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trailEntryDescriptor = $convert.base64Decode(
    'CgpUcmFpbEVudHJ5EhIKBHBhZ2UYASABKAlSBHBhZ2USIgoNZW50ZXJlZF9hdF9tcxgCIAEoA1'
    'ILZW50ZXJlZEF0TXMSHwoLZHVyYXRpb25fbXMYAyABKANSCmR1cmF0aW9uTXMSJAoOYXBwX3Nl'
    'c3Npb25faWQYBCABKAlSDGFwcFNlc3Npb25JZBIaCghwbGF0Zm9ybRgFIAEoCVIIcGxhdGZvcm'
    '0SHwoLYXBwX3ZlcnNpb24YBiABKAlSCmFwcFZlcnNpb24=');

@$core.Deprecated('Use getStatsResponseDescriptor instead')
const GetStatsResponse$json = {
  '1': 'GetStatsResponse',
  '2': [
    {'1': 'days', '3': 1, '4': 1, '5': 5, '10': 'days'},
    {
      '1': 'pages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.PageStat',
      '10': 'pages'
    },
    {
      '1': 'daily',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.DailyStat',
      '10': 'daily'
    },
    {
      '1': 'auth_attempts',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.AuthAttemptStat',
      '10': 'authAttempts'
    },
    {
      '1': 'users',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.UserActivity',
      '10': 'users'
    },
    {
      '1': 'trail',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrailEntry',
      '10': 'trail'
    },
    {'1': 'total_users', '3': 7, '4': 1, '5': 3, '10': 'totalUsers'},
    {'1': 'new_users', '3': 8, '4': 1, '5': 3, '10': 'newUsers'},
    {'1': 'active_users', '3': 9, '4': 1, '5': 3, '10': 'activeUsers'},
  ],
};

/// Descriptor for `GetStatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStatsResponseDescriptor = $convert.base64Decode(
    'ChBHZXRTdGF0c1Jlc3BvbnNlEhIKBGRheXMYASABKAVSBGRheXMSKgoFcGFnZXMYAiADKAsyFC'
    '53b3Jrb3V0LnYxLlBhZ2VTdGF0UgVwYWdlcxIrCgVkYWlseRgDIAMoCzIVLndvcmtvdXQudjEu'
    'RGFpbHlTdGF0UgVkYWlseRJACg1hdXRoX2F0dGVtcHRzGAQgAygLMhsud29ya291dC52MS5BdX'
    'RoQXR0ZW1wdFN0YXRSDGF1dGhBdHRlbXB0cxIuCgV1c2VycxgFIAMoCzIYLndvcmtvdXQudjEu'
    'VXNlckFjdGl2aXR5UgV1c2VycxIsCgV0cmFpbBgGIAMoCzIWLndvcmtvdXQudjEuVHJhaWxFbn'
    'RyeVIFdHJhaWwSHwoLdG90YWxfdXNlcnMYByABKANSCnRvdGFsVXNlcnMSGwoJbmV3X3VzZXJz'
    'GAggASgDUghuZXdVc2VycxIhCgxhY3RpdmVfdXNlcnMYCSABKANSC2FjdGl2ZVVzZXJz');

@$core.Deprecated('Use getTrainingStatsRequestDescriptor instead')
const GetTrainingStatsRequest$json = {
  '1': 'GetTrainingStatsRequest',
  '2': [
    {'1': 'days', '3': 1, '4': 1, '5': 5, '10': 'days'},
  ],
};

/// Descriptor for `GetTrainingStatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTrainingStatsRequestDescriptor =
    $convert.base64Decode(
        'ChdHZXRUcmFpbmluZ1N0YXRzUmVxdWVzdBISCgRkYXlzGAEgASgFUgRkYXlz');

@$core.Deprecated('Use adminUserDescriptor instead')
const AdminUser$json = {
  '1': 'AdminUser',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'created_at', '3': 2, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'last_seen_ms', '3': 3, '4': 1, '5': 3, '10': 'lastSeenMs'},
    {'1': 'platform', '3': 4, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'app_version', '3': 5, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'passkeys', '3': 6, '4': 1, '5': 5, '10': 'passkeys'},
    {'1': 'logins', '3': 7, '4': 1, '5': 5, '10': 'logins'},
    {'1': 'workouts', '3': 8, '4': 1, '5': 5, '10': 'workouts'},
    {
      '1': 'workouts_in_window',
      '3': 9,
      '4': 1,
      '5': 5,
      '10': 'workoutsInWindow'
    },
    {'1': 'last_workout_at', '3': 10, '4': 1, '5': 3, '10': 'lastWorkoutAt'},
    {'1': 'volume_lb', '3': 11, '4': 1, '5': 1, '10': 'volumeLb'},
    {'1': 'events', '3': 12, '4': 1, '5': 3, '10': 'events'},
    {'1': 'is_admin', '3': 13, '4': 1, '5': 8, '10': 'isAdmin'},
    {'1': 'lifting_now', '3': 14, '4': 1, '5': 8, '10': 'liftingNow'},
  ],
};

/// Descriptor for `AdminUser`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminUserDescriptor = $convert.base64Decode(
    'CglBZG1pblVzZXISGgoIdXNlcm5hbWUYASABKAlSCHVzZXJuYW1lEh0KCmNyZWF0ZWRfYXQYAi'
    'ABKANSCWNyZWF0ZWRBdBIgCgxsYXN0X3NlZW5fbXMYAyABKANSCmxhc3RTZWVuTXMSGgoIcGxh'
    'dGZvcm0YBCABKAlSCHBsYXRmb3JtEh8KC2FwcF92ZXJzaW9uGAUgASgJUgphcHBWZXJzaW9uEh'
    'oKCHBhc3NrZXlzGAYgASgFUghwYXNza2V5cxIWCgZsb2dpbnMYByABKAVSBmxvZ2lucxIaCgh3'
    'b3Jrb3V0cxgIIAEoBVIId29ya291dHMSLAoSd29ya291dHNfaW5fd2luZG93GAkgASgFUhB3b3'
    'Jrb3V0c0luV2luZG93EiYKD2xhc3Rfd29ya291dF9hdBgKIAEoA1INbGFzdFdvcmtvdXRBdBIb'
    'Cgl2b2x1bWVfbGIYCyABKAFSCHZvbHVtZUxiEhYKBmV2ZW50cxgMIAEoA1IGZXZlbnRzEhkKCG'
    'lzX2FkbWluGA0gASgIUgdpc0FkbWluEh8KC2xpZnRpbmdfbm93GA4gASgIUgpsaWZ0aW5nTm93');

@$core.Deprecated('Use adminWorkoutDescriptor instead')
const AdminWorkout$json = {
  '1': 'AdminWorkout',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'start_time', '3': 3, '4': 1, '5': 3, '10': 'startTime'},
    {'1': 'duration_seconds', '3': 4, '4': 1, '5': 3, '10': 'durationSeconds'},
    {'1': 'volume_lb', '3': 5, '4': 1, '5': 1, '10': 'volumeLb'},
    {'1': 'sets', '3': 6, '4': 1, '5': 5, '10': 'sets'},
    {'1': 'exercises', '3': 7, '4': 1, '5': 5, '10': 'exercises'},
    {'1': 'together', '3': 8, '4': 1, '5': 8, '10': 'together'},
  ],
};

/// Descriptor for `AdminWorkout`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminWorkoutDescriptor = $convert.base64Decode(
    'CgxBZG1pbldvcmtvdXQSGgoIdXNlcm5hbWUYASABKAlSCHVzZXJuYW1lEhIKBG5hbWUYAiABKA'
    'lSBG5hbWUSHQoKc3RhcnRfdGltZRgDIAEoA1IJc3RhcnRUaW1lEikKEGR1cmF0aW9uX3NlY29u'
    'ZHMYBCABKANSD2R1cmF0aW9uU2Vjb25kcxIbCgl2b2x1bWVfbGIYBSABKAFSCHZvbHVtZUxiEh'
    'IKBHNldHMYBiABKAVSBHNldHMSHAoJZXhlcmNpc2VzGAcgASgFUglleGVyY2lzZXMSGgoIdG9n'
    'ZXRoZXIYCCABKAhSCHRvZ2V0aGVy');

@$core.Deprecated('Use trainingDayDescriptor instead')
const TrainingDay$json = {
  '1': 'TrainingDay',
  '2': [
    {'1': 'epoch_day', '3': 1, '4': 1, '5': 3, '10': 'epochDay'},
    {'1': 'workouts', '3': 2, '4': 1, '5': 3, '10': 'workouts'},
    {'1': 'lifters', '3': 3, '4': 1, '5': 3, '10': 'lifters'},
  ],
};

/// Descriptor for `TrainingDay`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trainingDayDescriptor = $convert.base64Decode(
    'CgtUcmFpbmluZ0RheRIbCgllcG9jaF9kYXkYASABKANSCGVwb2NoRGF5EhoKCHdvcmtvdXRzGA'
    'IgASgDUgh3b3Jrb3V0cxIYCgdsaWZ0ZXJzGAMgASgDUgdsaWZ0ZXJz');

@$core.Deprecated('Use exerciseUseDescriptor instead')
const ExerciseUse$json = {
  '1': 'ExerciseUse',
  '2': [
    {
      '1': 'exercise',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.workout.v1.Exercise',
      '10': 'exercise'
    },
    {'1': 'sets', '3': 2, '4': 1, '5': 3, '10': 'sets'},
    {'1': 'lifters', '3': 3, '4': 1, '5': 3, '10': 'lifters'},
    {'1': 'volume_lb', '3': 4, '4': 1, '5': 1, '10': 'volumeLb'},
  ],
};

/// Descriptor for `ExerciseUse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exerciseUseDescriptor = $convert.base64Decode(
    'CgtFeGVyY2lzZVVzZRIwCghleGVyY2lzZRgBIAEoDjIULndvcmtvdXQudjEuRXhlcmNpc2VSCG'
    'V4ZXJjaXNlEhIKBHNldHMYAiABKANSBHNldHMSGAoHbGlmdGVycxgDIAEoA1IHbGlmdGVycxIb'
    'Cgl2b2x1bWVfbGIYBCABKAFSCHZvbHVtZUxi');

@$core.Deprecated('Use getTrainingStatsResponseDescriptor instead')
const GetTrainingStatsResponse$json = {
  '1': 'GetTrainingStatsResponse',
  '2': [
    {'1': 'days', '3': 1, '4': 1, '5': 5, '10': 'days'},
    {
      '1': 'users',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.AdminUser',
      '10': 'users'
    },
    {
      '1': 'workouts',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.AdminWorkout',
      '10': 'workouts'
    },
    {
      '1': 'daily',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.TrainingDay',
      '10': 'daily'
    },
    {
      '1': 'exercises',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.ExerciseUse',
      '10': 'exercises'
    },
    {
      '1': 'workouts_in_window',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'workoutsInWindow'
    },
    {'1': 'lifters_in_window', '3': 7, '4': 1, '5': 3, '10': 'liftersInWindow'},
    {'1': 'workouts_total', '3': 8, '4': 1, '5': 3, '10': 'workoutsTotal'},
    {
      '1': 'volume_lb_in_window',
      '3': 9,
      '4': 1,
      '5': 1,
      '10': 'volumeLbInWindow'
    },
  ],
};

/// Descriptor for `GetTrainingStatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTrainingStatsResponseDescriptor = $convert.base64Decode(
    'ChhHZXRUcmFpbmluZ1N0YXRzUmVzcG9uc2USEgoEZGF5cxgBIAEoBVIEZGF5cxIrCgV1c2Vycx'
    'gCIAMoCzIVLndvcmtvdXQudjEuQWRtaW5Vc2VyUgV1c2VycxI0Cgh3b3Jrb3V0cxgDIAMoCzIY'
    'LndvcmtvdXQudjEuQWRtaW5Xb3Jrb3V0Ugh3b3Jrb3V0cxItCgVkYWlseRgEIAMoCzIXLndvcm'
    'tvdXQudjEuVHJhaW5pbmdEYXlSBWRhaWx5EjUKCWV4ZXJjaXNlcxgFIAMoCzIXLndvcmtvdXQu'
    'djEuRXhlcmNpc2VVc2VSCWV4ZXJjaXNlcxIsChJ3b3Jrb3V0c19pbl93aW5kb3cYBiABKANSEH'
    'dvcmtvdXRzSW5XaW5kb3cSKgoRbGlmdGVyc19pbl93aW5kb3cYByABKANSD2xpZnRlcnNJbldp'
    'bmRvdxIlCg53b3Jrb3V0c190b3RhbBgIIAEoA1INd29ya291dHNUb3RhbBItChN2b2x1bWVfbG'
    'JfaW5fd2luZG93GAkgASgBUhB2b2x1bWVMYkluV2luZG93');

@$core.Deprecated('Use recoveryRequestDescriptor instead')
const RecoveryRequest$json = {
  '1': 'RecoveryRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'created_at', '3': 3, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'platform', '3': 4, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'created_ip', '3': 5, '4': 1, '5': 9, '10': 'createdIp'},
    {'1': 'passkeys', '3': 6, '4': 1, '5': 5, '10': 'passkeys'},
    {'1': 'logins', '3': 7, '4': 1, '5': 5, '10': 'logins'},
    {'1': 'last_seen_ms', '3': 8, '4': 1, '5': 3, '10': 'lastSeenMs'},
    {'1': 'status', '3': 9, '4': 1, '5': 9, '10': 'status'},
    {'1': 'decided_at', '3': 10, '4': 1, '5': 3, '10': 'decidedAt'},
  ],
};

/// Descriptor for `RecoveryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recoveryRequestDescriptor = $convert.base64Decode(
    'Cg9SZWNvdmVyeVJlcXVlc3QSHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEhoKCHVzZX'
    'JuYW1lGAIgASgJUgh1c2VybmFtZRIdCgpjcmVhdGVkX2F0GAMgASgDUgljcmVhdGVkQXQSGgoI'
    'cGxhdGZvcm0YBCABKAlSCHBsYXRmb3JtEh0KCmNyZWF0ZWRfaXAYBSABKAlSCWNyZWF0ZWRJcB'
    'IaCghwYXNza2V5cxgGIAEoBVIIcGFzc2tleXMSFgoGbG9naW5zGAcgASgFUgZsb2dpbnMSIAoM'
    'bGFzdF9zZWVuX21zGAggASgDUgpsYXN0U2Vlbk1zEhYKBnN0YXR1cxgJIAEoCVIGc3RhdHVzEh'
    '0KCmRlY2lkZWRfYXQYCiABKANSCWRlY2lkZWRBdA==');

@$core.Deprecated('Use listRecoveriesRequestDescriptor instead')
const ListRecoveriesRequest$json = {
  '1': 'ListRecoveriesRequest',
};

/// Descriptor for `ListRecoveriesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listRecoveriesRequestDescriptor =
    $convert.base64Decode('ChVMaXN0UmVjb3Zlcmllc1JlcXVlc3Q=');

@$core.Deprecated('Use listRecoveriesResponseDescriptor instead')
const ListRecoveriesResponse$json = {
  '1': 'ListRecoveriesResponse',
  '2': [
    {
      '1': 'recoveries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.RecoveryRequest',
      '10': 'recoveries'
    },
  ],
};

/// Descriptor for `ListRecoveriesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listRecoveriesResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0UmVjb3Zlcmllc1Jlc3BvbnNlEjsKCnJlY292ZXJpZXMYASADKAsyGy53b3Jrb3V0Ln'
        'YxLlJlY292ZXJ5UmVxdWVzdFIKcmVjb3Zlcmllcw==');

@$core.Deprecated('Use decideRecoveryRequestDescriptor instead')
const DecideRecoveryRequest$json = {
  '1': 'DecideRecoveryRequest',
  '2': [
    {'1': 'approve_code', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'approveCode'},
    {
      '1': 'deny_request_id',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'denyRequestId'
    },
    {
      '1': 'remove_other_passkeys',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'removeOtherPasskeys'
    },
  ],
  '8': [
    {'1': 'request'},
  ],
};

/// Descriptor for `DecideRecoveryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decideRecoveryRequestDescriptor = $convert.base64Decode(
    'ChVEZWNpZGVSZWNvdmVyeVJlcXVlc3QSIwoMYXBwcm92ZV9jb2RlGAEgASgJSABSC2FwcHJvdm'
    'VDb2RlEigKD2RlbnlfcmVxdWVzdF9pZBgCIAEoCUgAUg1kZW55UmVxdWVzdElkEjIKFXJlbW92'
    'ZV9vdGhlcl9wYXNza2V5cxgDIAEoCFITcmVtb3ZlT3RoZXJQYXNza2V5c0IJCgdyZXF1ZXN0');

@$core.Deprecated('Use decideRecoveryResponseDescriptor instead')
const DecideRecoveryResponse$json = {
  '1': 'DecideRecoveryResponse',
  '2': [
    {
      '1': 'recovery',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.RecoveryRequest',
      '10': 'recovery'
    },
  ],
};

/// Descriptor for `DecideRecoveryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decideRecoveryResponseDescriptor =
    $convert.base64Decode(
        'ChZEZWNpZGVSZWNvdmVyeVJlc3BvbnNlEjcKCHJlY292ZXJ5GAEgASgLMhsud29ya291dC52MS'
        '5SZWNvdmVyeVJlcXVlc3RSCHJlY292ZXJ5');
