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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'settings.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'settings.pbenum.dart';

class PlateColor extends $pb.GeneratedMessage {
  factory PlateColor({
    $core.double? weightKg,
    $core.String? hexColor,
  }) {
    final result = create();
    if (weightKg != null) result.weightKg = weightKg;
    if (hexColor != null) result.hexColor = hexColor;
    return result;
  }

  PlateColor._();

  factory PlateColor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlateColor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlateColor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'weightKg', fieldType: $pb.PbFieldType.OF)
    ..aOS(2, _omitFieldNames ? '' : 'hexColor')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlateColor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlateColor copyWith(void Function(PlateColor) updates) =>
      super.copyWith((message) => updates(message as PlateColor)) as PlateColor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlateColor create() => PlateColor._();
  @$core.override
  PlateColor createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlateColor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlateColor>(create);
  static PlateColor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get weightKg => $_getN(0);
  @$pb.TagNumber(1)
  set weightKg($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasWeightKg() => $_has(0);
  @$pb.TagNumber(1)
  void clearWeightKg() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get hexColor => $_getSZ(1);
  @$pb.TagNumber(2)
  set hexColor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHexColor() => $_has(1);
  @$pb.TagNumber(2)
  void clearHexColor() => $_clearField(2);
}

class PlateColorsConfig extends $pb.GeneratedMessage {
  factory PlateColorsConfig({
    $core.Iterable<PlateColor>? plates,
    $core.double? barWeightKg,
  }) {
    final result = create();
    if (plates != null) result.plates.addAll(plates);
    if (barWeightKg != null) result.barWeightKg = barWeightKg;
    return result;
  }

  PlateColorsConfig._();

  factory PlateColorsConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlateColorsConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlateColorsConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<PlateColor>(1, _omitFieldNames ? '' : 'plates',
        subBuilder: PlateColor.create)
    ..aD(2, _omitFieldNames ? '' : 'barWeightKg', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlateColorsConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlateColorsConfig copyWith(void Function(PlateColorsConfig) updates) =>
      super.copyWith((message) => updates(message as PlateColorsConfig))
          as PlateColorsConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlateColorsConfig create() => PlateColorsConfig._();
  @$core.override
  PlateColorsConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlateColorsConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlateColorsConfig>(create);
  static PlateColorsConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PlateColor> get plates => $_getList(0);

  @$pb.TagNumber(2)
  $core.double get barWeightKg => $_getN(1);
  @$pb.TagNumber(2)
  set barWeightKg($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBarWeightKg() => $_has(1);
  @$pb.TagNumber(2)
  void clearBarWeightKg() => $_clearField(2);
}

class WeightUnitConfig extends $pb.GeneratedMessage {
  factory WeightUnitConfig({
    WeightUnit? unit,
  }) {
    final result = create();
    if (unit != null) result.unit = unit;
    return result;
  }

  WeightUnitConfig._();

  factory WeightUnitConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WeightUnitConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WeightUnitConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<WeightUnit>(1, _omitFieldNames ? '' : 'unit',
        enumValues: WeightUnit.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeightUnitConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WeightUnitConfig copyWith(void Function(WeightUnitConfig) updates) =>
      super.copyWith((message) => updates(message as WeightUnitConfig))
          as WeightUnitConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WeightUnitConfig create() => WeightUnitConfig._();
  @$core.override
  WeightUnitConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WeightUnitConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WeightUnitConfig>(create);
  static WeightUnitConfig? _defaultInstance;

  @$pb.TagNumber(1)
  WeightUnit get unit => $_getN(0);
  @$pb.TagNumber(1)
  set unit(WeightUnit value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUnit() => $_has(0);
  @$pb.TagNumber(1)
  void clearUnit() => $_clearField(1);
}

class TrainingProgramAtAGlance extends $pb.GeneratedMessage {
  factory TrainingProgramAtAGlance({
    $core.String? daysPerWeek,
    $core.String? bestFor,
    $core.String? averageSessionTime,
    $core.String? progressionStyle,
  }) {
    final result = create();
    if (daysPerWeek != null) result.daysPerWeek = daysPerWeek;
    if (bestFor != null) result.bestFor = bestFor;
    if (averageSessionTime != null)
      result.averageSessionTime = averageSessionTime;
    if (progressionStyle != null) result.progressionStyle = progressionStyle;
    return result;
  }

  TrainingProgramAtAGlance._();

  factory TrainingProgramAtAGlance.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramAtAGlance.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramAtAGlance',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'daysPerWeek')
    ..aOS(2, _omitFieldNames ? '' : 'bestFor')
    ..aOS(3, _omitFieldNames ? '' : 'averageSessionTime')
    ..aOS(4, _omitFieldNames ? '' : 'progressionStyle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramAtAGlance clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramAtAGlance copyWith(
          void Function(TrainingProgramAtAGlance) updates) =>
      super.copyWith((message) => updates(message as TrainingProgramAtAGlance))
          as TrainingProgramAtAGlance;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramAtAGlance create() => TrainingProgramAtAGlance._();
  @$core.override
  TrainingProgramAtAGlance createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramAtAGlance getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramAtAGlance>(create);
  static TrainingProgramAtAGlance? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get daysPerWeek => $_getSZ(0);
  @$pb.TagNumber(1)
  set daysPerWeek($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDaysPerWeek() => $_has(0);
  @$pb.TagNumber(1)
  void clearDaysPerWeek() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get bestFor => $_getSZ(1);
  @$pb.TagNumber(2)
  set bestFor($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBestFor() => $_has(1);
  @$pb.TagNumber(2)
  void clearBestFor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get averageSessionTime => $_getSZ(2);
  @$pb.TagNumber(3)
  set averageSessionTime($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAverageSessionTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearAverageSessionTime() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get progressionStyle => $_getSZ(3);
  @$pb.TagNumber(4)
  set progressionStyle($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProgressionStyle() => $_has(3);
  @$pb.TagNumber(4)
  void clearProgressionStyle() => $_clearField(4);
}

class TrainingProgramLink extends $pb.GeneratedMessage {
  factory TrainingProgramLink({
    $core.String? label,
    $core.String? url,
  }) {
    final result = create();
    if (label != null) result.label = label;
    if (url != null) result.url = url;
    return result;
  }

  TrainingProgramLink._();

  factory TrainingProgramLink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramLink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramLink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramLink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramLink copyWith(void Function(TrainingProgramLink) updates) =>
      super.copyWith((message) => updates(message as TrainingProgramLink))
          as TrainingProgramLink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramLink create() => TrainingProgramLink._();
  @$core.override
  TrainingProgramLink createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramLink getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramLink>(create);
  static TrainingProgramLink? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);
}

/// Catalog definition for a training program (display/info only, no config fields).
class TrainingProgramDefinition extends $pb.GeneratedMessage {
  factory TrainingProgramDefinition({
    RegimeType? regimeType,
    $core.String? displayName,
    $core.String? headline,
    $core.String? summary,
    $core.String? description,
    $core.String? howItWorks,
    TrainingProgramAtAGlance? atAGlance,
    $core.Iterable<$core.String>? details,
    $core.Iterable<TrainingProgramLink>? learnMoreLinks,
    $core.int? sortOrder,
    TrainingProgramStateSchema? stateSchema,
  }) {
    final result = create();
    if (regimeType != null) result.regimeType = regimeType;
    if (displayName != null) result.displayName = displayName;
    if (headline != null) result.headline = headline;
    if (summary != null) result.summary = summary;
    if (description != null) result.description = description;
    if (howItWorks != null) result.howItWorks = howItWorks;
    if (atAGlance != null) result.atAGlance = atAGlance;
    if (details != null) result.details.addAll(details);
    if (learnMoreLinks != null) result.learnMoreLinks.addAll(learnMoreLinks);
    if (sortOrder != null) result.sortOrder = sortOrder;
    if (stateSchema != null) result.stateSchema = stateSchema;
    return result;
  }

  TrainingProgramDefinition._();

  factory TrainingProgramDefinition.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramDefinition.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramDefinition',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<RegimeType>(1, _omitFieldNames ? '' : 'regimeType',
        enumValues: RegimeType.values)
    ..aOS(2, _omitFieldNames ? '' : 'displayName')
    ..aOS(3, _omitFieldNames ? '' : 'headline')
    ..aOS(4, _omitFieldNames ? '' : 'summary')
    ..aOS(5, _omitFieldNames ? '' : 'description')
    ..aOS(6, _omitFieldNames ? '' : 'howItWorks')
    ..aOM<TrainingProgramAtAGlance>(7, _omitFieldNames ? '' : 'atAGlance',
        subBuilder: TrainingProgramAtAGlance.create)
    ..pPS(8, _omitFieldNames ? '' : 'details')
    ..pPM<TrainingProgramLink>(9, _omitFieldNames ? '' : 'learnMoreLinks',
        subBuilder: TrainingProgramLink.create)
    ..aI(11, _omitFieldNames ? '' : 'sortOrder')
    ..aOM<TrainingProgramStateSchema>(12, _omitFieldNames ? '' : 'stateSchema',
        subBuilder: TrainingProgramStateSchema.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramDefinition clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramDefinition copyWith(
          void Function(TrainingProgramDefinition) updates) =>
      super.copyWith((message) => updates(message as TrainingProgramDefinition))
          as TrainingProgramDefinition;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramDefinition create() => TrainingProgramDefinition._();
  @$core.override
  TrainingProgramDefinition createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramDefinition getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramDefinition>(create);
  static TrainingProgramDefinition? _defaultInstance;

  @$pb.TagNumber(1)
  RegimeType get regimeType => $_getN(0);
  @$pb.TagNumber(1)
  set regimeType(RegimeType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRegimeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegimeType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get displayName => $_getSZ(1);
  @$pb.TagNumber(2)
  set displayName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplayName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplayName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get headline => $_getSZ(2);
  @$pb.TagNumber(3)
  set headline($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeadline() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeadline() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get summary => $_getSZ(3);
  @$pb.TagNumber(4)
  set summary($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSummary() => $_has(3);
  @$pb.TagNumber(4)
  void clearSummary() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get description => $_getSZ(4);
  @$pb.TagNumber(5)
  set description($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDescription() => $_has(4);
  @$pb.TagNumber(5)
  void clearDescription() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get howItWorks => $_getSZ(5);
  @$pb.TagNumber(6)
  set howItWorks($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHowItWorks() => $_has(5);
  @$pb.TagNumber(6)
  void clearHowItWorks() => $_clearField(6);

  @$pb.TagNumber(7)
  TrainingProgramAtAGlance get atAGlance => $_getN(6);
  @$pb.TagNumber(7)
  set atAGlance(TrainingProgramAtAGlance value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasAtAGlance() => $_has(6);
  @$pb.TagNumber(7)
  void clearAtAGlance() => $_clearField(7);
  @$pb.TagNumber(7)
  TrainingProgramAtAGlance ensureAtAGlance() => $_ensure(6);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get details => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<TrainingProgramLink> get learnMoreLinks => $_getList(8);

  /// field 10 reserved (was config_fields)
  @$pb.TagNumber(11)
  $core.int get sortOrder => $_getIZ(9);
  @$pb.TagNumber(11)
  set sortOrder($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(11)
  $core.bool hasSortOrder() => $_has(9);
  @$pb.TagNumber(11)
  void clearSortOrder() => $_clearField(11);

  @$pb.TagNumber(12)
  TrainingProgramStateSchema get stateSchema => $_getN(10);
  @$pb.TagNumber(12)
  set stateSchema(TrainingProgramStateSchema value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasStateSchema() => $_has(10);
  @$pb.TagNumber(12)
  void clearStateSchema() => $_clearField(12);
  @$pb.TagNumber(12)
  TrainingProgramStateSchema ensureStateSchema() => $_ensure(10);
}

class StateEnumOption extends $pb.GeneratedMessage {
  factory StateEnumOption({
    $core.String? value,
    $core.String? label,
  }) {
    final result = create();
    if (value != null) result.value = value;
    if (label != null) result.label = label;
    return result;
  }

  StateEnumOption._();

  factory StateEnumOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StateEnumOption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StateEnumOption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StateEnumOption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StateEnumOption copyWith(void Function(StateEnumOption) updates) =>
      super.copyWith((message) => updates(message as StateEnumOption))
          as StateEnumOption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StateEnumOption create() => StateEnumOption._();
  @$core.override
  StateEnumOption createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StateEnumOption getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StateEnumOption>(create);
  static StateEnumOption? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);
}

/// Describes a single editable field in the program state.
class TrainingProgramStateFieldSchema extends $pb.GeneratedMessage {
  factory TrainingProgramStateFieldSchema({
    $core.String? key,
    $core.String? label,
    $core.String? helpText,
    $core.String? section,
    $core.int? order,
    StateFieldKind? kind,
    $core.bool? required,
    $core.double? minValue,
    $core.double? maxValue,
    $core.double? step,
    $core.Iterable<StateEnumOption>? enumOptions,
    $core.bool? onboardingField,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (label != null) result.label = label;
    if (helpText != null) result.helpText = helpText;
    if (section != null) result.section = section;
    if (order != null) result.order = order;
    if (kind != null) result.kind = kind;
    if (required != null) result.required = required;
    if (minValue != null) result.minValue = minValue;
    if (maxValue != null) result.maxValue = maxValue;
    if (step != null) result.step = step;
    if (enumOptions != null) result.enumOptions.addAll(enumOptions);
    if (onboardingField != null) result.onboardingField = onboardingField;
    return result;
  }

  TrainingProgramStateFieldSchema._();

  factory TrainingProgramStateFieldSchema.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramStateFieldSchema.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramStateFieldSchema',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'helpText')
    ..aOS(4, _omitFieldNames ? '' : 'section')
    ..aI(5, _omitFieldNames ? '' : 'order')
    ..aE<StateFieldKind>(6, _omitFieldNames ? '' : 'kind',
        enumValues: StateFieldKind.values)
    ..aOB(7, _omitFieldNames ? '' : 'required')
    ..aD(8, _omitFieldNames ? '' : 'minValue')
    ..aD(9, _omitFieldNames ? '' : 'maxValue')
    ..aD(10, _omitFieldNames ? '' : 'step')
    ..pPM<StateEnumOption>(11, _omitFieldNames ? '' : 'enumOptions',
        subBuilder: StateEnumOption.create)
    ..aOB(12, _omitFieldNames ? '' : 'onboardingField')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramStateFieldSchema clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramStateFieldSchema copyWith(
          void Function(TrainingProgramStateFieldSchema) updates) =>
      super.copyWith(
              (message) => updates(message as TrainingProgramStateFieldSchema))
          as TrainingProgramStateFieldSchema;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramStateFieldSchema create() =>
      TrainingProgramStateFieldSchema._();
  @$core.override
  TrainingProgramStateFieldSchema createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramStateFieldSchema getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramStateFieldSchema>(
          create);
  static TrainingProgramStateFieldSchema? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get helpText => $_getSZ(2);
  @$pb.TagNumber(3)
  set helpText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHelpText() => $_has(2);
  @$pb.TagNumber(3)
  void clearHelpText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get section => $_getSZ(3);
  @$pb.TagNumber(4)
  set section($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSection() => $_has(3);
  @$pb.TagNumber(4)
  void clearSection() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get order => $_getIZ(4);
  @$pb.TagNumber(5)
  set order($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOrder() => $_has(4);
  @$pb.TagNumber(5)
  void clearOrder() => $_clearField(5);

  @$pb.TagNumber(6)
  StateFieldKind get kind => $_getN(5);
  @$pb.TagNumber(6)
  set kind(StateFieldKind value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasKind() => $_has(5);
  @$pb.TagNumber(6)
  void clearKind() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get required => $_getBF(6);
  @$pb.TagNumber(7)
  set required($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRequired() => $_has(6);
  @$pb.TagNumber(7)
  void clearRequired() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get minValue => $_getN(7);
  @$pb.TagNumber(8)
  set minValue($core.double value) => $_setDouble(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMinValue() => $_has(7);
  @$pb.TagNumber(8)
  void clearMinValue() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.double get maxValue => $_getN(8);
  @$pb.TagNumber(9)
  set maxValue($core.double value) => $_setDouble(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMaxValue() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaxValue() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.double get step => $_getN(9);
  @$pb.TagNumber(10)
  set step($core.double value) => $_setDouble(9, value);
  @$pb.TagNumber(10)
  $core.bool hasStep() => $_has(9);
  @$pb.TagNumber(10)
  void clearStep() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<StateEnumOption> get enumOptions => $_getList(10);

  @$pb.TagNumber(12)
  $core.bool get onboardingField => $_getBF(11);
  @$pb.TagNumber(12)
  set onboardingField($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasOnboardingField() => $_has(11);
  @$pb.TagNumber(12)
  void clearOnboardingField() => $_clearField(12);
}

class TrainingProgramStateSchema extends $pb.GeneratedMessage {
  factory TrainingProgramStateSchema({
    $core.Iterable<TrainingProgramStateFieldSchema>? fields,
  }) {
    final result = create();
    if (fields != null) result.fields.addAll(fields);
    return result;
  }

  TrainingProgramStateSchema._();

  factory TrainingProgramStateSchema.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramStateSchema.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramStateSchema',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<TrainingProgramStateFieldSchema>(1, _omitFieldNames ? '' : 'fields',
        subBuilder: TrainingProgramStateFieldSchema.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramStateSchema clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramStateSchema copyWith(
          void Function(TrainingProgramStateSchema) updates) =>
      super.copyWith(
              (message) => updates(message as TrainingProgramStateSchema))
          as TrainingProgramStateSchema;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramStateSchema create() => TrainingProgramStateSchema._();
  @$core.override
  TrainingProgramStateSchema createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramStateSchema getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramStateSchema>(create);
  static TrainingProgramStateSchema? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TrainingProgramStateFieldSchema> get fields => $_getList(0);
}

enum StateFieldValue_Value { intVal, floatVal, boolVal, stringVal, notSet }

/// Typed value for a state field. Only one of the oneof members will be set.
class StateFieldValue extends $pb.GeneratedMessage {
  factory StateFieldValue({
    $fixnum.Int64? intVal,
    $core.double? floatVal,
    $core.bool? boolVal,
    $core.String? stringVal,
  }) {
    final result = create();
    if (intVal != null) result.intVal = intVal;
    if (floatVal != null) result.floatVal = floatVal;
    if (boolVal != null) result.boolVal = boolVal;
    if (stringVal != null) result.stringVal = stringVal;
    return result;
  }

  StateFieldValue._();

  factory StateFieldValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StateFieldValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, StateFieldValue_Value>
      _StateFieldValue_ValueByTag = {
    1: StateFieldValue_Value.intVal,
    2: StateFieldValue_Value.floatVal,
    3: StateFieldValue_Value.boolVal,
    4: StateFieldValue_Value.stringVal,
    0: StateFieldValue_Value.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StateFieldValue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4])
    ..aInt64(1, _omitFieldNames ? '' : 'intVal')
    ..aD(2, _omitFieldNames ? '' : 'floatVal')
    ..aOB(3, _omitFieldNames ? '' : 'boolVal')
    ..aOS(4, _omitFieldNames ? '' : 'stringVal')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StateFieldValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StateFieldValue copyWith(void Function(StateFieldValue) updates) =>
      super.copyWith((message) => updates(message as StateFieldValue))
          as StateFieldValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StateFieldValue create() => StateFieldValue._();
  @$core.override
  StateFieldValue createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StateFieldValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StateFieldValue>(create);
  static StateFieldValue? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  StateFieldValue_Value whichValue() =>
      _StateFieldValue_ValueByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearValue() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get intVal => $_getI64(0);
  @$pb.TagNumber(1)
  set intVal($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIntVal() => $_has(0);
  @$pb.TagNumber(1)
  void clearIntVal() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get floatVal => $_getN(1);
  @$pb.TagNumber(2)
  set floatVal($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFloatVal() => $_has(1);
  @$pb.TagNumber(2)
  void clearFloatVal() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get boolVal => $_getBF(2);
  @$pb.TagNumber(3)
  set boolVal($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBoolVal() => $_has(2);
  @$pb.TagNumber(3)
  void clearBoolVal() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get stringVal => $_getSZ(3);
  @$pb.TagNumber(4)
  set stringVal($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStringVal() => $_has(3);
  @$pb.TagNumber(4)
  void clearStringVal() => $_clearField(4);
}

/// Current (latest) state snapshot for the active training program.
class TrainingProgramState extends $pb.GeneratedMessage {
  factory TrainingProgramState({
    RegimeType? regimeType,
    $core.Iterable<$core.MapEntry<$core.String, StateFieldValue>>? fields,
    $fixnum.Int64? updatedAt,
    $core.String? source,
  }) {
    final result = create();
    if (regimeType != null) result.regimeType = regimeType;
    if (fields != null) result.fields.addEntries(fields);
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (source != null) result.source = source;
    return result;
  }

  TrainingProgramState._();

  factory TrainingProgramState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<RegimeType>(1, _omitFieldNames ? '' : 'regimeType',
        enumValues: RegimeType.values)
    ..m<$core.String, StateFieldValue>(2, _omitFieldNames ? '' : 'fields',
        entryClassName: 'TrainingProgramState.FieldsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: StateFieldValue.create,
        valueDefaultOrMaker: StateFieldValue.getDefault,
        packageName: const $pb.PackageName('workout.v1'))
    ..aInt64(3, _omitFieldNames ? '' : 'updatedAt')
    ..aOS(4, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramState copyWith(void Function(TrainingProgramState) updates) =>
      super.copyWith((message) => updates(message as TrainingProgramState))
          as TrainingProgramState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramState create() => TrainingProgramState._();
  @$core.override
  TrainingProgramState createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramState>(create);
  static TrainingProgramState? _defaultInstance;

  @$pb.TagNumber(1)
  RegimeType get regimeType => $_getN(0);
  @$pb.TagNumber(1)
  set regimeType(RegimeType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRegimeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegimeType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, StateFieldValue> get fields => $_getMap(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get updatedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set updatedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUpdatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpdatedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get source => $_getSZ(3);
  @$pb.TagNumber(4)
  set source($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSource() => $_has(3);
  @$pb.TagNumber(4)
  void clearSource() => $_clearField(4);
}

/// Historised event — append-only log of all state changes.
class TrainingProgramStateEvent extends $pb.GeneratedMessage {
  factory TrainingProgramStateEvent({
    $core.String? eventId,
    RegimeType? regimeType,
    $fixnum.Int64? effectiveAt,
    $fixnum.Int64? recordedAt,
    $core.String? source,
    $core.Iterable<$core.MapEntry<$core.String, StateFieldValue>>? fields,
    $core.String? sourceWorkoutId,
  }) {
    final result = create();
    if (eventId != null) result.eventId = eventId;
    if (regimeType != null) result.regimeType = regimeType;
    if (effectiveAt != null) result.effectiveAt = effectiveAt;
    if (recordedAt != null) result.recordedAt = recordedAt;
    if (source != null) result.source = source;
    if (fields != null) result.fields.addEntries(fields);
    if (sourceWorkoutId != null) result.sourceWorkoutId = sourceWorkoutId;
    return result;
  }

  TrainingProgramStateEvent._();

  factory TrainingProgramStateEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramStateEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramStateEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'eventId')
    ..aE<RegimeType>(2, _omitFieldNames ? '' : 'regimeType',
        enumValues: RegimeType.values)
    ..aInt64(3, _omitFieldNames ? '' : 'effectiveAt')
    ..aInt64(4, _omitFieldNames ? '' : 'recordedAt')
    ..aOS(5, _omitFieldNames ? '' : 'source')
    ..m<$core.String, StateFieldValue>(6, _omitFieldNames ? '' : 'fields',
        entryClassName: 'TrainingProgramStateEvent.FieldsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: StateFieldValue.create,
        valueDefaultOrMaker: StateFieldValue.getDefault,
        packageName: const $pb.PackageName('workout.v1'))
    ..aOS(7, _omitFieldNames ? '' : 'sourceWorkoutId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramStateEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramStateEvent copyWith(
          void Function(TrainingProgramStateEvent) updates) =>
      super.copyWith((message) => updates(message as TrainingProgramStateEvent))
          as TrainingProgramStateEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramStateEvent create() => TrainingProgramStateEvent._();
  @$core.override
  TrainingProgramStateEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramStateEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramStateEvent>(create);
  static TrainingProgramStateEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);

  @$pb.TagNumber(2)
  RegimeType get regimeType => $_getN(1);
  @$pb.TagNumber(2)
  set regimeType(RegimeType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasRegimeType() => $_has(1);
  @$pb.TagNumber(2)
  void clearRegimeType() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get effectiveAt => $_getI64(2);
  @$pb.TagNumber(3)
  set effectiveAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEffectiveAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearEffectiveAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get recordedAt => $_getI64(3);
  @$pb.TagNumber(4)
  set recordedAt($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRecordedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearRecordedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get source => $_getSZ(4);
  @$pb.TagNumber(5)
  set source($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSource() => $_has(4);
  @$pb.TagNumber(5)
  void clearSource() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbMap<$core.String, StateFieldValue> get fields => $_getMap(5);

  @$pb.TagNumber(7)
  $core.String get sourceWorkoutId => $_getSZ(6);
  @$pb.TagNumber(7)
  set sourceWorkoutId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSourceWorkoutId() => $_has(6);
  @$pb.TagNumber(7)
  void clearSourceWorkoutId() => $_clearField(7);
}

/// A single input field in a pending update (e.g., "deload percent").
class PendingStateUpdateField extends $pb.GeneratedMessage {
  factory PendingStateUpdateField({
    $core.String? key,
    $core.String? label,
    StateFieldKind? kind,
    StateFieldValue? defaultValue,
    $core.double? minValue,
    $core.double? maxValue,
    $core.double? step,
    $core.Iterable<StateEnumOption>? enumOptions,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (label != null) result.label = label;
    if (kind != null) result.kind = kind;
    if (defaultValue != null) result.defaultValue = defaultValue;
    if (minValue != null) result.minValue = minValue;
    if (maxValue != null) result.maxValue = maxValue;
    if (step != null) result.step = step;
    if (enumOptions != null) result.enumOptions.addAll(enumOptions);
    return result;
  }

  PendingStateUpdateField._();

  factory PendingStateUpdateField.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PendingStateUpdateField.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PendingStateUpdateField',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aE<StateFieldKind>(3, _omitFieldNames ? '' : 'kind',
        enumValues: StateFieldKind.values)
    ..aOM<StateFieldValue>(4, _omitFieldNames ? '' : 'defaultValue',
        subBuilder: StateFieldValue.create)
    ..aD(5, _omitFieldNames ? '' : 'minValue')
    ..aD(6, _omitFieldNames ? '' : 'maxValue')
    ..aD(7, _omitFieldNames ? '' : 'step')
    ..pPM<StateEnumOption>(8, _omitFieldNames ? '' : 'enumOptions',
        subBuilder: StateEnumOption.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PendingStateUpdateField clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PendingStateUpdateField copyWith(
          void Function(PendingStateUpdateField) updates) =>
      super.copyWith((message) => updates(message as PendingStateUpdateField))
          as PendingStateUpdateField;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PendingStateUpdateField create() => PendingStateUpdateField._();
  @$core.override
  PendingStateUpdateField createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PendingStateUpdateField getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PendingStateUpdateField>(create);
  static PendingStateUpdateField? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  StateFieldKind get kind => $_getN(2);
  @$pb.TagNumber(3)
  set kind(StateFieldKind value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  @$pb.TagNumber(4)
  StateFieldValue get defaultValue => $_getN(3);
  @$pb.TagNumber(4)
  set defaultValue(StateFieldValue value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDefaultValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearDefaultValue() => $_clearField(4);
  @$pb.TagNumber(4)
  StateFieldValue ensureDefaultValue() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.double get minValue => $_getN(4);
  @$pb.TagNumber(5)
  set minValue($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMinValue() => $_has(4);
  @$pb.TagNumber(5)
  void clearMinValue() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get maxValue => $_getN(5);
  @$pb.TagNumber(6)
  set maxValue($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMaxValue() => $_has(5);
  @$pb.TagNumber(6)
  void clearMaxValue() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get step => $_getN(6);
  @$pb.TagNumber(7)
  set step($core.double value) => $_setDouble(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStep() => $_has(6);
  @$pb.TagNumber(7)
  void clearStep() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<StateEnumOption> get enumOptions => $_getList(7);
}

/// A pending recommendation that blocks workout start until resolved.
/// Rendered entirely by backend — frontend shows fields dynamically.
class PendingStateUpdate extends $pb.GeneratedMessage {
  factory PendingStateUpdate({
    $core.String? updateId,
    $core.String? title,
    $core.String? message,
    $core.Iterable<PendingStateUpdateField>? fields,
  }) {
    final result = create();
    if (updateId != null) result.updateId = updateId;
    if (title != null) result.title = title;
    if (message != null) result.message = message;
    if (fields != null) result.fields.addAll(fields);
    return result;
  }

  PendingStateUpdate._();

  factory PendingStateUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PendingStateUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PendingStateUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'updateId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..pPM<PendingStateUpdateField>(4, _omitFieldNames ? '' : 'fields',
        subBuilder: PendingStateUpdateField.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PendingStateUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PendingStateUpdate copyWith(void Function(PendingStateUpdate) updates) =>
      super.copyWith((message) => updates(message as PendingStateUpdate))
          as PendingStateUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PendingStateUpdate create() => PendingStateUpdate._();
  @$core.override
  PendingStateUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PendingStateUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PendingStateUpdate>(create);
  static PendingStateUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get updateId => $_getSZ(0);
  @$pb.TagNumber(1)
  set updateId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUpdateId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpdateId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<PendingStateUpdateField> get fields => $_getList(3);
}

enum UserSetting_Setting { plateColors, weightUnit, notSet }

class UserSetting extends $pb.GeneratedMessage {
  factory UserSetting({
    PlateColorsConfig? plateColors,
    WeightUnitConfig? weightUnit,
  }) {
    final result = create();
    if (plateColors != null) result.plateColors = plateColors;
    if (weightUnit != null) result.weightUnit = weightUnit;
    return result;
  }

  UserSetting._();

  factory UserSetting.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserSetting.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, UserSetting_Setting>
      _UserSetting_SettingByTag = {
    10: UserSetting_Setting.plateColors,
    12: UserSetting_Setting.weightUnit,
    0: UserSetting_Setting.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserSetting',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 12])
    ..aOM<PlateColorsConfig>(10, _omitFieldNames ? '' : 'plateColors',
        subBuilder: PlateColorsConfig.create)
    ..aOM<WeightUnitConfig>(12, _omitFieldNames ? '' : 'weightUnit',
        subBuilder: WeightUnitConfig.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserSetting clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserSetting copyWith(void Function(UserSetting) updates) =>
      super.copyWith((message) => updates(message as UserSetting))
          as UserSetting;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserSetting create() => UserSetting._();
  @$core.override
  UserSetting createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserSetting getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserSetting>(create);
  static UserSetting? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(12)
  UserSetting_Setting whichSetting() =>
      _UserSetting_SettingByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(12)
  void clearSetting() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(10)
  PlateColorsConfig get plateColors => $_getN(0);
  @$pb.TagNumber(10)
  set plateColors(PlateColorsConfig value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasPlateColors() => $_has(0);
  @$pb.TagNumber(10)
  void clearPlateColors() => $_clearField(10);
  @$pb.TagNumber(10)
  PlateColorsConfig ensurePlateColors() => $_ensure(0);

  @$pb.TagNumber(12)
  WeightUnitConfig get weightUnit => $_getN(1);
  @$pb.TagNumber(12)
  set weightUnit(WeightUnitConfig value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasWeightUnit() => $_has(1);
  @$pb.TagNumber(12)
  void clearWeightUnit() => $_clearField(12);
  @$pb.TagNumber(12)
  WeightUnitConfig ensureWeightUnit() => $_ensure(1);
}

class UpdateSettingRequest extends $pb.GeneratedMessage {
  factory UpdateSettingRequest({
    UserSetting? setting,
  }) {
    final result = create();
    if (setting != null) result.setting = setting;
    return result;
  }

  UpdateSettingRequest._();

  factory UpdateSettingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSettingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSettingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<UserSetting>(1, _omitFieldNames ? '' : 'setting',
        subBuilder: UserSetting.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSettingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSettingRequest copyWith(void Function(UpdateSettingRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateSettingRequest))
          as UpdateSettingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSettingRequest create() => UpdateSettingRequest._();
  @$core.override
  UpdateSettingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSettingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSettingRequest>(create);
  static UpdateSettingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  UserSetting get setting => $_getN(0);
  @$pb.TagNumber(1)
  set setting(UserSetting value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSetting() => $_has(0);
  @$pb.TagNumber(1)
  void clearSetting() => $_clearField(1);
  @$pb.TagNumber(1)
  UserSetting ensureSetting() => $_ensure(0);
}

class UpdateSettingResponse extends $pb.GeneratedMessage {
  factory UpdateSettingResponse() => create();

  UpdateSettingResponse._();

  factory UpdateSettingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateSettingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSettingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSettingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSettingResponse copyWith(
          void Function(UpdateSettingResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateSettingResponse))
          as UpdateSettingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateSettingResponse create() => UpdateSettingResponse._();
  @$core.override
  UpdateSettingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateSettingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSettingResponse>(create);
  static UpdateSettingResponse? _defaultInstance;
}

class GetSettingsRequest extends $pb.GeneratedMessage {
  factory GetSettingsRequest() => create();

  GetSettingsRequest._();

  factory GetSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsRequest copyWith(void Function(GetSettingsRequest) updates) =>
      super.copyWith((message) => updates(message as GetSettingsRequest))
          as GetSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSettingsRequest create() => GetSettingsRequest._();
  @$core.override
  GetSettingsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSettingsRequest>(create);
  static GetSettingsRequest? _defaultInstance;
}

class GetSettingsResponse extends $pb.GeneratedMessage {
  factory GetSettingsResponse({
    $core.Iterable<UserSetting>? settings,
  }) {
    final result = create();
    if (settings != null) result.settings.addAll(settings);
    return result;
  }

  GetSettingsResponse._();

  factory GetSettingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSettingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSettingsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<UserSetting>(1, _omitFieldNames ? '' : 'settings',
        subBuilder: UserSetting.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsResponse copyWith(void Function(GetSettingsResponse) updates) =>
      super.copyWith((message) => updates(message as GetSettingsResponse))
          as GetSettingsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSettingsResponse create() => GetSettingsResponse._();
  @$core.override
  GetSettingsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSettingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSettingsResponse>(create);
  static GetSettingsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<UserSetting> get settings => $_getList(0);
}

class GetTrainingProgramCatalogRequest extends $pb.GeneratedMessage {
  factory GetTrainingProgramCatalogRequest() => create();

  GetTrainingProgramCatalogRequest._();

  factory GetTrainingProgramCatalogRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTrainingProgramCatalogRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTrainingProgramCatalogRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingProgramCatalogRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingProgramCatalogRequest copyWith(
          void Function(GetTrainingProgramCatalogRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetTrainingProgramCatalogRequest))
          as GetTrainingProgramCatalogRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTrainingProgramCatalogRequest create() =>
      GetTrainingProgramCatalogRequest._();
  @$core.override
  GetTrainingProgramCatalogRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTrainingProgramCatalogRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTrainingProgramCatalogRequest>(
          create);
  static GetTrainingProgramCatalogRequest? _defaultInstance;
}

class GetTrainingProgramCatalogResponse extends $pb.GeneratedMessage {
  factory GetTrainingProgramCatalogResponse({
    $core.Iterable<TrainingProgramDefinition>? programs,
  }) {
    final result = create();
    if (programs != null) result.programs.addAll(programs);
    return result;
  }

  GetTrainingProgramCatalogResponse._();

  factory GetTrainingProgramCatalogResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTrainingProgramCatalogResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTrainingProgramCatalogResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<TrainingProgramDefinition>(1, _omitFieldNames ? '' : 'programs',
        subBuilder: TrainingProgramDefinition.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingProgramCatalogResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingProgramCatalogResponse copyWith(
          void Function(GetTrainingProgramCatalogResponse) updates) =>
      super.copyWith((message) =>
              updates(message as GetTrainingProgramCatalogResponse))
          as GetTrainingProgramCatalogResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTrainingProgramCatalogResponse create() =>
      GetTrainingProgramCatalogResponse._();
  @$core.override
  GetTrainingProgramCatalogResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTrainingProgramCatalogResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTrainingProgramCatalogResponse>(
          create);
  static GetTrainingProgramCatalogResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TrainingProgramDefinition> get programs => $_getList(0);
}

class GetActiveTrainingProgramStateRequest extends $pb.GeneratedMessage {
  factory GetActiveTrainingProgramStateRequest() => create();

  GetActiveTrainingProgramStateRequest._();

  factory GetActiveTrainingProgramStateRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetActiveTrainingProgramStateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetActiveTrainingProgramStateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveTrainingProgramStateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveTrainingProgramStateRequest copyWith(
          void Function(GetActiveTrainingProgramStateRequest) updates) =>
      super.copyWith((message) =>
              updates(message as GetActiveTrainingProgramStateRequest))
          as GetActiveTrainingProgramStateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetActiveTrainingProgramStateRequest create() =>
      GetActiveTrainingProgramStateRequest._();
  @$core.override
  GetActiveTrainingProgramStateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetActiveTrainingProgramStateRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetActiveTrainingProgramStateRequest>(create);
  static GetActiveTrainingProgramStateRequest? _defaultInstance;
}

class GetActiveTrainingProgramStateResponse extends $pb.GeneratedMessage {
  factory GetActiveTrainingProgramStateResponse({
    TrainingProgramState? state,
    TrainingProgramStateSchema? schema,
  }) {
    final result = create();
    if (state != null) result.state = state;
    if (schema != null) result.schema = schema;
    return result;
  }

  GetActiveTrainingProgramStateResponse._();

  factory GetActiveTrainingProgramStateResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetActiveTrainingProgramStateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetActiveTrainingProgramStateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<TrainingProgramState>(1, _omitFieldNames ? '' : 'state',
        subBuilder: TrainingProgramState.create)
    ..aOM<TrainingProgramStateSchema>(2, _omitFieldNames ? '' : 'schema',
        subBuilder: TrainingProgramStateSchema.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveTrainingProgramStateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetActiveTrainingProgramStateResponse copyWith(
          void Function(GetActiveTrainingProgramStateResponse) updates) =>
      super.copyWith((message) =>
              updates(message as GetActiveTrainingProgramStateResponse))
          as GetActiveTrainingProgramStateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetActiveTrainingProgramStateResponse create() =>
      GetActiveTrainingProgramStateResponse._();
  @$core.override
  GetActiveTrainingProgramStateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetActiveTrainingProgramStateResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetActiveTrainingProgramStateResponse>(create);
  static GetActiveTrainingProgramStateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TrainingProgramState get state => $_getN(0);
  @$pb.TagNumber(1)
  set state(TrainingProgramState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);
  @$pb.TagNumber(1)
  TrainingProgramState ensureState() => $_ensure(0);

  @$pb.TagNumber(2)
  TrainingProgramStateSchema get schema => $_getN(1);
  @$pb.TagNumber(2)
  set schema(TrainingProgramStateSchema value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSchema() => $_has(1);
  @$pb.TagNumber(2)
  void clearSchema() => $_clearField(2);
  @$pb.TagNumber(2)
  TrainingProgramStateSchema ensureSchema() => $_ensure(1);
}

class SetActiveTrainingProgramStateRequest extends $pb.GeneratedMessage {
  factory SetActiveTrainingProgramStateRequest({
    RegimeType? regimeType,
    $core.Iterable<$core.MapEntry<$core.String, StateFieldValue>>? fields,
    $core.String? source,
  }) {
    final result = create();
    if (regimeType != null) result.regimeType = regimeType;
    if (fields != null) result.fields.addEntries(fields);
    if (source != null) result.source = source;
    return result;
  }

  SetActiveTrainingProgramStateRequest._();

  factory SetActiveTrainingProgramStateRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetActiveTrainingProgramStateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetActiveTrainingProgramStateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<RegimeType>(1, _omitFieldNames ? '' : 'regimeType',
        enumValues: RegimeType.values)
    ..m<$core.String, StateFieldValue>(2, _omitFieldNames ? '' : 'fields',
        entryClassName: 'SetActiveTrainingProgramStateRequest.FieldsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: StateFieldValue.create,
        valueDefaultOrMaker: StateFieldValue.getDefault,
        packageName: const $pb.PackageName('workout.v1'))
    ..aOS(3, _omitFieldNames ? '' : 'source')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetActiveTrainingProgramStateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetActiveTrainingProgramStateRequest copyWith(
          void Function(SetActiveTrainingProgramStateRequest) updates) =>
      super.copyWith((message) =>
              updates(message as SetActiveTrainingProgramStateRequest))
          as SetActiveTrainingProgramStateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetActiveTrainingProgramStateRequest create() =>
      SetActiveTrainingProgramStateRequest._();
  @$core.override
  SetActiveTrainingProgramStateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetActiveTrainingProgramStateRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          SetActiveTrainingProgramStateRequest>(create);
  static SetActiveTrainingProgramStateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  RegimeType get regimeType => $_getN(0);
  @$pb.TagNumber(1)
  set regimeType(RegimeType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRegimeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegimeType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, StateFieldValue> get fields => $_getMap(1);

  @$pb.TagNumber(3)
  $core.String get source => $_getSZ(2);
  @$pb.TagNumber(3)
  set source($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSource() => $_has(2);
  @$pb.TagNumber(3)
  void clearSource() => $_clearField(3);
}

class SetActiveTrainingProgramStateResponse extends $pb.GeneratedMessage {
  factory SetActiveTrainingProgramStateResponse({
    TrainingProgramState? state,
    $core.Iterable<$core.String>? validationWarnings,
  }) {
    final result = create();
    if (state != null) result.state = state;
    if (validationWarnings != null)
      result.validationWarnings.addAll(validationWarnings);
    return result;
  }

  SetActiveTrainingProgramStateResponse._();

  factory SetActiveTrainingProgramStateResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SetActiveTrainingProgramStateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetActiveTrainingProgramStateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<TrainingProgramState>(1, _omitFieldNames ? '' : 'state',
        subBuilder: TrainingProgramState.create)
    ..pPS(2, _omitFieldNames ? '' : 'validationWarnings')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetActiveTrainingProgramStateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetActiveTrainingProgramStateResponse copyWith(
          void Function(SetActiveTrainingProgramStateResponse) updates) =>
      super.copyWith((message) =>
              updates(message as SetActiveTrainingProgramStateResponse))
          as SetActiveTrainingProgramStateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetActiveTrainingProgramStateResponse create() =>
      SetActiveTrainingProgramStateResponse._();
  @$core.override
  SetActiveTrainingProgramStateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SetActiveTrainingProgramStateResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          SetActiveTrainingProgramStateResponse>(create);
  static SetActiveTrainingProgramStateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TrainingProgramState get state => $_getN(0);
  @$pb.TagNumber(1)
  set state(TrainingProgramState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);
  @$pb.TagNumber(1)
  TrainingProgramState ensureState() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get validationWarnings => $_getList(1);
}

class GetTrainingProgramStateHistoryRequest extends $pb.GeneratedMessage {
  factory GetTrainingProgramStateHistoryRequest() => create();

  GetTrainingProgramStateHistoryRequest._();

  factory GetTrainingProgramStateHistoryRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTrainingProgramStateHistoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTrainingProgramStateHistoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingProgramStateHistoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingProgramStateHistoryRequest copyWith(
          void Function(GetTrainingProgramStateHistoryRequest) updates) =>
      super.copyWith((message) =>
              updates(message as GetTrainingProgramStateHistoryRequest))
          as GetTrainingProgramStateHistoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTrainingProgramStateHistoryRequest create() =>
      GetTrainingProgramStateHistoryRequest._();
  @$core.override
  GetTrainingProgramStateHistoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTrainingProgramStateHistoryRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetTrainingProgramStateHistoryRequest>(create);
  static GetTrainingProgramStateHistoryRequest? _defaultInstance;
}

class GetTrainingProgramStateHistoryResponse extends $pb.GeneratedMessage {
  factory GetTrainingProgramStateHistoryResponse({
    $core.Iterable<TrainingProgramStateEvent>? events,
  }) {
    final result = create();
    if (events != null) result.events.addAll(events);
    return result;
  }

  GetTrainingProgramStateHistoryResponse._();

  factory GetTrainingProgramStateHistoryResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTrainingProgramStateHistoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTrainingProgramStateHistoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<TrainingProgramStateEvent>(1, _omitFieldNames ? '' : 'events',
        subBuilder: TrainingProgramStateEvent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingProgramStateHistoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingProgramStateHistoryResponse copyWith(
          void Function(GetTrainingProgramStateHistoryResponse) updates) =>
      super.copyWith((message) =>
              updates(message as GetTrainingProgramStateHistoryResponse))
          as GetTrainingProgramStateHistoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTrainingProgramStateHistoryResponse create() =>
      GetTrainingProgramStateHistoryResponse._();
  @$core.override
  GetTrainingProgramStateHistoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTrainingProgramStateHistoryResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          GetTrainingProgramStateHistoryResponse>(create);
  static GetTrainingProgramStateHistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TrainingProgramStateEvent> get events => $_getList(0);
}

class ApplyPendingStateUpdateRequest extends $pb.GeneratedMessage {
  factory ApplyPendingStateUpdateRequest({
    $core.String? updateId,
    $core.Iterable<$core.MapEntry<$core.String, StateFieldValue>>? fieldValues,
  }) {
    final result = create();
    if (updateId != null) result.updateId = updateId;
    if (fieldValues != null) result.fieldValues.addEntries(fieldValues);
    return result;
  }

  ApplyPendingStateUpdateRequest._();

  factory ApplyPendingStateUpdateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ApplyPendingStateUpdateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApplyPendingStateUpdateRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'updateId')
    ..m<$core.String, StateFieldValue>(2, _omitFieldNames ? '' : 'fieldValues',
        entryClassName: 'ApplyPendingStateUpdateRequest.FieldValuesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: StateFieldValue.create,
        valueDefaultOrMaker: StateFieldValue.getDefault,
        packageName: const $pb.PackageName('workout.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyPendingStateUpdateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyPendingStateUpdateRequest copyWith(
          void Function(ApplyPendingStateUpdateRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ApplyPendingStateUpdateRequest))
          as ApplyPendingStateUpdateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ApplyPendingStateUpdateRequest create() =>
      ApplyPendingStateUpdateRequest._();
  @$core.override
  ApplyPendingStateUpdateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ApplyPendingStateUpdateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ApplyPendingStateUpdateRequest>(create);
  static ApplyPendingStateUpdateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get updateId => $_getSZ(0);
  @$pb.TagNumber(1)
  set updateId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUpdateId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpdateId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, StateFieldValue> get fieldValues => $_getMap(1);
}

class ApplyPendingStateUpdateResponse extends $pb.GeneratedMessage {
  factory ApplyPendingStateUpdateResponse({
    TrainingProgramState? state,
  }) {
    final result = create();
    if (state != null) result.state = state;
    return result;
  }

  ApplyPendingStateUpdateResponse._();

  factory ApplyPendingStateUpdateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ApplyPendingStateUpdateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApplyPendingStateUpdateResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<TrainingProgramState>(1, _omitFieldNames ? '' : 'state',
        subBuilder: TrainingProgramState.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyPendingStateUpdateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApplyPendingStateUpdateResponse copyWith(
          void Function(ApplyPendingStateUpdateResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ApplyPendingStateUpdateResponse))
          as ApplyPendingStateUpdateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ApplyPendingStateUpdateResponse create() =>
      ApplyPendingStateUpdateResponse._();
  @$core.override
  ApplyPendingStateUpdateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ApplyPendingStateUpdateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ApplyPendingStateUpdateResponse>(
          create);
  static ApplyPendingStateUpdateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TrainingProgramState get state => $_getN(0);
  @$pb.TagNumber(1)
  set state(TrainingProgramState value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);
  @$pb.TagNumber(1)
  TrainingProgramState ensureState() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
