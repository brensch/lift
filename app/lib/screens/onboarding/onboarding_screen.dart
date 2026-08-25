/// Setup, three questions long: your marker, your unit, and (optionally)
/// your bodyweight and experience so the first weights aren't the empty
/// bar. Finishing calls CompleteOnboarding, which seeds the trackers and
/// copies the six default templates — after that the app is usable and
/// nothing else is required, ever.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';

import '../../gen/workout/v1/settings.pb.dart';
import '../../gen/workout/v1/workout.pb.dart' show ExperienceLevel, Gender;
import '../../logic/user_profile.dart';
import '../../logic/whimsical_emojis.dart';
import '../../logic/weight_units.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/grpc_client.dart';
import '../../services/user_service.dart';
import '../../services/workout_service.dart';
import '../science_screen.dart';
import 'steps/marker_step.dart';
import 'steps/unit_step.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _emojiWindowSize = 18;
  int _step = 0;
  bool _isSaving = false;
  bool _profileLoaded = false;
  bool _profileTouched = false;
  late String _selectedEmoji;
  late String _selectedColorHex;
  WeightUnit _unit = WeightUnit.WEIGHT_UNIT_LB;
  ExperienceLevel _experience =
      ExperienceLevel.EXPERIENCE_LEVEL_INTERMEDIATE;
  Gender _gender = Gender.GENDER_UNSPECIFIED;
  final TextEditingController _bodyWeightController = TextEditingController();
  late List<String> _emojiChoices;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    final shuffled = [...whimsicalEmojiCatalog]..shuffle(rng);
    _emojiChoices = shuffled.take(_emojiWindowSize).toList();
    _selectedEmoji = _emojiChoices[rng.nextInt(_emojiWindowSize)];
    _selectedColorHex =
        profileColorHexOptions[rng.nextInt(profileColorHexOptions.length)];
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _bodyWeightController.dispose();
    super.dispose();
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

  double _parsedBodyWeightKg() {
    final text = _bodyWeightController.text.trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0) return 0;
    return isMetricUnit(_unit) ? value : value * 0.45359237;
  }

  Future<void> _finish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bodyWeightKg = _parsedBodyWeightKg();

      // Profile marker (and bodyweight, for calorie estimates).
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
        context.read<SettingsProvider>().applyWeightUnitLocally(_unit);
      }

      // The server seeds trackers and the default templates.
      if (!mounted) return;
      final service = WorkoutServiceWrapper(context.read<GrpcClient>());
      await service.completeOnboarding(
        bodyWeightKg: bodyWeightKg,
        experience: bodyWeightKg > 0
            ? _experience
            : ExperienceLevel.EXPERIENCE_LEVEL_UNSPECIFIED,
        unit: _unit,
        gender: _gender,
      );

      if (!mounted) return;
      // Refresh home so the router's onboarded gate flips.
      final auth = context.read<AuthProvider>();
      await context.read<WorkoutProvider>().loadActiveWorkout(
        auth.userId ?? '',
      );
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = <Widget>[
      MarkerStep(
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
        onNext: () => setState(() => _step = 1),
      ),
      UnitStep(
        selectedUnit: _unit,
        onSelect: (unit) async => setState(() => _unit = unit),
        onBack: () => setState(() => _step = 0),
        onNext: () => setState(() => _step = 2),
      ),
      _BodyStep(
        unit: _unit,
        controller: _bodyWeightController,
        experience: _experience,
        onExperienceChanged: (level) => setState(() => _experience = level),
        gender: _gender,
        onGenderChanged: (gender) => setState(() => _gender = gender),
        onOpenScience: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const ScienceScreen()),
        ),
        isSaving: _isSaving,
        onBack: () => setState(() => _step = 1),
        onFinish: _finish,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _StepDots(step: _step, count: steps.length),
            Expanded(child: steps[_step]),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int step;
  final int count;
  const _StepDots({required this.step, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        return Container(
          width: i == step ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: i == step
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Step 3: gender, bodyweight and experience — all skippable. They only
/// scale the seeded starting weights; skip everything and the bar is the
/// starting weight.
class _BodyStep extends StatelessWidget {
  final WeightUnit unit;
  final TextEditingController controller;
  final ExperienceLevel experience;
  final ValueChanged<ExperienceLevel> onExperienceChanged;
  final Gender gender;
  final ValueChanged<Gender> onGenderChanged;
  final VoidCallback onOpenScience;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const _BodyStep({
    required this.unit,
    required this.controller,
    required this.experience,
    required this.onExperienceChanged,
    required this.gender,
    required this.onGenderChanged,
    required this.onOpenScience,
    required this.isSaving,
    required this.onBack,
    required this.onFinish,
  });

  static const _levels = [
    (ExperienceLevel.EXPERIENCE_LEVEL_CUTE, 'Cute', '🐣'),
    (ExperienceLevel.EXPERIENCE_LEVEL_BEGINNER, 'A few months', '🌱'),
    (ExperienceLevel.EXPERIENCE_LEVEL_INTERMEDIATE, 'A while', '💪'),
    (ExperienceLevel.EXPERIENCE_LEVEL_EXPERT, 'Years', '🦍'),
  ];

  static const _genders = [
    (Gender.GENDER_FEMALE, 'Female', '♀'),
    (Gender.GENDER_MALE, 'Male', '♂'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            'A little about you',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'All optional. These only scale your starting weights — skip '
            'everything and the big lifts open at the empty bar.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'GENDER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _genders.map((entry) {
              final selected = gender == entry.$1;
              return ChoiceChip(
                label: Text('${entry.$3} ${entry.$2}'),
                selected: selected,
                onSelected: (_) => onGenderChanged(
                  selected ? Gender.GENDER_UNSPECIFIED : entry.$1,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: 'Bodyweight',
              suffixText: weightUnitSuffix(unit),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'HOW LONG HAVE YOU LIFTED?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _levels.map((entry) {
              final selected = experience == entry.$1;
              return ChoiceChip(
                label: Text('${entry.$3} ${entry.$2}'),
                selected: selected,
                onSelected: (_) => onExperienceChanged(entry.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onOpenScience,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science_outlined, size: 15, color: cs.tertiary),
                const SizedBox(width: 5),
                Text(
                  'Why these questions? Read the science',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.tertiary,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: isSaving ? null : onBack,
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
                    onPressed: isSaving ? null : onFinish,
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'START LIFTING',
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
