// This is a generated file - do not edit.
//
// Generated from workout/v1/auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Why a passkey ceremony died on the device, as far as the app can tell.
/// A fixed enum, never free text: this rides on an unauthenticated RPC.
class AuthFailureReason extends $pb.ProtobufEnum {
  static const AuthFailureReason AUTH_FAILURE_REASON_UNSPECIFIED =
      AuthFailureReason._(
          0, _omitEnumNames ? '' : 'AUTH_FAILURE_REASON_UNSPECIFIED');
  static const AuthFailureReason AUTH_FAILURE_REASON_CANCELLED =
      AuthFailureReason._(
          1, _omitEnumNames ? '' : 'AUTH_FAILURE_REASON_CANCELLED');
  static const AuthFailureReason AUTH_FAILURE_REASON_NO_CREDENTIAL =
      AuthFailureReason._(
          2, _omitEnumNames ? '' : 'AUTH_FAILURE_REASON_NO_CREDENTIAL');
  static const AuthFailureReason AUTH_FAILURE_REASON_UNSUPPORTED =
      AuthFailureReason._(
          3, _omitEnumNames ? '' : 'AUTH_FAILURE_REASON_UNSUPPORTED');
  static const AuthFailureReason AUTH_FAILURE_REASON_PLATFORM_ERROR =
      AuthFailureReason._(
          4, _omitEnumNames ? '' : 'AUTH_FAILURE_REASON_PLATFORM_ERROR');
  static const AuthFailureReason AUTH_FAILURE_REASON_TIMEOUT =
      AuthFailureReason._(
          5, _omitEnumNames ? '' : 'AUTH_FAILURE_REASON_TIMEOUT');
  static const AuthFailureReason AUTH_FAILURE_REASON_OTHER =
      AuthFailureReason._(6, _omitEnumNames ? '' : 'AUTH_FAILURE_REASON_OTHER');

  static const $core.List<AuthFailureReason> values = <AuthFailureReason>[
    AUTH_FAILURE_REASON_UNSPECIFIED,
    AUTH_FAILURE_REASON_CANCELLED,
    AUTH_FAILURE_REASON_NO_CREDENTIAL,
    AUTH_FAILURE_REASON_UNSUPPORTED,
    AUTH_FAILURE_REASON_PLATFORM_ERROR,
    AUTH_FAILURE_REASON_TIMEOUT,
    AUTH_FAILURE_REASON_OTHER,
  ];

  static final $core.List<AuthFailureReason?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static AuthFailureReason? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AuthFailureReason._(super.value, super.name);
}

class RecoveryState extends $pb.ProtobufEnum {
  static const RecoveryState RECOVERY_STATE_UNSPECIFIED =
      RecoveryState._(0, _omitEnumNames ? '' : 'RECOVERY_STATE_UNSPECIFIED');
  static const RecoveryState RECOVERY_STATE_PENDING =
      RecoveryState._(1, _omitEnumNames ? '' : 'RECOVERY_STATE_PENDING');
  static const RecoveryState RECOVERY_STATE_APPROVED =
      RecoveryState._(2, _omitEnumNames ? '' : 'RECOVERY_STATE_APPROVED');
  static const RecoveryState RECOVERY_STATE_DENIED =
      RecoveryState._(3, _omitEnumNames ? '' : 'RECOVERY_STATE_DENIED');
  static const RecoveryState RECOVERY_STATE_EXPIRED =
      RecoveryState._(4, _omitEnumNames ? '' : 'RECOVERY_STATE_EXPIRED');

  static const $core.List<RecoveryState> values = <RecoveryState>[
    RECOVERY_STATE_UNSPECIFIED,
    RECOVERY_STATE_PENDING,
    RECOVERY_STATE_APPROVED,
    RECOVERY_STATE_DENIED,
    RECOVERY_STATE_EXPIRED,
  ];

  static final $core.List<RecoveryState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static RecoveryState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RecoveryState._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
