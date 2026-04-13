import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import '../gen/workout/v1/settings.pb.dart';
import '../logic/user_profile.dart';
import '../logic/whimsical_emojis.dart';
import '../logic/weight_units.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/grpc_client.dart';
import '../services/app_logger.dart';
import '../services/health_service.dart';
import '../services/user_service.dart';
import 'regime_info_screen.dart';

enum _ExperienceLevel { cute, beginner, intermediate, expert }

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
  _ExperienceLevel _experienceLevel = _ExperienceLevel.intermediate;
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
    await provider.updateWeightUnit(unit);
    final currentKg = _parsedBodyWeightKg(provider);
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

  double _experienceMultiplier(_ExperienceLevel level) {
    switch (level) {
      case _ExperienceLevel.cute:
        return 0.40;
      case _ExperienceLevel.beginner:
        return 0.85;
      case _ExperienceLevel.intermediate:
        return 1.0;
      case _ExperienceLevel.expert:
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
                        ? _MarkerStep(
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
                        ? _UnitStep(
                            selectedUnit: provider.weightUnit,
                            onSelect: (unit) =>
                                _selectWeightUnit(provider, unit),
                            onBack: () => _goToStep(0),
                            onNext: () => _goToStep(2),
                          )
                        : _step == 2
                        ? _ProgramStep(
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
                        ? _ConfigStep(
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
                        : _ConfirmStep(
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

class _UnitStep extends StatelessWidget {
  final WeightUnit selectedUnit;
  final Future<void> Function(WeightUnit unit) onSelect;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _UnitStep({
    required this.selectedUnit,
    required this.onSelect,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE YOUR UNITS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'What plates are you lifting with?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Ie are you in America',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          _UnitCard(
            title: 'Pounds',
            subtitle:
                'Best for making you think you lift more because the number is larger.',
            badge: '🦅',
            selected: selectedUnit == WeightUnit.WEIGHT_UNIT_LB,
            onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_LB),
          ),
          const SizedBox(height: 10),
          _UnitCard(
            title: 'Kilograms',
            subtitle: 'Best for science and everywhere except America',
            badge: '🌍',
            selected: selectedUnit == WeightUnit.WEIGHT_UNIT_KG,
            onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_KG),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('BACK'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: onNext,
                    child: const Text(
                      'NEXT',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgramStep extends StatelessWidget {
  final List<TrainingProgramDefinition> programs;
  final RegimeType selectedType;
  final void Function(TrainingProgramDefinition) onSelect;
  final void Function(TrainingProgramDefinition) onInfo;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _ProgramStep({
    required this.programs,
    required this.selectedType,
    required this.onSelect,
    required this.onInfo,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE YOUR PROGRAM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How do you train?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            "Each program builds up the weight you can lift over time using different strategies. Pick one based on how much time you spend in the gym, how experienced you are, and/or vibes.",
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: programs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = programs[i];
                final selected = p.regimeType == selectedType;
                return _ProgramCard(
                  program: p,
                  selected: selected,
                  onTap: () => onSelect(p),
                  onInfo: () => onInfo(p),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('BACK'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: onNext,
                    child: const Text(
                      'NEXT',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfigStep extends StatelessWidget {
  final TrainingProgramDefinition program;
  final Map<String, TextEditingController> controllers;
  final TextEditingController bodyWeightController;
  final WeightUnit weightUnit;
  final _ExperienceLevel experienceLevel;
  final String bodyWeightHint;
  final bool isImportingBodyWeight;
  final ValueChanged<_ExperienceLevel> onSelectExperience;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _ConfigStep({
    required this.program,
    required this.controllers,
    required this.bodyWeightController,
    required this.weightUnit,
    required this.experienceLevel,
    required this.bodyWeightHint,
    required this.isImportingBodyWeight,
    required this.onSelectExperience,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onboardingFields =
        program.stateSchema.fields.where((f) => f.onboardingField).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            children: [
              Text(
                'STARTING WEIGHTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: cs.tertiary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose starting weights',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${program.displayName} · ${program.headline}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                program.summary,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 18),
              _BodyWeightInlineField(
                controller: bodyWeightController,
                weightUnit: weightUnit,
                hintText: bodyWeightHint,
                isImporting: isImportingBodyWeight,
              ),
              const SizedBox(height: 16),
              _ExperienceSelector(
                selected: experienceLevel,
                onSelect: onSelectExperience,
              ),
              const SizedBox(height: 12),
              Text(
                'These defaults are calculated from your bodyweight and self proclaimed muscle size.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: cs.onSurface.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 18),
              for (final f in onboardingFields)
                if (controllers.containsKey(f.key))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StateFieldInput(
                      field: f,
                      controller: controllers[f.key]!,
                      weightUnit: weightUnit,
                    ),
                  ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('BACK'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: onNext,
                    child: const Text(
                      'NEXT',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final TrainingProgramDefinition program;
  final Map<String, TextEditingController> controllers;
  final WeightUnit weightUnit;
  final String selectedEmoji;
  final String selectedColorHex;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  final bool isSaving;

  const _ConfirmStep({
    required this.program,
    required this.controllers,
    required this.weightUnit,
    required this.selectedEmoji,
    required this.selectedColorHex,
    required this.onBack,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = profileColorFromHex(selectedColorHex);
    // Pick text colour that contrasts with the accent background.
    final onAccent =
        accent.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    final onboardingFields = program.stateSchema.fields
        .where((f) => f.onboardingField)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final suffix = weightUnitSuffix(weightUnit);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFIRM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Do these look right?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Starting too heavy is the most common beginner mistake. You can change these later in settings.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent,
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coloured hero header
                Container(
                  color: accent,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        selectedEmoji,
                        style: const TextStyle(fontSize: 56),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              program.displayName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: onAccent,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              program.headline,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: onAccent.withValues(alpha: 0.7),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Weight rows
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (int i = 0; i < onboardingFields.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: cs.outline.withValues(alpha: 0.1),
                          ),
                        Builder(
                          builder: (context) {
                            final f = onboardingFields[i];
                            final text =
                                controllers[f.key]?.text.trim() ?? '';
                            final isWeight =
                                SettingsProvider.isWeightField(f);
                            final displayValue =
                                isWeight && text.isNotEmpty
                                    ? '$text $suffix'
                                    : text.isNotEmpty
                                    ? text
                                    : '—';
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      f.label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface.withValues(
                                          alpha: isWeight ? 0.85 : 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    displayValue,
                                    style: TextStyle(
                                      fontSize: isWeight ? 17 : 15,
                                      fontWeight: FontWeight.w900,
                                      color: isWeight
                                          ? accent
                                          : cs.onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                ],
              ),
            ),
          const Spacer(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('BACK'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: onAccent,
                    ),
                    child: isSaving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onAccent,
                            ),
                          )
                        : const Text(
                            'START',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkerStep extends StatelessWidget {
  final String selectedEmoji;
  final String selectedColorHex;
  final List<String> emojiChoices;
  final ValueChanged<String> onSelectEmoji;
  final ValueChanged<String> onSelectColor;
  final VoidCallback onRefreshEmojis;
  final VoidCallback onNext;

  const _MarkerStep({
    required this.selectedEmoji,
    required this.selectedColorHex,
    required this.emojiChoices,
    required this.onSelectEmoji,
    required this.onSelectColor,
    required this.onRefreshEmojis,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PICK YOUR MARKER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your colour and creature',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'In group workouts this becomes your side stripe and emoji badge.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          _ProfilePreviewCard(emoji: selectedEmoji, colorHex: selectedColorHex),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'WHIMSICAL EMOJIS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: cs.tertiary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onRefreshEmojis,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: emojiChoices
                        .map(
                          (emoji) => _EmojiChoiceChip(
                            emoji: emoji,
                            selected: emoji == selectedEmoji,
                            onTap: () => onSelectEmoji(emoji),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'COLOUR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: profileColorHexOptions
                        .map(
                          (hex) => _ColorChoiceDot(
                            hex: hex,
                            selected: hex == selectedColorHex,
                            onTap: () => onSelectColor(hex),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onNext,
              child: const Text(
                'NEXT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  final String emoji;
  final String colorHex;

  const _ProfilePreviewCard({required this.emoji, required this.colorHex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = profileColorFromHex(colorHex);
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 88,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group workout preview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your emoji replaces the vertical name and your colour owns the sidebar.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiChoiceChip extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _EmojiChoiceChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}

class _ColorChoiceDot extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChoiceDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = profileColorFromHex(hex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? cs.onSurface : color.withValues(alpha: 0.6),
            width: selected ? 3 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _BodyWeightInlineField extends StatelessWidget {
  final TextEditingController controller;
  final WeightUnit weightUnit;
  final String hintText;
  final bool isImporting;

  const _BodyWeightInlineField({
    required this.controller,
    required this.weightUnit,
    required this.hintText,
    required this.isImporting,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Bodyweight',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            if (isImporting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Weight',
            suffixText: weightUnitSuffix(weightUnit),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hintText,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: cs.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

class _ExperienceSelector extends StatelessWidget {
  final _ExperienceLevel selected;
  final ValueChanged<_ExperienceLevel> onSelect;

  const _ExperienceSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      (_ExperienceLevel.cute, 'Cute'),
      (_ExperienceLevel.beginner, 'Some'),
      (_ExperienceLevel.intermediate, 'More'),
      (_ExperienceLevel.expert, 'Lots'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Muscles',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final item in items) ...[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: item.$1 == _ExperienceLevel.expert ? 0 : 8,
                  ),
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(item.$2, textAlign: TextAlign.center),
                    ),
                    selected: selected == item.$1,
                    selectedColor: cs.primary.withValues(alpha: 0.14),
                    showCheckmark: false,
                    onSelected: (_) => onSelect(item.$1),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepperField extends StatefulWidget {
  final TextEditingController controller;
  final double step;
  final double min;
  final double? max;
  final String? suffixText;

  const _StepperField({
    required this.controller,
    required this.step,
    required this.min,
    this.max,
    this.suffixText,
  });

  @override
  State<_StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<_StepperField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _bump(double delta) {
    final current =
        double.tryParse(widget.controller.text.trim()) ?? widget.min;
    final decimals = widget.step % 1 == 0 ? 0 : 2;
    final next = (current + delta).clamp(
      widget.min,
      widget.max ?? double.infinity,
    );
    widget.controller.text = next.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _StepperButton(icon: Icons.remove, onTap: () => _bump(-widget.step)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixText: widget.suffixText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StepperButton(icon: Icons.add, onTap: () => _bump(widget.step)),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

/// Renders a single state field input: enum → choice chips, numeric → text field.
class _StateFieldInput extends StatefulWidget {
  final TrainingProgramStateFieldSchema field;
  final TextEditingController controller;
  final WeightUnit weightUnit;

  const _StateFieldInput({
    required this.field,
    required this.controller,
    required this.weightUnit,
  });

  @override
  State<_StateFieldInput> createState() => _StateFieldInputState();
}

class _StateFieldInputState extends State<_StateFieldInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final f = widget.field;

    if (f.kind == StateFieldKind.STATE_FIELD_KIND_ENUM &&
        f.enumOptions.isNotEmpty) {
      final current = widget.controller.text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (f.helpText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 8),
              child: Text(
                f.helpText,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            children: f.enumOptions.map((opt) {
              return ChoiceChip(
                label: Text(opt.label.isNotEmpty ? opt.label : opt.value),
                selected: opt.value == current,
                onSelected: (_) =>
                    setState(() => widget.controller.text = opt.value),
              );
            }).toList(),
          ),
        ],
      );
    }

    final isNumeric =
        f.kind == StateFieldKind.STATE_FIELD_KIND_FLOAT ||
        f.kind == StateFieldKind.STATE_FIELD_KIND_INT;
    final unit = widget.weightUnit;
    final isWeightField = SettingsProvider.isWeightField(f);
    final suffix = isWeightField ? weightUnitSuffixPlural(unit) : null;
    final step = isWeightField
        ? _barbellIncrement(unit)
        : (f.step > 0 ? f.step : 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.label,
                style: TextStyle(
                  fontWeight: isWeightField ? FontWeight.w900 : FontWeight.w700,
                  fontSize: isWeightField ? 18 : 14,
                ),
              ),
              if (f.helpText.isNotEmpty && !isWeightField)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Text(
                    f.helpText,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 224,
          child: isNumeric
              ? _StepperField(
                  controller: widget.controller,
                  step: step,
                  min: f.minValue,
                  max: f.maxValue > f.minValue ? f.maxValue : null,
                  suffixText: suffix,
                )
              : TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.text,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixText: suffix,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.outline.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

double _barbellIncrement(WeightUnit unit) => standardPlates(unit).last * 2;

class _ProgramCard extends StatelessWidget {
  final TrainingProgramDefinition program;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  const _ProgramCard({
    required this.program,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outline,
                    width: 2,
                  ),
                  color: selected ? cs.primary : Colors.transparent,
                ),
                child: selected
                    ? Icon(Icons.check, size: 10, color: cs.onPrimary)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          program.headline,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        if (program.hasAtAGlance()) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _PreviewPill(
                                emoji: '📅',
                                text: program.atAGlance.daysPerWeek,
                              ),
                              _PreviewPill(
                                emoji: '🎯',
                                text: program.atAGlance.bestFor,
                              ),
                              _PreviewPill(
                                emoji: '⏱️',
                                text: program.atAGlance.averageSessionTime,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: -1,
                    right: 0,
                    child: IconButton(
                      onPressed: onInfo,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      icon: const Icon(Icons.info_outline_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  const _UnitCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Text(
                badge,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, height: 1.0),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.primary : cs.outline,
                  width: 2,
                ),
                color: selected ? cs.primary : Colors.transparent,
              ),
              child: selected
                  ? Icon(Icons.check, size: 10, color: cs.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  final String emoji;
  final String text;
  const _PreviewPill({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$emoji $text',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
