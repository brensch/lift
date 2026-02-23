import 'package:flutter/material.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/settings.pbgrpc.dart';
import '../services/grpc_client.dart';

class SettingsProvider extends ChangeNotifier {
  final GrpcClient _grpcClient;

  static Map<double, Color> defaultPlateColors() => {
    45: Colors.red,
    35: Colors.blue,
    25: const Color(0xFFFFEB3B), // yellow
    10: Colors.green,
    5: const Color(0xFF616161), // dark grey
    2.5: const Color(0xFFBDBDBD), // light grey
  };

  Map<double, Color> _plateColors = defaultPlateColors();

  UserWorkoutConfig? _workoutConfig;
  bool _loaded = false;

  SettingsProvider(this._grpcClient);

  Map<double, Color> get plateColors => _plateColors;
  bool get loaded => _loaded;
  UserWorkoutConfig? get workoutConfig => _workoutConfig;
  bool get hasWorkoutConfig => _workoutConfig != null;

  Color plateColor(double weight) {
    return _plateColors[weight] ?? Colors.purple;
  }

  Future<void> load() async {
    // Reset workout config before reload so missing settings don't leave stale
    // in-memory values around (important for fresh signup/login flows).
    _workoutConfig = null;
    _loaded = false;
    notifyListeners();
    try {
      final response = await _grpcClient.settingsService
          .getSettings(GetSettingsRequest());
      for (final setting in response.settings) {
        if (setting.whichSetting() == UserSetting_Setting.plateColors) {
          _applyPlateColors(setting.plateColors);
        } else if (setting.whichSetting() == UserSetting_Setting.workoutConfig) {
          _workoutConfig = setting.workoutConfig;
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      // If settings can't be loaded, use defaults
      _loaded = true;
      notifyListeners();
    }
  }

  void clear() {
    _plateColors = defaultPlateColors();
    _workoutConfig = null;
    _loaded = false;
    notifyListeners();
  }

  Future<void> updateWorkoutConfig(UserWorkoutConfig config) async {
    _workoutConfig = config;
    notifyListeners();
    try {
      await _grpcClient.settingsService.updateSetting(
        UpdateSettingRequest(
          setting: UserSetting(workoutConfig: config),
        ),
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

  Future<void> updatePlateColors(Map<double, Color> colors) async {
    _plateColors = Map.from(colors);
    notifyListeners();

    final config = PlateColorsConfig(
      plates: colors.entries.map((e) => PlateColor(
        weightKg: e.key,
        hexColor: _colorToHex(e.value),
      )).toList(),
    );

    try {
      await _grpcClient.settingsService.updateSetting(
        UpdateSettingRequest(
          setting: UserSetting(plateColors: config),
        ),
      );
    } catch (e) {
      // Optimistic update already applied
    }
  }

  static Color? _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value == null) return null;
      return Color.fromARGB(255, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
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
