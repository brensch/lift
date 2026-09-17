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

class WeightUnit extends $pb.ProtobufEnum {
  static const WeightUnit WEIGHT_UNIT_UNSPECIFIED =
      WeightUnit._(0, _omitEnumNames ? '' : 'WEIGHT_UNIT_UNSPECIFIED');
  static const WeightUnit WEIGHT_UNIT_LB =
      WeightUnit._(1, _omitEnumNames ? '' : 'WEIGHT_UNIT_LB');
  static const WeightUnit WEIGHT_UNIT_KG =
      WeightUnit._(2, _omitEnumNames ? '' : 'WEIGHT_UNIT_KG');

  static const $core.List<WeightUnit> values = <WeightUnit>[
    WEIGHT_UNIT_UNSPECIFIED,
    WEIGHT_UNIT_LB,
    WEIGHT_UNIT_KG,
  ];

  static final $core.List<WeightUnit?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static WeightUnit? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WeightUnit._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
