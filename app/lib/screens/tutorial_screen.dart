/// The walkthrough: one page per thing worth pointing at, each built from
/// the real widget with sample data. The piece being explained throbs with
/// a red outline; the title and explanation sit underneath it. Copy comes
/// from app/copy.yaml (see gen/copy.dart). Shown once on first arrival at
/// home, and replayable from the menu ("Tutorial").
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../gen/workout/v1/workout.pb.dart';
import '../theme/app_theme.dart';
import '../widgets/workout_bar/bar_controls.dart';
import '../widgets/workout_status_box.dart';
import 'home/home_screen.dart';
import 'science_screen.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.tutorial;
    final pages = t.pages;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  t.skip,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                itemCount: pages.length,
                itemBuilder: (context, i) => _TutorialPage(
                  page: pages[i],
                  demo: _demoFor(context, pages[i].key),
                  last: i == pages.length - 1,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) {
                return Container(
                  width: i == _page ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _page
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (_page == pages.length - 1) {
                      Navigator.pop(context);
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(
                    _page == pages.length - 1 ? t.finish : t.next,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The sample widget for a page, with the piece being explained wrapped in
  /// [Throb]. Keys match app/copy.yaml; an unknown key shows nothing rather
  /// than crashing, so the copy file can gain a page before the widget does.
  Widget _demoFor(BuildContext context, String key) {
    switch (key) {
      case 'volume':
        return Throb(
          radius: AppTheme.brLg,
          child: VolumeCard(
            volume: _sampleVolume(),
            recovery: _sampleRecovery(),
            highlight: const {
              MuscleGroup.MUSCLE_GROUP_BACK,
              MuscleGroup.MUSCLE_GROUP_BICEPS,
            },
          ),
        );
      case 'suggested':
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Throb(
              radius: BorderRadius.circular(999),
              child: TemplateChip(
                template: _sampleTemplate(),
                trackers: _sampleTrackers(),
                selected: true,
                recommended: true,
                onTap: () {},
              ),
            ),
            TemplateChip(
              template: _sampleTemplate(name: 'Legs', id: 't2'),
              trackers: _sampleTrackers(),
              selected: false,
              recommended: false,
              onTap: () {},
            ),
            TemplateChip(
              template: _sampleTemplate(name: 'Push', id: 't3'),
              trackers: _sampleTrackers(),
              selected: false,
              recommended: false,
              onTap: () {},
            ),
          ],
        );
      case 'plan':
        return Throb(
          radius: AppTheme.brLg,
          child: IgnorePointer(
            child: SelectedTemplateCard(
              template: _sampleTemplate(),
              trackers: _sampleTrackers(),
              unit: WeightUnit.WEIGHT_UNIT_LB,
              recommended: true,
              suggestionReason: 'Back and biceps are behind',
              isStarting: false,
              onStart: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        );
      case 'start':
        return Throb(
          radius: AppTheme.brMd,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () {},
              child: const Text(
                'START',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        );
      case 'current_set':
        return _BottomBarSample(highlight: _BarPart.status);
      case 'timer':
        return _BottomBarSample(highlight: _BarPart.timer);
      case 'complete':
        return _BottomBarSample(highlight: _BarPart.button);
      case 'progression':
        return const _ProgressionDiagram();
      default:
        return const SizedBox.shrink();
    }
  }
}

/// A page: the demo up top, centred, then the title and the explanation.
class _TutorialPage extends StatelessWidget {
  final CopyTutorialPagesItem page;
  final Widget demo;
  final bool last;

  const _TutorialPage({
    required this.page,
    required this.demo,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Room for the glow; it draws outside the widget's box.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: demo,
          ),
          const SizedBox(height: 8),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            page.body,
            style: TextStyle(
              fontSize: 16,
              height: 1.45,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (last)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScienceScreen(),
                    ),
                  ),
                  icon: const Text('🧠', style: TextStyle(fontSize: 15)),
                  label: Text(
                    copy.tutorial.papersButton,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A glowing, throbbing red outline around the thing being explained.
class Throb extends StatefulWidget {
  final Widget child;
  final BorderRadius radius;

  const Throb({super.key, required this.child, required this.radius});

  @override
  State<Throb> createState() => _ThrobState();
}

class _ThrobState extends State<Throb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).scaffoldBackgroundColor;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          // Opaque ground so the glow shows only around the widget, never
          // through it; the outline is painted over the child's edges.
          decoration: BoxDecoration(
            color: surface,
            borderRadius: widget.radius,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentRed.withValues(alpha: 0.35 + 0.35 * t),
                blurRadius: 10 + 18 * t,
                spreadRadius: 1 + 5 * t,
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: widget.radius,
            border: Border.all(
              color: AppTheme.accentRed.withValues(alpha: 0.75 + 0.25 * t),
              width: 2.5,
            ),
          ),
          child: child,
        );
      },
      child: ClipRRect(borderRadius: widget.radius, child: widget.child),
    );
  }
}

// ── The live bar, with one part lit up per page ──────────────────────────────

enum _BarPart { status, timer, button }

class _BottomBarSample extends StatelessWidget {
  final _BarPart highlight;

  const _BottomBarSample({required this.highlight});

  Widget _maybe(_BarPart part, BorderRadius radius, Widget child) =>
      highlight == part ? Throb(radius: radius, child: child) : child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.secondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
          left: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
          right: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _maybe(
            _BarPart.status,
            AppTheme.brMd,
            StatusBox(
              sideLabel: 'YOU',
              sideBadge: '🦆',
              stateLabel: 'Next up',
              color: cs.tertiary,
              set: _sampleSet(),
              sideLabelWidth: 44,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _maybe(
                _BarPart.timer,
                AppTheme.brMd,
                const TimerHeartBox(
                  elapsedText: '23:41',
                  heartRateText: '128',
                  heartRateDetected: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _maybe(
                  _BarPart.button,
                  AppTheme.brMd,
                  const IgnorePointer(
                    child: BigButton(label: 'Complete Set', onPressed: _noop),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}

// ── The progression rule as a diagram ────────────────────────────────────────

class _ProgressionDiagram extends StatelessWidget {
  const _ProgressionDiagram();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget step(String weight, String reps, {bool up = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: up
              ? AppTheme.accentGreen.withValues(alpha: 0.12)
              : cs.surfaceContainerLowest,
          borderRadius: AppTheme.brMd,
          border: Border.all(
            color: up
                ? AppTheme.accentGreen.withValues(alpha: 0.5)
                : cs.outline.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          children: [
            Text(
              weight,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              reps,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    Widget arrow() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        step('135 lb', '3 × 6'),
        arrow(),
        step('135 lb', '3 × 7'),
        arrow(),
        Throb(radius: AppTheme.brMd, child: step('140 lb', '3 × 6', up: true)),
      ],
    );
  }
}

// ── Sample data (never touches the network) ──────────────────────────────────

ProposedSet _sampleSet() => ProposedSet()
  ..id = 'sample'
  ..exercise = Exercise.EXERCISE_BARBELL_ROW
  ..targetReps = 6
  ..targetWeight = 115;

WorkoutTemplate _sampleTemplate({String name = 'Pull', String id = 't1'}) {
  return WorkoutTemplate()
    ..id = id
    ..name = name
    ..exercises.addAll(
      name == 'Pull'
          ? [
              Exercise.EXERCISE_BARBELL_ROW,
              Exercise.EXERCISE_PULL_UP,
              Exercise.EXERCISE_DUMBBELL_ROW,
              Exercise.EXERCISE_BARBELL_CURL,
            ]
          : name == 'Legs'
          ? [
              Exercise.EXERCISE_SQUAT,
              Exercise.EXERCISE_ROMANIAN_DEADLIFT,
              Exercise.EXERCISE_CALF_RAISE,
            ]
          : [
              Exercise.EXERCISE_BENCH_PRESS,
              Exercise.EXERCISE_OVERHEAD_PRESS,
              Exercise.EXERCISE_LATERAL_RAISE,
            ],
    );
}

ExerciseTracker _tracker(
  Exercise exercise,
  double weight,
  int sets,
  int reps,
  int rest, {
  bool warmup = false,
  MuscleGroup muscle = MuscleGroup.MUSCLE_GROUP_UNSPECIFIED,
}) {
  return ExerciseTracker()
    ..exercise = exercise
    ..workingWeight = weight
    ..sets = sets
    ..targetReps = reps
    ..repRangeLow = reps
    ..repRangeHigh = reps + 4
    ..restSeconds = rest
    ..includeWarmup = warmup
    ..primaryMuscle = muscle;
}

List<ExerciseTracker> _sampleTrackers() {
  return [
    _tracker(Exercise.EXERCISE_BARBELL_ROW, 115, 3, 6, 150,
        warmup: true, muscle: MuscleGroup.MUSCLE_GROUP_BACK),
    _tracker(Exercise.EXERCISE_PULL_UP, 0, 3, 5, 120,
        muscle: MuscleGroup.MUSCLE_GROUP_BACK),
    _tracker(Exercise.EXERCISE_DUMBBELL_ROW, 40, 3, 8, 120,
        muscle: MuscleGroup.MUSCLE_GROUP_BACK),
    _tracker(Exercise.EXERCISE_BARBELL_CURL, 45, 3, 10, 90,
        muscle: MuscleGroup.MUSCLE_GROUP_BICEPS),
    _tracker(Exercise.EXERCISE_SQUAT, 185, 3, 6, 180,
        warmup: true, muscle: MuscleGroup.MUSCLE_GROUP_QUADS),
    _tracker(Exercise.EXERCISE_ROMANIAN_DEADLIFT, 155, 3, 6, 180,
        warmup: true, muscle: MuscleGroup.MUSCLE_GROUP_HAMSTRINGS),
    _tracker(Exercise.EXERCISE_CALF_RAISE, 25, 3, 10, 90,
        muscle: MuscleGroup.MUSCLE_GROUP_CALVES),
    _tracker(Exercise.EXERCISE_BENCH_PRESS, 135, 3, 6, 150,
        warmup: true, muscle: MuscleGroup.MUSCLE_GROUP_CHEST),
    _tracker(Exercise.EXERCISE_OVERHEAD_PRESS, 75, 3, 6, 150,
        warmup: true, muscle: MuscleGroup.MUSCLE_GROUP_SHOULDERS),
    _tracker(Exercise.EXERCISE_LATERAL_RAISE, 15, 3, 10, 90,
        muscle: MuscleGroup.MUSCLE_GROUP_SHOULDERS),
  ];
}

MuscleVolume _volume(MuscleGroup muscle, double sets) => MuscleVolume()
  ..muscle = muscle
  ..completedSets7d = sets
  ..targetLow = 10
  ..targetHigh = 20;

List<MuscleVolume> _sampleVolume() {
  return [
    _volume(MuscleGroup.MUSCLE_GROUP_CHEST, 12),
    _volume(MuscleGroup.MUSCLE_GROUP_BACK, 4.5),
    _volume(MuscleGroup.MUSCLE_GROUP_SHOULDERS, 6.5),
    _volume(MuscleGroup.MUSCLE_GROUP_BICEPS, 2),
    _volume(MuscleGroup.MUSCLE_GROUP_TRICEPS, 7.5),
    _volume(MuscleGroup.MUSCLE_GROUP_QUADS, 11),
    _volume(MuscleGroup.MUSCLE_GROUP_HAMSTRINGS, 5),
    _volume(MuscleGroup.MUSCLE_GROUP_GLUTES, 12.5),
    _volume(MuscleGroup.MUSCLE_GROUP_CALVES, 3),
    _volume(MuscleGroup.MUSCLE_GROUP_CORE, 3),
  ];
}

List<MuscleRecoveryStatus> _sampleRecovery() {
  MuscleRecoveryStatus status(String key, bool recovered, int hours) =>
      MuscleRecoveryStatus()
        ..muscleKey = key
        ..recovered = recovered
        ..hoursRemaining = Int64(hours);
  return [
    status('chest', false, 14),
    status('back', true, 0),
    status('shoulders', false, 2),
    status('biceps', true, 0),
    status('triceps', false, 2),
    status('quads', true, 0),
    status('hamstrings', true, 0),
    status('glutes', true, 0),
    status('calves', true, 0),
    status('core', true, 0),
  ];
}
