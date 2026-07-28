
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
  WorkoutSummary? _summary;
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
          _summary = response.summary;
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
    // The server computes the rollup; this is a thin formatting view over it.
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
            Text(
              'Exercise totals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
  final ExerciseSummaryView exercise;

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
                label: 'Est. 1RM',
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

/// Thin formatting view over the server-computed [WorkoutSummary]. All the
/// numbers are already rolled up on the backend; this only turns them into
/// display strings.
class WorkoutSummaryData {
  final WorkoutSummary _s;
  final WeightUnit unit;
  WorkoutSummaryData(this._s, this.unit);

  String get durationLabel =>
      _formatDuration(Duration(seconds: _s.durationSeconds.toInt()));
  String get volumeLabel =>
      '${formatWeight(_s.totalVolume, unit)} ${weightUnitSuffix(unit)}';
  String get liftingTimeLabel =>
      _formatDuration(Duration(seconds: _s.liftingSeconds.toInt()));
  String get restingTimeLabel =>
      _formatDuration(Duration(seconds: _s.restingSeconds.toInt()));
  String get yappingTimeLabel =>
      _formatDuration(Duration(seconds: _s.yappingSeconds.toInt()));
  String get volumePerMinuteLabel =>
      '${_formatDecimal(displayWeightFromPounds(_s.volumePerMinute, unit))} ${weightUnitSuffix(unit)}/min';
  String get workRestRatioLabel => _s.restingSeconds > 0
      ? '${_formatDecimal(_s.workRestRatio, fractionDigits: 2)}x'
      : '—';
  List<ExerciseSummaryView> get exerciseSummaries =>
      _s.exercises.map((e) => ExerciseSummaryView(e, unit)).toList();

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

}

/// Thin formatting view over the server's per-exercise [ExerciseSummary].
class ExerciseSummaryView {
  final ExerciseSummary _e;
  final WeightUnit unit;
  ExerciseSummaryView(this._e, this.unit);

  Exercise get exercise => _e.exercise;
  int get totalSets => _e.totalSets;
  int get totalReps => _e.totalReps;
  String get name => exerciseNames[_e.exercise] ?? 'Unknown';
  String get emoji => exerciseEmojis[_e.exercise] ?? '?';
  String get volumeLabel =>
      '${formatWeight(_e.totalVolume, unit)} ${weightUnitSuffix(unit)}';
  String get formattedOneRm => _e.bestOneRepMax > 0
      ? '${formatWeight(_e.bestOneRepMax, unit)} ${weightUnitSuffix(unit)}'
      : '—';
  String get heaviestSetWeightLabel => _e.heaviestSetWeight > 0
      ? '${formatWeight(_e.heaviestSetWeight, unit)} ${weightUnitSuffix(unit)}'
      : '—';
}
