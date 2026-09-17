import 'dart:async';

import 'package:flutter/material.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/settings.pbgrpc.dart';
import '../logic/weight_units.dart';
import '../services/app_logger.dart';
import '../services/grpc_client.dart';

class SettingsProvider extends ChangeNotifier {
  final GrpcClient _grpcClient;

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
  bool _loaded = false;

  bool _loadRetryScheduled = false;

  SettingsProvider(this._grpcClient);

  Map<double, Color> get plateColors => _plateColors;
  WeightUnit get weightUnit => _weightUnit;
  bool get loaded => _loaded;

  Color plateColor(double weight) {
    return _plateColors[weight] ?? Colors.purple;
  }

  Future<void> load() async {
    _weightUnit = WeightUnit.WEIGHT_UNIT_LB;
    _plateColors = defaultPlateColors(_weightUnit);
    _loaded = false;
    notifyListeners();
    try {
      final response = await retryReadAfterReconnect(
        operation: 'GetSettings',
        resetChannel: _grpcClient.resetChannel,
        rpc: () =>
            _grpcClient.settingsService.getSettings(GetSettingsRequest()),
      );
      for (final setting in response.settings) {
        if (setting.whichSetting() == UserSetting_Setting.plateColors) {
          _applyPlateColors(setting.plateColors);
        } else if (setting.whichSetting() == UserSetting_Setting.weightUnit) {
          _weightUnit = setting.weightUnit.unit;
        }
      }
      if (_plateColors.isEmpty) {
        _plateColors = defaultPlateColors(_weightUnit);
      }

      _loadRetryScheduled = false;
      _loaded = true;
      notifyListeners();
    } catch (e) {
      AppLogger.instance.warn('Settings', 'load failed, will retry', {
        'error': e.toString(),
      });
      _loaded = true;
      notifyListeners();
      _scheduleLoadRetry();
    }
  }

  void _scheduleLoadRetry() {
    if (_loadRetryScheduled) return;
    _loadRetryScheduled = true;
    Timer(const Duration(seconds: 5), () {
      _loadRetryScheduled = false;
      load();
    });
  }

  void clear() {
    _weightUnit = WeightUnit.WEIGHT_UNIT_LB;
    _plateColors = defaultPlateColors(_weightUnit);
    _loaded = false;
    notifyListeners();
  }

  /// Applied locally right away (onboarding uses this before the server
  /// round-trips through CompleteOnboarding).
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
      await _grpcClient.settingsService.updateSetting(
        UpdateSettingRequest(
          setting: UserSetting(weightUnit: WeightUnitConfig(unit: unit)),
        ),
      );
    } catch (_) {
      // Optimistic update already applied.
    }
  }

  Future<void> updatePlateColors(Map<double, Color> colors) async {
    _plateColors = Map.from(colors);
    notifyListeners();

    final config = PlateColorsConfig(
      plates: colors.entries
          .map(
            (e) => PlateColor(weightKg: e.key, hexColor: _colorToHex(e.value)),
          )
          .toList(),
    );

    try {
      await _grpcClient.settingsService.updateSetting(
        UpdateSettingRequest(setting: UserSetting(plateColors: config)),
      );
    } catch (e) {
      // Optimistic update already applied
    }
  }

  void _applyPlateColors(PlateColorsConfig config) {
    final Map<double, Color> colors = {};
    for (final plate in config.plates) {
      final color = _hexToColor(plate.hexColor);
      if (color != null) {
        colors[plate.weightKg] = color;
      }
    }
    if (colors.isNotEmpty) {
      _plateColors = colors;
    }
  }

  static Color? _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value == null) return null;
      return Color.fromARGB(
        255,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      );
    }
    return null;
  }

  static String _colorToHex(Color color) {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }
}
