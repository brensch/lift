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
import 'package:provider/provider.dart';

import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../logic/weight_units.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/health_service.dart';
import '../../services/wearable_bridge_service.dart';
import '../../theme/app_theme.dart';
import 'template_editor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isStarting = false;

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
        const [],
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

  Future<void> _setUpHealthAndWatch(WearableBridgeService bridge) async {
    // ONE comprehensive Health permission request, fully awaited, THEN launch
    // the watch — never concurrently (the iOS half-answered-sheet bug).
    await HealthService.requestWorkoutHealthPermissions();
    try {
      if (await bridge.isWatchAppAvailable()) {
        await bridge.openWatchApp();
      }
    } catch (e) {
      debugPrint('Auto watch launch failed: $e');
    }
  }

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
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Your weights are safe — they live on the exercises, not the '
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

    final templates = home.templates;
    final suggestedId = home.suggestedTemplateId;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _VolumeCard(volume: home.volume),
          const SizedBox(height: 16),
          if (templates.isEmpty) _EmptyState(onCreate: () => _editTemplate(null)),
          // Suggested first, then user order.
          for (final template in _ordered(templates, suggestedId))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TemplateCard(
                template: template,
                trackers: wp.trackers,
                unit: unit,
                suggested: template.id == suggestedId,
                suggestionReason:
                    template.id == suggestedId ? home.suggestionReason : '',
                isStarting: _isStarting,
                onStart: () => _start(templateId: template.id),
                onEdit: () => _editTemplate(template),
                onDelete: () => _confirmDeleteTemplate(template),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editTemplate(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'NEW TEMPLATE',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isStarting ? null : () => _start(),
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text(
                    'START EMPTY',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<WorkoutTemplate> _ordered(
    List<WorkoutTemplate> templates,
    String suggestedId,
  ) {
    if (suggestedId.isEmpty) return templates;
    return [
      ...templates.where((t) => t.id == suggestedId),
      ...templates.where((t) => t.id != suggestedId),
    ];
  }
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
        borderRadius: AppTheme.brMd,
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text('🏗️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'No templates yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'A template is just a list of exercises. The app handles the '
            'sets, reps and weight.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onCreate,
            child: const Text('CREATE ONE'),
          ),
        ],
      ),
    );
  }
}

// ── Weekly volume ────────────────────────────────────────────────────────────

/// Ten compact bars: weighted hard sets per muscle in the last 7 days,
/// against the 10–20 band. This is the honesty panel — the app prescribes
/// per-exercise numbers, so weekly volume is decided by what you pick, and
/// this is where you see it.
class _VolumeCard extends StatelessWidget {
  final List<MuscleVolume> volume;
  const _VolumeCard({required this.volume});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (volume.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: AppTheme.brMd,
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETS THIS WEEK · AIM FOR 10–20 PER MUSCLE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in volume)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _VolumeRow(entry: entry),
            ),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final MuscleVolume entry;
  const _VolumeRow({required this.entry});

  static const _labels = {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sets = entry.completedSets7d;
    final low = entry.targetLow.toDouble();
    final high = entry.targetHigh.toDouble();
    // The bar spans 0..high; the band marker sits at low.
    final fraction = (sets / high).clamp(0.0, 1.0);
    final inBand = sets >= low && sets <= high;
    final over = sets > high;
    final color = over
        ? cs.error
        : inBand
        ? const Color(0xFF7CF2C0)
        : cs.onSurface.withValues(alpha: 0.35);

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            _labels[entry.muscle] ?? '?',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    // The band-floor tick at 10 sets.
                    Positioned(
                      left: width * (low / high) - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            sets % 1 == 0 ? sets.toStringAsFixed(0) : sets.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// ── Template cards ───────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final List<ExerciseTracker> trackers;
  final WeightUnit unit;
  final bool suggested;
  final String suggestionReason;
  final bool isStarting;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.trackers,
    required this.unit,
    required this.suggested,
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
    final accent = suggested ? cs.primary : cs.outline.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.brMd,
        border: Border.all(color: accent, width: suggested ? 2 : 1),
        color: suggested ? cs.primary.withValues(alpha: 0.05) : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (suggested && suggestionReason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Up next — $suggestionReason',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
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
          const SizedBox(height: 6),
          for (final exercise in template.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _ExerciseLine(
                exercise: exercise,
                tracker: _trackerFor(exercise),
                unit: unit,
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: suggested
                  ? FilledButton(
                      onPressed: isStarting ? null : onStart,
                      child: const Text(
                        'START',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: isStarting ? null : onStart,
                      child: const Text(
                        'START',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          prescription,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
