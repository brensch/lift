import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../services/grpc_client.dart';
import '../services/workout_service.dart';
import '../logic/utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExerciseStatus>? _schedule;
  List<ProposedExerciseGroup>? _proposedGroups;
  Set<int> _selectedGroupIndices = {};
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;
  late final TextEditingController _nameController = TextEditingController(
    text: _getDefaultWorkoutName(),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getDefaultWorkoutName() {
    return greetingTime().toUpperCase();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final grpc = context.read<GrpcClient>();
    final workoutService = WorkoutServiceWrapper(grpc);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final scheduleRes = await workoutService.getProposedWorkoutSchedule(
        auth.userId!,
      );

      if (!mounted) return;

      final schedule = scheduleRes.exerciseStatuses;
      final proposedGroups = scheduleRes.proposedGroups;

      // Auto-select first few groups (compounds)
      final autoSelected = <int>{};
      for (int i = 0; i < proposedGroups.length && autoSelected.length < 3; i++) {
        // Select groups that contain recovered exercises
        final groupExercises = proposedGroups[i].exerciseConfigs
            .map((c) => c.exercise.value)
            .toSet();
        final hasRecovered = schedule.any(
          (s) => groupExercises.contains(s.exercise.value) && s.recovered,
        );
        final hasAlwaysInclude = schedule.any(
          (s) => groupExercises.contains(s.exercise.value) && s.alwaysInclude,
        );
        if (hasAlwaysInclude || hasRecovered) {
          autoSelected.add(i);
        }
      }

      setState(() {
        _schedule = schedule;
        _proposedGroups = proposedGroups;
        _selectedGroupIndices = autoSelected;
        _nameController.text = _getDefaultWorkoutName();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = cleanErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startWorkout() async {
    if (_selectedGroupIndices.isEmpty || _proposedGroups == null) return;

    setState(() => _isStarting = true);

    try {
      final exerciseGroups = <ExerciseGroup>[];
      int groupOrder = 0;

      // Build status lookup for weight population
      final statusMap = <int, ExerciseStatus>{};
      if (_schedule != null) {
        for (final s in _schedule!) {
          statusMap[s.exercise.value] = s;
        }
      }

      for (final idx in _selectedGroupIndices.toList()..sort()) {
        final proposed = _proposedGroups![idx];
        final groupId = _uuid.v4();

        // Build ExerciseTypeConfigs with weights from exercise_statuses
        final configs = proposed.exerciseConfigs.map((c) {
          final status = statusMap[c.exercise.value];
          final weight = status?.targetWeight ?? c.startWeight;
          return ExerciseTypeConfig()
            ..exercise = c.exercise
            ..startWeight = weight
            ..endWeight = weight
            ..reps = c.reps
            ..includeWarmup = c.includeWarmup;
        }).toList();

        exerciseGroups.add(
          ExerciseGroup()
            ..id = groupId
            ..name = proposed.name
            ..sets = proposed.sets
            ..interleaveWarmups = proposed.interleaveWarmups
            ..workoutOrder = groupOrder++
            ..exerciseConfigs.addAll(configs),
        );
      }

      final now = DateTime.now();
      final dateStr =
          "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";

      // Build exercise summary from selected groups
      final exerciseSummary = _selectedGroupIndices
          .toList()
          ..sort();
      final summaryNames = exerciseSummary
          .map((idx) => _proposedGroups![idx].name)
          .join(' / ');

      final baseName = _nameController.text.trim().isEmpty
          ? _getDefaultWorkoutName()
          : _nameController.text.trim().toUpperCase();

      final workoutName = "$dateStr - $summaryNames - $baseName"
          .toUpperCase();

      final workoutProvider = context.read<WorkoutProvider>();

      final workoutId = await workoutProvider.startWorkout(
        workoutName,
        exerciseGroups,
      );

      if (workoutId != null && mounted) {
        final mp = context.read<MultiplayerProvider>();
        if (mp.isInSession) {
          await mp.updateActiveWorkout(workoutId);
        }
      }
    } catch (e) {
      debugPrint('Error starting workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start workout: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  void _toggleGroup(int index) {
    setState(() {
      if (_selectedGroupIndices.contains(index)) {
        _selectedGroupIndices.remove(index);
      } else {
        _selectedGroupIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = context.read<AuthProvider>().username ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'SELECT YOUR EXERCISE GROUPS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final group = _proposedGroups![index];
                  final isSelected = _selectedGroupIndices.contains(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupCard(
                      group: group,
                      exerciseStatuses: _schedule ?? [],
                      isSelected: isSelected,
                      onTap: () => _toggleGroup(index),
                    ),
                  );
                },
                childCount: _proposedGroups?.length ?? 0,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            left: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            right: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GOOD ${greetingTime().toUpperCase()} ${userName.split(' ').first.toUpperCase()}.',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'WORKOUT NAME (OPTIONAL)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: _getDefaultWorkoutName(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: _selectedGroupIndices.isEmpty || _isStarting
                    ? null
                    : _startWorkout,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isStarting
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        'START WORKOUT (${_selectedGroupIndices.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String greetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _GroupCard extends StatelessWidget {
  final ProposedExerciseGroup group;
  final List<ExerciseStatus> exerciseStatuses;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.exerciseStatuses,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final borderColor = isSelected ? colorScheme.primary : colorScheme.outline;
    final bgColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.05)
        : colorScheme.surface;

    // Get recovery status for exercises in this group
    final groupExercises = group.exerciseConfigs
        .map((c) => c.exercise.value)
        .toSet();
    final allRecovered = groupExercises.every((exVal) {
      final status = exerciseStatuses.cast<ExerciseStatus?>().firstWhere(
        (s) => s!.exercise.value == exVal,
        orElse: () => null,
      );
      return status?.recovered ?? true;
    });

    // Get latest last performed
    int? latestPerformed;
    for (final exVal in groupExercises) {
      final status = exerciseStatuses.cast<ExerciseStatus?>().firstWhere(
        (s) => s!.exercise.value == exVal,
        orElse: () => null,
      );
      if (status != null && status.lastPerformedAt != Int64.ZERO) {
        final ts = status.lastPerformedAt.toInt();
        if (latestPerformed == null || ts > latestPerformed) {
          latestPerformed = ts;
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    group.name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      height: 1.1,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Exercise list with weights
            ...group.exerciseConfigs.map((config) {
              final ex = Exercise.valueOf(config.exercise.value);
              final name = exerciseNames[ex] ?? '?';
              final weight = config.startWeight;
              final weightStr = weight == weight.roundToDouble()
                  ? weight.toInt().toString()
                  : weight.toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${weightStr}lb',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${group.sets}x${group.exerciseConfigs.first.reps}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                if (group.exerciseConfigs.length > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      group.interleaveWarmups ? 'SUPERSET' : 'PAIRED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: allRecovered
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimeSince(latestPerformed),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeSince(int? timestamp) {
    if (timestamp == null || timestamp == 0) return 'NEW';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - timestamp;

    if (diff < 60) return 'NOW';
    if (diff < 3600) return '${(diff / 60).floor()}m';
    if (diff < 86400) return '${(diff / 3600).floor()}h';
    return '${(diff / 86400).floor()}d';
  }
}
