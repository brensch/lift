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
    'GAggASgDUghuZXdVc2Vycw==');
