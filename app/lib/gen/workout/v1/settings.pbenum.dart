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

class StateFieldKind extends $pb.ProtobufEnum {
  static const StateFieldKind STATE_FIELD_KIND_UNSPECIFIED =
      StateFieldKind._(0, _omitEnumNames ? '' : 'STATE_FIELD_KIND_UNSPECIFIED');
  static const StateFieldKind STATE_FIELD_KIND_INT =
      StateFieldKind._(1, _omitEnumNames ? '' : 'STATE_FIELD_KIND_INT');
  static const StateFieldKind STATE_FIELD_KIND_FLOAT =
      StateFieldKind._(2, _omitEnumNames ? '' : 'STATE_FIELD_KIND_FLOAT');
  static const StateFieldKind STATE_FIELD_KIND_BOOL =
      StateFieldKind._(3, _omitEnumNames ? '' : 'STATE_FIELD_KIND_BOOL');
  static const StateFieldKind STATE_FIELD_KIND_STRING =
      StateFieldKind._(4, _omitEnumNames ? '' : 'STATE_FIELD_KIND_STRING');
  static const StateFieldKind STATE_FIELD_KIND_ENUM =
      StateFieldKind._(5, _omitEnumNames ? '' : 'STATE_FIELD_KIND_ENUM');

  static const $core.List<StateFieldKind> values = <StateFieldKind>[
    STATE_FIELD_KIND_UNSPECIFIED,
    STATE_FIELD_KIND_INT,
    STATE_FIELD_KIND_FLOAT,
    STATE_FIELD_KIND_BOOL,
    STATE_FIELD_KIND_STRING,
    STATE_FIELD_KIND_ENUM,
  ];

  static final $core.List<StateFieldKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static StateFieldKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StateFieldKind._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
