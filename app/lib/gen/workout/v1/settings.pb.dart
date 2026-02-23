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

class TrainingProgramIntChoice extends $pb.GeneratedMessage {
  factory TrainingProgramIntChoice({
    $core.int? value,
    $core.String? label,
  }) {
    final result = create();
    if (value != null) result.value = value;
    if (label != null) result.label = label;
    return result;
  }

  TrainingProgramIntChoice._();

  factory TrainingProgramIntChoice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramIntChoice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramIntChoice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'value')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramIntChoice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramIntChoice copyWith(
          void Function(TrainingProgramIntChoice) updates) =>
      super.copyWith((message) => updates(message as TrainingProgramIntChoice))
          as TrainingProgramIntChoice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramIntChoice create() => TrainingProgramIntChoice._();
  @$core.override
  TrainingProgramIntChoice createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramIntChoice getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramIntChoice>(create);
  static TrainingProgramIntChoice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get value => $_getIZ(0);
  @$pb.TagNumber(1)
  set value($core.int value) => $_setSignedInt32(0, value);
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

class TrainingProgramConfigField extends $pb.GeneratedMessage {
  factory TrainingProgramConfigField({
    $core.String? key,
    $core.String? label,
    $core.String? helpText,
    TrainingProgramFieldKind? kind,
    TrainingProgramFieldBinding? binding,
    $core.bool? required,
    $core.int? defaultInt32,
    $core.double? defaultFloat,
    $core.bool? defaultBool,
    $core.int? exerciseId,
    $core.Iterable<TrainingProgramIntChoice>? intChoices,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (label != null) result.label = label;
    if (helpText != null) result.helpText = helpText;
    if (kind != null) result.kind = kind;
    if (binding != null) result.binding = binding;
    if (required != null) result.required = required;
    if (defaultInt32 != null) result.defaultInt32 = defaultInt32;
    if (defaultFloat != null) result.defaultFloat = defaultFloat;
    if (defaultBool != null) result.defaultBool = defaultBool;
    if (exerciseId != null) result.exerciseId = exerciseId;
    if (intChoices != null) result.intChoices.addAll(intChoices);
    return result;
  }

  TrainingProgramConfigField._();

  factory TrainingProgramConfigField.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingProgramConfigField.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingProgramConfigField',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..aOS(3, _omitFieldNames ? '' : 'helpText')
    ..aE<TrainingProgramFieldKind>(4, _omitFieldNames ? '' : 'kind',
        enumValues: TrainingProgramFieldKind.values)
    ..aE<TrainingProgramFieldBinding>(5, _omitFieldNames ? '' : 'binding',
        enumValues: TrainingProgramFieldBinding.values)
    ..aOB(6, _omitFieldNames ? '' : 'required')
    ..aI(7, _omitFieldNames ? '' : 'defaultInt32')
    ..aD(8, _omitFieldNames ? '' : 'defaultFloat',
        fieldType: $pb.PbFieldType.OF)
    ..aOB(9, _omitFieldNames ? '' : 'defaultBool')
    ..aI(10, _omitFieldNames ? '' : 'exerciseId')
    ..pPM<TrainingProgramIntChoice>(11, _omitFieldNames ? '' : 'intChoices',
        subBuilder: TrainingProgramIntChoice.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramConfigField clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingProgramConfigField copyWith(
          void Function(TrainingProgramConfigField) updates) =>
      super.copyWith(
              (message) => updates(message as TrainingProgramConfigField))
          as TrainingProgramConfigField;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingProgramConfigField create() => TrainingProgramConfigField._();
  @$core.override
  TrainingProgramConfigField createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingProgramConfigField getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingProgramConfigField>(create);
  static TrainingProgramConfigField? _defaultInstance;

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
  TrainingProgramFieldKind get kind => $_getN(3);
  @$pb.TagNumber(4)
  set kind(TrainingProgramFieldKind value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasKind() => $_has(3);
  @$pb.TagNumber(4)
  void clearKind() => $_clearField(4);

  @$pb.TagNumber(5)
  TrainingProgramFieldBinding get binding => $_getN(4);
  @$pb.TagNumber(5)
  set binding(TrainingProgramFieldBinding value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasBinding() => $_has(4);
  @$pb.TagNumber(5)
  void clearBinding() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get required => $_getBF(5);
  @$pb.TagNumber(6)
  set required($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRequired() => $_has(5);
  @$pb.TagNumber(6)
  void clearRequired() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get defaultInt32 => $_getIZ(6);
  @$pb.TagNumber(7)
  set defaultInt32($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDefaultInt32() => $_has(6);
  @$pb.TagNumber(7)
  void clearDefaultInt32() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get defaultFloat => $_getN(7);
  @$pb.TagNumber(8)
  set defaultFloat($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDefaultFloat() => $_has(7);
  @$pb.TagNumber(8)
  void clearDefaultFloat() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get defaultBool => $_getBF(8);
  @$pb.TagNumber(9)
  set defaultBool($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDefaultBool() => $_has(8);
  @$pb.TagNumber(9)
  void clearDefaultBool() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get exerciseId => $_getIZ(9);
  @$pb.TagNumber(10)
  set exerciseId($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasExerciseId() => $_has(9);
  @$pb.TagNumber(10)
  void clearExerciseId() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<TrainingProgramIntChoice> get intChoices => $_getList(10);
}

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
    $core.Iterable<TrainingProgramConfigField>? configFields,
    $core.int? sortOrder,
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
    if (configFields != null) result.configFields.addAll(configFields);
    if (sortOrder != null) result.sortOrder = sortOrder;
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
    ..pPM<TrainingProgramConfigField>(10, _omitFieldNames ? '' : 'configFields',
        subBuilder: TrainingProgramConfigField.create)
    ..aI(11, _omitFieldNames ? '' : 'sortOrder')
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

  @$pb.TagNumber(10)
  $pb.PbList<TrainingProgramConfigField> get configFields => $_getList(9);

  @$pb.TagNumber(11)
  $core.int get sortOrder => $_getIZ(10);
  @$pb.TagNumber(11)
  set sortOrder($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSortOrder() => $_has(10);
  @$pb.TagNumber(11)
  void clearSortOrder() => $_clearField(11);
}

class UserWorkoutConfig extends $pb.GeneratedMessage {
  factory UserWorkoutConfig({
    RegimeType? regimeType,
    $core.int? daysPerWeek,
    $core.Iterable<$core.MapEntry<$core.int, $core.double>>? oneRepMaxes,
    $core.String? regimeStateJson,
  }) {
    final result = create();
    if (regimeType != null) result.regimeType = regimeType;
    if (daysPerWeek != null) result.daysPerWeek = daysPerWeek;
    if (oneRepMaxes != null) result.oneRepMaxes.addEntries(oneRepMaxes);
    if (regimeStateJson != null) result.regimeStateJson = regimeStateJson;
    return result;
  }

  UserWorkoutConfig._();

  factory UserWorkoutConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserWorkoutConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserWorkoutConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<RegimeType>(1, _omitFieldNames ? '' : 'regimeType',
        enumValues: RegimeType.values)
    ..aI(2, _omitFieldNames ? '' : 'daysPerWeek')
    ..m<$core.int, $core.double>(3, _omitFieldNames ? '' : 'oneRepMaxes',
        entryClassName: 'UserWorkoutConfig.OneRepMaxesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OF,
        packageName: const $pb.PackageName('workout.v1'))
    ..aOS(4, _omitFieldNames ? '' : 'regimeStateJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserWorkoutConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserWorkoutConfig copyWith(void Function(UserWorkoutConfig) updates) =>
      super.copyWith((message) => updates(message as UserWorkoutConfig))
          as UserWorkoutConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserWorkoutConfig create() => UserWorkoutConfig._();
  @$core.override
  UserWorkoutConfig createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserWorkoutConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserWorkoutConfig>(create);
  static UserWorkoutConfig? _defaultInstance;

  @$pb.TagNumber(1)
  RegimeType get regimeType => $_getN(0);
  @$pb.TagNumber(1)
  set regimeType(RegimeType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRegimeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearRegimeType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get daysPerWeek => $_getIZ(1);
  @$pb.TagNumber(2)
  set daysPerWeek($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDaysPerWeek() => $_has(1);
  @$pb.TagNumber(2)
  void clearDaysPerWeek() => $_clearField(2);

  /// 1RM per exercise (Exercise enum int32 -> weight in lbs). Used for Wendler TM calculation.
  @$pb.TagNumber(3)
  $pb.PbMap<$core.int, $core.double> get oneRepMaxes => $_getMap(2);

  /// JSON blob for regime-specific mutable state (GZCLP stages, Wendler week/cycle).
  @$pb.TagNumber(4)
  $core.String get regimeStateJson => $_getSZ(3);
  @$pb.TagNumber(4)
  set regimeStateJson($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRegimeStateJson() => $_has(3);
  @$pb.TagNumber(4)
  void clearRegimeStateJson() => $_clearField(4);
}

enum UserSetting_Setting { plateColors, workoutConfig, notSet }

class UserSetting extends $pb.GeneratedMessage {
  factory UserSetting({
    PlateColorsConfig? plateColors,
    UserWorkoutConfig? workoutConfig,
  }) {
    final result = create();
    if (plateColors != null) result.plateColors = plateColors;
    if (workoutConfig != null) result.workoutConfig = workoutConfig;
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
    11: UserSetting_Setting.workoutConfig,
    0: UserSetting_Setting.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserSetting',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11])
    ..aOM<PlateColorsConfig>(10, _omitFieldNames ? '' : 'plateColors',
        subBuilder: PlateColorsConfig.create)
    ..aOM<UserWorkoutConfig>(11, _omitFieldNames ? '' : 'workoutConfig',
        subBuilder: UserWorkoutConfig.create)
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
  @$pb.TagNumber(11)
  UserSetting_Setting whichSetting() =>
      _UserSetting_SettingByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
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

  @$pb.TagNumber(11)
  UserWorkoutConfig get workoutConfig => $_getN(1);
  @$pb.TagNumber(11)
  set workoutConfig(UserWorkoutConfig value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasWorkoutConfig() => $_has(1);
  @$pb.TagNumber(11)
  void clearWorkoutConfig() => $_clearField(11);
  @$pb.TagNumber(11)
  UserWorkoutConfig ensureWorkoutConfig() => $_ensure(1);
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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
