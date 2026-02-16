// This is a generated file - do not edit.
//
// Generated from workout/v1/auth.proto.

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

@$core.Deprecated('Use registerStartRequestDescriptor instead')
const RegisterStartRequest$json = {
  '1': 'RegisterStartRequest',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
  ],
};

/// Descriptor for `RegisterStartRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerStartRequestDescriptor =
    $convert.base64Decode(
        'ChRSZWdpc3RlclN0YXJ0UmVxdWVzdBIaCgh1c2VybmFtZRgBIAEoCVIIdXNlcm5hbWU=');

@$core.Deprecated('Use registerStartResponseDescriptor instead')
const RegisterStartResponse$json = {
  '1': 'RegisterStartResponse',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'options_json', '3': 2, '4': 1, '5': 9, '10': 'optionsJson'},
  ],
};

/// Descriptor for `RegisterStartResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerStartResponseDescriptor = $convert.base64Decode(
    'ChVSZWdpc3RlclN0YXJ0UmVzcG9uc2USFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEiEKDG9wdG'
    'lvbnNfanNvbhgCIAEoCVILb3B0aW9uc0pzb24=');

@$core.Deprecated('Use registerFinishRequestDescriptor instead')
const RegisterFinishRequest$json = {
  '1': 'RegisterFinishRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'credential_json', '3': 2, '4': 1, '5': 9, '10': 'credentialJson'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
  ],
  '8': [
    {'1': '_name'},
  ],
};

/// Descriptor for `RegisterFinishRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerFinishRequestDescriptor = $convert.base64Decode(
    'ChVSZWdpc3RlckZpbmlzaFJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEicKD2NyZW'
    'RlbnRpYWxfanNvbhgCIAEoCVIOY3JlZGVudGlhbEpzb24SFwoEbmFtZRgDIAEoCUgAUgRuYW1l'
    'iAEBQgcKBV9uYW1l');

@$core.Deprecated('Use authResponseDescriptor instead')
const AuthResponse$json = {
  '1': 'AuthResponse',
  '2': [
    {'1': 'session_token', '3': 1, '4': 1, '5': 9, '10': 'sessionToken'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'username', '3': 3, '4': 1, '5': 9, '10': 'username'},
  ],
};

/// Descriptor for `AuthResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List authResponseDescriptor = $convert.base64Decode(
    'CgxBdXRoUmVzcG9uc2USIwoNc2Vzc2lvbl90b2tlbhgBIAEoCVIMc2Vzc2lvblRva2VuEhcKB3'
    'VzZXJfaWQYAiABKAlSBnVzZXJJZBIaCgh1c2VybmFtZRgDIAEoCVIIdXNlcm5hbWU=');

@$core.Deprecated('Use loginStartRequestDescriptor instead')
const LoginStartRequest$json = {
  '1': 'LoginStartRequest',
  '2': [
    {
      '1': 'username',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'username',
      '17': true
    },
  ],
  '8': [
    {'1': '_username'},
  ],
};

/// Descriptor for `LoginStartRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginStartRequestDescriptor = $convert.base64Decode(
    'ChFMb2dpblN0YXJ0UmVxdWVzdBIfCgh1c2VybmFtZRgBIAEoCUgAUgh1c2VybmFtZYgBAUILCg'
    'lfdXNlcm5hbWU=');

@$core.Deprecated('Use loginStartResponseDescriptor instead')
const LoginStartResponse$json = {
  '1': 'LoginStartResponse',
  '2': [
    {'1': 'challenge_id', '3': 1, '4': 1, '5': 9, '10': 'challengeId'},
    {'1': 'options_json', '3': 2, '4': 1, '5': 9, '10': 'optionsJson'},
  ],
};

/// Descriptor for `LoginStartResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginStartResponseDescriptor = $convert.base64Decode(
    'ChJMb2dpblN0YXJ0UmVzcG9uc2USIQoMY2hhbGxlbmdlX2lkGAEgASgJUgtjaGFsbGVuZ2VJZB'
    'IhCgxvcHRpb25zX2pzb24YAiABKAlSC29wdGlvbnNKc29u');

@$core.Deprecated('Use loginFinishRequestDescriptor instead')
const LoginFinishRequest$json = {
  '1': 'LoginFinishRequest',
  '2': [
    {'1': 'challenge_id', '3': 1, '4': 1, '5': 9, '10': 'challengeId'},
    {'1': 'credential_json', '3': 2, '4': 1, '5': 9, '10': 'credentialJson'},
  ],
};

/// Descriptor for `LoginFinishRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginFinishRequestDescriptor = $convert.base64Decode(
    'ChJMb2dpbkZpbmlzaFJlcXVlc3QSIQoMY2hhbGxlbmdlX2lkGAEgASgJUgtjaGFsbGVuZ2VJZB'
    'InCg9jcmVkZW50aWFsX2pzb24YAiABKAlSDmNyZWRlbnRpYWxKc29u');

@$core.Deprecated('Use logoutRequestDescriptor instead')
const LogoutRequest$json = {
  '1': 'LogoutRequest',
};

/// Descriptor for `LogoutRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutRequestDescriptor =
    $convert.base64Decode('Cg1Mb2dvdXRSZXF1ZXN0');

@$core.Deprecated('Use logoutResponseDescriptor instead')
const LogoutResponse$json = {
  '1': 'LogoutResponse',
};

/// Descriptor for `LogoutResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutResponseDescriptor =
    $convert.base64Decode('Cg5Mb2dvdXRSZXNwb25zZQ==');

@$core.Deprecated('Use addPasskeyStartRequestDescriptor instead')
const AddPasskeyStartRequest$json = {
  '1': 'AddPasskeyStartRequest',
};

/// Descriptor for `AddPasskeyStartRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addPasskeyStartRequestDescriptor =
    $convert.base64Decode('ChZBZGRQYXNza2V5U3RhcnRSZXF1ZXN0');

@$core.Deprecated('Use addPasskeyStartResponseDescriptor instead')
const AddPasskeyStartResponse$json = {
  '1': 'AddPasskeyStartResponse',
  '2': [
    {'1': 'options_json', '3': 1, '4': 1, '5': 9, '10': 'optionsJson'},
  ],
};

/// Descriptor for `AddPasskeyStartResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addPasskeyStartResponseDescriptor =
    $convert.base64Decode(
        'ChdBZGRQYXNza2V5U3RhcnRSZXNwb25zZRIhCgxvcHRpb25zX2pzb24YASABKAlSC29wdGlvbn'
        'NKc29u');

@$core.Deprecated('Use addPasskeyFinishRequestDescriptor instead')
const AddPasskeyFinishRequest$json = {
  '1': 'AddPasskeyFinishRequest',
  '2': [
    {'1': 'credential_json', '3': 1, '4': 1, '5': 9, '10': 'credentialJson'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
  ],
  '8': [
    {'1': '_name'},
  ],
};

/// Descriptor for `AddPasskeyFinishRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addPasskeyFinishRequestDescriptor =
    $convert.base64Decode(
        'ChdBZGRQYXNza2V5RmluaXNoUmVxdWVzdBInCg9jcmVkZW50aWFsX2pzb24YASABKAlSDmNyZW'
        'RlbnRpYWxKc29uEhcKBG5hbWUYAiABKAlIAFIEbmFtZYgBAUIHCgVfbmFtZQ==');

@$core.Deprecated('Use addPasskeyFinishResponseDescriptor instead')
const AddPasskeyFinishResponse$json = {
  '1': 'AddPasskeyFinishResponse',
};

/// Descriptor for `AddPasskeyFinishResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addPasskeyFinishResponseDescriptor =
    $convert.base64Decode('ChhBZGRQYXNza2V5RmluaXNoUmVzcG9uc2U=');

@$core.Deprecated('Use deletePasskeyRequestDescriptor instead')
const DeletePasskeyRequest$json = {
  '1': 'DeletePasskeyRequest',
  '2': [
    {'1': 'credential_id', '3': 1, '4': 1, '5': 9, '10': 'credentialId'},
  ],
};

/// Descriptor for `DeletePasskeyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePasskeyRequestDescriptor = $convert.base64Decode(
    'ChREZWxldGVQYXNza2V5UmVxdWVzdBIjCg1jcmVkZW50aWFsX2lkGAEgASgJUgxjcmVkZW50aW'
    'FsSWQ=');

@$core.Deprecated('Use deletePasskeyResponseDescriptor instead')
const DeletePasskeyResponse$json = {
  '1': 'DeletePasskeyResponse',
};

/// Descriptor for `DeletePasskeyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePasskeyResponseDescriptor =
    $convert.base64Decode('ChVEZWxldGVQYXNza2V5UmVzcG9uc2U=');

@$core.Deprecated('Use passkeyInfoDescriptor instead')
const PasskeyInfo$json = {
  '1': 'PasskeyInfo',
  '2': [
    {'1': 'credential_id', '3': 1, '4': 1, '5': 9, '10': 'credentialId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {'1': 'created_at', '3': 3, '4': 1, '5': 3, '10': 'createdAt'},
    {
      '1': 'created_at_ip',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'createdAtIp',
      '17': true
    },
    {'1': 'transports', '3': 5, '4': 3, '5': 9, '10': 'transports'},
  ],
  '8': [
    {'1': '_name'},
    {'1': '_created_at_ip'},
  ],
};

/// Descriptor for `PasskeyInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List passkeyInfoDescriptor = $convert.base64Decode(
    'CgtQYXNza2V5SW5mbxIjCg1jcmVkZW50aWFsX2lkGAEgASgJUgxjcmVkZW50aWFsSWQSFwoEbm'
    'FtZRgCIAEoCUgAUgRuYW1liAEBEh0KCmNyZWF0ZWRfYXQYAyABKANSCWNyZWF0ZWRBdBInCg1j'
    'cmVhdGVkX2F0X2lwGAQgASgJSAFSC2NyZWF0ZWRBdElwiAEBEh4KCnRyYW5zcG9ydHMYBSADKA'
    'lSCnRyYW5zcG9ydHNCBwoFX25hbWVCEAoOX2NyZWF0ZWRfYXRfaXA=');

@$core.Deprecated('Use listPasskeysRequestDescriptor instead')
const ListPasskeysRequest$json = {
  '1': 'ListPasskeysRequest',
};

/// Descriptor for `ListPasskeysRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPasskeysRequestDescriptor =
    $convert.base64Decode('ChNMaXN0UGFzc2tleXNSZXF1ZXN0');

@$core.Deprecated('Use listPasskeysResponseDescriptor instead')
const ListPasskeysResponse$json = {
  '1': 'ListPasskeysResponse',
  '2': [
    {
      '1': 'passkeys',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.workout.v1.PasskeyInfo',
      '10': 'passkeys'
    },
  ],
};

/// Descriptor for `ListPasskeysResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPasskeysResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0UGFzc2tleXNSZXNwb25zZRIzCghwYXNza2V5cxgBIAMoCzIXLndvcmtvdXQudjEuUG'
    'Fzc2tleUluZm9SCHBhc3NrZXlz');

@$core.Deprecated('Use passwordRegisterRequestDescriptor instead')
const PasswordRegisterRequest$json = {
  '1': 'PasswordRegisterRequest',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
  ],
};

/// Descriptor for `PasswordRegisterRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List passwordRegisterRequestDescriptor =
    $convert.base64Decode(
        'ChdQYXNzd29yZFJlZ2lzdGVyUmVxdWVzdBIaCgh1c2VybmFtZRgBIAEoCVIIdXNlcm5hbWUSGg'
        'oIcGFzc3dvcmQYAiABKAlSCHBhc3N3b3Jk');

@$core.Deprecated('Use passwordLoginRequestDescriptor instead')
const PasswordLoginRequest$json = {
  '1': 'PasswordLoginRequest',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
  ],
};

/// Descriptor for `PasswordLoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List passwordLoginRequestDescriptor = $convert.base64Decode(
    'ChRQYXNzd29yZExvZ2luUmVxdWVzdBIaCgh1c2VybmFtZRgBIAEoCVIIdXNlcm5hbWUSGgoIcG'
    'Fzc3dvcmQYAiABKAlSCHBhc3N3b3Jk');

@$core.Deprecated('Use testLoginRequestDescriptor instead')
const TestLoginRequest$json = {
  '1': 'TestLoginRequest',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
  ],
};

/// Descriptor for `TestLoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testLoginRequestDescriptor = $convert.base64Decode(
    'ChBUZXN0TG9naW5SZXF1ZXN0EhoKCHVzZXJuYW1lGAEgASgJUgh1c2VybmFtZQ==');
