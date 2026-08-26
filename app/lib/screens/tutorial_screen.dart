/// The walkthrough: a swipeable carousel of the app's key pieces, built
/// from the real widgets with sample data. Each page annotates its widget
/// with short callout labels connected by hairlines — spec-sheet style —
/// instead of paragraphs. Shown once on first arrival at home, and
/// replayable from the menu ("Tutorial").
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

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
    final pages = _buildPages(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'SKIP',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: pages,
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
                    _page == pages.length - 1 ? "LET'S LIFT" : 'NEXT',
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

  List<Widget> _buildPages(BuildContext context) {
    return [
      _TutorialPage(
        title: 'Your muscles, tracked',
        above: const [
          _Callout('HARD SETS THIS WEEK · AIM FOR THE BAND', 0.62),
        ],
        below: const [
          _Callout('YELLOW = STILL RECOVERING', 0.18),
          _Callout('✓ = ENOUGH VOLUME', 0.88),
        ],
        child: VolumeCard(
          volume: _sampleVolume(),
          recovery: _sampleRecovery(),
          highlight: const {
            MuscleGroup.MUSCLE_GROUP_BACK,
            MuscleGroup.MUSCLE_GROUP_BICEPS,
          },
        ),
      ),
      _TutorialPage(
        title: 'Pick a workout',
        above: const [
          _Callout('★ = SUGGESTED TODAY', 0.14),
        ],
        below: const [
          _Callout('TAP TO SELECT · TEMPLATES ARE YOURS TO EDIT', 0.5),
        ],
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            TemplateChip(
              template: _sampleTemplate(),
              trackers: _sampleTrackers(),
              selected: true,
              recommended: true,
              onTap: () {},
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
        ),
      ),
      _TutorialPage(
        title: 'The numbers are handled',
        above: const [
          _Callout('SETS × REPS @ WEIGHT — ALL PRESCRIBED', 0.6),
        ],
        below: const [
          _Callout('\u{1F525} = WARMUPS INCLUDED', 0.14),
          _Callout('START FROM HERE', 0.85),
        ],
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
      ),
      _TutorialPage(
        title: 'During the workout',
        above: const [
          _Callout('YOUR CURRENT SET — WEIGHT AND REPS TO HIT', 0.55),
        ],
        below: const [
          _Callout('ELAPSED · HEART RATE', 0.16),
          _Callout('TAP WHEN THE SET IS DONE', 0.7),
        ],
        child: const _RealBottomBarSample(),
      ),
      _TutorialPage(
        title: 'Progress happens by itself',
        above: const [
          _Callout('CLEAR EVERY SET → +1 REP', 0.3),
        ],
        below: const [
          _Callout('TOP OF THE RANGE → +WEIGHT, REPS RESET', 0.62),
        ],
        footer: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScienceScreen(),
                ),
              ),
              icon: const Text('🧠', style: TextStyle(fontSize: 15)),
              label: const Text(
                'READ THE PAPERS',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        child: const _ProgressionDiagram(),
      ),
    ];
  }
}

// ── Callout system ───────────────────────────────────────────────────────────

/// A short annotation anchored at a horizontal fraction (0..1) of the
/// page's widget, connected to it by a hairline and a dot.
class _Callout {
  final String label;
  final double x;
  const _Callout(this.label, this.x);
}

/// One layer of callouts above or below the widget: labels on the far
/// row, a 1px connector dropping to (or rising from) the widget edge.
class _CalloutLayer extends StatelessWidget {
  final List<_Callout> callouts;
  final bool below;
  const _CalloutLayer({required this.callouts, required this.below});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineColor = cs.outline.withValues(alpha: 0.8);
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: Stack(
        children: [
          for (final callout in callouts) ...[
            Align(
              alignment: Alignment(callout.x * 2 - 1, below ? 1 : -1),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  callout.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    height: 1.25,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment(callout.x * 2 - 1, below ? -1 : 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (below)
                    _dot()
                  else
                    Container(width: 1, height: 12, color: lineColor),
                  if (below)
                    Container(width: 1, height: 12, color: lineColor)
                  else
                    _dot(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot() => Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: AppTheme.accentGreen,
          shape: BoxShape.circle,
        ),
      );
}

class _TutorialPage extends StatelessWidget {
  final String title;
  final List<_Callout> above;
  final List<_Callout> below;
  final Widget child;
  final Widget? footer;

  const _TutorialPage({
    required this.title,
    required this.child,
    this.above = const [],
    this.below = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          if (above.isNotEmpty) _CalloutLayer(callouts: above, below: false),
          child,
          if (below.isNotEmpty) _CalloutLayer(callouts: below, below: true),
          ?footer,
        ],
      ),
    );
  }
}

// ── Page 4: the real bottom bar, solo layout ─────────────────────────────────

/// The in-workout bottom bar, assembled from the SAME widgets the live bar
/// uses (StatusBox, TimerHeartBox, BigButton) in its solo layout — only
/// the data is a sample and the buttons do nothing.
class _RealBottomBarSample extends StatelessWidget {
  const _RealBottomBarSample();

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
          StatusBox(
            sideLabel: 'YOU',
            sideBadge: '🦆',
            stateLabel: 'Next up',
            color: Theme.of(context).colorScheme.tertiary,
            set: _sampleSet(),
            sideLabelWidth: 44,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              TimerHeartBox(
                elapsedText: '23:41',
                heartRateText: '128',
                heartRateDetected: true,
              ),
              SizedBox(width: 8),
              Expanded(
                child: IgnorePointer(
                  child: BigButton(label: 'Start Set', onPressed: _noop),
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

// ── Page 5: the progression rule as a diagram ────────────────────────────────

class _ProgressionDiagram extends StatelessWidget {
  const _ProgressionDiagram();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget step(String weight, String reps, {bool highlight = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? AppTheme.accentGreen.withValues(alpha: 0.12)
              : cs.surfaceContainerLowest,
          borderRadius: AppTheme.brMd,
          border: Border.all(
            color: highlight
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
        step('140 lb', '3 × 6', highlight: true),
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
