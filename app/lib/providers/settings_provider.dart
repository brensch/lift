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

  /// The colours the user recorded, keyed by plate (of whichever unit they
  /// chose them in).
  Map<double, Color> _chosenColors = {};
  Map<double, Color> _plateColors = defaultPlateColors();
  WeightUnit _weightUnit = WeightUnit.WEIGHT_UNIT_LB;

  SettingsProvider(this._account);

  Map<double, Color> get plateColors => _plateColors;
  WeightUnit get weightUnit => _weightUnit;

  Color plateColor(double weight) {
    return _plateColors[weight] ?? Colors.purple;
  }

  /// Every plate of [unit]: the user's colour where they chose one, the
  /// unit's default otherwise.
  static Map<double, Color> _colorsFor(
    WeightUnit unit,
    Map<double, Color> chosen,
  ) => {
    for (final MapEntry(key: plate, value: fallback) in defaultPlateColors(
      unit,
    ).entries)
      plate: chosen[plate] ?? fallback,
  };

  /// Reads the settings from the account. If that fails, what is shown
  /// stays as it was.
  Future<void> load() async {
    final List<UserSetting> settings;
    try {
      settings = await _account.getSettings();
    } catch (e) {
      AppLogger.instance.warn('Settings', 'load failed', {
        'error': e.toString(),
      });
      return;
    }
    var unit = WeightUnit.WEIGHT_UNIT_LB;
    var chosen = <double, Color>{};
    for (final setting in settings) {
      if (setting.whichSetting() == UserSetting_Setting.plateColors) {
        chosen = _parsePlateColors(setting.plateColors);
      } else if (setting.whichSetting() == UserSetting_Setting.weightUnit) {
        unit = setting.weightUnit.unit;
      }
    }
    _weightUnit = unit;
    _chosenColors = chosen;
    _plateColors = _colorsFor(unit, chosen);
    notifyListeners();
  }

  void clear() {
    _weightUnit = WeightUnit.WEIGHT_UNIT_LB;
    _chosenColors = {};
    _plateColors = defaultPlateColors(_weightUnit);
    notifyListeners();
  }

  /// Shows [unit] without recording it (onboarding records it through
  /// CompleteOnboarding).
  void applyWeightUnitLocally(WeightUnit unit) {
    if (_weightUnit == unit) return;
    _weightUnit = unit;
    _plateColors = _colorsFor(unit, _chosenColors);
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
    _chosenColors = Map.from(colors);
    _plateColors = _colorsFor(_weightUnit, _chosenColors);
    notifyListeners();

    final config = PlateColorsConfig(
      plates: colors.entries
          .map((e) => PlateColor(weight: e.key, hexColor: colorHex(e.value)))
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

  static Map<double, Color> _parsePlateColors(PlateColorsConfig config) => {
    for (final plate in config.plates)
      plate.weight: ?colorFromHex(plate.hexColor),
  };
}
