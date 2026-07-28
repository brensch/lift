import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import '../../gen/workout/v1/settings.pb.dart';
import '../../logic/user_profile.dart';
import '../../logic/whimsical_emojis.dart';
import '../../logic/weight_units.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/grpc_client.dart';
import '../../services/app_logger.dart';
import '../../services/health_service.dart';
import '../../services/user_service.dart';
import '../regime_info_screen.dart';
import 'steps/config_step.dart';
import 'steps/confirm_step.dart';
import 'steps/marker_step.dart';
import 'steps/program_step.dart';
import 'steps/unit_step.dart';

enum ExperienceLevel { cute, beginner, intermediate, expert }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _emojiWindowSize = 18;
  int _step = 0;
  RegimeType? _selectedRegimeType;
  final Map<String, TextEditingController> _controllers = {};
  late final TextEditingController _bodyWeightController;
  bool _isSaving = false;
  bool _initialized = false;
  bool _profileLoaded = false;
  bool _profileTouched = false;
  bool _syncingBodyWeightText = false;
  bool _isImportingBodyWeight = false;
  late String _selectedEmoji;
  late String _selectedColorHex;
  String _bodyWeightHint =
      'We use your bodyweight to estimate calories burned for each workout.';
  ExperienceLevel _experienceLevel = ExperienceLevel.intermediate;
  late List<String> _emojiChoices;

  @override
  void initState() {
    super.initState();
    _bodyWeightController = TextEditingController();
    _bodyWeightController.addListener(_onBodyWeightChanged);
    final rng = Random();
    final shuffled = [...whimsicalEmojiCatalog]..shuffle(rng);
    _emojiChoices = shuffled.take(_emojiWindowSize).toList();
    _selectedEmoji = _emojiChoices[rng.nextInt(_emojiWindowSize)];
    _selectedColorHex =
        profileColorHexOptions[rng.nextInt(profileColorHexOptions.length)];
  }

  void _goToStep(int nextStep) {
    if (_step == nextStep) return;
    setState(() => _step = nextStep);
    if (nextStep == 3) {
      unawaited(_prepareConfigStep());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _bodyWeightController
      ..removeListener(_onBodyWeightChanged)
      ..dispose();
    super.dispose();
  }

  void _initFromCatalog(SettingsProvider provider) {
    if (_initialized || !provider.loaded || provider.trainingPrograms.isEmpty) {
      return;
    }
    final first = provider.trainingPrograms.first;
    _selectedRegimeType = first.regimeType;
    _seedFromSchema(first.stateSchema.fields);
    _initialized = true;
  }

  void _seedFromSchema(List<TrainingProgramStateFieldSchema> fields) {
    for (final f in fields) {
      if (!f.onboardingField) continue;
      _controllers.putIfAbsent(f.key, () => TextEditingController());
      _controllers[f.key]!.text = _defaultTextForField(f);
    }
  }

  String _defaultTextForField(TrainingProgramStateFieldSchema f) {
    if (f.kind == StateFieldKind.STATE_FIELD_KIND_FLOAT) {
      final provider = context.read<SettingsProvider>();
      final value = SettingsProvider.isWeightField(f)
          ? snapDisplayWeight(
              displayWeightFromPounds(f.minValue, provider.weightUnit),
              provider.weightUnit,
              poundStep: f.step,
              kilogramStep: SettingsProvider.displayStepForField(
                f,
                provider.weightUnit,
              ),
            )
          : f.minValue;
      if (value <= 0) return '';
      return value % 1 == 0
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
    } else if (f.kind == StateFieldKind.STATE_FIELD_KIND_INT) {
      return f.minValue.toInt().toString();
    } else if (f.kind == StateFieldKind.STATE_FIELD_KIND_ENUM) {
      return f.enumOptions.isNotEmpty ? f.enumOptions.first.value : '';
    }
    return '';
  }

  void _selectProgram(TrainingProgramDefinition p) {
    setState(() {
      _selectedRegimeType = p.regimeType;
      // Re-seed controllers for new program's onboarding fields
      final fields = p.stateSchema.fields
          .where((f) => f.onboardingField)
          .toList();
      for (final f in fields) {
        if (!_controllers.containsKey(f.key)) {
          _controllers[f.key] = TextEditingController(
            text: _defaultTextForField(f),
          );
        }
      }
    });
    _applyRecommendedWeights(context.read<SettingsProvider>(), p);
  }

  Future<void> _selectWeightUnit(
    SettingsProvider provider,
    WeightUnit unit,
  ) async {
    // Capture the entered bodyweight in canonical kg while the OLD unit is still
    // active. If we changed the unit first, `_parsedBodyWeightKg` would re-read
    // the same digits as the new unit (180 lb silently becoming 180 kg).
    final currentKg = _parsedBodyWeightKg(provider);
    await provider.updateWeightUnit(unit);
    if (currentKg != null && currentKg > 0) {
      _setBodyWeightText(currentKg, unit);
    }
    final selectedProgram = _selectedRegimeType == null
        ? null
        : provider.trainingProgramFor(_selectedRegimeType!);
    if (selectedProgram != null) {
      _seedFromSchema(selectedProgram.stateSchema.fields);
      _applyRecommendedWeights(provider, selectedProgram);
    }
  }

  void _onBodyWeightChanged() {
    if (_syncingBodyWeightText || !mounted) return;
    final provider = context.read<SettingsProvider>();
    final program = _selectedRegimeType == null
        ? null
        : provider.trainingProgramFor(_selectedRegimeType!);
    if (program != null) {
      _applyRecommendedWeights(provider, program);
    }
  }

  double? _parsedBodyWeightKg(SettingsProvider provider) {
    final raw = double.tryParse(_bodyWeightController.text.trim());
    if (raw == null || raw <= 0) return null;
    return isMetricUnit(provider.weightUnit) ? raw : poundsToKilograms(raw);
  }

  void _setBodyWeightText(double kg, WeightUnit unit) {
    final display = isMetricUnit(unit) ? kg : kilogramsToPounds(kg);
    final text = display % 1 == 0
        ? display.toStringAsFixed(0)
        : display.toStringAsFixed(1);
    _syncingBodyWeightText = true;
    _bodyWeightController.text = text;
    _syncingBodyWeightText = false;
  }

  Future<void> _prepareConfigStep() async {
    final provider = context.read<SettingsProvider>();
    final program = _selectedRegimeType == null
        ? null
        : provider.trainingProgramFor(_selectedRegimeType!);
    if (program == null) return;

    AppLogger.instance.info('Onboarding', 'bodyweight import', {
      'phase': 'start',
    });
    final auth = context.read<AuthProvider>();
    if (mounted) {
      setState(() {
        _isImportingBodyWeight = true;
        _bodyWeightHint = Platform.isAndroid
            ? 'Checking Health Connect for your latest bodyweight...'
            : 'Checking Apple Health for your latest bodyweight...';
      });
    }
    final importedKg = await HealthService.readLatestBodyWeightKg(
      requestPermissions: true,
    );
    if (!mounted) return;
    if (importedKg != null && importedKg > 0) {
      _setBodyWeightText(importedKg, provider.weightUnit);
      AppLogger.instance.info('Onboarding', 'bodyweight import', {
        'source': Platform.isAndroid ? 'health_connect' : 'apple_health',
        'bodyWeightKg': importedKg,
      });
      setState(() {
        _bodyWeightHint = Platform.isAndroid
            ? 'Pulled from Health Connect. You can edit it before you start. We use bodyweight to estimate calories burned.'
            : 'Pulled from Apple Health. You can edit it before you start. We use bodyweight to estimate calories burned.';
      });
    } else if (auth.bodyWeightKg > 0) {
      _setBodyWeightText(auth.bodyWeightKg, provider.weightUnit);
      AppLogger.instance.info('Onboarding', 'bodyweight import', {
        'source': 'profile',
        'bodyWeightKg': auth.bodyWeightKg,
      });
      setState(() {
        _bodyWeightHint =
            'Using the bodyweight saved on your profile. We use it to estimate calories burned.';
      });
    } else {
      AppLogger.instance.warn('Onboarding', 'bodyweight import empty');
      setState(() {
        _bodyWeightHint =
            'Enter your bodyweight to personalize starting weights and estimate calories burned.';
      });
    }
    if (mounted) {
      setState(() => _isImportingBodyWeight = false);
    }

    _applyRecommendedWeights(provider, program);
  }

  double _experienceMultiplier(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.cute:
        return 0.40;
      case ExperienceLevel.beginner:
        return 0.85;
      case ExperienceLevel.intermediate:
        return 1.0;
      case ExperienceLevel.expert:
        return 1.15;
    }
  }

  double? _ratioForFieldKey(String key) {
    switch (key) {
      case 'squat_weight':
      case 'squat_t1_weight':
        return 0.95;
      case 'bench_press_weight':
      case 'bench_press_t2_weight':
        return 0.70;
      case 'barbell_row_weight':
      case 'barbell_row_t2_weight':
        return 0.75;
      case 'overhead_press_weight':
      case 'overhead_press_t2_weight':
        return 0.50;
      case 'deadlift_weight':
      case 'deadlift_t1_weight':
        return 1.15;
      case 'squat_tm':
        return 1.10;
      case 'bench_press_tm':
        return 0.80;
      case 'deadlift_tm':
        return 1.35;
      case 'overhead_press_tm':
        return 0.55;
      default:
        return null;
    }
  }

  String _formattedRecommendedValue(
    TrainingProgramStateFieldSchema field,
    SettingsProvider provider,
    double bodyWeightKg,
  ) {
    final bodyWeightLb = kilogramsToPounds(bodyWeightKg);
    final baseRatio = _ratioForFieldKey(field.key);
    if (baseRatio == null) {
      return _defaultTextForField(field);
    }

    final targetPounds =
        (bodyWeightLb * baseRatio * _experienceMultiplier(_experienceLevel))
            .clamp(field.minValue, field.maxValue)
            .toDouble();
    final snappedPounds = snapPoundsForUnit(
      targetPounds,
      provider.weightUnit,
      poundStep: field.step,
      kilogramStep: SettingsProvider.displayStepForField(
        field,
        provider.weightUnit,
      ),
    );
    final display = displayWeightFromPounds(snappedPounds, provider.weightUnit);
    return display % 1 == 0
        ? display.toStringAsFixed(0)
        : display.toStringAsFixed(1);
  }

  void _applyRecommendedWeights(
    SettingsProvider provider,
    TrainingProgramDefinition program,
  ) {
    final bodyWeightKg = _parsedBodyWeightKg(provider);
    if (bodyWeightKg == null || bodyWeightKg <= 0) return;

    final onboardingFields = program.stateSchema.fields
        .where((f) => f.onboardingField)
        .toList();
    for (final field in onboardingFields) {
      if (!SettingsProvider.isWeightField(field)) continue;
      final controller = _controllers[field.key];
      if (controller == null) continue;
      final recommended = _formattedRecommendedValue(
        field,
        provider,
        bodyWeightKg,
      );
      if (controller.text != recommended) {
        controller.text = recommended;
      }
    }
  }

  void _refreshEmojiChoices() {
    final pool = <String>{...whimsicalEmojiCatalog, _selectedEmoji}.toList();
    pool.shuffle(Random());
    setState(() {
      _emojiChoices = pool.take(_emojiWindowSize).toList();
      if (!_emojiChoices.contains(_selectedEmoji)) {
        _emojiChoices = [
          _selectedEmoji,
          ..._emojiChoices.take(_emojiWindowSize - 1),
        ];
      }
    });
  }

  Future<void> _loadProfile() async {
    if (_profileLoaded) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null || userId.isEmpty) {
      _profileLoaded = true;
      return;
    }
    _profileLoaded = true;
    try {
      final user = await UserServiceWrapper(
        context.read<GrpcClient>(),
      ).getUser(userId);
      if (!mounted || user == null || _profileTouched) return;
      // Only apply the server profile if the user previously saved a custom
      // one (i.e. the emoji differs from the server-side new-account default).
      // If it's still the default "💪" they haven't customised yet, keep the
      // random pick we already chose so the page feels fresh each sign-up.
      const serverDefaultEmoji = '💪';
      final emoji = normalizedProfileEmoji(user.profileEmoji);
      if (emoji == serverDefaultEmoji) return;
      setState(() {
        _selectedEmoji = emoji;
        _selectedColorHex = normalizedProfileColorHex(user.profileColorHex);
        if (!_emojiChoices.contains(_selectedEmoji)) {
          _emojiChoices = [
            _selectedEmoji,
            ..._emojiChoices.take(_emojiWindowSize - 1),
          ];
        }
      });
    } catch (_) {
      // Keep onboarding defaults if the profile fetch fails.
    }
  }

  Future<void> _save(
    SettingsProvider provider,
    TrainingProgramDefinition program,
  ) async {
    setState(() => _isSaving = true);
    try {
      final bodyWeightKg = _parsedBodyWeightKg(provider);
      final updatedUser = await UserServiceWrapper(context.read<GrpcClient>())
          .updateMyProfile(
            profileEmoji: _selectedEmoji,
            profileColorHex: _selectedColorHex,
            bodyWeightKg: bodyWeightKg,
          );
      if (mounted) {
        context.read<AuthProvider>().setProfile(
          profileEmoji: updatedUser.profileEmoji,
          profileColorHex: updatedUser.profileColorHex,
          bodyWeightKg: updatedUser.bodyWeightKg.toDouble(),
        );
      }

      final onboardingFields = program.stateSchema.fields
          .where((f) => f.onboardingField)
          .toList();

      final fields = <String, StateFieldValue>{};
      for (final f in onboardingFields) {
        final text = _controllers[f.key]?.text.trim() ?? '';
        final val = SettingsProvider.fieldValueFromText(
          f,
          text,
          unit: provider.weightUnit,
        );
        if (val != null) fields[f.key] = val;
      }

      await provider.setActiveTrainingProgramState(
        regimeType: program.regimeType,
        fields: fields,
        source: 'onboarding_init',
      );
      if (!mounted) return;
      context.go('/');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    _initFromCatalog(provider);
    _loadProfile();

    if (!provider.loaded ||
        provider.trainingPrograms.isEmpty ||
        _selectedRegimeType == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final programs = provider.trainingPrograms;
    final selected =
        provider.trainingProgramFor(_selectedRegimeType!) ?? programs.first;
    final cs = Theme.of(context).colorScheme;
    final progressAlignment = switch (_step) {
      0 => Alignment.centerLeft,
      1 => const Alignment(-0.333, 0),
      2 => const Alignment(0.333, 0),
      _ => Alignment.centerRight,
    };

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) _goToStep(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: SizedBox(
                  height: 5,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      const gap = 8.0;
                      final segmentWidth = (totalWidth - (gap * 3)) / 4;
                      return Stack(
                        children: [
                          Row(
                            children: [
                              for (var i = 0; i < 4; i++) ...[
                                if (i > 0) const SizedBox(width: gap),
                                Container(
                                  width: segmentWidth,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: cs.outline.withValues(alpha: 0.18),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: progressAlignment,
                            child: Container(
                              width: segmentWidth,
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(opacity: curved, child: child);
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _step == 0
                        ? MarkerStep(
                            selectedEmoji: _selectedEmoji,
                            selectedColorHex: _selectedColorHex,
                            emojiChoices: _emojiChoices,
                            onSelectEmoji: (emoji) => setState(() {
                              _profileTouched = true;
                              _selectedEmoji = emoji;
                            }),
                            onSelectColor: (hex) => setState(() {
                              _profileTouched = true;
                              _selectedColorHex = hex;
                            }),
                            onRefreshEmojis: _refreshEmojiChoices,
                            onNext: () => _goToStep(1),
                          )
                        : _step == 1
                        ? UnitStep(
                            selectedUnit: provider.weightUnit,
                            onSelect: (unit) =>
                                _selectWeightUnit(provider, unit),
                            onBack: () => _goToStep(0),
                            onNext: () => _goToStep(2),
                          )
                        : _step == 2
                        ? ProgramStep(
                            programs: programs,
                            selectedType: selected.regimeType,
                            onSelect: _selectProgram,
                            onInfo: (p) => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RegimeInfoScreen(regimeType: p.regimeType),
                              ),
                            ),
                            onBack: () => _goToStep(1),
                            onNext: () => _goToStep(3),
                          )
                        : _step == 3
                        ? ConfigStep(
                            program: selected,
                            controllers: _controllers,
                            bodyWeightController: _bodyWeightController,
                            weightUnit: provider.weightUnit,
                            experienceLevel: _experienceLevel,
                            bodyWeightHint: _bodyWeightHint,
                            isImportingBodyWeight: _isImportingBodyWeight,
                            onSelectExperience: (level) {
                              setState(() => _experienceLevel = level);
                              _applyRecommendedWeights(provider, selected);
                            },
                            onBack: () => _goToStep(2),
                            onNext: () => _goToStep(4),
                          )
                        : ConfirmStep(
                            program: selected,
                            controllers: _controllers,
                            weightUnit: provider.weightUnit,
                            selectedEmoji: _selectedEmoji,
                            selectedColorHex: _selectedColorHex,
                            onBack: () => _goToStep(3),
                            onSave: _isSaving
                                ? null
                                : () => _save(provider, selected),
                            isSaving: _isSaving,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


