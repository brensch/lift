/// Setup, five steps long: your marker, your unit, how strong you are
/// (a slider that sets the first weights), your bodyweight for calories,
/// and the library templates you want to start with. Finishing calls
/// CompleteOnboarding, which seeds the trackers and copies the chosen
/// templates — after that the app is usable and nothing else is required,
/// ever.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';

import '../../gen/copy.dart';
import '../../gen/workout/v1/settings.pb.dart';
import '../../gen/workout/v1/workout.pb.dart'
    show ExperienceLevel, LibraryTemplate;
import '../../logic/user_profile.dart';
import '../../logic/whimsical_emojis.dart';
import '../../logic/weight_units.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/grpc_client.dart';
import '../../services/user_service.dart';
import '../../services/workout_service.dart';
import 'steps/marker_step.dart';
import 'steps/strength_step.dart';
import 'steps/templates_step.dart';
import 'steps/unit_step.dart';
import 'steps/weight_step.dart';

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
  double _strength = 0.5; // chick 0 .. gorilla 1
  final TextEditingController _bodyWeightController = TextEditingController();
  late List<String> _emojiChoices;
  List<LibraryTemplate>? _library;
  Object? _libraryError;
  final Set<String> _selectedLibraryIds = {};

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
    unawaited(_loadLibrary());
  }

  /// The library, fetched up front so the last step is instant. Defaults
  /// come ticked.
  Future<void> _loadLibrary() async {
    try {
      final library = await WorkoutServiceWrapper(
        context.read<GrpcClient>(),
      ).listTemplateLibrary();
      if (!mounted) return;
      setState(() {
        _library = library;
        _libraryError = null;
        if (_selectedLibraryIds.isEmpty) {
          _selectedLibraryIds.addAll(
            library.where((t) => t.isDefault).map((t) => t.id),
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => _libraryError = e);
    }
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
        experience: ExperienceLevel.EXPERIENCE_LEVEL_UNSPECIFIED,
        unit: _unit,
        strength: _strength,
        libraryIds: _selectedLibraryIds.toList(),
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
          SnackBar(
            content: Text(
              copy.onboarding.weight.failed.replaceAll('{error}', '$e'),
            ),
          ),
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
      StrengthStep(
        unit: _unit,
        strength: _strength,
        onChanged: (v) => setState(() => _strength = v),
        onBack: () => setState(() => _step = 1),
        onNext: () => setState(() => _step = 3),
      ),
      WeightStep(
        unit: _unit,
        controller: _bodyWeightController,
        onBack: () => setState(() => _step = 2),
        onNext: () {
          if (_library == null && _libraryError == null) {
            unawaited(_loadLibrary());
          }
          setState(() => _step = 4);
        },
      ),
      TemplatesStep(
        library: _library,
        error: _libraryError,
        selected: _selectedLibraryIds,
        onToggle: (id) => setState(() {
          if (!_selectedLibraryIds.remove(id)) _selectedLibraryIds.add(id);
        }),
        isSaving: _isSaving,
        onBack: () => setState(() => _step = 3),
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
            color: i == step ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
