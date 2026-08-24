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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
