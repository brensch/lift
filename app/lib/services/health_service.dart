import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

enum HealthWriteResult { success, permissionDenied, error }

class HealthService {
  static const _kcalPerMinute = 5.0;

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

    final types = [HealthDataType.WORKOUT, HealthDataType.TOTAL_CALORIES_BURNED];
    final permissions = [HealthDataAccess.WRITE, HealthDataAccess.WRITE];

    final hasPerms = await health.hasPermissions(types, permissions: permissions);
    debugPrint('Health: hasPermissions=$hasPerms');

    if (hasPerms != true) {
      debugPrint('Health: requesting authorization...');
      final authorized = await health.requestAuthorization(types, permissions: permissions);
      debugPrint('Health: authorization result=$authorized');
      if (!authorized) {
        debugPrint('Health: authorization denied, skipping write');
        return HealthWriteResult.permissionDenied;
      }
    }

    final durationMinutes = endTime.difference(startTime).inSeconds / 60.0;
    final calories = (durationMinutes * _kcalPerMinute).round();

    debugPrint('Health: writing workout "$title", ${durationMinutes.toStringAsFixed(1)} min, $calories kcal');

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
}
