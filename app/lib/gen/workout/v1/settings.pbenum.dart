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

/// The 10-muscle taxonomy. Volume, recovery and the exercise catalog all
/// use this one list — there is no second muscle grouping anywhere.
class MuscleGroup extends $pb.ProtobufEnum {
  static const MuscleGroup MUSCLE_GROUP_UNSPECIFIED =
      MuscleGroup._(0, _omitEnumNames ? '' : 'MUSCLE_GROUP_UNSPECIFIED');
  static const MuscleGroup MUSCLE_GROUP_QUADS =
      MuscleGroup._(1, _omitEnumNames ? '' : 'MUSCLE_GROUP_QUADS');
  static const MuscleGroup MUSCLE_GROUP_HAMSTRINGS =
      MuscleGroup._(2, _omitEnumNames ? '' : 'MUSCLE_GROUP_HAMSTRINGS');
  static const MuscleGroup MUSCLE_GROUP_GLUTES =
      MuscleGroup._(3, _omitEnumNames ? '' : 'MUSCLE_GROUP_GLUTES');
  static const MuscleGroup MUSCLE_GROUP_CHEST =
      MuscleGroup._(4, _omitEnumNames ? '' : 'MUSCLE_GROUP_CHEST');
  static const MuscleGroup MUSCLE_GROUP_BACK =
      MuscleGroup._(5, _omitEnumNames ? '' : 'MUSCLE_GROUP_BACK');
  static const MuscleGroup MUSCLE_GROUP_SHOULDERS =
      MuscleGroup._(6, _omitEnumNames ? '' : 'MUSCLE_GROUP_SHOULDERS');
  static const MuscleGroup MUSCLE_GROUP_BICEPS =
      MuscleGroup._(7, _omitEnumNames ? '' : 'MUSCLE_GROUP_BICEPS');
  static const MuscleGroup MUSCLE_GROUP_TRICEPS =
      MuscleGroup._(8, _omitEnumNames ? '' : 'MUSCLE_GROUP_TRICEPS');
  static const MuscleGroup MUSCLE_GROUP_CALVES =
      MuscleGroup._(9, _omitEnumNames ? '' : 'MUSCLE_GROUP_CALVES');
  static const MuscleGroup MUSCLE_GROUP_CORE =
      MuscleGroup._(10, _omitEnumNames ? '' : 'MUSCLE_GROUP_CORE');

  static const $core.List<MuscleGroup> values = <MuscleGroup>[
    MUSCLE_GROUP_UNSPECIFIED,
    MUSCLE_GROUP_QUADS,
    MUSCLE_GROUP_HAMSTRINGS,
    MUSCLE_GROUP_GLUTES,
    MUSCLE_GROUP_CHEST,
    MUSCLE_GROUP_BACK,
    MUSCLE_GROUP_SHOULDERS,
    MUSCLE_GROUP_BICEPS,
    MUSCLE_GROUP_TRICEPS,
    MUSCLE_GROUP_CALVES,
    MUSCLE_GROUP_CORE,
  ];

  static final $core.List<MuscleGroup?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static MuscleGroup? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const MuscleGroup._(super.value, super.name);
}

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
