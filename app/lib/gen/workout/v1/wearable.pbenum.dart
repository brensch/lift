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
  static const WearActionType WEAR_ACTION_TYPE_COMPLETE_SET = WearActionType._(
      2, _omitEnumNames ? '' : 'WEAR_ACTION_TYPE_COMPLETE_SET');
  static const WearActionType WEAR_ACTION_TYPE_END_WORKOUT =
      WearActionType._(4, _omitEnumNames ? '' : 'WEAR_ACTION_TYPE_END_WORKOUT');
  static const WearActionType WEAR_ACTION_TYPE_START_SET =
      WearActionType._(8, _omitEnumNames ? '' : 'WEAR_ACTION_TYPE_START_SET');

  static const $core.List<WearActionType> values = <WearActionType>[
    WEAR_ACTION_TYPE_UNSPECIFIED,
    WEAR_ACTION_TYPE_COMPLETE_SET,
    WEAR_ACTION_TYPE_END_WORKOUT,
    WEAR_ACTION_TYPE_START_SET,
  ];

  static final $core.Map<$core.int, WearActionType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static WearActionType? valueOf($core.int value) => _byValue[value];

  const WearActionType._(super.value, super.name);
}

class HeartRateAvailability extends $pb.ProtobufEnum {
  static const HeartRateAvailability HEART_RATE_AVAILABILITY_UNSPECIFIED =
      HeartRateAvailability._(
          0, _omitEnumNames ? '' : 'HEART_RATE_AVAILABILITY_UNSPECIFIED');
  static const HeartRateAvailability HEART_RATE_AVAILABILITY_AVAILABLE =
      HeartRateAvailability._(
          1, _omitEnumNames ? '' : 'HEART_RATE_AVAILABILITY_AVAILABLE');

  static const $core.List<HeartRateAvailability> values =
      <HeartRateAvailability>[
    HEART_RATE_AVAILABILITY_UNSPECIFIED,
    HEART_RATE_AVAILABILITY_AVAILABLE,
  ];

  static final $core.List<HeartRateAvailability?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static HeartRateAvailability? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const HeartRateAvailability._(super.value, super.name);
}

/// What a set's circle shows, as the phone's own circle does.
class WearCircleState extends $pb.ProtobufEnum {
  static const WearCircleState WEAR_CIRCLE_STATE_UNSPECIFIED =
      WearCircleState._(
          0, _omitEnumNames ? '' : 'WEAR_CIRCLE_STATE_UNSPECIFIED');
  static const WearCircleState WEAR_CIRCLE_STATE_PENDING =
      WearCircleState._(1, _omitEnumNames ? '' : 'WEAR_CIRCLE_STATE_PENDING');
  static const WearCircleState WEAR_CIRCLE_STATE_NEXT =
      WearCircleState._(2, _omitEnumNames ? '' : 'WEAR_CIRCLE_STATE_NEXT');
  static const WearCircleState WEAR_CIRCLE_STATE_LIFTING =
      WearCircleState._(3, _omitEnumNames ? '' : 'WEAR_CIRCLE_STATE_LIFTING');
  static const WearCircleState WEAR_CIRCLE_STATE_FULL =
      WearCircleState._(4, _omitEnumNames ? '' : 'WEAR_CIRCLE_STATE_FULL');
  static const WearCircleState WEAR_CIRCLE_STATE_SHORT =
      WearCircleState._(5, _omitEnumNames ? '' : 'WEAR_CIRCLE_STATE_SHORT');
  static const WearCircleState WEAR_CIRCLE_STATE_ZERO =
      WearCircleState._(6, _omitEnumNames ? '' : 'WEAR_CIRCLE_STATE_ZERO');
  static const WearCircleState WEAR_CIRCLE_STATE_SKIPPED =
      WearCircleState._(7, _omitEnumNames ? '' : 'WEAR_CIRCLE_STATE_SKIPPED');

  static const $core.List<WearCircleState> values = <WearCircleState>[
    WEAR_CIRCLE_STATE_UNSPECIFIED,
    WEAR_CIRCLE_STATE_PENDING,
    WEAR_CIRCLE_STATE_NEXT,
    WEAR_CIRCLE_STATE_LIFTING,
    WEAR_CIRCLE_STATE_FULL,
    WEAR_CIRCLE_STATE_SHORT,
    WEAR_CIRCLE_STATE_ZERO,
    WEAR_CIRCLE_STATE_SKIPPED,
  ];

  static final $core.List<WearCircleState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static WearCircleState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WearCircleState._(super.value, super.name);
}

/// How a set went, in three words: what the banner and the watch ask.
class QuickAnswer extends $pb.ProtobufEnum {
  static const QuickAnswer QUICK_ANSWER_UNSPECIFIED =
      QuickAnswer._(0, _omitEnumNames ? '' : 'QUICK_ANSWER_UNSPECIFIED');

  /// Plenty left: a ramp jumps further; an effort target had room.
  static const QuickAnswer QUICK_ANSWER_EASY =
      QuickAnswer._(1, _omitEnumNames ? '' : 'QUICK_ANSWER_EASY');

  /// Nearly all out: a ramp is done; an effort target was about right.
  static const QuickAnswer QUICK_ANSWER_HARD =
      QuickAnswer._(2, _omitEnumNames ? '' : 'QUICK_ANSWER_HARD');

  /// Couldn't finish the reps: recorded as a miss.
  static const QuickAnswer QUICK_ANSWER_FAIL =
      QuickAnswer._(3, _omitEnumNames ? '' : 'QUICK_ANSWER_FAIL');

  static const $core.List<QuickAnswer> values = <QuickAnswer>[
    QUICK_ANSWER_UNSPECIFIED,
    QUICK_ANSWER_EASY,
    QUICK_ANSWER_HARD,
    QUICK_ANSWER_FAIL,
  ];

  static final $core.List<QuickAnswer?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static QuickAnswer? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const QuickAnswer._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
