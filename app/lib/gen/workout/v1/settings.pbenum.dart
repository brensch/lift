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
  static const RegimeType REGIME_TYPE_WENDLER_531_4DAY =
      RegimeType._(4, _omitEnumNames ? '' : 'REGIME_TYPE_WENDLER_531_4DAY');
  static const RegimeType REGIME_TYPE_WENDLER_531_3DAY =
      RegimeType._(5, _omitEnumNames ? '' : 'REGIME_TYPE_WENDLER_531_3DAY');

  static const $core.List<RegimeType> values = <RegimeType>[
    REGIME_TYPE_UNSPECIFIED,
    REGIME_TYPE_LINEAR_5X5,
    REGIME_TYPE_GZCLP,
    REGIME_TYPE_WENDLER_531_4DAY,
    REGIME_TYPE_WENDLER_531_3DAY,
  ];

  static final $core.List<RegimeType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static RegimeType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RegimeType._(super.value, super.name);
}

class TrainingProgramFieldKind extends $pb.ProtobufEnum {
  static const TrainingProgramFieldKind
      TRAINING_PROGRAM_FIELD_KIND_UNSPECIFIED = TrainingProgramFieldKind._(
          0, _omitEnumNames ? '' : 'TRAINING_PROGRAM_FIELD_KIND_UNSPECIFIED');
  static const TrainingProgramFieldKind TRAINING_PROGRAM_FIELD_KIND_INT32 =
      TrainingProgramFieldKind._(
          1, _omitEnumNames ? '' : 'TRAINING_PROGRAM_FIELD_KIND_INT32');
  static const TrainingProgramFieldKind TRAINING_PROGRAM_FIELD_KIND_FLOAT =
      TrainingProgramFieldKind._(
          2, _omitEnumNames ? '' : 'TRAINING_PROGRAM_FIELD_KIND_FLOAT');
  static const TrainingProgramFieldKind TRAINING_PROGRAM_FIELD_KIND_BOOL =
      TrainingProgramFieldKind._(
          3, _omitEnumNames ? '' : 'TRAINING_PROGRAM_FIELD_KIND_BOOL');

  static const $core.List<TrainingProgramFieldKind> values =
      <TrainingProgramFieldKind>[
    TRAINING_PROGRAM_FIELD_KIND_UNSPECIFIED,
    TRAINING_PROGRAM_FIELD_KIND_INT32,
    TRAINING_PROGRAM_FIELD_KIND_FLOAT,
    TRAINING_PROGRAM_FIELD_KIND_BOOL,
  ];

  static final $core.List<TrainingProgramFieldKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TrainingProgramFieldKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TrainingProgramFieldKind._(super.value, super.name);
}

class TrainingProgramFieldBinding extends $pb.ProtobufEnum {
  static const TrainingProgramFieldBinding
      TRAINING_PROGRAM_FIELD_BINDING_UNSPECIFIED =
      TrainingProgramFieldBinding._(0,
          _omitEnumNames ? '' : 'TRAINING_PROGRAM_FIELD_BINDING_UNSPECIFIED');
  static const TrainingProgramFieldBinding
      TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK =
      TrainingProgramFieldBinding._(1,
          _omitEnumNames ? '' : 'TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK');
  static const TrainingProgramFieldBinding
      TRAINING_PROGRAM_FIELD_BINDING_ONE_REP_MAX =
      TrainingProgramFieldBinding._(2,
          _omitEnumNames ? '' : 'TRAINING_PROGRAM_FIELD_BINDING_ONE_REP_MAX');

  static const $core.List<TrainingProgramFieldBinding> values =
      <TrainingProgramFieldBinding>[
    TRAINING_PROGRAM_FIELD_BINDING_UNSPECIFIED,
    TRAINING_PROGRAM_FIELD_BINDING_DAYS_PER_WEEK,
    TRAINING_PROGRAM_FIELD_BINDING_ONE_REP_MAX,
  ];

  static final $core.List<TrainingProgramFieldBinding?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TrainingProgramFieldBinding? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TrainingProgramFieldBinding._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
