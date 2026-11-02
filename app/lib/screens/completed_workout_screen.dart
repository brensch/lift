import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../logic/exercise_blocks.dart';
import '../logic/exercises.dart';
import '../logic/plan_text.dart';
import '../logic/session_state.dart';
import '../logic/user_profile.dart';
import '../logic/weight_units.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/grpc_client.dart';
import '../services/multiplayer_service.dart';
import '../services/workout_service.dart';
import '../widgets/common/flat.dart';
import '../widgets/heart_rate/heart_rate_chart.dart';
import '../widgets/set_log.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';
import '../gen/copy.dart';

class CompletedWorkoutScreen extends StatefulWidget {
  final String workoutId;
  final bool isHistory;

  const CompletedWorkoutScreen({
    super.key,
    required this.workoutId,
    this.isHistory = false,
  });

  @override
  State<CompletedWorkoutScreen> createState() => _CompletedWorkoutScreenState();
}

class _CompletedWorkoutScreenState extends State<CompletedWorkoutScreen> {
  // Self-contained data — no dependency on WorkoutProvider
  Workout? _workout;
  WorkoutSummary? _summary;
  List<ProposedSet> _proposedSets = [];
  List<CompletedSet> _completedSets = [];
  List<ExerciseLog> _logs = [];

  bool _isLoading = true;
  String? _loadError;
  List<User> _sessionFriends = [];
  bool _sessionFriendsLoaded = false;
  List<HeartRateSample> _heartRateSamples = [];

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  Future<void> _loadWorkout() async {
    final grpc = context.read<GrpcClient>();
    final workoutProvider = context.read<WorkoutProvider>();
    final service = context.read<WorkoutServiceWrapper>();
    final multiplayer = MultiplayerServiceWrapper(grpc);
    try {
      _loadError = null;
      final response = await service.getWorkout(widget.workoutId);
      final sessionId = response.workout.sessionId;
      if (mounted) {
        setState(() {
          _workout = response.workout;
          _summary = response.summary;
          _proposedSets = List.from(response.proposedSets);
          _completedSets = List.from(response.completedSets);
          _logs = List.from(response.exerciseLogs);
          _heartRateSamples = workoutProvider.workout?.id == response.workout.id
              ? workoutProvider.wearHeartRateSamples
              : const [];
          _isLoading = false;
          _loadError = null;
          _sessionFriends = [];
          _sessionFriendsLoaded = sessionId.isEmpty;
        });
      }

      if (sessionId.isNotEmpty) {
        await _loadSessionFriends(sessionId, multiplayer);
      }
    } catch (e, st) {
      debugPrint(
        'CompletedWorkoutScreen: failed to load workout ${widget.workoutId}: $e\n$st',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load workout summary.';
        });
      }
    }
  }

  Future<void> _loadSessionFriends(
    String sessionId,
    MultiplayerServiceWrapper service,
  ) async {
    List<User> friends = [];
    try {
      final rosters = await service.getSessionRosters([sessionId]);
      friends = [for (final r in rosters) ...r.partners];
    } catch (_) {
      friends = [];
    }
    if (mounted) {
      setState(() {
        _sessionFriends = friends;
        _sessionFriendsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_workout == null) {
      return Scaffold(
        appBar: AppBar(title: PageTitle('Workout summary')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError ?? 'Failed to load workout summary.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                    });
                    _loadWorkout();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final workout = _workout!;
    final ownProposedSets = _proposedSets
        .where((p) => p.workoutId == workout.id)
        .toList();
    final ownCompletedSets = _completedSets
        .where((c) => c.workoutId == workout.id)
        .toList();
    final auth = context.watch<AuthProvider>();
    final unit = context.watch<SettingsProvider>().weightUnit;
    final summary = WorkoutSummaryData(_summary ?? WorkoutSummary(), unit);
    final hasHeartRateChart =
        workout.startTime != Int64.ZERO && _heartRateSamples.isNotEmpty;
    final chartNow = workout.endTime != Int64.ZERO
        ? DateTime.fromMillisecondsSinceEpoch(workout.endTime.toInt() * 1000)
        : DateTime.now();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            onPressed: _handleBackNavigation,
          ),
          title: PageTitle(
            workout.name.isNotEmpty ? workout.name : 'Workout summary',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            FlatSection(
              label: 'Session',
              bleed: true,
              flushBottom: true,
              child: _MetricGrid(
                metrics: [
                  ('Duration', summary.durationLabel, null),
                  ('Volume', summary.volumeLabel, null),
                  ('Sets', '${summary.workingSets}', null),
                  (
                    copy.workout.lifting,
                    summary.liftingTimeLabel,
                    context.tokens.lifting,
                  ),
                  (
                    copy.workout.resting,
                    summary.restingTimeLabel,
                    context.tokens.resting,
                  ),
                  (
                    copy.workout.yapping,
                    summary.yappingTimeLabel,
                    context.tokens.yapping,
                  ),
                ],
              ),
            ),
            if (hasHeartRateChart)
              FlatSection(
                label: 'Heart',
                bleed: true,
                // Edge to edge, as the workout's Heart tab draws it.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: HeartRateChart(
                    heartRateSamples: _heartRateSamples,
                    completedSets: ownCompletedSets,
                    workoutStartTime: workout.startTime,
                    now: chartNow,
                    followLiveClock: false,
                  ),
                ),
              ),
            FlatSection(label: 'Trained with', child: _buildFriends(context)),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.tokens.hairline),
                ),
              ),
              child: const SectionLabel('Exercises'),
            ),
            for (final exercise in summary.exerciseSummaries)
              _ExerciseSummaryRow(
                exercise: exercise,
                log: _logFor(exercise.exercise),
                unit: unit,
              ),
            SetLog(
              proposedSets: ownProposedSets,
              completedSets: ownCompletedSets,
              workoutOwnerEmojis: {
                workout.id: normalizedProfileEmoji(auth.profileEmoji),
              },
            ),
          ],
        ),
      ),
    );
  }

  ExerciseLog? _logFor(Exercise exercise) {
    for (final log in _logs) {
      if (log.decision.exercise == exercise) return log;
    }
    return null;
  }

  /// Who you trained with: a chip each, their emoji on their colour.
  Widget _buildFriends(BuildContext context) {
    final t = context.tokens;
    if (!_sessionFriendsLoaded || _sessionFriends.isEmpty) {
      return Text(
        _sessionFriendsLoaded ? 'Nobody (solo session)' : 'Loading…',
        style: TextStyle(fontSize: t.size.bodyLg, color: t.muted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final user in _sessionFriends)
          Container(
            decoration: BoxDecoration(
              color: t.panel,
              border: Border.all(color: t.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  color: profileColorFromHex(user.profileColorHex),
                  child: Text(
                    normalizedProfileEmoji(user.profileEmoji),
                    style: TextStyle(fontSize: t.size.titleLg, height: 1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    user.name.isNotEmpty ? user.name : user.id,
                    style: TextStyle(
                      fontSize: t.size.bodyLg,
                      fontWeight: t.weight.bold,
                      color: t.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _handleBackNavigation() {
    if (!widget.isHistory) {
      final wp = context.read<WorkoutProvider>();
      if (wp.workout?.id == widget.workoutId && !wp.hasActiveWorkout) {
        wp.dismissEndedWorkout();
      }
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/');
    }
  }
}

/// The session's numbers as a full-width grid: three to a row, cells split
/// by hairlines, a state's total labelled in its colour.
class _MetricGrid extends StatelessWidget {
  final List<(String, String, Color?)> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget cell((String, String, Color?) m, {required bool last}) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : BorderSide(color: t.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.$1.toUpperCase(),
              style: t.mono(
                TextStyle(
                  fontSize: t.size.small,
                  fontWeight: t.weight.bold,
                  letterSpacing: 1,
                  color: m.$3 ?? t.muted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                m.$2,
                maxLines: 1,
                style: t.mono(
                  TextStyle(
                    fontSize: t.size.titleLg,
                    fontWeight: t.weight.bold,
                    color: t.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final rows = <Widget>[];
    for (var i = 0; i < metrics.length; i += 3) {
      final row = metrics.sublist(i, (i + 3).clamp(0, metrics.length));
      rows.add(
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.hairline)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < 3; j++)
                  j < row.length
                      ? cell(row[j], last: j == 2)
                      : const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// One exercise's totals: a full-width row, name then the numbers, then what
/// was planned and why, the weight changes along the way, and the max after.
class _ExerciseSummaryRow extends StatelessWidget {
  final ExerciseSummaryView exercise;
  final ExerciseLog? log;
  final WeightUnit unit;

  const _ExerciseSummaryRow({
    required this.exercise,
    required this.log,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final log = this.log;
    final max = exercise.maxAfter;
    final s = copy.plan.summary;
    final notes = [
      if (log != null) ...[
        s.planned.replaceAll('{plan}', planLine(log.decision, unit)),
        ...reasonLines(log.decision, unit),
        for (final change in log.changes) changeText(change, unit),
      ],
    ].where((line) => line.isNotEmpty);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name,
            style: TextStyle(
              fontSize: t.size.subtitle,
              fontWeight: t.weight.bold,
              color: t.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ExerciseStatColumn(
                label: 'Sets',
                value: '${exercise.totalSets}',
              ),
              _ExerciseStatColumn(
                label: 'Reps',
                value: '${exercise.totalReps}',
              ),
              _ExerciseStatColumn(label: 'Volume', value: exercise.volumeLabel),
              _ExerciseStatColumn(
                label: 'Max',
                value: max == null
                    ? '-'
                    : maxText(
                        max,
                        unit,
                        bodyweight:
                            log != null && isBodyweightDecision(log.decision),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Heaviest set: ${exercise.heaviestSetWeightLabel}',
            style: TextStyle(fontSize: t.size.body, color: t.muted),
          ),
          for (final note in notes)
            Text(
              note,
              style: TextStyle(fontSize: t.size.body, color: t.muted),
            ),
        ],
      ),
    );
  }
}

class _ExerciseStatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _ExerciseStatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Text(
          value,
          style: t.mono(
            TextStyle(
              fontSize: t.size.subtitle,
              fontWeight: t.weight.bold,
              color: t.text,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: t.size.body,
            fontWeight: t.weight.medium,
            color: t.muted,
          ),
        ),
      ],
    );
  }
}

/// Thin formatting view over the core's [WorkoutSummary]. The numbers are
/// already rolled up; this only turns them into display strings.
class WorkoutSummaryData {
  final WorkoutSummary _s;
  final WeightUnit unit;
  WorkoutSummaryData(this._s, this.unit);

  String get durationLabel => formatDurationShort(_s.durationSeconds.toInt());
  String get volumeLabel =>
      '${compactVolume(_s.totalVolume, unit)} ${weightUnitSuffix(unit)}';
  String get liftingTimeLabel => formatDurationShort(_s.liftingSeconds.toInt());
  String get restingTimeLabel => formatDurationShort(_s.restingSeconds.toInt());
  String get yappingTimeLabel => formatDurationShort(_s.yappingSeconds.toInt());
  int get workingSets => _s.workingSets;
  List<ExerciseSummaryView> get exerciseSummaries =>
      _s.exercises.map((e) => ExerciseSummaryView(e, unit)).toList();
}

/// Thin formatting view over the core's per-exercise [ExerciseSummary].
class ExerciseSummaryView {
  final ExerciseSummary _e;
  final WeightUnit unit;
  ExerciseSummaryView(this._e, this.unit);

  Exercise get exercise => _e.exercise;
  int get totalSets => _e.totalSets;
  int get totalReps => _e.totalReps;
  String get name => exerciseNames[_e.exercise] ?? 'Unknown';

  /// The lift's estimated max after this session (lb), when it has one.
  double? get maxAfter =>
      _e.estimatedMaxAfter > 0 ? _e.estimatedMaxAfter : null;
  String get volumeLabel =>
      '${compactVolume(_e.totalVolume, unit)} ${weightUnitSuffix(unit)}';
  String get heaviestSetWeightLabel => _e.heaviestSetWeight > 0
      ? formatWeight(_e.heaviestSetWeight, unit, includeUnit: true)
      : '-';
}
