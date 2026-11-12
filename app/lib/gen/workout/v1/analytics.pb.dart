// This is a generated file - do not edit.
//
// Generated from workout/v1/analytics.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'workout.pbenum.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// One screen visit. `page` is a stable slug — a go_router path template
/// ("/settings", "/exercise/:ex") or an in-screen step ("onboarding/2-unit") —
/// never a concrete id. Platform and app version ride on the request metadata
/// (`x-platform`, `x-app-version`), not on each row.
class PageView extends $pb.GeneratedMessage {
  factory PageView({
    $core.String? appSessionId,
    $core.int? seq,
    $core.String? page,
    $fixnum.Int64? enteredAtMs,
    $fixnum.Int64? durationMs,
  }) {
    final result = create();
    if (appSessionId != null) result.appSessionId = appSessionId;
    if (seq != null) result.seq = seq;
    if (page != null) result.page = page;
    if (enteredAtMs != null) result.enteredAtMs = enteredAtMs;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  PageView._();

  factory PageView.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PageView.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PageView',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'appSessionId')
    ..aI(2, _omitFieldNames ? '' : 'seq')
    ..aOS(3, _omitFieldNames ? '' : 'page')
    ..aInt64(4, _omitFieldNames ? '' : 'enteredAtMs')
    ..aInt64(5, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageView clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageView copyWith(void Function(PageView) updates) =>
      super.copyWith((message) => updates(message as PageView)) as PageView;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PageView create() => PageView._();
  @$core.override
  PageView createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PageView getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PageView>(create);
  static PageView? _defaultInstance;

  /// One id per app launch, so a trail can be split into sittings.
  @$pb.TagNumber(1)
  $core.String get appSessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set appSessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAppSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppSessionId() => $_clearField(1);

  /// Monotonic per app_session_id. (user, session, seq) is the row's identity,
  /// so a retried batch is ignored rather than double counted.
  @$pb.TagNumber(2)
  $core.int get seq => $_getIZ(1);
  @$pb.TagNumber(2)
  set seq($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeq() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeq() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get page => $_getSZ(2);
  @$pb.TagNumber(3)
  set page($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPage() => $_has(2);
  @$pb.TagNumber(3)
  void clearPage() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get enteredAtMs => $_getI64(3);
  @$pb.TagNumber(4)
  set enteredAtMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEnteredAtMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearEnteredAtMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get durationMs => $_getI64(4);
  @$pb.TagNumber(5)
  set durationMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationMs() => $_clearField(5);
}

class RecordPageViewsRequest extends $pb.GeneratedMessage {
  factory RecordPageViewsRequest({
    $core.Iterable<PageView>? views,
  }) {
    final result = create();
    if (views != null) result.views.addAll(views);
    return result;
  }

  RecordPageViewsRequest._();

  factory RecordPageViewsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordPageViewsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordPageViewsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<PageView>(1, _omitFieldNames ? '' : 'views',
        subBuilder: PageView.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordPageViewsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordPageViewsRequest copyWith(
          void Function(RecordPageViewsRequest) updates) =>
      super.copyWith((message) => updates(message as RecordPageViewsRequest))
          as RecordPageViewsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordPageViewsRequest create() => RecordPageViewsRequest._();
  @$core.override
  RecordPageViewsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordPageViewsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordPageViewsRequest>(create);
  static RecordPageViewsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PageView> get views => $_getList(0);
}

class RecordPageViewsResponse extends $pb.GeneratedMessage {
  factory RecordPageViewsResponse({
    $core.int? accepted,
  }) {
    final result = create();
    if (accepted != null) result.accepted = accepted;
    return result;
  }

  RecordPageViewsResponse._();

  factory RecordPageViewsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordPageViewsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordPageViewsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'accepted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordPageViewsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordPageViewsResponse copyWith(
          void Function(RecordPageViewsResponse) updates) =>
      super.copyWith((message) => updates(message as RecordPageViewsResponse))
          as RecordPageViewsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordPageViewsResponse create() => RecordPageViewsResponse._();
  @$core.override
  RecordPageViewsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordPageViewsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordPageViewsResponse>(create);
  static RecordPageViewsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get accepted => $_getIZ(0);
  @$pb.TagNumber(1)
  set accepted($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccepted() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccepted() => $_clearField(1);
}

class GetAdminStatusRequest extends $pb.GeneratedMessage {
  factory GetAdminStatusRequest() => create();

  GetAdminStatusRequest._();

  factory GetAdminStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAdminStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAdminStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAdminStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAdminStatusRequest copyWith(
          void Function(GetAdminStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetAdminStatusRequest))
          as GetAdminStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAdminStatusRequest create() => GetAdminStatusRequest._();
  @$core.override
  GetAdminStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAdminStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAdminStatusRequest>(create);
  static GetAdminStatusRequest? _defaultInstance;
}

class GetAdminStatusResponse extends $pb.GeneratedMessage {
  factory GetAdminStatusResponse({
    $core.bool? isAdmin,
  }) {
    final result = create();
    if (isAdmin != null) result.isAdmin = isAdmin;
    return result;
  }

  GetAdminStatusResponse._();

  factory GetAdminStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAdminStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAdminStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isAdmin')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAdminStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAdminStatusResponse copyWith(
          void Function(GetAdminStatusResponse) updates) =>
      super.copyWith((message) => updates(message as GetAdminStatusResponse))
          as GetAdminStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAdminStatusResponse create() => GetAdminStatusResponse._();
  @$core.override
  GetAdminStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAdminStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAdminStatusResponse>(create);
  static GetAdminStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isAdmin => $_getBF(0);
  @$pb.TagNumber(1)
  set isAdmin($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsAdmin() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsAdmin() => $_clearField(1);
}

class GetStatsRequest extends $pb.GeneratedMessage {
  factory GetStatsRequest({
    $core.int? days,
    $core.String? trailUsername,
  }) {
    final result = create();
    if (days != null) result.days = days;
    if (trailUsername != null) result.trailUsername = trailUsername;
    return result;
  }

  GetStatsRequest._();

  factory GetStatsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStatsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStatsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'days')
    ..aOS(2, _omitFieldNames ? '' : 'trailUsername')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatsRequest copyWith(void Function(GetStatsRequest) updates) =>
      super.copyWith((message) => updates(message as GetStatsRequest))
          as GetStatsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStatsRequest create() => GetStatsRequest._();
  @$core.override
  GetStatsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStatsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStatsRequest>(create);
  static GetStatsRequest? _defaultInstance;

  /// Look-back window in days. 0 = 30. Capped at a year.
  @$pb.TagNumber(1)
  $core.int get days => $_getIZ(0);
  @$pb.TagNumber(1)
  set days($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDays() => $_has(0);
  @$pb.TagNumber(1)
  void clearDays() => $_clearField(1);

  /// When set, `trail` holds this user's most recent page views.
  @$pb.TagNumber(2)
  $core.String get trailUsername => $_getSZ(1);
  @$pb.TagNumber(2)
  set trailUsername($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTrailUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearTrailUsername() => $_clearField(2);
}

class PageStat extends $pb.GeneratedMessage {
  factory PageStat({
    $core.String? page,
    $fixnum.Int64? views,
    $fixnum.Int64? uniqueUsers,
    $fixnum.Int64? medianDurationMs,
    $fixnum.Int64? totalDurationMs,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (views != null) result.views = views;
    if (uniqueUsers != null) result.uniqueUsers = uniqueUsers;
    if (medianDurationMs != null) result.medianDurationMs = medianDurationMs;
    if (totalDurationMs != null) result.totalDurationMs = totalDurationMs;
    return result;
  }

  PageStat._();

  factory PageStat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PageStat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PageStat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'page')
    ..aInt64(2, _omitFieldNames ? '' : 'views')
    ..aInt64(3, _omitFieldNames ? '' : 'uniqueUsers')
    ..aInt64(4, _omitFieldNames ? '' : 'medianDurationMs')
    ..aInt64(5, _omitFieldNames ? '' : 'totalDurationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageStat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PageStat copyWith(void Function(PageStat) updates) =>
      super.copyWith((message) => updates(message as PageStat)) as PageStat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PageStat create() => PageStat._();
  @$core.override
  PageStat createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PageStat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PageStat>(create);
  static PageStat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get page => $_getSZ(0);
  @$pb.TagNumber(1)
  set page($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get views => $_getI64(1);
  @$pb.TagNumber(2)
  set views($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasViews() => $_has(1);
  @$pb.TagNumber(2)
  void clearViews() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get uniqueUsers => $_getI64(2);
  @$pb.TagNumber(3)
  set uniqueUsers($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUniqueUsers() => $_has(2);
  @$pb.TagNumber(3)
  void clearUniqueUsers() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get medianDurationMs => $_getI64(3);
  @$pb.TagNumber(4)
  set medianDurationMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMedianDurationMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearMedianDurationMs() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get totalDurationMs => $_getI64(4);
  @$pb.TagNumber(5)
  set totalDurationMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTotalDurationMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearTotalDurationMs() => $_clearField(5);
}

class DailyStat extends $pb.GeneratedMessage {
  factory DailyStat({
    $core.String? day,
    $fixnum.Int64? views,
    $fixnum.Int64? uniqueUsers,
  }) {
    final result = create();
    if (day != null) result.day = day;
    if (views != null) result.views = views;
    if (uniqueUsers != null) result.uniqueUsers = uniqueUsers;
    return result;
  }

  DailyStat._();

  factory DailyStat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DailyStat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DailyStat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'day')
    ..aInt64(2, _omitFieldNames ? '' : 'views')
    ..aInt64(3, _omitFieldNames ? '' : 'uniqueUsers')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DailyStat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DailyStat copyWith(void Function(DailyStat) updates) =>
      super.copyWith((message) => updates(message as DailyStat)) as DailyStat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DailyStat create() => DailyStat._();
  @$core.override
  DailyStat createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DailyStat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DailyStat>(create);
  static DailyStat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get day => $_getSZ(0);
  @$pb.TagNumber(1)
  set day($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDay() => $_has(0);
  @$pb.TagNumber(1)
  void clearDay() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get views => $_getI64(1);
  @$pb.TagNumber(2)
  set views($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasViews() => $_has(1);
  @$pb.TagNumber(2)
  void clearViews() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get uniqueUsers => $_getI64(2);
  @$pb.TagNumber(3)
  set uniqueUsers($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUniqueUsers() => $_has(2);
  @$pb.TagNumber(3)
  void clearUniqueUsers() => $_clearField(3);
}

/// Sign-in / sign-up attempts grouped by everything worth slicing on.
/// outcome: "started" (never finished — the passkey sheet failed or was
/// dismissed on the device), "ok", "rejected" (server refused the credential),
/// "client_error" (the app reported why; see `reason`).
class AuthAttemptStat extends $pb.GeneratedMessage {
  factory AuthAttemptStat({
    $core.String? kind,
    $core.String? platform,
    $core.String? appVersion,
    $core.String? outcome,
    $core.String? reason,
    $fixnum.Int64? count,
  }) {
    final result = create();
    if (kind != null) result.kind = kind;
    if (platform != null) result.platform = platform;
    if (appVersion != null) result.appVersion = appVersion;
    if (outcome != null) result.outcome = outcome;
    if (reason != null) result.reason = reason;
    if (count != null) result.count = count;
    return result;
  }

  AuthAttemptStat._();

  factory AuthAttemptStat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AuthAttemptStat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AuthAttemptStat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'kind')
    ..aOS(2, _omitFieldNames ? '' : 'platform')
    ..aOS(3, _omitFieldNames ? '' : 'appVersion')
    ..aOS(4, _omitFieldNames ? '' : 'outcome')
    ..aOS(5, _omitFieldNames ? '' : 'reason')
    ..aInt64(6, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthAttemptStat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AuthAttemptStat copyWith(void Function(AuthAttemptStat) updates) =>
      super.copyWith((message) => updates(message as AuthAttemptStat))
          as AuthAttemptStat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AuthAttemptStat create() => AuthAttemptStat._();
  @$core.override
  AuthAttemptStat createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AuthAttemptStat getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AuthAttemptStat>(create);
  static AuthAttemptStat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get kind => $_getSZ(0);
  @$pb.TagNumber(1)
  set kind($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get platform => $_getSZ(1);
  @$pb.TagNumber(2)
  set platform($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlatform() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlatform() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get appVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set appVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAppVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearAppVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get outcome => $_getSZ(3);
  @$pb.TagNumber(4)
  set outcome($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOutcome() => $_has(3);
  @$pb.TagNumber(4)
  void clearOutcome() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get reason => $_getSZ(4);
  @$pb.TagNumber(5)
  set reason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReason() => $_has(4);
  @$pb.TagNumber(5)
  void clearReason() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get count => $_getI64(5);
  @$pb.TagNumber(6)
  set count($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCount() => $_has(5);
  @$pb.TagNumber(6)
  void clearCount() => $_clearField(6);
}

class UserActivity extends $pb.GeneratedMessage {
  factory UserActivity({
    $core.String? username,
    $fixnum.Int64? views,
    $fixnum.Int64? lastSeenMs,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (views != null) result.views = views;
    if (lastSeenMs != null) result.lastSeenMs = lastSeenMs;
    return result;
  }

  UserActivity._();

  factory UserActivity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserActivity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserActivity',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..aInt64(2, _omitFieldNames ? '' : 'views')
    ..aInt64(3, _omitFieldNames ? '' : 'lastSeenMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserActivity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserActivity copyWith(void Function(UserActivity) updates) =>
      super.copyWith((message) => updates(message as UserActivity))
          as UserActivity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserActivity create() => UserActivity._();
  @$core.override
  UserActivity createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserActivity getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserActivity>(create);
  static UserActivity? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get views => $_getI64(1);
  @$pb.TagNumber(2)
  set views($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasViews() => $_has(1);
  @$pb.TagNumber(2)
  void clearViews() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lastSeenMs => $_getI64(2);
  @$pb.TagNumber(3)
  set lastSeenMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastSeenMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastSeenMs() => $_clearField(3);
}

class TrailEntry extends $pb.GeneratedMessage {
  factory TrailEntry({
    $core.String? page,
    $fixnum.Int64? enteredAtMs,
    $fixnum.Int64? durationMs,
    $core.String? appSessionId,
    $core.String? platform,
    $core.String? appVersion,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (enteredAtMs != null) result.enteredAtMs = enteredAtMs;
    if (durationMs != null) result.durationMs = durationMs;
    if (appSessionId != null) result.appSessionId = appSessionId;
    if (platform != null) result.platform = platform;
    if (appVersion != null) result.appVersion = appVersion;
    return result;
  }

  TrailEntry._();

  factory TrailEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrailEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrailEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'page')
    ..aInt64(2, _omitFieldNames ? '' : 'enteredAtMs')
    ..aInt64(3, _omitFieldNames ? '' : 'durationMs')
    ..aOS(4, _omitFieldNames ? '' : 'appSessionId')
    ..aOS(5, _omitFieldNames ? '' : 'platform')
    ..aOS(6, _omitFieldNames ? '' : 'appVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrailEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrailEntry copyWith(void Function(TrailEntry) updates) =>
      super.copyWith((message) => updates(message as TrailEntry)) as TrailEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrailEntry create() => TrailEntry._();
  @$core.override
  TrailEntry createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrailEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrailEntry>(create);
  static TrailEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get page => $_getSZ(0);
  @$pb.TagNumber(1)
  set page($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get enteredAtMs => $_getI64(1);
  @$pb.TagNumber(2)
  set enteredAtMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEnteredAtMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnteredAtMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get durationMs => $_getI64(2);
  @$pb.TagNumber(3)
  set durationMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDurationMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearDurationMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get appSessionId => $_getSZ(3);
  @$pb.TagNumber(4)
  set appSessionId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAppSessionId() => $_has(3);
  @$pb.TagNumber(4)
  void clearAppSessionId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get platform => $_getSZ(4);
  @$pb.TagNumber(5)
  set platform($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPlatform() => $_has(4);
  @$pb.TagNumber(5)
  void clearPlatform() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get appVersion => $_getSZ(5);
  @$pb.TagNumber(6)
  set appVersion($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAppVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearAppVersion() => $_clearField(6);
}

class GetStatsResponse extends $pb.GeneratedMessage {
  factory GetStatsResponse({
    $core.int? days,
    $core.Iterable<PageStat>? pages,
    $core.Iterable<DailyStat>? daily,
    $core.Iterable<AuthAttemptStat>? authAttempts,
    $core.Iterable<UserActivity>? users,
    $core.Iterable<TrailEntry>? trail,
    $fixnum.Int64? totalUsers,
    $fixnum.Int64? newUsers,
    $fixnum.Int64? activeUsers,
  }) {
    final result = create();
    if (days != null) result.days = days;
    if (pages != null) result.pages.addAll(pages);
    if (daily != null) result.daily.addAll(daily);
    if (authAttempts != null) result.authAttempts.addAll(authAttempts);
    if (users != null) result.users.addAll(users);
    if (trail != null) result.trail.addAll(trail);
    if (totalUsers != null) result.totalUsers = totalUsers;
    if (newUsers != null) result.newUsers = newUsers;
    if (activeUsers != null) result.activeUsers = activeUsers;
    return result;
  }

  GetStatsResponse._();

  factory GetStatsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStatsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStatsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'days')
    ..pPM<PageStat>(2, _omitFieldNames ? '' : 'pages',
        subBuilder: PageStat.create)
    ..pPM<DailyStat>(3, _omitFieldNames ? '' : 'daily',
        subBuilder: DailyStat.create)
    ..pPM<AuthAttemptStat>(4, _omitFieldNames ? '' : 'authAttempts',
        subBuilder: AuthAttemptStat.create)
    ..pPM<UserActivity>(5, _omitFieldNames ? '' : 'users',
        subBuilder: UserActivity.create)
    ..pPM<TrailEntry>(6, _omitFieldNames ? '' : 'trail',
        subBuilder: TrailEntry.create)
    ..aInt64(7, _omitFieldNames ? '' : 'totalUsers')
    ..aInt64(8, _omitFieldNames ? '' : 'newUsers')
    ..aInt64(9, _omitFieldNames ? '' : 'activeUsers')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatsResponse copyWith(void Function(GetStatsResponse) updates) =>
      super.copyWith((message) => updates(message as GetStatsResponse))
          as GetStatsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStatsResponse create() => GetStatsResponse._();
  @$core.override
  GetStatsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStatsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStatsResponse>(create);
  static GetStatsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get days => $_getIZ(0);
  @$pb.TagNumber(1)
  set days($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDays() => $_has(0);
  @$pb.TagNumber(1)
  void clearDays() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<PageStat> get pages => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<DailyStat> get daily => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<AuthAttemptStat> get authAttempts => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<UserActivity> get users => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<TrailEntry> get trail => $_getList(5);

  @$pb.TagNumber(7)
  $fixnum.Int64 get totalUsers => $_getI64(6);
  @$pb.TagNumber(7)
  set totalUsers($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTotalUsers() => $_has(6);
  @$pb.TagNumber(7)
  void clearTotalUsers() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get newUsers => $_getI64(7);
  @$pb.TagNumber(8)
  set newUsers($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasNewUsers() => $_has(7);
  @$pb.TagNumber(8)
  void clearNewUsers() => $_clearField(8);

  /// Distinct users with a page view inside the window; `users` is capped.
  @$pb.TagNumber(9)
  $fixnum.Int64 get activeUsers => $_getI64(8);
  @$pb.TagNumber(9)
  set activeUsers($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasActiveUsers() => $_has(8);
  @$pb.TagNumber(9)
  void clearActiveUsers() => $_clearField(9);
}

class GetTrainingStatsRequest extends $pb.GeneratedMessage {
  factory GetTrainingStatsRequest({
    $core.int? days,
  }) {
    final result = create();
    if (days != null) result.days = days;
    return result;
  }

  GetTrainingStatsRequest._();

  factory GetTrainingStatsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTrainingStatsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTrainingStatsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'days')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingStatsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingStatsRequest copyWith(
          void Function(GetTrainingStatsRequest) updates) =>
      super.copyWith((message) => updates(message as GetTrainingStatsRequest))
          as GetTrainingStatsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTrainingStatsRequest create() => GetTrainingStatsRequest._();
  @$core.override
  GetTrainingStatsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTrainingStatsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTrainingStatsRequest>(create);
  static GetTrainingStatsRequest? _defaultInstance;

  /// Look-back window in days. 0 = 30. Capped at a year.
  @$pb.TagNumber(1)
  $core.int get days => $_getIZ(0);
  @$pb.TagNumber(1)
  set days($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDays() => $_has(0);
  @$pb.TagNumber(1)
  void clearDays() => $_clearField(1);
}

/// One account, as an admin sees it.
class AdminUser extends $pb.GeneratedMessage {
  factory AdminUser({
    $core.String? username,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? lastSeenMs,
    $core.String? platform,
    $core.String? appVersion,
    $core.int? passkeys,
    $core.int? logins,
    $core.int? workouts,
    $core.int? workoutsInWindow,
    $fixnum.Int64? lastWorkoutAt,
    $core.double? volumeLb,
    $fixnum.Int64? events,
    $core.bool? isAdmin,
    $core.bool? liftingNow,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (createdAt != null) result.createdAt = createdAt;
    if (lastSeenMs != null) result.lastSeenMs = lastSeenMs;
    if (platform != null) result.platform = platform;
    if (appVersion != null) result.appVersion = appVersion;
    if (passkeys != null) result.passkeys = passkeys;
    if (logins != null) result.logins = logins;
    if (workouts != null) result.workouts = workouts;
    if (workoutsInWindow != null) result.workoutsInWindow = workoutsInWindow;
    if (lastWorkoutAt != null) result.lastWorkoutAt = lastWorkoutAt;
    if (volumeLb != null) result.volumeLb = volumeLb;
    if (events != null) result.events = events;
    if (isAdmin != null) result.isAdmin = isAdmin;
    if (liftingNow != null) result.liftingNow = liftingNow;
    return result;
  }

  AdminUser._();

  factory AdminUser.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminUser.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminUser',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..aInt64(2, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(3, _omitFieldNames ? '' : 'lastSeenMs')
    ..aOS(4, _omitFieldNames ? '' : 'platform')
    ..aOS(5, _omitFieldNames ? '' : 'appVersion')
    ..aI(6, _omitFieldNames ? '' : 'passkeys')
    ..aI(7, _omitFieldNames ? '' : 'logins')
    ..aI(8, _omitFieldNames ? '' : 'workouts')
    ..aI(9, _omitFieldNames ? '' : 'workoutsInWindow')
    ..aInt64(10, _omitFieldNames ? '' : 'lastWorkoutAt')
    ..aD(11, _omitFieldNames ? '' : 'volumeLb')
    ..aInt64(12, _omitFieldNames ? '' : 'events')
    ..aOB(13, _omitFieldNames ? '' : 'isAdmin')
    ..aOB(14, _omitFieldNames ? '' : 'liftingNow')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUser clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUser copyWith(void Function(AdminUser) updates) =>
      super.copyWith((message) => updates(message as AdminUser)) as AdminUser;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminUser create() => AdminUser._();
  @$core.override
  AdminUser createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminUser getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AdminUser>(create);
  static AdminUser? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get createdAt => $_getI64(1);
  @$pb.TagNumber(2)
  set createdAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCreatedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearCreatedAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lastSeenMs => $_getI64(2);
  @$pb.TagNumber(3)
  set lastSeenMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastSeenMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastSeenMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get platform => $_getSZ(3);
  @$pb.TagNumber(4)
  set platform($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlatform() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlatform() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get appVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set appVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAppVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearAppVersion() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get passkeys => $_getIZ(5);
  @$pb.TagNumber(6)
  set passkeys($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPasskeys() => $_has(5);
  @$pb.TagNumber(6)
  void clearPasskeys() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get logins => $_getIZ(6);
  @$pb.TagNumber(7)
  set logins($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLogins() => $_has(6);
  @$pb.TagNumber(7)
  void clearLogins() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get workouts => $_getIZ(7);
  @$pb.TagNumber(8)
  set workouts($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWorkouts() => $_has(7);
  @$pb.TagNumber(8)
  void clearWorkouts() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get workoutsInWindow => $_getIZ(8);
  @$pb.TagNumber(9)
  set workoutsInWindow($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasWorkoutsInWindow() => $_has(8);
  @$pb.TagNumber(9)
  void clearWorkoutsInWindow() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get lastWorkoutAt => $_getI64(9);
  @$pb.TagNumber(10)
  set lastWorkoutAt($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLastWorkoutAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearLastWorkoutAt() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.double get volumeLb => $_getN(10);
  @$pb.TagNumber(11)
  set volumeLb($core.double value) => $_setDouble(10, value);
  @$pb.TagNumber(11)
  $core.bool hasVolumeLb() => $_has(10);
  @$pb.TagNumber(11)
  void clearVolumeLb() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get events => $_getI64(11);
  @$pb.TagNumber(12)
  set events($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasEvents() => $_has(11);
  @$pb.TagNumber(12)
  void clearEvents() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get isAdmin => $_getBF(12);
  @$pb.TagNumber(13)
  set isAdmin($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasIsAdmin() => $_has(12);
  @$pb.TagNumber(13)
  void clearIsAdmin() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get liftingNow => $_getBF(13);
  @$pb.TagNumber(14)
  set liftingNow($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasLiftingNow() => $_has(13);
  @$pb.TagNumber(14)
  void clearLiftingNow() => $_clearField(14);
}

/// One finished workout.
class AdminWorkout extends $pb.GeneratedMessage {
  factory AdminWorkout({
    $core.String? username,
    $core.String? name,
    $fixnum.Int64? startTime,
    $fixnum.Int64? durationSeconds,
    $core.double? volumeLb,
    $core.int? sets,
    $core.int? exercises,
    $core.bool? together,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (name != null) result.name = name;
    if (startTime != null) result.startTime = startTime;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    if (volumeLb != null) result.volumeLb = volumeLb;
    if (sets != null) result.sets = sets;
    if (exercises != null) result.exercises = exercises;
    if (together != null) result.together = together;
    return result;
  }

  AdminWorkout._();

  factory AdminWorkout.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminWorkout.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminWorkout',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'startTime')
    ..aInt64(4, _omitFieldNames ? '' : 'durationSeconds')
    ..aD(5, _omitFieldNames ? '' : 'volumeLb')
    ..aI(6, _omitFieldNames ? '' : 'sets')
    ..aI(7, _omitFieldNames ? '' : 'exercises')
    ..aOB(8, _omitFieldNames ? '' : 'together')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminWorkout clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminWorkout copyWith(void Function(AdminWorkout) updates) =>
      super.copyWith((message) => updates(message as AdminWorkout))
          as AdminWorkout;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminWorkout create() => AdminWorkout._();
  @$core.override
  AdminWorkout createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminWorkout getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminWorkout>(create);
  static AdminWorkout? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get startTime => $_getI64(2);
  @$pb.TagNumber(3)
  set startTime($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartTime() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get durationSeconds => $_getI64(3);
  @$pb.TagNumber(4)
  set durationSeconds($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationSeconds() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get volumeLb => $_getN(4);
  @$pb.TagNumber(5)
  set volumeLb($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasVolumeLb() => $_has(4);
  @$pb.TagNumber(5)
  void clearVolumeLb() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get sets => $_getIZ(5);
  @$pb.TagNumber(6)
  set sets($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSets() => $_has(5);
  @$pb.TagNumber(6)
  void clearSets() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get exercises => $_getIZ(6);
  @$pb.TagNumber(7)
  set exercises($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExercises() => $_has(6);
  @$pb.TagNumber(7)
  void clearExercises() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get together => $_getBF(7);
  @$pb.TagNumber(8)
  set together($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTogether() => $_has(7);
  @$pb.TagNumber(8)
  void clearTogether() => $_clearField(8);
}

class TrainingDay extends $pb.GeneratedMessage {
  factory TrainingDay({
    $fixnum.Int64? epochDay,
    $fixnum.Int64? workouts,
    $fixnum.Int64? lifters,
  }) {
    final result = create();
    if (epochDay != null) result.epochDay = epochDay;
    if (workouts != null) result.workouts = workouts;
    if (lifters != null) result.lifters = lifters;
    return result;
  }

  TrainingDay._();

  factory TrainingDay.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TrainingDay.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrainingDay',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'epochDay')
    ..aInt64(2, _omitFieldNames ? '' : 'workouts')
    ..aInt64(3, _omitFieldNames ? '' : 'lifters')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingDay clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrainingDay copyWith(void Function(TrainingDay) updates) =>
      super.copyWith((message) => updates(message as TrainingDay))
          as TrainingDay;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TrainingDay create() => TrainingDay._();
  @$core.override
  TrainingDay createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TrainingDay getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrainingDay>(create);
  static TrainingDay? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get epochDay => $_getI64(0);
  @$pb.TagNumber(1)
  set epochDay($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEpochDay() => $_has(0);
  @$pb.TagNumber(1)
  void clearEpochDay() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get workouts => $_getI64(1);
  @$pb.TagNumber(2)
  set workouts($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkouts() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkouts() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lifters => $_getI64(2);
  @$pb.TagNumber(3)
  set lifters($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLifters() => $_has(2);
  @$pb.TagNumber(3)
  void clearLifters() => $_clearField(3);
}

class ExerciseUse extends $pb.GeneratedMessage {
  factory ExerciseUse({
    $1.Exercise? exercise,
    $fixnum.Int64? sets,
    $fixnum.Int64? lifters,
    $core.double? volumeLb,
  }) {
    final result = create();
    if (exercise != null) result.exercise = exercise;
    if (sets != null) result.sets = sets;
    if (lifters != null) result.lifters = lifters;
    if (volumeLb != null) result.volumeLb = volumeLb;
    return result;
  }

  ExerciseUse._();

  factory ExerciseUse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ExerciseUse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExerciseUse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aE<$1.Exercise>(1, _omitFieldNames ? '' : 'exercise',
        enumValues: $1.Exercise.values)
    ..aInt64(2, _omitFieldNames ? '' : 'sets')
    ..aInt64(3, _omitFieldNames ? '' : 'lifters')
    ..aD(4, _omitFieldNames ? '' : 'volumeLb')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseUse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExerciseUse copyWith(void Function(ExerciseUse) updates) =>
      super.copyWith((message) => updates(message as ExerciseUse))
          as ExerciseUse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ExerciseUse create() => ExerciseUse._();
  @$core.override
  ExerciseUse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ExerciseUse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExerciseUse>(create);
  static ExerciseUse? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Exercise get exercise => $_getN(0);
  @$pb.TagNumber(1)
  set exercise($1.Exercise value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasExercise() => $_has(0);
  @$pb.TagNumber(1)
  void clearExercise() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sets => $_getI64(1);
  @$pb.TagNumber(2)
  set sets($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSets() => $_has(1);
  @$pb.TagNumber(2)
  void clearSets() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lifters => $_getI64(2);
  @$pb.TagNumber(3)
  set lifters($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLifters() => $_has(2);
  @$pb.TagNumber(3)
  void clearLifters() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get volumeLb => $_getN(3);
  @$pb.TagNumber(4)
  set volumeLb($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVolumeLb() => $_has(3);
  @$pb.TagNumber(4)
  void clearVolumeLb() => $_clearField(4);
}

class GetTrainingStatsResponse extends $pb.GeneratedMessage {
  factory GetTrainingStatsResponse({
    $core.int? days,
    $core.Iterable<AdminUser>? users,
    $core.Iterable<AdminWorkout>? workouts,
    $core.Iterable<TrainingDay>? daily,
    $core.Iterable<ExerciseUse>? exercises,
    $fixnum.Int64? workoutsInWindow,
    $fixnum.Int64? liftersInWindow,
    $fixnum.Int64? workoutsTotal,
    $core.double? volumeLbInWindow,
  }) {
    final result = create();
    if (days != null) result.days = days;
    if (users != null) result.users.addAll(users);
    if (workouts != null) result.workouts.addAll(workouts);
    if (daily != null) result.daily.addAll(daily);
    if (exercises != null) result.exercises.addAll(exercises);
    if (workoutsInWindow != null) result.workoutsInWindow = workoutsInWindow;
    if (liftersInWindow != null) result.liftersInWindow = liftersInWindow;
    if (workoutsTotal != null) result.workoutsTotal = workoutsTotal;
    if (volumeLbInWindow != null) result.volumeLbInWindow = volumeLbInWindow;
    return result;
  }

  GetTrainingStatsResponse._();

  factory GetTrainingStatsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTrainingStatsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTrainingStatsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'days')
    ..pPM<AdminUser>(2, _omitFieldNames ? '' : 'users',
        subBuilder: AdminUser.create)
    ..pPM<AdminWorkout>(3, _omitFieldNames ? '' : 'workouts',
        subBuilder: AdminWorkout.create)
    ..pPM<TrainingDay>(4, _omitFieldNames ? '' : 'daily',
        subBuilder: TrainingDay.create)
    ..pPM<ExerciseUse>(5, _omitFieldNames ? '' : 'exercises',
        subBuilder: ExerciseUse.create)
    ..aInt64(6, _omitFieldNames ? '' : 'workoutsInWindow')
    ..aInt64(7, _omitFieldNames ? '' : 'liftersInWindow')
    ..aInt64(8, _omitFieldNames ? '' : 'workoutsTotal')
    ..aD(9, _omitFieldNames ? '' : 'volumeLbInWindow')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingStatsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTrainingStatsResponse copyWith(
          void Function(GetTrainingStatsResponse) updates) =>
      super.copyWith((message) => updates(message as GetTrainingStatsResponse))
          as GetTrainingStatsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTrainingStatsResponse create() => GetTrainingStatsResponse._();
  @$core.override
  GetTrainingStatsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTrainingStatsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTrainingStatsResponse>(create);
  static GetTrainingStatsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get days => $_getIZ(0);
  @$pb.TagNumber(1)
  set days($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDays() => $_has(0);
  @$pb.TagNumber(1)
  void clearDays() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<AdminUser> get users => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<AdminWorkout> get workouts => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<TrainingDay> get daily => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<ExerciseUse> get exercises => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get workoutsInWindow => $_getI64(5);
  @$pb.TagNumber(6)
  set workoutsInWindow($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasWorkoutsInWindow() => $_has(5);
  @$pb.TagNumber(6)
  void clearWorkoutsInWindow() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get liftersInWindow => $_getI64(6);
  @$pb.TagNumber(7)
  set liftersInWindow($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLiftersInWindow() => $_has(6);
  @$pb.TagNumber(7)
  void clearLiftersInWindow() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get workoutsTotal => $_getI64(7);
  @$pb.TagNumber(8)
  set workoutsTotal($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWorkoutsTotal() => $_has(7);
  @$pb.TagNumber(8)
  void clearWorkoutsTotal() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.double get volumeLbInWindow => $_getN(8);
  @$pb.TagNumber(9)
  set volumeLbInWindow($core.double value) => $_setDouble(8, value);
  @$pb.TagNumber(9)
  $core.bool hasVolumeLbInWindow() => $_has(8);
  @$pb.TagNumber(9)
  void clearVolumeLbInWindow() => $_clearField(9);
}

class RecoveryRequest extends $pb.GeneratedMessage {
  factory RecoveryRequest({
    $core.String? requestId,
    $core.String? username,
    $fixnum.Int64? createdAt,
    $core.String? platform,
    $core.String? createdIp,
    $core.int? passkeys,
    $core.int? logins,
    $fixnum.Int64? lastSeenMs,
    $core.String? status,
    $fixnum.Int64? decidedAt,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (username != null) result.username = username;
    if (createdAt != null) result.createdAt = createdAt;
    if (platform != null) result.platform = platform;
    if (createdIp != null) result.createdIp = createdIp;
    if (passkeys != null) result.passkeys = passkeys;
    if (logins != null) result.logins = logins;
    if (lastSeenMs != null) result.lastSeenMs = lastSeenMs;
    if (status != null) result.status = status;
    if (decidedAt != null) result.decidedAt = decidedAt;
    return result;
  }

  RecoveryRequest._();

  factory RecoveryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecoveryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecoveryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aInt64(3, _omitFieldNames ? '' : 'createdAt')
    ..aOS(4, _omitFieldNames ? '' : 'platform')
    ..aOS(5, _omitFieldNames ? '' : 'createdIp')
    ..aI(6, _omitFieldNames ? '' : 'passkeys')
    ..aI(7, _omitFieldNames ? '' : 'logins')
    ..aInt64(8, _omitFieldNames ? '' : 'lastSeenMs')
    ..aOS(9, _omitFieldNames ? '' : 'status')
    ..aInt64(10, _omitFieldNames ? '' : 'decidedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryRequest copyWith(void Function(RecoveryRequest) updates) =>
      super.copyWith((message) => updates(message as RecoveryRequest))
          as RecoveryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecoveryRequest create() => RecoveryRequest._();
  @$core.override
  RecoveryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecoveryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecoveryRequest>(create);
  static RecoveryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get createdAt => $_getI64(2);
  @$pb.TagNumber(3)
  set createdAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedAt() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get platform => $_getSZ(3);
  @$pb.TagNumber(4)
  set platform($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlatform() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlatform() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get createdIp => $_getSZ(4);
  @$pb.TagNumber(5)
  set createdIp($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCreatedIp() => $_has(4);
  @$pb.TagNumber(5)
  void clearCreatedIp() => $_clearField(5);

  /// The account, so the admin can judge the request.
  @$pb.TagNumber(6)
  $core.int get passkeys => $_getIZ(5);
  @$pb.TagNumber(6)
  set passkeys($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPasskeys() => $_has(5);
  @$pb.TagNumber(6)
  void clearPasskeys() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get logins => $_getIZ(6);
  @$pb.TagNumber(7)
  set logins($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasLogins() => $_has(6);
  @$pb.TagNumber(7)
  void clearLogins() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get lastSeenMs => $_getI64(7);
  @$pb.TagNumber(8)
  set lastSeenMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLastSeenMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearLastSeenMs() => $_clearField(8);

  /// "pending", "approved" or "denied".
  @$pb.TagNumber(9)
  $core.String get status => $_getSZ(8);
  @$pb.TagNumber(9)
  set status($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasStatus() => $_has(8);
  @$pb.TagNumber(9)
  void clearStatus() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get decidedAt => $_getI64(9);
  @$pb.TagNumber(10)
  set decidedAt($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDecidedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearDecidedAt() => $_clearField(10);
}

class ListRecoveriesRequest extends $pb.GeneratedMessage {
  factory ListRecoveriesRequest() => create();

  ListRecoveriesRequest._();

  factory ListRecoveriesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListRecoveriesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListRecoveriesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListRecoveriesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListRecoveriesRequest copyWith(
          void Function(ListRecoveriesRequest) updates) =>
      super.copyWith((message) => updates(message as ListRecoveriesRequest))
          as ListRecoveriesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListRecoveriesRequest create() => ListRecoveriesRequest._();
  @$core.override
  ListRecoveriesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListRecoveriesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListRecoveriesRequest>(create);
  static ListRecoveriesRequest? _defaultInstance;
}

class ListRecoveriesResponse extends $pb.GeneratedMessage {
  factory ListRecoveriesResponse({
    $core.Iterable<RecoveryRequest>? recoveries,
  }) {
    final result = create();
    if (recoveries != null) result.recoveries.addAll(recoveries);
    return result;
  }

  ListRecoveriesResponse._();

  factory ListRecoveriesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListRecoveriesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListRecoveriesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..pPM<RecoveryRequest>(1, _omitFieldNames ? '' : 'recoveries',
        subBuilder: RecoveryRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListRecoveriesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListRecoveriesResponse copyWith(
          void Function(ListRecoveriesResponse) updates) =>
      super.copyWith((message) => updates(message as ListRecoveriesResponse))
          as ListRecoveriesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListRecoveriesResponse create() => ListRecoveriesResponse._();
  @$core.override
  ListRecoveriesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListRecoveriesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListRecoveriesResponse>(create);
  static ListRecoveriesResponse? _defaultInstance;

  /// Waiting first, then the recently decided. Never the codes: an admin
  /// approves the code they were sent.
  @$pb.TagNumber(1)
  $pb.PbList<RecoveryRequest> get recoveries => $_getList(0);
}

class GetRecoveryRequest extends $pb.GeneratedMessage {
  factory GetRecoveryRequest({
    $core.String? code,
  }) {
    final result = create();
    if (code != null) result.code = code;
    return result;
  }

  GetRecoveryRequest._();

  factory GetRecoveryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRecoveryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRecoveryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRecoveryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRecoveryRequest copyWith(void Function(GetRecoveryRequest) updates) =>
      super.copyWith((message) => updates(message as GetRecoveryRequest))
          as GetRecoveryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRecoveryRequest create() => GetRecoveryRequest._();
  @$core.override
  GetRecoveryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRecoveryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetRecoveryRequest>(create);
  static GetRecoveryRequest? _defaultInstance;

  /// The code the person sent.
  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);
}

class AdminPasskey extends $pb.GeneratedMessage {
  factory AdminPasskey({
    $core.String? name,
    $fixnum.Int64? createdAt,
    $core.String? createdIp,
    $core.Iterable<$core.String>? transports,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (createdAt != null) result.createdAt = createdAt;
    if (createdIp != null) result.createdIp = createdIp;
    if (transports != null) result.transports.addAll(transports);
    return result;
  }

  AdminPasskey._();

  factory AdminPasskey.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminPasskey.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminPasskey',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aInt64(2, _omitFieldNames ? '' : 'createdAt')
    ..aOS(3, _omitFieldNames ? '' : 'createdIp')
    ..pPS(4, _omitFieldNames ? '' : 'transports')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminPasskey clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminPasskey copyWith(void Function(AdminPasskey) updates) =>
      super.copyWith((message) => updates(message as AdminPasskey))
          as AdminPasskey;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminPasskey create() => AdminPasskey._();
  @$core.override
  AdminPasskey createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminPasskey getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminPasskey>(create);
  static AdminPasskey? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get createdAt => $_getI64(1);
  @$pb.TagNumber(2)
  set createdAt($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCreatedAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearCreatedAt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get createdIp => $_getSZ(2);
  @$pb.TagNumber(3)
  set createdIp($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedIp() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedIp() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get transports => $_getList(3);
}

class AdminPartner extends $pb.GeneratedMessage {
  factory AdminPartner({
    $core.String? username,
    $core.int? sessionsTogether,
    $fixnum.Int64? lastTrainedAt,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (sessionsTogether != null) result.sessionsTogether = sessionsTogether;
    if (lastTrainedAt != null) result.lastTrainedAt = lastTrainedAt;
    return result;
  }

  AdminPartner._();

  factory AdminPartner.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminPartner.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminPartner',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..aI(2, _omitFieldNames ? '' : 'sessionsTogether')
    ..aInt64(3, _omitFieldNames ? '' : 'lastTrainedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminPartner clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminPartner copyWith(void Function(AdminPartner) updates) =>
      super.copyWith((message) => updates(message as AdminPartner))
          as AdminPartner;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminPartner create() => AdminPartner._();
  @$core.override
  AdminPartner createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminPartner getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminPartner>(create);
  static AdminPartner? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get sessionsTogether => $_getIZ(1);
  @$pb.TagNumber(2)
  set sessionsTogether($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionsTogether() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionsTogether() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lastTrainedAt => $_getI64(2);
  @$pb.TagNumber(3)
  set lastTrainedAt($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastTrainedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastTrainedAt() => $_clearField(3);
}

/// The account a recovery asks for, in enough detail to question whoever is
/// asking: things its owner would know and a stranger would not.
class RecoveryAccount extends $pb.GeneratedMessage {
  factory RecoveryAccount({
    AdminUser? user,
    $core.String? emoji,
    $core.String? colorHex,
    $core.double? bodyWeightKg,
    $fixnum.Int64? lastActiveAt,
    $core.Iterable<AdminPasskey>? passkeys,
    $core.Iterable<AdminPartner>? partners,
    $core.Iterable<$core.String>? templates,
    $core.Iterable<AdminWorkout>? recentWorkouts,
    $core.Iterable<ExerciseUse>? lifts,
  }) {
    final result = create();
    if (user != null) result.user = user;
    if (emoji != null) result.emoji = emoji;
    if (colorHex != null) result.colorHex = colorHex;
    if (bodyWeightKg != null) result.bodyWeightKg = bodyWeightKg;
    if (lastActiveAt != null) result.lastActiveAt = lastActiveAt;
    if (passkeys != null) result.passkeys.addAll(passkeys);
    if (partners != null) result.partners.addAll(partners);
    if (templates != null) result.templates.addAll(templates);
    if (recentWorkouts != null) result.recentWorkouts.addAll(recentWorkouts);
    if (lifts != null) result.lifts.addAll(lifts);
    return result;
  }

  RecoveryAccount._();

  factory RecoveryAccount.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecoveryAccount.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecoveryAccount',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<AdminUser>(1, _omitFieldNames ? '' : 'user',
        subBuilder: AdminUser.create)
    ..aOS(2, _omitFieldNames ? '' : 'emoji')
    ..aOS(3, _omitFieldNames ? '' : 'colorHex')
    ..aD(4, _omitFieldNames ? '' : 'bodyWeightKg')
    ..aInt64(5, _omitFieldNames ? '' : 'lastActiveAt')
    ..pPM<AdminPasskey>(6, _omitFieldNames ? '' : 'passkeys',
        subBuilder: AdminPasskey.create)
    ..pPM<AdminPartner>(7, _omitFieldNames ? '' : 'partners',
        subBuilder: AdminPartner.create)
    ..pPS(8, _omitFieldNames ? '' : 'templates')
    ..pPM<AdminWorkout>(9, _omitFieldNames ? '' : 'recentWorkouts',
        subBuilder: AdminWorkout.create)
    ..pPM<ExerciseUse>(10, _omitFieldNames ? '' : 'lifts',
        subBuilder: ExerciseUse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryAccount clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecoveryAccount copyWith(void Function(RecoveryAccount) updates) =>
      super.copyWith((message) => updates(message as RecoveryAccount))
          as RecoveryAccount;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecoveryAccount create() => RecoveryAccount._();
  @$core.override
  RecoveryAccount createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecoveryAccount getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecoveryAccount>(create);
  static RecoveryAccount? _defaultInstance;

  @$pb.TagNumber(1)
  AdminUser get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(AdminUser value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  AdminUser ensureUser() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get emoji => $_getSZ(1);
  @$pb.TagNumber(2)
  set emoji($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmoji() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmoji() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get colorHex => $_getSZ(2);
  @$pb.TagNumber(3)
  set colorHex($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasColorHex() => $_has(2);
  @$pb.TagNumber(3)
  void clearColorHex() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get bodyWeightKg => $_getN(3);
  @$pb.TagNumber(4)
  set bodyWeightKg($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBodyWeightKg() => $_has(3);
  @$pb.TagNumber(4)
  void clearBodyWeightKg() => $_clearField(4);

  /// The latest use of a signed-in device, to within a day; 0 = none signed in.
  @$pb.TagNumber(5)
  $fixnum.Int64 get lastActiveAt => $_getI64(4);
  @$pb.TagNumber(5)
  set lastActiveAt($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastActiveAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastActiveAt() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<AdminPasskey> get passkeys => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<AdminPartner> get partners => $_getList(6);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get templates => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<AdminWorkout> get recentWorkouts => $_getList(8);

  @$pb.TagNumber(10)
  $pb.PbList<ExerciseUse> get lifts => $_getList(9);
}

class GetRecoveryResponse extends $pb.GeneratedMessage {
  factory GetRecoveryResponse({
    RecoveryRequest? recovery,
    RecoveryAccount? account,
  }) {
    final result = create();
    if (recovery != null) result.recovery = recovery;
    if (account != null) result.account = account;
    return result;
  }

  GetRecoveryResponse._();

  factory GetRecoveryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRecoveryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRecoveryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<RecoveryRequest>(1, _omitFieldNames ? '' : 'recovery',
        subBuilder: RecoveryRequest.create)
    ..aOM<RecoveryAccount>(2, _omitFieldNames ? '' : 'account',
        subBuilder: RecoveryAccount.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRecoveryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRecoveryResponse copyWith(void Function(GetRecoveryResponse) updates) =>
      super.copyWith((message) => updates(message as GetRecoveryResponse))
          as GetRecoveryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRecoveryResponse create() => GetRecoveryResponse._();
  @$core.override
  GetRecoveryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRecoveryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetRecoveryResponse>(create);
  static GetRecoveryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  RecoveryRequest get recovery => $_getN(0);
  @$pb.TagNumber(1)
  set recovery(RecoveryRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRecovery() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecovery() => $_clearField(1);
  @$pb.TagNumber(1)
  RecoveryRequest ensureRecovery() => $_ensure(0);

  @$pb.TagNumber(2)
  RecoveryAccount get account => $_getN(1);
  @$pb.TagNumber(2)
  set account(RecoveryAccount value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAccount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccount() => $_clearField(2);
  @$pb.TagNumber(2)
  RecoveryAccount ensureAccount() => $_ensure(1);
}

enum DecideRecoveryRequest_Request { approveCode, denyRequestId, notSet }

class DecideRecoveryRequest extends $pb.GeneratedMessage {
  factory DecideRecoveryRequest({
    $core.String? approveCode,
    $core.String? denyRequestId,
    $core.bool? removeOtherPasskeys,
  }) {
    final result = create();
    if (approveCode != null) result.approveCode = approveCode;
    if (denyRequestId != null) result.denyRequestId = denyRequestId;
    if (removeOtherPasskeys != null)
      result.removeOtherPasskeys = removeOtherPasskeys;
    return result;
  }

  DecideRecoveryRequest._();

  factory DecideRecoveryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecideRecoveryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, DecideRecoveryRequest_Request>
      _DecideRecoveryRequest_RequestByTag = {
    1: DecideRecoveryRequest_Request.approveCode,
    2: DecideRecoveryRequest_Request.denyRequestId,
    0: DecideRecoveryRequest_Request.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecideRecoveryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aOS(1, _omitFieldNames ? '' : 'approveCode')
    ..aOS(2, _omitFieldNames ? '' : 'denyRequestId')
    ..aOB(3, _omitFieldNames ? '' : 'removeOtherPasskeys')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecideRecoveryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecideRecoveryRequest copyWith(
          void Function(DecideRecoveryRequest) updates) =>
      super.copyWith((message) => updates(message as DecideRecoveryRequest))
          as DecideRecoveryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecideRecoveryRequest create() => DecideRecoveryRequest._();
  @$core.override
  DecideRecoveryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DecideRecoveryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecideRecoveryRequest>(create);
  static DecideRecoveryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  DecideRecoveryRequest_Request whichRequest() =>
      _DecideRecoveryRequest_RequestByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearRequest() => $_clearField($_whichOneof(0));

  /// Approve the request that came with this code.
  @$pb.TagNumber(1)
  $core.String get approveCode => $_getSZ(0);
  @$pb.TagNumber(1)
  set approveCode($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApproveCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearApproveCode() => $_clearField(1);

  /// Refuse this request.
  @$pb.TagNumber(2)
  $core.String get denyRequestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set denyRequestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDenyRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDenyRequestId() => $_clearField(2);

  /// On approving: drop the account's other passkeys and sign out its
  /// devices (a stolen phone, not just a lost key).
  @$pb.TagNumber(3)
  $core.bool get removeOtherPasskeys => $_getBF(2);
  @$pb.TagNumber(3)
  set removeOtherPasskeys($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRemoveOtherPasskeys() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemoveOtherPasskeys() => $_clearField(3);
}

class DecideRecoveryResponse extends $pb.GeneratedMessage {
  factory DecideRecoveryResponse({
    RecoveryRequest? recovery,
  }) {
    final result = create();
    if (recovery != null) result.recovery = recovery;
    return result;
  }

  DecideRecoveryResponse._();

  factory DecideRecoveryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecideRecoveryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecideRecoveryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'workout.v1'),
      createEmptyInstance: create)
    ..aOM<RecoveryRequest>(1, _omitFieldNames ? '' : 'recovery',
        subBuilder: RecoveryRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecideRecoveryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecideRecoveryResponse copyWith(
          void Function(DecideRecoveryResponse) updates) =>
      super.copyWith((message) => updates(message as DecideRecoveryResponse))
          as DecideRecoveryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecideRecoveryResponse create() => DecideRecoveryResponse._();
  @$core.override
  DecideRecoveryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DecideRecoveryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecideRecoveryResponse>(create);
  static DecideRecoveryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  RecoveryRequest get recovery => $_getN(0);
  @$pb.TagNumber(1)
  set recovery(RecoveryRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRecovery() => $_has(0);
  @$pb.TagNumber(1)
  void clearRecovery() => $_clearField(1);
  @$pb.TagNumber(1)
  RecoveryRequest ensureRecovery() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
