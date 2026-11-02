import 'dart:async';

import 'package:flutter/material.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../logic/user_profile.dart';
import '../logic/weight_units.dart';
import '../services/app_logger.dart';
import '../services/workout_service.dart';

class SettingsProvider extends ChangeNotifier {
  /// Settings are part of the account, on this phone.
  final WorkoutServiceWrapper _account;

  static Map<double, Color> defaultPlateColors([
    WeightUnit unit = WeightUnit.WEIGHT_UNIT_LB,
  ]) => isMetricUnit(unit)
      ? {
          25: Colors.red,
          20: Colors.blue,
          15: const Color(0xFFFFEB3B),
          10: Colors.green,
          5: const Color(0xFF616161),
          2.5: const Color(0xFFBDBDBD),
          1.25: const Color(0xFFE0E0E0),
        }
      : {
          45: Colors.red,
          35: Colors.blue,
          25: const Color(0xFFFFEB3B),
          10: Colors.green,
          5: const Color(0xFF616161),
          2.5: const Color(0xFFBDBDBD),
        };

  Map<double, Color> _plateColors = defaultPlateColors();
  WeightUnit _weightUnit = WeightUnit.WEIGHT_UNIT_LB;

  SettingsProvider(this._account);

  Map<double, Color> get plateColors => _plateColors;
  WeightUnit get weightUnit => _weightUnit;

  Color plateColor(double weight) {
    return _plateColors[weight] ?? Colors.purple;
  }

  Future<void> load() async {
    _weightUnit = WeightUnit.WEIGHT_UNIT_LB;
    _plateColors = defaultPlateColors(_weightUnit);
    notifyListeners();
    try {
      for (final setting in await _account.getSettings()) {
        if (setting.whichSetting() == UserSetting_Setting.plateColors) {
          _applyPlateColors(setting.plateColors);
        } else if (setting.whichSetting() == UserSetting_Setting.weightUnit) {
          _weightUnit = setting.weightUnit.unit;
        }
      }
      if (_plateColors.isEmpty) {
        _plateColors = defaultPlateColors(_weightUnit);
      }
    } catch (e) {
      AppLogger.instance.warn('Settings', 'load failed', {
        'error': e.toString(),
      });
    }
    notifyListeners();
  }

  void clear() {
    _weightUnit = WeightUnit.WEIGHT_UNIT_LB;
    _plateColors = defaultPlateColors(_weightUnit);
    notifyListeners();
  }

  /// Shows [unit] without recording it (onboarding records it through
  /// CompleteOnboarding).
  void applyWeightUnitLocally(WeightUnit unit) {
    if (_weightUnit == unit) return;
    _weightUnit = unit;
    if (_plateColors.isEmpty ||
        _plateColors.keys.every(
          (k) => !defaultPlateColors(unit).containsKey(k),
        )) {
      _plateColors = defaultPlateColors(unit);
    }
    notifyListeners();
  }

  Future<void> updateWeightUnit(WeightUnit unit) async {
    if (_weightUnit == unit) return;
    applyWeightUnitLocally(unit);

    try {
      await _account.updateSetting(
        UserSetting(weightUnit: WeightUnitConfig(unit: unit)),
      );
    } catch (e) {
      AppLogger.instance.warn('Settings', 'weight unit update failed', {
        'error': e.toString(),
      });
    }
  }

  Future<void> updatePlateColors(Map<double, Color> colors) async {
    _plateColors = Map.from(colors);
    notifyListeners();

    final config = PlateColorsConfig(
      plates: colors.entries
          .map((e) => PlateColor(weightKg: e.key, hexColor: colorHex(e.value)))
          .toList(),
    );

    try {
      await _account.updateSetting(UserSetting(plateColors: config));
    } catch (e) {
      AppLogger.instance.warn('Settings', 'plate colours update failed', {
        'error': e.toString(),
      });
    }
  }

  void _applyPlateColors(PlateColorsConfig config) {
    final Map<double, Color> colors = {};
    for (final plate in config.plates) {
      final color = colorFromHex(plate.hexColor);
      if (color != null) {
        colors[plate.weightKg] = color;
      }
    }
    if (colors.isNotEmpty) {
      _plateColors = colors;
    }
  }
}
