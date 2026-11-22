// This is a generated file - do not edit.
//
// Generated from workout/v1/assistant.proto.

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

@$core.Deprecated('Use connectRequestDescriptor instead')
const ConnectRequest$json = {
  '1': 'ConnectRequest',
  '2': [
    {'1': 'client_id', '3': 1, '4': 1, '5': 9, '10': 'clientId'},
    {'1': 'redirect_uri', '3': 2, '4': 1, '5': 9, '10': 'redirectUri'},
    {'1': 'code_challenge', '3': 3, '4': 1, '5': 9, '10': 'codeChallenge'},
    {
      '1': 'code_challenge_method',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'codeChallengeMethod'
    },
    {'1': 'state', '3': 5, '4': 1, '5': 9, '10': 'state'},
    {'1': 'scope', '3': 6, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'resource', '3': 7, '4': 1, '5': 9, '10': 'resource'},
  ],
};

/// Descriptor for `ConnectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectRequestDescriptor = $convert.base64Decode(
    'Cg5Db25uZWN0UmVxdWVzdBIbCgljbGllbnRfaWQYASABKAlSCGNsaWVudElkEiEKDHJlZGlyZW'
    'N0X3VyaRgCIAEoCVILcmVkaXJlY3RVcmkSJQoOY29kZV9jaGFsbGVuZ2UYAyABKAlSDWNvZGVD'
    'aGFsbGVuZ2USMgoVY29kZV9jaGFsbGVuZ2VfbWV0aG9kGAQgASgJUhNjb2RlQ2hhbGxlbmdlTW'
    'V0aG9kEhQKBXN0YXRlGAUgASgJUgVzdGF0ZRIUCgVzY29wZRgGIAEoCVIFc2NvcGUSGgoIcmVz'
    'b3VyY2UYByABKAlSCHJlc291cmNl');

@$core.Deprecated('Use describeConnectRequestDescriptor instead')
const DescribeConnectRequest$json = {
  '1': 'DescribeConnectRequest',
  '2': [
    {
      '1': 'request',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ConnectRequest',
      '10': 'request'
    },
  ],
};

/// Descriptor for `DescribeConnectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List describeConnectRequestDescriptor =
    $convert.base64Decode(
        'ChZEZXNjcmliZUNvbm5lY3RSZXF1ZXN0EjQKB3JlcXVlc3QYASABKAsyGi53b3Jrb3V0LnYxLk'
        'Nvbm5lY3RSZXF1ZXN0UgdyZXF1ZXN0');

@$core.Deprecated('Use describeConnectResponseDescriptor instead')
const DescribeConnectResponse$json = {
  '1': 'DescribeConnectResponse',
  '2': [
    {'1': 'client_name', '3': 1, '4': 1, '5': 9, '10': 'clientName'},
    {'1': 'redirect_host', '3': 2, '4': 1, '5': 9, '10': 'redirectHost'},
    {'1': 'can', '3': 3, '4': 3, '5': 9, '10': 'can'},
  ],
};

/// Descriptor for `DescribeConnectResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List describeConnectResponseDescriptor = $convert.base64Decode(
    'ChdEZXNjcmliZUNvbm5lY3RSZXNwb25zZRIfCgtjbGllbnRfbmFtZRgBIAEoCVIKY2xpZW50Tm'
    'FtZRIjCg1yZWRpcmVjdF9ob3N0GAIgASgJUgxyZWRpcmVjdEhvc3QSEAoDY2FuGAMgAygJUgNj'
    'YW4=');

@$core.Deprecated('Use answerConnectRequestDescriptor instead')
const AnswerConnectRequest$json = {
  '1': 'AnswerConnectRequest',
  '2': [
    {
      '1': 'request',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.workout.v1.ConnectRequest',
      '10': 'request'
    },
    {'1': 'allow', '3': 2, '4': 1, '5': 8, '10': 'allow'},
  ],
};

/// Descriptor for `AnswerConnectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerConnectRequestDescriptor = $convert.base64Decode(
    'ChRBbnN3ZXJDb25uZWN0UmVxdWVzdBI0CgdyZXF1ZXN0GAEgASgLMhoud29ya291dC52MS5Db2'
    '5uZWN0UmVxdWVzdFIHcmVxdWVzdBIUCgVhbGxvdxgCIAEoCFIFYWxsb3c=');

@$core.Deprecated('Use answerConnectResponseDescriptor instead')
const AnswerConnectResponse$json = {
  '1': 'AnswerConnectResponse',
  '2': [
    {'1': 'redirect_to', '3': 1, '4': 1, '5': 9, '10': 'redirectTo'},
  ],
};

/// Descriptor for `AnswerConnectResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerConnectResponseDescriptor = $convert.base64Decode(
    'ChVBbnN3ZXJDb25uZWN0UmVzcG9uc2USHwoLcmVkaXJlY3RfdG8YASABKAlSCnJlZGlyZWN0VG'
    '8=');

@$core.Deprecated('Use assistantGrantDescriptor instead')
const AssistantGrant$json = {
  '1': 'AssistantGrant',
  '2': [
    {'1': 'grant_id', '3': 1, '4': 1, '5': 9, '10': 'grantId'},
    {'1': 'client_name', '3': 2, '4': 1, '5': 9, '10': 'clientName'},
    {'1': 'created_at', '3': 3, '4': 1, '5': 3, '10': 'createdAt'},
    {'1': 'last_used_at', '3': 4, '4': 1, '5': 3, '10': 'lastUsedAt'},
    {'1': 'scope', '3': 5, '4': 1, '5': 9, '10': 'scope'},
  ],
};

/// Descriptor for `AssistantGrant`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assistantGrantDescriptor = $convert.base64Decode(
    'Cg5Bc3Npc3RhbnRHcmFudBIZCghncmFudF9pZBgBIAEoCVIHZ3JhbnRJZBIfCgtjbGllbnRfbm'
    'FtZRgCIAEoCVIKY2xpZW50TmFtZRIdCgpjcmVhdGVkX2F0GAMgASgDUgljcmVhdGVkQXQSIAoM'
    'bGFzdF91c2VkX2F0GAQgASgDUgpsYXN0VXNlZEF0EhQKBXNjb3BlGAUgASgJUgVzY29wZQ==');

@$core.Deprecated('Use listAssistantsRequestDescriptor instead')
const ListAssistantsRequest$json = {
  '1': 'ListAssistantsRequest',
};

/// Descriptor for `ListAssistantsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAssistantsRequestDescriptor =
    $convert.base64Decode('ChVMaXN0QXNzaXN0YW50c1JlcXVlc3Q=');

@$core.Deprecated('Use listAssistantsResponseDescriptor instead')
const ListAssistantsResponse$json = {
  '1': 'ListAssistantsResponse',
  '2': [
    {
      '1': 'grants',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.AssistantGrant',
      '10': 'grants'
    },
  ],
};

/// Descriptor for `ListAssistantsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAssistantsResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0QXNzaXN0YW50c1Jlc3BvbnNlEjIKBmdyYW50cxgBIAMoCzIaLndvcmtvdXQudjEuQX'
        'NzaXN0YW50R3JhbnRSBmdyYW50cw==');

@$core.Deprecated('Use revokeAssistantRequestDescriptor instead')
const RevokeAssistantRequest$json = {
  '1': 'RevokeAssistantRequest',
  '2': [
    {'1': 'grant_id', '3': 1, '4': 1, '5': 9, '10': 'grantId'},
  ],
};

/// Descriptor for `RevokeAssistantRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revokeAssistantRequestDescriptor =
    $convert.base64Decode(
        'ChZSZXZva2VBc3Npc3RhbnRSZXF1ZXN0EhkKCGdyYW50X2lkGAEgASgJUgdncmFudElk');

@$core.Deprecated('Use revokeAssistantResponseDescriptor instead')
const RevokeAssistantResponse$json = {
  '1': 'RevokeAssistantResponse',
};

/// Descriptor for `RevokeAssistantResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revokeAssistantResponseDescriptor =
    $convert.base64Decode('ChdSZXZva2VBc3Npc3RhbnRSZXNwb25zZQ==');
