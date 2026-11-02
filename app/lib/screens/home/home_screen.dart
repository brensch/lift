/// Home: your templates, your weekly volume, and one suggestion.
///
/// A template is an ordered list of exercises and nothing else — the core
/// plans sets, reps, rest and weight in the time the user has, so every
/// card here shows the numbers the workout will actually start with, and
/// why. The chips are in groups: the rotation, the favourites, then New
/// and Manage.
/// The suggestion is the rotation template whose rested muscles are
/// furthest below the 10–20 weekly-set band, and the card says which; it
/// is one tap, never a gate.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../tutorial/tutorial_seen.dart';
import '../../tutorial/tutorial_target.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/settings.pb.dart' show MuscleGroup, WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../logic/plan_text.dart';
import '../../logic/rotation_text.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/wearable_bridge_service.dart';
import '../../theme/theme_spec.dart';
import '../tutorial_screen.dart';
import 'template_editor.dart';
import 'template_library_sheet.dart';
import '../../widgets/common/flat.dart';
import '../../widgets/template_row.dart';
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

  /// The Edit sheet: the user's workouts and the library.
  Future<void> _editTemplates() =>
      showTemplateLibrary(context, provider: context.read<WorkoutProvider>());

  /// Open a library workout in the editor to make it the user's own:
  /// nothing changes until Save there.
  Future<void> _cloneTemplate(WorkoutTemplate template) => showTemplateEditor(
    context,
    template: template,
    provider: context.read<WorkoutProvider>(),
    personalise: true,
  );

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
    Widget chip(WorkoutTemplate template) => TemplateChip(
      template: template,
      selected: template.id == selected?.id,
      recommended: template.id == suggestedId,
      onTap: () => setState(() => _selectedTemplateId = template.id),
    );
    final highlight = selected == null
        ? const <MuscleGroup>{}
        : templateMuscles(selected, wp.plans).toSet();

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
              child: _TemplateChips(
                rotation: [
                  for (final template in templates)
                    if (template.inRotation) chip(template),
                ],
                favourites: [
                  for (final template in templates)
                    if (!template.inRotation) chip(template),
                  _ActionChip(
                    icon: AppIcons.lightning,
                    label: 'Empty',
                    selected: emptySelected,
                    onTap: () =>
                        setState(() => _selectedTemplateId = _emptyWorkoutId),
                  ),
                ],
                actions: [
                  // Straight to a blank workout of your own.
                  _ActionChip(
                    icon: AppIcons.add,
                    label: copy.library.newButton,
                    selected: false,
                    onTap: () => _editTemplate(null),
                  ),
                  TutorialTarget(
                    id: 'home_add',
                    child: _ActionChip(
                      icon: AppIcons.lines,
                      label: copy.library.editButton,
                      selected: false,
                      onTap: _editTemplates,
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
                  plan: wp.templatePlanFor(selected.id),
                  budgetMinutes: wp.budgetMinutes,
                  onBudgetStep: wp.stepBudget,
                  unit: unit,
                  recommended: selected.id == suggestedId,
                  reason:
                      selected.id == suggestedId && home.hasSuggestionReason()
                      ? suggestionLine(home.suggestionReason)
                      : '',
                  isStarting: _isStarting,
                  onStart: () => _start(templateId: selected!.id),
                  onEdit: () => _editTemplate(selected),
                  onClone: () => _cloneTemplate(selected!),
                  onDelete: () => _confirmDeleteTemplate(selected!),
                  onToggleRotation: () =>
                      wp.setInRotation(selected!, !selected.inRotation),
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

/// The template chips in three groups: the rotation and the favourites
/// (the Empty workout chip last), each under its title, then a line of
/// the action chips. A group with nothing in it has no title; an empty
/// rotation says how to fill it.
class _TemplateChips extends StatelessWidget {
  final List<Widget> rotation;
  final List<Widget> favourites;
  final List<Widget> actions;

  const _TemplateChips({
    required this.rotation,
    required this.favourites,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = copy.library;
    Widget wrap(List<Widget> children) =>
        Wrap(spacing: 6, runSpacing: 6, children: children);
    Widget group(String title, List<Widget> chips) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SectionLabel(title), const SizedBox(height: 6), wrap(chips)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rotation.isEmpty)
          Text(
            l.rotationEmptyHome,
            style: TextStyle(fontSize: t.size.body, color: t.muted),
          )
        else
          group(l.rotationHeading, rotation),
        if (favourites.isNotEmpty) ...[
          const SizedBox(height: 12),
          group(l.favouritesHeading, favourites),
        ],
        const SizedBox(height: 12),
        wrap(actions),
      ],
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
      // The same panel as the workout card it stands in for.
      decoration: BoxDecoration(
        borderRadius: context.tokens.brMd,
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        color: context.tokens.panel,
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
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : context.tokens.panel,
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

/// The distinct primary muscles a template trains, in exercise order, from
/// each lift's plan (Home's [plans] hold every lift's).
List<MuscleGroup> templateMuscles(
  WorkoutTemplate template,
  List<ExercisePlan> plans,
) {
  final byExercise = {
    for (final p in plans) p.decision.exercise: p.primaryMuscle,
  };
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
///
/// [proportional] draws shares instead (the Manage sheet's lap of the main
/// plan, which is not a week): each bar against the most-trained muscle's,
/// with no band, no tick, no set count and no recovery chip.
class VolumeCard extends StatelessWidget {
  final List<MuscleVolume> volume;
  final List<MuscleRecoveryStatus> recovery;

  /// Primary muscles of the selected template; empty = nothing selected
  /// (no dimming, no colored names). Not drawn when [proportional].
  final Set<MuscleGroup> highlight;

  /// Bars as shares of the largest, not against the weekly target.
  final bool proportional;

  const VolumeCard({
    super.key,
    required this.volume,
    required this.recovery,
    this.highlight = const {},
    this.proportional = false,
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
    final most = volume.fold<double>(
      0,
      (most, v) => v.completedSets7d > most ? v.completedSets7d : most,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        borderRadius: context.tokens.brMd,
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        color: context.tokens.panel,
      ),
      child: Column(
        children: [
          for (final entry in volume)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: proportional
                  ? _ShareRow(entry: entry, most: most)
                  : _VolumeRow(
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

/// One muscle as a share: its name and a bar against [most], the
/// largest of the card's. Nothing else.
class _ShareRow extends StatelessWidget {
  final MuscleVolume entry;
  final double most;

  const _ShareRow({required this.entry, required this.most});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cs = Theme.of(context).colorScheme;
    final share = most > 0
        ? (entry.completedSets7d / most).clamp(0.0, 1.0)
        : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            muscleShortLabels[entry.muscle] ?? '?',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: t.size.bodyLg,
              fontWeight: t.weight.bold,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: t.br(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: share,
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.muted,
                      borderRadius: t.br(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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

/// A small tappable summary of one template: its name and a star on the
/// volume recommendation. The time it takes is on the selected card.
class TemplateChip extends StatelessWidget {
  final WorkoutTemplate template;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  const TemplateChip({
    super.key,
    required this.template,
    required this.selected,
    required this.recommended,
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
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : context.tokens.panel,
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
            if (!template.coupled)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(AppIcons.copy, size: 14, color: cs.primary),
              ),
            Text(
              template.name,
              style: TextStyle(
                fontSize: context.tokens.size.body,
                fontWeight: context.tokens.weight.heavy,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one expanded card: the time the user has, every exercise with the
/// exact numbers the workout will start with and why, the time it should
/// take, and START.
class SelectedTemplateCard extends StatelessWidget {
  final WorkoutTemplate template;

  /// The template planned in the budget; null before the first load.
  final TemplatePlan? plan;
  final int budgetMinutes;
  final ValueChanged<int> onBudgetStep;
  final WeightUnit unit;
  final bool recommended;

  /// Why it is suggested, from the core's reason; empty when it is not.
  final String reason;
  final bool isStarting;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onClone;
  final VoidCallback onDelete;
  final VoidCallback onToggleRotation;

  const SelectedTemplateCard({
    super.key,
    required this.template,
    required this.plan,
    required this.budgetMinutes,
    required this.onBudgetStep,
    required this.unit,
    required this.recommended,
    required this.reason,
    required this.isStarting,
    required this.onStart,
    required this.onEdit,
    required this.onClone,
    required this.onDelete,
    required this.onToggleRotation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = recommended ? cs.primary : cs.outline.withValues(alpha: 0.5);
    final plans = plan?.plans ?? const <ExercisePlan>[];

    return Container(
      decoration: BoxDecoration(
        borderRadius: context.tokens.brMd,
        border: Border.all(color: accent),
        color: context.tokens.panel,
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
                    Text(
                      template.name,
                      style: TextStyle(
                        fontSize: context.tokens.size.titleLg,
                        fontWeight: context.tokens.weight.heavy,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!template.coupled) const PersonalTag(),
                    if (recommended && reason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: context.tokens.size.body,
                            color: cs.onSurface.withValues(alpha: 0.6),
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
                  if (value == 'clone') onClone();
                  if (value == 'delete') onDelete();
                  if (value == 'rotation') onToggleRotation();
                },
                // A library workout follows the library: clone it to make
                // it yours. Your own you edit. Either goes in or out of
                // the rotation.
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rotation',
                    child: Text(
                      template.inRotation
                          ? copy.rotation.remove
                          : copy.rotation.add,
                    ),
                  ),
                  if (template.coupled) ...[
                    PopupMenuItem(
                      value: 'clone',
                      child: Text(copy.library.clone),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(copy.library.remove),
                    ),
                  ] else ...[
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(copy.library.delete),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 8),
            child: _TimeControl(
              plan: plan ?? TemplatePlan.getDefault(),
              budgetMinutes: budgetMinutes,
              onStep: onBudgetStep,
            ),
          ),
          for (final exercisePlan in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: _ExerciseLine(decision: exercisePlan.decision, unit: unit),
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

/// "− 60 min +" and what the plan takes: "~52 min", "Needs 70 min" when
/// two sets a lift don't fit, or "~62 min · the longest it gets" when the
/// budget is at or past what the workout can use (its `max_seconds`): then
/// + buys nothing and is off. The budget is shared by every template, so
/// it is never moved here; only this template's cap is shown. A lift never
/// done ramps until a set falls short, so a workout with one has no length
/// to give: the calibration line stands in its place.
class _TimeControl extends StatelessWidget {
  final TemplatePlan plan;
  final int budgetMinutes;
  final ValueChanged<int> onStep;

  const _TimeControl({
    required this.plan,
    required this.budgetMinutes,
    required this.onStep,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    if (plan.plans.any((p) => p.decision.calibration)) {
      return Text(
        copy.plan.calibration,
        style: TextStyle(fontSize: t.size.body, color: t.muted),
      );
    }
    final seconds = plan.estimatedSeconds;
    final budget = budgetMinutes * 60;
    final over = seconds > budget;
    final capped = plan.maxSeconds > 0 && budget >= plan.maxSeconds;
    final template = over
        ? copy.plan.needs
        : (capped ? copy.plan.longest : copy.plan.estimate);
    final estimate = seconds <= 0
        ? ''
        : template.replaceAll('{min}', '${planMinutes(seconds)}');
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onStep(-1),
          icon: const Icon(AppIcons.removeCircle),
        ),
        Text(
          copy.plan.budget.replaceAll('{min}', '$budgetMinutes'),
          style: TextStyle(
            fontSize: t.size.bodyLg,
            fontWeight: t.weight.heavy,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: capped ? null : () => onStep(1),
          icon: const Icon(AppIcons.addCircle),
        ),
        Expanded(
          child: Text(
            estimate,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: t.size.body,
              fontWeight: t.weight.bold,
              color: over ? cs.error : cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// One lift of a template card: "Squat   3×8 @ 185 lb", and under it why.
class _ExerciseLine extends StatelessWidget {
  final ExerciseDecision decision;
  final WeightUnit unit;

  const _ExerciseLine({required this.decision, required this.unit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = exerciseNames[decision.exercise] ?? '?';
    final reason = reasonShort(decision, unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              planLine(decision, unit),
              style: TextStyle(
                fontSize: context.tokens.size.bodyLg,
                fontWeight: context.tokens.weight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        if (reason.isNotEmpty)
          Text(
            reason,
            style: TextStyle(
              fontSize: context.tokens.size.small,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }
}
