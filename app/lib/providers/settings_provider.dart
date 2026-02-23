import 'package:fixnum/fixnum.dart' as fixnum;
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
  List<TrainingProgramDefinition> _trainingPrograms = const [];
  TrainingProgramState? _programState;
  bool _loaded = false;

  SettingsProvider(this._grpcClient);

  Map<double, Color> get plateColors => _plateColors;
  bool get loaded => _loaded;
  TrainingProgramState? get programState => _programState;

  /// True once the user has saved a training program state (i.e. completed onboarding).
  bool get hasProgramState =>
      _programState != null && _programState!.updatedAt > 0;

  List<TrainingProgramDefinition> get trainingPrograms =>
      List.unmodifiable(_trainingPrograms);
  bool get hasTrainingProgramCatalog => _trainingPrograms.isNotEmpty;

  TrainingProgramDefinition? trainingProgramFor(RegimeType type) {
    try {
      return _trainingPrograms.firstWhere((p) => p.regimeType == type);
    } catch (_) {
      return null;
    }
  }

  TrainingProgramDefinition? trainingProgramForInt(int regimeTypeValue) {
    try {
      return _trainingPrograms.firstWhere(
        (p) => p.regimeType.value == regimeTypeValue,
      );
    } catch (_) {
      return null;
    }
  }

  Color plateColor(double weight) {
    return _plateColors[weight] ?? Colors.purple;
  }

  Future<void> load() async {
    _programState = null;
    _trainingPrograms = const [];
    _loaded = false;
    notifyListeners();
    try {
      // Load catalog
      final catalog = await _grpcClient.settingsService
          .getTrainingProgramCatalog(GetTrainingProgramCatalogRequest());
      _trainingPrograms = [...catalog.programs]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // Load user settings (plate colors)
      final response = await _grpcClient.settingsService.getSettings(
        GetSettingsRequest(),
      );
      for (final setting in response.settings) {
        if (setting.whichSetting() == UserSetting_Setting.plateColors) {
          _applyPlateColors(setting.plateColors);
        }
      }

      // Load training program state
      final stateRes = await _grpcClient.settingsService
          .getActiveTrainingProgramState(
            GetActiveTrainingProgramStateRequest(),
          );
      if (stateRes.hasState()) _programState = stateRes.state;

      _loaded = true;
      notifyListeners();
    } catch (e) {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> refreshActiveTrainingProgramState() async {
    try {
      final stateRes = await _grpcClient.settingsService
          .getActiveTrainingProgramState(
            GetActiveTrainingProgramStateRequest(),
          );
      _programState = stateRes.hasState() ? stateRes.state : null;
      notifyListeners();
    } catch (_) {
      // Keep existing cached state on refresh failure.
    }
  }

  void clear() {
    _plateColors = defaultPlateColors();
    _programState = null;
    _trainingPrograms = const [];
    _loaded = false;
    notifyListeners();
  }

  /// Save a new training program state (onboarding or manual edit).
  Future<List<String>> setActiveTrainingProgramState({
    required RegimeType regimeType,
    required Map<String, StateFieldValue> fields,
    String source = 'manual_edit',
  }) async {
    final req = SetActiveTrainingProgramStateRequest(
      regimeType: regimeType,
      fields: fields.entries,
      source: source,
    );
    final res = await _grpcClient.settingsService.setActiveTrainingProgramState(
      req,
    );
    if (res.hasState()) _programState = res.state;
    notifyListeners();
    return res.validationWarnings;
  }

  /// Apply a pending state update (e.g. weight progression prompt).
  Future<void> applyPendingStateUpdate({
    required String updateId,
    required Map<String, StateFieldValue> fieldValues,
  }) async {
    final req = ApplyPendingStateUpdateRequest(
      updateId: updateId,
      fieldValues: fieldValues.entries,
    );
    final res = await _grpcClient.settingsService.applyPendingStateUpdate(req);
    if (res.hasState()) _programState = res.state;
    notifyListeners();
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

  /// Build a [StateFieldValue] from a text controller value based on field kind.
  static StateFieldValue? fieldValueFromText(
    TrainingProgramStateFieldSchema field,
    String text,
  ) {
    final kind = field.kind;
    if (kind == StateFieldKind.STATE_FIELD_KIND_FLOAT) {
      final v = double.tryParse(text);
      if (v == null) return null;
      return StateFieldValue(floatVal: v);
    } else if (kind == StateFieldKind.STATE_FIELD_KIND_INT) {
      final v = int.tryParse(text);
      if (v == null) return null;
      return StateFieldValue(intVal: fixnum.Int64(v));
    } else if (kind == StateFieldKind.STATE_FIELD_KIND_BOOL) {
      return StateFieldValue(boolVal: text.toLowerCase() == 'true');
    } else {
      // STRING or ENUM
      if (text.isEmpty) return null;
      return StateFieldValue(stringVal: text);
    }
  }

  /// Get the display string for a [StateFieldValue].
  static String fieldValueToText(StateFieldValue? v) {
    if (v == null) return '';
    switch (v.whichValue()) {
      case StateFieldValue_Value.floatVal:
        return v.floatVal.toStringAsFixed(0);
      case StateFieldValue_Value.intVal:
        return v.intVal.toString();
      case StateFieldValue_Value.boolVal:
        return v.boolVal ? 'true' : 'false';
      case StateFieldValue_Value.stringVal:
        return v.stringVal;
      default:
        return '';
    }
  }
}
