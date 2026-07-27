// This is a generated file - do not edit.
//
// Generated from workout/v1/training.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SetRole extends $pb.ProtobufEnum {
  static const SetRole SET_ROLE_UNSPECIFIED =
      SetRole._(0, _omitEnumNames ? '' : 'SET_ROLE_UNSPECIFIED');
  static const SetRole SET_ROLE_WORKING =
      SetRole._(1, _omitEnumNames ? '' : 'SET_ROLE_WORKING');
  static const SetRole SET_ROLE_WARMUP =
      SetRole._(2, _omitEnumNames ? '' : 'SET_ROLE_WARMUP');

  static const $core.List<SetRole> values = <SetRole>[
    SET_ROLE_UNSPECIFIED,
    SET_ROLE_WORKING,
    SET_ROLE_WARMUP,
  ];

  static final $core.List<SetRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SetRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SetRole._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
