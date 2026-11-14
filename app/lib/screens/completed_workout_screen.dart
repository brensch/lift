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
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/grpc_client.dart';
import '../services/multiplayer_service.dart';
import '../services/workout_service.dart';
import '../widgets/common/flat.dart';
import '../services/error_modal_service.dart';
import '../widgets/common/quiet_link.dart';
import '../widgets/dialogs/discard_workout_dialog.dart';
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
    final service = context.read<WorkoutServiceWrapper>();
    final multiplayer = MultiplayerServiceWrapper(grpc);
    try {
      _loadError = null;
      final response = await service.getWorkout(widget.workoutId);
      // From the account, so a workout opened from History shows it too.
      final heartRate = await service.getWorkoutHeartRate(widget.workoutId);
      final sessionId = response.workout.sessionId;
      if (mounted) {
        setState(() {
          _workout = response.workout;
          _summary = response.summary;
          _proposedSets = List.from(response.proposedSets);
          _completedSets = List.from(response.completedSets);
          _logs = List.from(response.exerciseLogs);
          _heartRateSamples = [
            for (final point in heartRate)
              HeartRateSample()
                ..sampledAt = point.sampledAt
                ..bpm = point.bpm,
          ];
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
          _loadError = copy.summary.loadFailed;
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
        appBar: AppBar(title: PageTitle(copy.summary.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError ?? copy.summary.loadFailed),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _loadError = null;
                    });
                    _loadWorkout();
                  },
                  child: Text(copy.summary.retry),
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
            workout.name.isNotEmpty ? workout.name : copy.summary.title,
          ),
        ),
        body: ListView(
          // A pixel on top: room for the Session band's top line.
          padding: const EdgeInsets.only(top: 1, bottom: 24),
          children: [
            FlatSection(
              label: copy.summary.session,
              flush: true,
              child: FlatMetricGrid(
                metrics: [
                  (copy.summary.duration, summary.durationLabel, null),
                  (copy.summary.volume, summary.volumeLabel, null),
                  (copy.summary.sets, '${summary.workingSets}', null),
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
                label: copy.summary.heart,
                flush: true,
                // The plot nearly edge to edge; its figures' grid all of it,
                // ending the section.
                child: HeartRateChart(
                  heartRateSamples: _heartRateSamples,
                  completedSets: ownCompletedSets,
                  workoutStartTime: workout.startTime,
                  now: chartNow,
                  followLiveClock: false,
                  inset: 8,
                  closeGrid: false,
                ),
              ),
            // The quote it was done under; none on one from before quotes.
            if (workout.motivation.isNotEmpty)
              FlatSection(
                label: copy.motivation.title,
                child: Text(
                  workout.motivation,
                  style: TextStyle(
                    fontSize: context.tokens.size.bodyLg,
                    color: context.tokens.text,
                  ),
                ),
              ),
            FlatSection(
              label: copy.summary.trainedWith,
              child: _buildFriends(context),
            ),
            FlatHeading(copy.summary.exercises),
            for (final exercise in summary.exerciseSummaries)
              _ExerciseSummaryRow(
                exercise: exercise,
                log: _logFor(exercise.exercise),
                unit: unit,
              ),
            SetLog(
              proposedSets: ownProposedSets,
              completedSets: ownCompletedSets,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: QuietLink(
                label: copy.workout.discardWorkout,
                onPressed: _discard,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Throw the workout away, once the person confirms, and go back: it is
  /// gone from history.
  Future<void> _discard() async {
    if (!await confirmDiscardWorkout(context) || !mounted) return;
    final service = context.read<WorkoutServiceWrapper>();
    final wp = context.read<WorkoutProvider>();
    try {
      await service.discardWorkout(widget.workoutId);
    } catch (e) {
      if (mounted) ErrorModalService.showError(cleanErrorMessage(e));
      return;
    }
    if (wp.workout?.id == widget.workoutId) await wp.dismissEndedWorkout();
    // Home's volume, recovery and plans counted it: plan them without it.
    await wp.refreshHome();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    } else {
      context.go('/');
    }
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
        _sessionFriendsLoaded ? copy.summary.solo : copy.summary.loading,
        style: TextStyle(fontSize: t.size.bodyLg, color: t.muted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final user in _sessionFriends)
          Container(
            // Their colour block runs to the chip's edge: it takes its corners.
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: t.panel,
              borderRadius: context.tokens.brMd,
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
                label: copy.summary.sets,
                value: '${exercise.totalSets}',
              ),
              _ExerciseStatColumn(
                label: copy.summary.reps,
                value: '${exercise.totalReps}',
              ),
              _ExerciseStatColumn(
                label: copy.summary.volume,
                value: exercise.volumeLabel,
              ),
              _ExerciseStatColumn(
                label: copy.summary.max,
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
            copy.summary.heaviestSet.replaceAll(
              '{weight}',
              exercise.heaviestSetWeightLabel,
            ),
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
  String get name => exerciseName(_e.exercise);

  /// The lift's estimated max after this session (lb), when it has one.
  double? get maxAfter =>
      _e.estimatedMaxAfter > 0 ? _e.estimatedMaxAfter : null;
  String get volumeLabel =>
      '${compactVolume(_e.totalVolume, unit)} ${weightUnitSuffix(unit)}';
  String get heaviestSetWeightLabel => _e.heaviestSetWeight > 0
      ? formatWeight(_e.heaviestSetWeight, unit, includeUnit: true)
      : '-';
}
