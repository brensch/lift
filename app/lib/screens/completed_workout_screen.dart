import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../logic/exercises.dart';
import '../logic/user_profile.dart';
import '../logic/weight_units.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/grpc_client.dart';
import '../services/multiplayer_service.dart';
import '../services/workout_service.dart';
import '../widgets/heart_rate/heart_rate_chart.dart';
import '../widgets/set_log.dart';
import '../widgets/user_message_chip.dart';
import '../services/notification_service.dart';

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
  List<ProposedSet> _proposedSets = [];
  List<CompletedSet> _completedSets = [];
  List<UserMessage> _messages = [];
  bool _showingNextSessionChanges = false;
  bool _isLoading = true;
  String? _loadError;
  List<String> _sessionFriends = [];
  bool _sessionFriendsLoaded = false;
  List<HeartRateSample> _heartRateSamples = [];

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  Future<void> _loadWorkout() async {
    final grpc = context.read<GrpcClient>();
    final auth = context.read<AuthProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    final service = WorkoutServiceWrapper(grpc);
    final multiplayer = MultiplayerServiceWrapper(grpc);
    final sessionSelfId = auth.userId ?? '';
    try {
      _loadError = null;
      final response = await _getWorkoutWithRetry(service);
      final providerCompletionMessages =
          workoutProvider.workout?.id == response.workout.id
          ? List<UserMessage>.from(workoutProvider.workoutMessages)
          : const <UserMessage>[];
      final persistedWorkoutMessages = List<UserMessage>.from(
        response.userMessages,
      );
      final sessionId = response.workout.sessionId;
      if (mounted) {
        setState(() {
          _workout = response.workout;
          _proposedSets = List.from(response.proposedSets);
          _completedSets = List.from(response.completedSets);
          _messages = providerCompletionMessages.isNotEmpty
              ? providerCompletionMessages
              : persistedWorkoutMessages.isNotEmpty
              ? persistedWorkoutMessages
              : const <UserMessage>[];
          _showingNextSessionChanges =
              providerCompletionMessages.isNotEmpty ||
              persistedWorkoutMessages.isNotEmpty;
          _heartRateSamples = workoutProvider.workout?.id == response.workout.id
              ? workoutProvider.wearHeartRateSamples
              : const [];
          _isLoading = false;
          _loadError = null;
          _sessionFriends = [];
          _sessionFriendsLoaded = sessionId.isEmpty;
        });
      }

      final userId = auth.userId;
      if (sessionId.isNotEmpty) {
        await _loadSessionFriends(sessionId, multiplayer, sessionSelfId);
      }

      if (!widget.isHistory && userId != null && userId.isNotEmpty) {
        _scheduleNextWorkoutNotification(userId, service);
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

  Future<GetWorkoutResponse> _getWorkoutWithRetry(
    WorkoutServiceWrapper service,
  ) async {
    Object? lastError;
    StackTrace? lastStack;
    // Freshly ended workouts can briefly race backend persistence.
    final attempts = widget.isHistory ? 1 : 8;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await service.getWorkout(widget.workoutId);
        if (widget.isHistory || response.workout.endTime != Int64.ZERO) {
          return response;
        }
        lastError = StateError('Workout summary is not finalized yet.');
      } catch (e, st) {
        lastError = e;
        lastStack = st;
      }
      if (attempt == attempts) break;
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
    if (lastStack != null) {
      Error.throwWithStackTrace(lastError!, lastStack);
    }
    throw lastError ?? StateError('Failed to load finalized workout summary.');
  }

  Future<void> _scheduleNextWorkoutNotification(
    String userId,
    WorkoutServiceWrapper service,
  ) async {
    try {
      final scheduleRes = await service.getProposedWorkoutSchedule(userId);
      if (!scheduleRes.hasTrainingStatus()) return;
      final ts = scheduleRes.trainingStatus;
      if (ts.nextSessionAt.toInt() <= 0) return;
      final regimeName = scheduleRes.hasRegimeContext()
          ? scheduleRes.regimeContext.regimeDisplayName
          : 'your';
      await NotificationService.scheduleNextWorkout(
        nextSessionAtUnix: ts.nextSessionAt.toInt(),
        regimeName: regimeName.isNotEmpty ? regimeName : 'your',
      );
    } catch (_) {
      // Fail silently — notification is best-effort
    }
  }

  Future<void> _loadSessionFriends(
    String sessionId,
    MultiplayerServiceWrapper service,
    String selfId,
  ) async {
    List<String> names = [];
    try {
      final sessionResponse = await service.getSessionParticipants(sessionId);
      final participants = sessionResponse.participants;
      final seen = <String>{};
      for (final participant in participants) {
        final user = participant.user;
        if (user.id.isEmpty || (selfId.isNotEmpty && user.id == selfId)) {
          continue;
        }
        final display = user.name.isNotEmpty ? user.name : user.id;
        if (display.isEmpty) continue;
        if (seen.add(display)) {
          names.add(display);
        }
      }
    } catch (_) {
      names = [];
    }
    if (mounted) {
      setState(() {
        _sessionFriends = names;
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
        appBar: AppBar(title: const Text('Workout summary')),
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
    final summary = WorkoutSummaryData.fromWorkout(
      workout: workout,
      proposedSets: ownProposedSets,
      completedSets: ownCompletedSets,
      unit: unit,
    );
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
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackNavigation,
          ),
          title: Text(
            workout.name.isNotEmpty ? workout.name : 'Workout summary',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Session snapshot',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              children: [
                _SummaryMetric(
                  label: 'Duration',
                  value: summary.durationLabel,
                  icon: Icons.timer_outlined,
                ),
                _SummaryMetric(
                  label: 'Lifting',
                  value: summary.liftingTimeLabel,
                  icon: Icons.fitness_center,
                ),
                _SummaryMetric(
                  label: 'Yapping',
                  value: summary.yappingTimeLabel,
                  icon: Icons.chat_bubble_outline,
                ),
                _SummaryMetric(
                  label: 'Resting',
                  value: summary.restingTimeLabel,
                  icon: Icons.self_improvement,
                ),
                _SummaryMetric(
                  label: 'Volume',
                  value: summary.volumeLabel,
                  icon: Icons.line_weight,
                ),
                _SummaryMetric(
                  label: 'Work density',
                  value: summary.volumePerMinuteLabel,
                  icon: Icons.bar_chart,
                ),
                _SummaryMetric(
                  label: 'Rest ratio',
                  value: summary.workRestRatioLabel,
                  icon: Icons.self_improvement,
                ),
              ],
            ),
            if (hasHeartRateChart) ...[
              const SizedBox(height: 16),
              HeartRateChart(
                heartRateSamples: _heartRateSamples,
                completedSets: ownCompletedSets,
                workoutStartTime: workout.startTime,
                now: chartNow,
                followLiveClock: false,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Friends worked out with',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            _buildFriendChips(context),
            if (_messages.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                _showingNextSessionChanges ? 'Updates' : 'Workout notes',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              ..._messages.map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: UserMessageChip(message: message),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exercise totals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text('Records TBD', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            ...summary.exerciseSummaries.map(
              (exercise) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ExerciseSummaryCard(exercise: exercise),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Set log',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
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

  Widget _buildFriendChips(BuildContext context) {
    if (!_sessionFriendsLoaded) {
      return Text(
        'Loading friends...',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (_sessionFriends.isEmpty) {
      return Text(
        'None (solo session)',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _sessionFriends
          .map(
            (name) => Chip(
              label: Text(name),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          )
          .toList(),
    );
  }

  void _handleBackNavigation() {
    if (!widget.isHistory) {
      final wp = context.read<WorkoutProvider>();
      if (wp.workout?.id == widget.workoutId && !wp.hasActiveWorkout) {
        wp.clear();
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

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSummaryCard extends StatelessWidget {
  final ExerciseSummary exercise;

  const _ExerciseSummaryCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(exercise.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                exercise.recordNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                label: 'Best 1RM',
                value: exercise.formattedOneRm,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Heaviest set: ${exercise.heaviestSetWeightLabel}',
            style: Theme.of(context).textTheme.bodySmall,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class WorkoutSummaryData {
  final WeightUnit unit;
  final Duration duration;
  final double totalVolume;
  final Duration liftingTime;
  final Duration restingTime;
  final Duration yappingTime;
  final double volumePerMinute;
  final double workRestRatio;
  final List<ExerciseSummary> exerciseSummaries;

  WorkoutSummaryData({
    required this.unit,
    required this.duration,
    required this.totalVolume,
    required this.liftingTime,
    required this.restingTime,
    required this.yappingTime,
    required this.volumePerMinute,
    required this.workRestRatio,
    required this.exerciseSummaries,
  });

  String get durationLabel => _formatDuration(duration);
  String get volumeLabel =>
      '${formatWeight(totalVolume, unit)} ${weightUnitSuffix(unit)}';
  String get liftingTimeLabel => _formatDuration(liftingTime);
  String get restingTimeLabel => _formatDuration(restingTime);
  String get yappingTimeLabel => _formatDuration(yappingTime);
  String get volumePerMinuteLabel =>
      '${_formatDecimal(displayWeightFromPounds(volumePerMinute, unit))} ${weightUnitSuffix(unit)}/min';
  String get workRestRatioLabel => restingTime.inSeconds > 0
      ? '${_formatDecimal(liftingTime.inSeconds.toDouble() / restingTime.inSeconds.toDouble(), fractionDigits: 2)}x'
      : '—';

  static String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '0m';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  static String _formatDecimal(double value, {int fractionDigits = 1}) {
    final formatted = value.toStringAsFixed(fractionDigits);
    if (formatted.endsWith('.0')) {
      return formatted.substring(0, formatted.length - 2);
    }
    return formatted;
  }

  factory WorkoutSummaryData.fromWorkout({
    required Workout workout,
    required List<ProposedSet> proposedSets,
    required List<CompletedSet> completedSets,
    required WeightUnit unit,
  }) {
    final completed = completedSets
        .where((set) => set.endedAt != Int64.ZERO)
        .toList();

    final Map<String, ProposedSet> proposedById = {
      for (final set in proposedSets) set.id: set,
    };

    final Map<Exercise, ExerciseSummaryBuilder> exerciseBuilders = {};
    double totalVolume = 0;
    Duration liftingTime = Duration.zero;
    Duration restingTime = Duration.zero;

    // Sort chronologically so we can cap rest at when the next set started.
    final ordered =
        completed.where((set) => set.startedAt != Int64.ZERO).toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    for (var i = 0; i < ordered.length; i++) {
      final completedSet = ordered[i];
      final proposed = proposedById[completedSet.proposedSetId];
      if (proposed == null) continue;

      final setDurationSeconds = completedSet.endedAt > completedSet.startedAt
          ? (completedSet.endedAt - completedSet.startedAt).toInt()
          : 0;
      liftingTime += Duration(seconds: setDurationSeconds);

      // Rest time: cap at when the next set actually started (rest stops
      // once you begin a new lift) and at workout end if it ended sooner.
      if (completedSet.restUntil > completedSet.endedAt) {
        Int64 restEnd = completedSet.restUntil;
        if (i + 1 < ordered.length && ordered[i + 1].startedAt < restEnd) {
          restEnd = ordered[i + 1].startedAt;
        }
        if (workout.endTime != Int64.ZERO && workout.endTime < restEnd) {
          restEnd = workout.endTime;
        }
        final restSeconds = (restEnd - completedSet.endedAt).toInt();
        if (restSeconds > 0) {
          restingTime += Duration(seconds: restSeconds);
        }
      }

      final setVolume = completedSet.actualReps * completedSet.actualWeight;
      if (setVolume.isFinite) {
        totalVolume += setVolume;
      }

      final builder = exerciseBuilders.putIfAbsent(
        proposed.exercise,
        () => ExerciseSummaryBuilder(proposed.exercise, unit),
      );
      builder.addSet(completedSet, proposed);
    }

    final sortedExercises = exerciseBuilders.values
        .map((b) => b.build())
        .toList()
        .cast<ExerciseSummary>();
    sortedExercises.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));

    final workRestRatio = restingTime.inSeconds > 0
        ? liftingTime.inSeconds.toDouble() / restingTime.inSeconds.toDouble()
        : liftingTime.inSeconds.toDouble();

    final workoutDuration =
        workout.endTime != Int64.ZERO && workout.startTime != Int64.ZERO
        ? Duration(seconds: (workout.endTime - workout.startTime).toInt())
        : Duration.zero;

    final liftingMinutes = math.max<int>(1, liftingTime.inMinutes).toDouble();
    final volumePerMinute = liftingMinutes > 0.0
        ? totalVolume / liftingMinutes
        : 0.0;

    final yappingTime = _calculateYappingTime(ordered, workout);

    return WorkoutSummaryData(
      unit: unit,
      duration: workoutDuration,
      totalVolume: totalVolume,
      liftingTime: liftingTime,
      restingTime: restingTime,
      yappingTime: yappingTime,
      volumePerMinute: volumePerMinute,
      workRestRatio: workRestRatio,
      exerciseSummaries: sortedExercises,
    );
  }

  /// Yapping = time between sets that isn't lifting or resting.
  /// If the user had rest prescribed, yapping starts when rest ends.
  /// If no rest was prescribed (e.g. warmups), yapping is the full gap.
  static Duration _calculateYappingTime(
    List<CompletedSet> orderedSets,
    Workout workout,
  ) {
    int yappingSeconds = 0;
    for (var i = 0; i < orderedSets.length - 1; i++) {
      final current = orderedSets[i];
      final next = orderedSets[i + 1];
      // Yapping starts after rest ends (or immediately after the set if
      // no rest was prescribed) and ends when the next set starts.
      final gapStart = current.restUntil > current.endedAt
          ? current.restUntil
          : current.endedAt;
      if (next.startedAt > gapStart) {
        yappingSeconds += (next.startedAt - gapStart).toInt();
      }
    }
    return Duration(seconds: yappingSeconds);
  }
}

class ExerciseSummary {
  final WeightUnit unit;
  final Exercise exercise;
  final String name;
  final String emoji;
  final int totalSets;
  final int totalReps;
  final double totalVolume;
  final double bestOneRm;
  final double heaviestSetWeight;
  final String recordNote;

  ExerciseSummary({
    required this.unit,
    required this.exercise,
    required this.name,
    required this.emoji,
    required this.totalSets,
    required this.totalReps,
    required this.totalVolume,
    required this.bestOneRm,
    required this.heaviestSetWeight,
    required this.recordNote,
  });

  String get volumeLabel =>
      '${formatWeight(totalVolume, unit)} ${weightUnitSuffix(unit)}';
  String get formattedOneRm => bestOneRm > 0
      ? '${formatWeight(bestOneRm, unit)} ${weightUnitSuffix(unit)}'
      : '—';
  String get heaviestSetWeightLabel => heaviestSetWeight > 0
      ? '${formatWeight(heaviestSetWeight, unit)} ${weightUnitSuffix(unit)}'
      : '—';
}

class ExerciseSummaryBuilder {
  final WeightUnit unit;
  final Exercise exercise;
  int totalSets = 0;
  int totalReps = 0;
  double totalVolume = 0;
  double bestOneRm = 0;
  double heaviestSetWeight = 0;

  ExerciseSummaryBuilder(this.exercise, this.unit);

  void addSet(CompletedSet completedSet, ProposedSet proposed) {
    totalSets += 1;
    totalReps += completedSet.actualReps;
    final setVolume = completedSet.actualReps * completedSet.actualWeight;
    if (setVolume.isFinite) {
      totalVolume += setVolume;
    }
    heaviestSetWeight = math.max(heaviestSetWeight, completedSet.actualWeight);
    final oneRm = _estimateOneRm(
      completedSet.actualWeight,
      completedSet.actualReps,
    );
    bestOneRm = math.max(bestOneRm, oneRm);
  }

  ExerciseSummary build() {
    return ExerciseSummary(
      unit: unit,
      exercise: exercise,
      name: exerciseNames[exercise] ?? 'Unknown',
      emoji: exerciseEmojis[exercise] ?? '?',
      totalSets: totalSets,
      totalReps: totalReps,
      totalVolume: totalVolume,
      bestOneRm: bestOneRm,
      heaviestSetWeight: heaviestSetWeight,
      recordNote: 'Record tracking soon',
    );
  }

  double _estimateOneRm(double weight, int reps) {
    if (!weight.isFinite || weight <= 0 || reps <= 0) return 0;
    return weight * (1 + reps / 30.0);
  }
}
