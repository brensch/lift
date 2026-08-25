/// The walkthrough: a swipeable carousel of the app's key pieces, built
/// from the real widgets with sample data — not screenshots. Shown once
/// on first arrival at home, and replayable from the menu ("Tutorial").
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../gen/workout/v1/workout.pb.dart';
import '../theme/app_theme.dart';
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
        body:
            'Every hard set you do is counted per muscle across a '
            'rolling week. Aim for the band — 10 to 20 sets per muscle '
            'per week is what maximises growth. The tick marks 10; a '
            'chip like "14h" means that muscle is still recovering.',
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
        body:
            'Your workouts are templates — just lists of exercises. Tap '
            'a chip to see one; the ★ marks what we suggest based on '
            'which muscles are furthest behind this week. "Empty" is for '
            'making it up as you go, and "New" builds your own.',
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
        title: 'We bring the numbers',
        body:
            'Weight, sets, reps, rest — all handled, for every exercise. '
            'The 🔥 lifts get a warmup ladder. If a weight is wrong, '
            'tap the exercise mid-workout and nudge it up or down; '
            'everything else stays prescribed.',
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
        body:
            'The bar at the bottom always shows your current set: the '
            'weight to load, the reps to hit. Lift, tap done, and the '
            'rest timer runs — go again when it says go. Stop 1–2 reps '
            'before failure.',
        child: _SampleSetBar(),
      ),
      _TutorialPage(
        title: 'Progress happens by itself',
        body:
            'Clear every set and next time asks for one more rep. Top '
            'the rep range and the weight goes up a notch. Struggle '
            'twice and we back off 10% so you can build back stronger. '
            'You lift; the app remembers.',
        child: Center(
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
    ];
  }
}

class _TutorialPage extends StatelessWidget {
  final String title;
  final String body;
  final Widget child;

  const _TutorialPage({
    required this.title,
    required this.body,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// A faithful miniature of the in-workout bottom bar, built from the
/// app's own primitives (provider-free so the tutorial can render it).
class _SampleSetBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.panelDark,
        borderRadius: AppTheme.brMd,
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UP NEXT · SET 2 OF 3',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Barbell Row',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '115',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(
                  'lb × 8 reps',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: AppTheme.accentGreen,
                disabledForegroundColor: const Color(0xFF0A0A0A),
              ),
              child: const Text(
                'DONE — LOG SET',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sample data (never touches the network) ──────────────────────────────────

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
