// This is a generated file - do not edit.
//
// Generated from workout/v1/settings.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class RegimeType extends $pb.ProtobufEnum {
  static const RegimeType REGIME_TYPE_UNSPECIFIED =
      RegimeType._(0, _omitEnumNames ? '' : 'REGIME_TYPE_UNSPECIFIED');
  static const RegimeType REGIME_TYPE_LINEAR_5X5 =
      RegimeType._(1, _omitEnumNames ? '' : 'REGIME_TYPE_LINEAR_5X5');
  static const RegimeType REGIME_TYPE_GZCLP =
      RegimeType._(2, _omitEnumNames ? '' : 'REGIME_TYPE_GZCLP');
  static const RegimeType REGIME_TYPE_WENDLER_531 =
      RegimeType._(3, _omitEnumNames ? '' : 'REGIME_TYPE_WENDLER_531');

  static const $core.List<RegimeType> values = <RegimeType>[
    REGIME_TYPE_UNSPECIFIED,
    REGIME_TYPE_LINEAR_5X5,
    REGIME_TYPE_GZCLP,
    REGIME_TYPE_WENDLER_531,
  ];

  static final $core.List<RegimeType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static RegimeType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RegimeType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
