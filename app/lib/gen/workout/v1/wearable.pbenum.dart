// This is a generated file - do not edit.
//
// Generated from workout/v1/wearable.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class WearActionType extends $pb.ProtobufEnum {
  static const WearActionType WEAR_ACTION_TYPE_UNSPECIFIED =
      WearActionType._(0, _omitEnumNames ? '' : 'WEAR_ACTION_TYPE_UNSPECIFIED');
  static const WearActionType WEAR_ACTION_TYPE_START_SET =
      WearActionType._(1, _omitEnumNames ? '' : 'WEAR_ACTION_TYPE_START_SET');
  static const WearActionType WEAR_ACTION_TYPE_COMPLETE_SET = WearActionType._(
      2, _omitEnumNames ? '' : 'WEAR_ACTION_TYPE_COMPLETE_SET');
  static const WearActionType WEAR_ACTION_TYPE_SKIP_WARMUP =
      WearActionType._(3, _omitEnumNames ? '' : 'WEAR_ACTION_TYPE_SKIP_WARMUP');
  static const WearActionType WEAR_ACTION_TYPE_END_WORKOUT =
      WearActionType._(4, _omitEnumNames ? '' : 'WEAR_ACTION_TYPE_END_WORKOUT');

  static const $core.List<WearActionType> values = <WearActionType>[
    WEAR_ACTION_TYPE_UNSPECIFIED,
    WEAR_ACTION_TYPE_START_SET,
    WEAR_ACTION_TYPE_COMPLETE_SET,
    WEAR_ACTION_TYPE_SKIP_WARMUP,
    WEAR_ACTION_TYPE_END_WORKOUT,
  ];

  static final $core.List<WearActionType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static WearActionType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WearActionType._(super.value, super.name);
}

class WearActionStyle extends $pb.ProtobufEnum {
  static const WearActionStyle WEAR_ACTION_STYLE_UNSPECIFIED =
      WearActionStyle._(
          0, _omitEnumNames ? '' : 'WEAR_ACTION_STYLE_UNSPECIFIED');
  static const WearActionStyle WEAR_ACTION_STYLE_PRIMARY =
      WearActionStyle._(1, _omitEnumNames ? '' : 'WEAR_ACTION_STYLE_PRIMARY');
  static const WearActionStyle WEAR_ACTION_STYLE_SECONDARY =
      WearActionStyle._(2, _omitEnumNames ? '' : 'WEAR_ACTION_STYLE_SECONDARY');
  static const WearActionStyle WEAR_ACTION_STYLE_REP_OPTION = WearActionStyle._(
      3, _omitEnumNames ? '' : 'WEAR_ACTION_STYLE_REP_OPTION');

  static const $core.List<WearActionStyle> values = <WearActionStyle>[
    WEAR_ACTION_STYLE_UNSPECIFIED,
    WEAR_ACTION_STYLE_PRIMARY,
    WEAR_ACTION_STYLE_SECONDARY,
    WEAR_ACTION_STYLE_REP_OPTION,
  ];

  static final $core.List<WearActionStyle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static WearActionStyle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WearActionStyle._(super.value, super.name);
}

class HeartRateAvailability extends $pb.ProtobufEnum {
  static const HeartRateAvailability HEART_RATE_AVAILABILITY_UNSPECIFIED =
      HeartRateAvailability._(
          0, _omitEnumNames ? '' : 'HEART_RATE_AVAILABILITY_UNSPECIFIED');
  static const HeartRateAvailability HEART_RATE_AVAILABILITY_AVAILABLE =
      HeartRateAvailability._(
          1, _omitEnumNames ? '' : 'HEART_RATE_AVAILABILITY_AVAILABLE');
  static const HeartRateAvailability HEART_RATE_AVAILABILITY_ACQUIRING =
      HeartRateAvailability._(
          2, _omitEnumNames ? '' : 'HEART_RATE_AVAILABILITY_ACQUIRING');
  static const HeartRateAvailability HEART_RATE_AVAILABILITY_UNAVAILABLE =
      HeartRateAvailability._(
          3, _omitEnumNames ? '' : 'HEART_RATE_AVAILABILITY_UNAVAILABLE');

  static const $core.List<HeartRateAvailability> values =
      <HeartRateAvailability>[
    HEART_RATE_AVAILABILITY_UNSPECIFIED,
    HEART_RATE_AVAILABILITY_AVAILABLE,
    HEART_RATE_AVAILABILITY_ACQUIRING,
    HEART_RATE_AVAILABILITY_UNAVAILABLE,
  ];

  static final $core.List<HeartRateAvailability?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static HeartRateAvailability? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HeartRateAvailability._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
