/// Home: your templates, your weekly volume, and one suggestion.
///
/// A template is an ordered list of exercises and nothing else — the
/// server prescribes sets, reps, rest and weight from the trackers, so
/// every card here shows the numbers the workout will actually start
/// with. The suggestion is the template whose muscles are furthest below
/// the 10–20 weekly-set band; it is one tap, never a gate.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../tutorial/tutorial_seen.dart';
import '../../tutorial/tutorial_target.dart';
import 'package:provider/provider.dart';

import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../logic/session_estimate.dart';
import '../../logic/weight_units.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/wearable_bridge_service.dart';
import '../../theme/theme_spec.dart';
import '../tutorial_screen.dart';
import 'template_editor.dart';
import 'template_library_sheet.dart';
import '../../theme/app_icons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isStarting = false;
  bool _tutorialChecked = false;
  // Which template card is expanded. Defaults to the suggestion; the user
  // taps the small chips to switch.
  String? _selectedTemplateId;

  /// First arrival at a working home: show the walkthrough once per account.
  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked) return;
    _tutorialChecked = true;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId.isEmpty) return;
    if (await TutorialSeen.checkAndMark(userId)) return;
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'tutorial'),
        builder: (_) => const TutorialScreen(),
      ),
    );
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;
    await context.read<WorkoutProvider>().loadActiveWorkout(userId);
  }

  Future<void> _start({String templateId = ''}) async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final wearableBridge = context.read<WearableBridgeService>();
      final workoutProvider = context.read<WorkoutProvider>();
      final workoutId = await workoutProvider.startWorkout(
        templateId.isEmpty ? 'Workout' : '',
        templateId: templateId,
      );
      if (workoutId != null && mounted) {
        unawaited(_setUpHealthAndWatch(wearableBridge));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start workout: $e')));
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  // Health was granted (or not) once, up front, by PermissionsService; the
  // watch launch needs no prompt of its own.
  Future<void> _setUpHealthAndWatch(WearableBridgeService bridge) async {
    try {
      if (await bridge.isWatchAppAvailable()) {
        await bridge.openWatchApp();
      }
    } catch (e) {
      debugPrint('Auto watch launch failed: $e');
    }
  }

  /// The Add sheet: the library, or a blank template.
  Future<void> _addTemplate() =>
      showTemplateLibrary(context, provider: context.read<WorkoutProvider>());

  Future<void> _editTemplate(WorkoutTemplate? template) async {
    final wp = context.read<WorkoutProvider>();
    await showTemplateEditor(context, template: template, provider: wp);
  }

  Future<void> _confirmDeleteTemplate(WorkoutTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete ${template.name}?',
          style: TextStyle(fontWeight: context.tokens.weight.heavy),
        ),
        content: const Text(
          'Your weights are safe. They live on the exercises, not the '
          'template.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<WorkoutProvider>().deleteTemplate(template.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final unit = context.watch<SettingsProvider>().weightUnit;
    final home = wp.home;

    if (home == null) {
      return Center(
        child: wp.lastLoadError != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not reach the gym computer.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('RETRY'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      );
    }

    if (home.onboarded && !_tutorialChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
    }

    final templates = home.templates;
    final suggestedId = home.suggestedTemplateId;

    // Resolve the selection: sticky while valid, otherwise the suggestion,
    // otherwise the first template. '_empty' selects the freestyle card.
    final emptySelected = _selectedTemplateId == _emptyWorkoutId;
    WorkoutTemplate? selected;
    if (!emptySelected) {
      for (final t in templates) {
        if (t.id == _selectedTemplateId) selected = t;
      }
      if (selected == null && templates.isNotEmpty) {
        selected = templates.firstWhere(
          (t) => t.id == suggestedId,
          orElse: () => templates.first,
        );
      }
    }
    final highlight = selected == null
        ? const <MuscleGroup>{}
        : templateMuscles(selected, wp.trackers).toSet();

    // Scrolls (and pulls to refresh) only when the content is taller than the
    // screen; when it fits, the page stays put. No stretch at the edges.
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TutorialTarget(
              id: 'home_volume',
              child: VolumeCard(
                volume: home.volume,
                recovery: home.recovery,
                highlight: highlight,
              ),
            ),
            const SizedBox(height: 14),
            TutorialTarget(
              id: 'home_templates',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final template in templates)
                    TemplateChip(
                      template: template,
                      trackers: wp.trackers,
                      selected: template.id == selected?.id,
                      recommended: template.id == suggestedId,
                      onTap: () =>
                          setState(() => _selectedTemplateId = template.id),
                    ),
                  _ActionChip(
                    icon: AppIcons.lightning,
                    label: 'Empty',
                    selected: emptySelected,
                    onTap: () =>
                        setState(() => _selectedTemplateId = _emptyWorkoutId),
                  ),
                  TutorialTarget(
                    id: 'home_add',
                    child: _ActionChip(
                      icon: AppIcons.add,
                      label: 'Add',
                      selected: false,
                      onTap: _addTemplate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (emptySelected)
              _EmptyWorkoutCard(
                isStarting: _isStarting,
                onStart: () => _start(),
              )
            else if (selected != null)
              TutorialTarget(
                id: 'home_plan',
                child: SelectedTemplateCard(
                  template: selected,
                  trackers: wp.trackers,
                  unit: unit,
                  recommended: selected.id == suggestedId,
                  suggestionReason: selected.id == suggestedId
                      ? home.suggestionReason
                      : '',
                  isStarting: _isStarting,
                  onStart: () => _start(templateId: selected!.id),
                  onEdit: () => _editTemplate(selected),
                  onDelete: () => _confirmDeleteTemplate(selected!),
                ),
              )
            else
              _EmptyState(onCreate: () => _editTemplate(null)),
          ],
        ),
      ),
    );
  }
}

/// Sentinel selection id for the freestyle "empty workout" card.
const _emptyWorkoutId = '__empty__';

/// The freestyle card: no plan, exercises picked as you go, the app still
/// brings the numbers.
class _EmptyWorkoutCard extends StatelessWidget {
  final bool isStarting;
  final VoidCallback onStart;
  const _EmptyWorkoutCard({required this.isStarting, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: context.tokens.brMd,
        border: Border.all(color: cs.outline.withValues(alpha: 0.6), width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Don't tell me what to do",
            style: TextStyle(
              fontSize: context.tokens.size.titleLg,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "I'll add exercises as I go. The app still brings the "
            'weights, sets and reps for whatever you pick.',
            style: TextStyle(
              fontSize: context.tokens.size.bodyLg,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: isStarting ? null : onStart,
              child: isStarting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'START',
                      style: TextStyle(
                        fontWeight: context.tokens.weight.heavy,
                        fontSize: context.tokens.size.subtitle,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip-shaped button that sits inline with the template chips.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.12) : null,
          borderRadius: context.tokens.br(10),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: context.tokens.size.body,
                fontWeight: context.tokens.weight.heavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Short display names for the ten muscles, shared by the volume rows and
/// the template chips.
const muscleShortLabels = {
  MuscleGroup.MUSCLE_GROUP_CHEST: 'Chest',
  MuscleGroup.MUSCLE_GROUP_BACK: 'Back',
  MuscleGroup.MUSCLE_GROUP_SHOULDERS: 'Delts',
  MuscleGroup.MUSCLE_GROUP_BICEPS: 'Biceps',
  MuscleGroup.MUSCLE_GROUP_TRICEPS: 'Triceps',
  MuscleGroup.MUSCLE_GROUP_QUADS: 'Quads',
  MuscleGroup.MUSCLE_GROUP_HAMSTRINGS: 'Hams',
  MuscleGroup.MUSCLE_GROUP_GLUTES: 'Glutes',
  MuscleGroup.MUSCLE_GROUP_CALVES: 'Calves',
  MuscleGroup.MUSCLE_GROUP_CORE: 'Core',
};

/// The distinct primary muscles a template trains, in exercise order.
List<MuscleGroup> templateMuscles(
  WorkoutTemplate template,
  List<ExerciseTracker> trackers,
) {
  final byExercise = {for (final t in trackers) t.exercise: t.primaryMuscle};
  final out = <MuscleGroup>[];
  for (final exercise in template.exercises) {
    final muscle = byExercise[exercise];
    if (muscle != null &&
        muscle != MuscleGroup.MUSCLE_GROUP_UNSPECIFIED &&
        !out.contains(muscle)) {
      out.add(muscle);
    }
  }
  return out;
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: context.tokens.brMd,
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text('🏗️', style: TextStyle(fontSize: context.tokens.size.display)),
          const SizedBox(height: 12),
          Text(
            'No templates yet',
            style: TextStyle(
              fontSize: context.tokens.size.title,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A template is just a list of exercises. The app handles the '
            'sets, reps and weight.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onCreate, child: const Text('CREATE ONE')),
        ],
      ),
    );
  }
}

// ── Weekly volume ────────────────────────────────────────────────────────────

/// The V10 tracker: one row per muscle carrying three signals on three
/// channels — weekly volume (bar vs the 10–20 band), freshness (a
/// countdown chip until the muscle is recovered), and selection (name
/// color: green = the selected workout hits it and it's ready, amber =
/// it hits it but the muscle isn't recovered yet; untargeted rows dim).
class VolumeCard extends StatelessWidget {
  final List<MuscleVolume> volume;
  final List<MuscleRecoveryStatus> recovery;

  /// Primary muscles of the selected template; empty = nothing selected
  /// (no dimming, no colored names).
  final Set<MuscleGroup> highlight;

  const VolumeCard({
    super.key,
    required this.volume,
    required this.recovery,
    this.highlight = const {},
  });

  static const _recoveryKeys = {
    'chest': MuscleGroup.MUSCLE_GROUP_CHEST,
    'back': MuscleGroup.MUSCLE_GROUP_BACK,
    'shoulders': MuscleGroup.MUSCLE_GROUP_SHOULDERS,
    'biceps': MuscleGroup.MUSCLE_GROUP_BICEPS,
    'triceps': MuscleGroup.MUSCLE_GROUP_TRICEPS,
    'quads': MuscleGroup.MUSCLE_GROUP_QUADS,
    'hamstrings': MuscleGroup.MUSCLE_GROUP_HAMSTRINGS,
    'glutes': MuscleGroup.MUSCLE_GROUP_GLUTES,
    'calves': MuscleGroup.MUSCLE_GROUP_CALVES,
    'core': MuscleGroup.MUSCLE_GROUP_CORE,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (volume.isEmpty) return const SizedBox.shrink();
    final recoveryByMuscle = <MuscleGroup, MuscleRecoveryStatus>{
      for (final entry in recovery)
        if (_recoveryKeys[entry.muscleKey] != null)
          _recoveryKeys[entry.muscleKey]!: entry,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        borderRadius: context.tokens.brMd,
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          for (final entry in volume)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: _VolumeRow(
                entry: entry,
                recovery: recoveryByMuscle[entry.muscle],
                targeted: highlight.contains(entry.muscle),
                anySelected: highlight.isNotEmpty,
              ),
            ),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final MuscleVolume entry;
  final MuscleRecoveryStatus? recovery;
  final bool targeted;
  final bool anySelected;

  const _VolumeRow({
    required this.entry,
    required this.recovery,
    required this.targeted,
    required this.anySelected,
  });

  static const _trackMax = 24.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sets = entry.completedSets7d;
    final low = entry.targetLow.toDouble();
    final high = entry.targetHigh.toDouble();
    final inBand = sets >= low && sets <= high;
    final over = sets > high;
    final fill = over
        ? context.tokens.accentAmber
        : inBand
        ? context.tokens.accentGreen
        : context.tokens.outline;

    final recovering = recovery != null && !recovery!.recovered;
    // The selected workout's muscles are picked out in the primary orange.
    final nameColor = targeted ? context.tokens.primary : cs.onSurface;

    final row = Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            muscleShortLabels[entry.muscle] ?? '?',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.tokens.size.bodyLg,
              fontWeight: context.tokens.weight.bold,
              color: nameColor,
            ),
          ),
        ),
        // Hours still recovering, just left of the bar; the slot is kept
        // empty when there are none so every bar lines up.
        SizedBox(
          width: 52,
          child: recovering
              ? Align(
                  alignment: Alignment.centerRight,
                  child: _RecoveryChip(
                    hours: recovery!.hoursRemaining.toInt(),
                    urgent: targeted,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 6,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    // Track with the 10–20 band zone tinted.
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: context.tokens.br(6),
                      ),
                    ),
                    Positioned(
                      left: width * (low / _trackMax),
                      width: width * ((high - low) / _trackMax),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        color: context.tokens.accentGreen.withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),
                    // The fill, inset like the mock's rounded pill.
                    Positioned(
                      left: 0,
                      top: 2,
                      bottom: 2,
                      width: width * (sets / _trackMax).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: context.tokens.br(4),
                        ),
                      ),
                    ),
                    // Tick at the band floor.
                    Positioned(
                      left: width * (low / _trackMax) - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: cs.onSurface.withValues(alpha: 0.28),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: sets % 1 == 0
                      ? sets.toStringAsFixed(0)
                      : sets.toStringAsFixed(1),
                  // In the target range the number goes green.
                  style: TextStyle(
                    color: inBand
                        ? context.tokens.accentGreen
                        : over
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                if (over)
                  TextSpan(
                    text: '▲',
                    style: TextStyle(color: context.tokens.accentAmber),
                  ),
              ],
            ),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: context.tokens.size.bodyLg,
              fontWeight: context.tokens.weight.heavy,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );

    // With a workout selected, untargeted muscles step back.
    return Opacity(opacity: anySelected && !targeted ? 0.45 : 1.0, child: row);
  }
}

/// "14h" — hours until this muscle is recovered. Amber when the selected
/// workout is about to train it anyway.
class _RecoveryChip extends StatelessWidget {
  final int hours;
  final bool urgent;
  const _RecoveryChip({required this.hours, required this.urgent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = urgent
        ? context.tokens.primary
        : cs.onSurface.withValues(alpha: 0.45);
    final border = urgent
        ? context.tokens.primary
        : cs.outline.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: context.tokens.br(6),
      ),
      child: Text(
        '${hours}h',
        style: TextStyle(
          fontSize: context.tokens.size.small,
          fontWeight: context.tokens.weight.heavy,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}

// ── Template cards ───────────────────────────────────────────────────────────

/// A small tappable summary of one template: name, rough duration, and a
/// star on the volume recommendation. Deliberately dense — these wrap
/// three-plus to a row.
class TemplateChip extends StatelessWidget {
  final WorkoutTemplate template;
  final List<ExerciseTracker> trackers;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  const TemplateChip({
    super.key,
    required this.template,
    required this.trackers,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = estimatedSessionLabel(template, trackers);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.12) : null,
          borderRadius: context.tokens.br(10),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (recommended)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(AppIcons.star, size: 14, color: cs.primary),
              ),
            Text(
              template.name,
              style: TextStyle(
                fontSize: context.tokens.size.body,
                fontWeight: context.tokens.weight.heavy,
                letterSpacing: -0.2,
              ),
            ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: context.tokens.size.small,
                    fontWeight: context.tokens.weight.bold,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The one expanded card: every exercise with the exact numbers the workout
/// will start with, the muscles it hits, the time it should take, and START.
class SelectedTemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final List<ExerciseTracker> trackers;
  final WeightUnit unit;
  final bool recommended;
  final String suggestionReason;
  final bool isStarting;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SelectedTemplateCard({
    super.key,
    required this.template,
    required this.trackers,
    required this.unit,
    required this.recommended,
    required this.suggestionReason,
    required this.isStarting,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
  });

  ExerciseTracker? _trackerFor(Exercise exercise) {
    for (final tracker in trackers) {
      if (tracker.exercise == exercise) return tracker;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = recommended ? cs.primary : cs.outline.withValues(alpha: 0.6);
    final time = estimatedSessionLabel(template, trackers);

    return Container(
      decoration: BoxDecoration(
        borderRadius: context.tokens.brMd,
        border: Border.all(color: accent, width: 2),
        color: recommended ? cs.primary.withValues(alpha: 0.05) : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            template.name,
                            style: TextStyle(
                              fontSize: context.tokens.size.titleLg,
                              fontWeight: context.tokens.weight.heavy,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (time.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              time,
                              style: TextStyle(
                                fontSize: context.tokens.size.bodyLg,
                                fontWeight: context.tokens.weight.bold,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (recommended)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          suggestionReason.isEmpty
                              ? 'Recommended next'
                              : 'Recommended: $suggestionReason',
                          style: TextStyle(
                            fontSize: context.tokens.size.body,
                            fontWeight: context.tokens.weight.bold,
                            color: cs.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  AppIcons.more,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          for (final exercise in template.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 5, right: 8),
              child: _ExerciseLine(
                exercise: exercise,
                tracker: _trackerFor(exercise),
                unit: unit,
              ),
            ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TutorialTarget(
              id: 'home_start',
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: isStarting ? null : onStart,
                  child: isStarting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'START',
                          style: TextStyle(
                            fontWeight: context.tokens.weight.heavy,
                            fontSize: context.tokens.size.subtitle,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of a template card: "Squat   3×8 @ 185 lb".
class _ExerciseLine extends StatelessWidget {
  final Exercise exercise;
  final ExerciseTracker? tracker;
  final WeightUnit unit;

  const _ExerciseLine({
    required this.exercise,
    required this.tracker,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = exerciseNames[exercise] ?? '?';
    final resolved = tracker;
    final prescription = resolved == null
        ? ''
        : resolved.workingWeight > 0
        ? '${resolved.sets}×${resolved.targetReps} @ '
              '${formatWeight(resolved.workingWeight, unit, includeUnit: true)}'
        : '${resolved.sets}×${resolved.targetReps}';
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: context.tokens.size.bodyLg,
              fontWeight: context.tokens.weight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          prescription,
          style: TextStyle(
            fontSize: context.tokens.size.bodyLg,
            fontWeight: context.tokens.weight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
