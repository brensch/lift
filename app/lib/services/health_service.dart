import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'app_logger.dart';

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
  // MET value for traditional strength training from the 2011 Compendium of
  // Physical Activities (Ainsworth et al., Med Sci Sports Exerc 43(8):1575-81).
  // MET formula: calories = MET × 3.5 × body_weight_kg × duration_min / 200
  static const _strengthTrainingMet = 3.5;
  // Fallback flat rate when bodyweight is unknown (conservative estimate).
  static const _fallbackKcalPerMin = 5.0;

  static Future<HeartRateZoneProfile?>? _cachedZoneProfileFuture;
  static bool _healthPermissionRequestInFlight = false;
  static bool _workoutHealthPermissionsRequested = false;

  /// Set true by the e2e harness before the app launches. When true, the methods
  /// that proactively prompt for Health permissions no-op: on the emulator those
  /// requests open the native Health Connect sheet, which pauses the Flutter
  /// surface and hangs an integration_test. Health isn't under test there, so
  /// suppressing the prompt is safe. Always false in production.
  @visibleForTesting
  static bool suppressPermissionPrompts = false;

  /// Requests every Health permission the workout flow uses, in a SINGLE system
  /// sheet, at most once per app run.
  ///
  /// This is the ONLY place that proactively prompts. iOS HealthKit hides
  /// read-permission status (`hasPermissions` returns null for reads), so checking it
  /// before each read/write makes the app re-request forever; and firing several
  /// separate authorization requests (live HR read, HR-sample write, workout write,
  /// resting HR, …) makes iOS present a cascade of sheets that appear to "reset" when
  /// you grant them. We ask for the full union once, up front, then never prompt
  /// again — every other read/write simply attempts the operation and silently
  /// no-ops if the user declined.
  ///
  /// `requestAuthorization` is idempotent: on later app runs it presents no sheet for
  /// already-decided types, so calling this again is harmless.
  static Future<void> requestWorkoutHealthPermissions() async {
    if (suppressPermissionPrompts) return;
    if (_workoutHealthPermissionsRequested) return;
    // Another request is mid-flight; don't stack a competing sheet. Retry next time.
    if (_healthPermissionRequestInFlight) return;
    _workoutHealthPermissionsRequested = true;
    _healthPermissionRequestInFlight = true;
    try {
      final health = Health();
      await health.configure();

      final types = <HealthDataType>[];
      final access = <HealthDataAccess>[];
      void want(HealthDataType type, HealthDataAccess accessLevel) {
        if (health.isDataTypeAvailable(type)) {
          types.add(type);
          access.add(accessLevel);
        }
      }

      // Live HR from the watch (read) + saving HR samples into the workout (write).
      want(HealthDataType.HEART_RATE, HealthDataAccess.READ_WRITE);
      want(HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataAccess.READ_WRITE);
      // Saving the completed workout. writeWorkoutData batches the exercise
      // session together with a TotalCaloriesBurned record in a single insert, so
      // without the total-calories write grant the WHOLE workout write is rejected
      // (SecurityException) and nothing reaches Health Connect. Request it here so
      // the user is actually prompted for it — declaring it in the manifest alone
      // is not enough.
      want(HealthDataType.WORKOUT, HealthDataAccess.WRITE);
      want(HealthDataType.TOTAL_CALORIES_BURNED, HealthDataAccess.WRITE);
      // Heart-rate zone chart inputs.
      want(HealthDataType.RESTING_HEART_RATE, HealthDataAccess.READ);
      if (Platform.isIOS) {
        want(HealthDataType.BIRTH_DATE, HealthDataAccess.READ);
      }
      // Body-weight import for calorie maths.
      want(HealthDataType.WEIGHT, HealthDataAccess.READ);

      if (types.isEmpty) return;
      AppLogger.instance.info('Health', 'requestWorkoutHealthPermissions', {
        'types': types.map((t) => t.name).toList(),
      });
      await health.requestAuthorization(types, permissions: access);
    } catch (e, st) {
      debugPrint('Health: requestWorkoutHealthPermissions failed: $e\n$st');
      // Allow a retry on a later workout if it threw before prompting.
      _workoutHealthPermissionsRequested = false;
    } finally {
      _healthPermissionRequestInFlight = false;
    }
  }

  static Future<double?> readLatestBodyWeightKg({
    bool requestPermissions = false,
  }) async {
    // e2e: never open the native Health sheet (see suppressPermissionPrompts).
    if (suppressPermissionPrompts && requestPermissions) return null;
    try {
      AppLogger.instance.info('Health', 'readLatestBodyWeightKg', {
        'phase': 'start',
        'requestPermissions': requestPermissions,
        'platform': Platform.isAndroid
            ? 'android'
            : Platform.isIOS
            ? 'ios'
            : 'other',
      });
      final health = Health();
      await health.configure();

      const type = HealthDataType.WEIGHT;
      if (!health.isDataTypeAvailable(type)) {
        AppLogger.instance.warn('Health', 'weight unavailable');
        return null;
      }

      final permissions = [HealthDataAccess.READ];
      final hasPerms = await health.hasPermissions([
        type,
      ], permissions: permissions);
      AppLogger.instance.info('Health', 'weight permissions', {
        'hasPerms': hasPerms,
      });
      if (hasPerms != true) {
        if (!requestPermissions) return null;
        if (_healthPermissionRequestInFlight) return null;
        _healthPermissionRequestInFlight = true;
        final granted = await health.requestAuthorization([
          type,
        ], permissions: permissions);
        _healthPermissionRequestInFlight = false;
        AppLogger.instance.info('Health', 'weight permission request', {
          'granted': granted,
        });
        if (!granted) return null;
      }

      final now = DateTime.now();
      final recentPoints = await health.getHealthDataFromTypes(
        types: [type],
        startTime: now.subtract(const Duration(days: 30)),
        endTime: now,
      );
      double? weightKg = _latestNumericValueForType(recentPoints, type);
      AppLogger.instance.info('Health', 'weight recent read', {
        'points': recentPoints.length,
        'weightKg': weightKg,
      });

      if (weightKg == null && Platform.isAndroid) {
        try {
          final historicalPoints = await health.getHealthDataFromTypes(
            types: [type],
            startTime: now.subtract(const Duration(days: 365)),
            endTime: now,
          );
          weightKg = _latestNumericValueForType(historicalPoints, type);
          AppLogger.instance.info('Health', 'weight historical read', {
            'points': historicalPoints.length,
            'weightKg': weightKg,
          });
        } catch (e) {
          debugPrint('Health: extended WEIGHT read failed: $e');
          AppLogger.instance.warn('Health', 'weight historical read failed', {
            'error': e.toString(),
          });
        }
      }

      AppLogger.instance.info('Health', 'readLatestBodyWeightKg', {
        'phase': 'done',
        'weightKg': weightKg,
      });
      return weightKg != null && weightKg > 0 ? weightKg : null;
    } catch (e, st) {
      _healthPermissionRequestInFlight = false;
      debugPrint('Health: readLatestBodyWeightKg failed: $e\n$st');
      AppLogger.instance.error('Health', 'readLatestBodyWeightKg failed', {
        'error': e.toString(),
      });
      return null;
    }
  }

  static int estimateCalories({
    required double durationMinutes,
    required double bodyWeightKg,
  }) {
    if (bodyWeightKg > 0) {
      return (_strengthTrainingMet * 3.5 * bodyWeightKg * durationMinutes / 200)
          .round();
    }
    return (durationMinutes * _fallbackKcalPerMin).round();
  }

  static Future<HealthWriteResult> writeCompletedWorkout({
    required DateTime startTime,
    required DateTime endTime,
    required String title,
    required double totalVolumeKg,
    required int workingSets,
    required double bodyWeightKg,
  }) async {
    debugPrint('Health: writeCompletedWorkout called');

    final health = Health();
    await health.configure();
    debugPrint('Health: configured');

    // Auth is requested once, comprehensively (see requestWorkoutHealthPermissions),
    // normally at workout start. Ensure it has run at least once (e.g. for a resumed
    // workout ended in a fresh app run), then just attempt the write — we never
    // re-prompt per write.
    await requestWorkoutHealthPermissions();

    final durationMinutes = endTime.difference(startTime).inSeconds / 60.0;
    final calories = estimateCalories(
      durationMinutes: durationMinutes,
      bodyWeightKg: bodyWeightKg,
    );

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

    // Note: we deliberately do NOT read the workout back in-app to "confirm" it.
    // The health plugin's workout read pulls associated Distance/Steps/Calories
    // records too, which would force this strength-training app to request
    // READ_DISTANCE/READ_STEPS — permissions it has no business asking for. A
    // successful insert (result=true) is Health Connect's own confirmation that
    // the record was stored; readability was verified out-of-band via the Health
    // Connect UI. Sync status is surfaced to the user in Settings instead.
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

    // Heart-rate write access is part of the single comprehensive request made at
    // workout start. Ensure it has run once, then just attempt the writes — no
    // per-write permission prompt (that caused the repeating "write heart rate" sheet).
    await requestWorkoutHealthPermissions();

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
