import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../gen/workout/v1/workout.pb.dart';

enum HealthWriteResult { success, permissionDenied, error }

class HeartRateZoneProfile {
  final DateTime? birthDate;
  final int? ageYears;
  final double? restingHeartRateBpm;
  final int estimatedMaxHeartRateBpm;

  const HeartRateZoneProfile({
    required this.birthDate,
    required this.ageYears,
    required this.restingHeartRateBpm,
    required this.estimatedMaxHeartRateBpm,
  });

  bool get hasRestingHeartRate =>
      restingHeartRateBpm != null && restingHeartRateBpm! > 0;
}

class HealthService {
  static const _kcalPerMinute = 5.0;
  static Future<HeartRateZoneProfile?>? _cachedZoneProfileFuture;
  static bool _healthPermissionRequestInFlight = false;

  static Future<HealthWriteResult> writeCompletedWorkout({
    required DateTime startTime,
    required DateTime endTime,
    required String title,
    required double totalVolumeKg,
    required int workingSets,
  }) async {
    debugPrint('Health: writeCompletedWorkout called');

    final health = Health();
    await health.configure();
    debugPrint('Health: configured');

    final types = [
      HealthDataType.WORKOUT,
      HealthDataType.TOTAL_CALORIES_BURNED,
    ];
    final permissions = [HealthDataAccess.WRITE, HealthDataAccess.WRITE];

    final hasPerms = await health.hasPermissions(
      types,
      permissions: permissions,
    );
    debugPrint('Health: hasPermissions=$hasPerms');

    if (hasPerms != true) {
      debugPrint('Health: requesting authorization...');
      final authorized = await health.requestAuthorization(
        types,
        permissions: permissions,
      );
      debugPrint('Health: authorization result=$authorized');
      if (!authorized) {
        debugPrint('Health: authorization denied, skipping write');
        return HealthWriteResult.permissionDenied;
      }
    }

    final durationMinutes = endTime.difference(startTime).inSeconds / 60.0;
    final calories = (durationMinutes * _kcalPerMinute).round();

    debugPrint(
      'Health: writing workout "$title", ${durationMinutes.toStringAsFixed(1)} min, $calories kcal',
    );

    final success = await health.writeWorkoutData(
      activityType: Platform.isAndroid
          ? HealthWorkoutActivityType.STRENGTH_TRAINING
          : HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
      title: title,
      start: startTime,
      end: endTime,
      totalEnergyBurned: calories,
      totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
    );

    debugPrint('Health: writeWorkoutData result=$success');
    return success ? HealthWriteResult.success : HealthWriteResult.error;
  }

  static Future<void> writeHeartRateSamples({
    required String workoutId,
    required List<WorkoutHeartRatePoint> samples,
  }) async {
    if (samples.isEmpty) return;

    final health = Health();
    await health.configure();

    final types = <HealthDataType>[HealthDataType.HEART_RATE];
    final permissions = <HealthDataAccess>[HealthDataAccess.WRITE];
    if (Platform.isAndroid &&
        health.isDataTypeAvailable(HealthDataType.RESTING_HEART_RATE)) {
      // Piggyback this on the existing HR permission flow so the chart can
      // compute zones without a second competing permission request.
      types.add(HealthDataType.RESTING_HEART_RATE);
      permissions.add(HealthDataAccess.READ);
    }

    final hasPerms = await health.hasPermissions(
      types,
      permissions: permissions,
    );
    if (hasPerms != true) {
      if (_healthPermissionRequestInFlight) return;
      _healthPermissionRequestInFlight = true;
      final granted = await health.requestAuthorization(
        types,
        permissions: permissions,
      );
      _healthPermissionRequestInFlight = false;
      if (!granted) return;
    }

    for (final sample in samples) {
      final ts = DateTime.fromMillisecondsSinceEpoch(sample.sampledAt.toInt());
      await health.writeHealthData(
        value: sample.bpm.toDouble(),
        type: HealthDataType.HEART_RATE,
        startTime: ts,
        endTime: ts,
        clientRecordId: 'lift_hr_${workoutId}_${sample.sampledAt.toInt()}',
        clientRecordVersion: 1,
      );
    }
  }

  static Future<HeartRateZoneProfile?> readHeartRateZoneProfile({
    bool useCache = true,
    bool requestPermissions = false,
  }) {
    if (!useCache || _cachedZoneProfileFuture == null) {
      _cachedZoneProfileFuture = _readHeartRateZoneProfileImpl(
        requestPermissions: requestPermissions,
      );
    }
    return _cachedZoneProfileFuture!;
  }

  static Future<HeartRateZoneProfile?> _readHeartRateZoneProfileImpl({
    required bool requestPermissions,
  }) async {
    try {
      final health = Health();
      await health.configure();

      final supportedTypes = <HealthDataType>[];
      if (health.isDataTypeAvailable(HealthDataType.RESTING_HEART_RATE)) {
        supportedTypes.add(HealthDataType.RESTING_HEART_RATE);
      }
      if (Platform.isIOS &&
          health.isDataTypeAvailable(HealthDataType.BIRTH_DATE)) {
        supportedTypes.add(HealthDataType.BIRTH_DATE);
      }
      if (supportedTypes.isEmpty) return null;

      final permissions = List<HealthDataAccess>.filled(
        supportedTypes.length,
        HealthDataAccess.READ,
      );

      final hasPerms = await health.hasPermissions(
        supportedTypes,
        permissions: permissions,
      );
      if (hasPerms != true) {
        if (!requestPermissions) return null;
        if (_healthPermissionRequestInFlight) return null;
        _healthPermissionRequestInFlight = true;
        final granted = await health.requestAuthorization(
          supportedTypes,
          permissions: permissions,
        );
        _healthPermissionRequestInFlight = false;
        if (!granted) return null;
      }

      final now = DateTime.now();
      final lookback = Platform.isAndroid
          ? now.subtract(const Duration(days: 30))
          : DateTime(now.year - 2, now.month, now.day);
      double? restingHr;
      if (supportedTypes.contains(HealthDataType.RESTING_HEART_RATE)) {
        final restingPoints = await health.getHealthDataFromTypes(
          types: [HealthDataType.RESTING_HEART_RATE],
          startTime: lookback,
          endTime: now,
        );
        debugPrint(
          'Health: RESTING_HEART_RATE points (recent window)=${restingPoints.length}',
        );
        restingHr = _latestNumericValueForType(
          restingPoints,
          HealthDataType.RESTING_HEART_RATE,
        );
        if (restingHr == null && Platform.isAndroid) {
          // Some users only have occasional resting HR summaries older than 30d.
          // Try a longer window; if Health Connect blocks it without history access,
          // this will fail and we silently keep the fallback behavior.
          try {
            final olderPoints = await health.getHealthDataFromTypes(
              types: [HealthDataType.RESTING_HEART_RATE],
              startTime: now.subtract(const Duration(days: 365)),
              endTime: now,
            );
            debugPrint(
              'Health: RESTING_HEART_RATE points (365d window)=${olderPoints.length}',
            );
            restingHr = _latestNumericValueForType(
              olderPoints,
              HealthDataType.RESTING_HEART_RATE,
            );
          } catch (e) {
            debugPrint('Health: extended RESTING_HEART_RATE read failed: $e');
          }
        }
        debugPrint('Health: selected resting HR=$restingHr');
      }

      DateTime? birthDate;
      if (supportedTypes.contains(HealthDataType.BIRTH_DATE)) {
        final birthPoints = await health.getHealthDataFromTypes(
          types: [HealthDataType.BIRTH_DATE],
          startTime: DateTime(1900, 1, 1),
          endTime: now,
        );
        birthDate = _extractBirthDate(birthPoints);
      }

      final ageYears = birthDate != null
          ? _calculateAgeYears(birthDate, now)
          : null;
      final estimatedMaxHr = ageYears != null
          ? (220 - ageYears).clamp(140, 220)
          : 200;
      debugPrint(
        'Health: zone profile ageYears=$ageYears estimatedMaxHr=$estimatedMaxHr birthDate=$birthDate',
      );

      return HeartRateZoneProfile(
        birthDate: birthDate,
        ageYears: ageYears,
        restingHeartRateBpm: restingHr,
        estimatedMaxHeartRateBpm: estimatedMaxHr,
      );
    } catch (e, st) {
      _healthPermissionRequestInFlight = false;
      debugPrint('Health: readHeartRateZoneProfile failed: $e\n$st');
      return null;
    }
  }

  static double? _latestNumericValueForType(
    List<HealthDataPoint> points,
    HealthDataType type,
  ) {
    final matches = points.where((p) => p.type == type).toList()
      ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
    for (final point in matches) {
      final v = _numericValue(point);
      if (v != null && v > 0) return v.toDouble();
    }
    return null;
  }

  static num? _numericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) return value.numericValue;
    final json = value.toJson();
    final dynamic numeric = json['numericValue'];
    if (numeric is num) return numeric;
    return null;
  }

  static DateTime? _extractBirthDate(List<HealthDataPoint> points) {
    for (final point in points) {
      final from = point.dateFrom;
      if (_looksLikeBirthDate(from)) {
        return DateTime(from.year, from.month, from.day);
      }

      final numeric = _numericValue(point);
      final parsedFromNumeric = _birthDateFromNumeric(numeric);
      if (parsedFromNumeric != null) return parsedFromNumeric;

      final metadata = point.metadata;
      if (metadata != null) {
        final year = _toInt(metadata['year']);
        final month = _toInt(metadata['month']) ?? 1;
        final day = _toInt(metadata['day']) ?? 1;
        if (year != null && year >= 1900 && year <= DateTime.now().year) {
          return DateTime(year, month.clamp(1, 12), day.clamp(1, 31));
        }
      }
    }
    return null;
  }

  static bool _looksLikeBirthDate(DateTime dt) {
    final now = DateTime.now();
    return dt.year >= 1900 &&
        dt.isBefore(now) &&
        now.difference(dt).inDays > 3650;
  }

  static DateTime? _birthDateFromNumeric(num? value) {
    if (value == null) return null;
    final now = DateTime.now();

    if (value >= 1900 && value <= now.year) {
      return DateTime(value.toInt(), 1, 1);
    }
    if (value > 1000000000000) {
      final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      return _looksLikeBirthDate(dt)
          ? DateTime(dt.year, dt.month, dt.day)
          : null;
    }
    if (value > 1000000000) {
      final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000);
      return _looksLikeBirthDate(dt)
          ? DateTime(dt.year, dt.month, dt.day)
          : null;
    }
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int _calculateAgeYears(DateTime birthDate, DateTime now) {
    var age = now.year - birthDate.year;
    final hadBirthdayThisYear =
        (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthdayThisYear) age -= 1;
    return age.clamp(1, 120);
  }
}
