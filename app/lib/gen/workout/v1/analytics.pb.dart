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

  /// Look-back window in days. 0 = 30. Capped at the retention window.
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
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
