import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/warmup.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../services/grpc_client.dart';
import '../services/workout_service.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExerciseStatus>? _schedule;
  String? _activeWorkoutId;
  Set<Exercise> _selectedExercises = {};
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final scheduleRes = await workoutService.getProposedWorkoutSchedule(auth.userId!);

      String? activeId = scheduleRes.activeWorkoutId.isNotEmpty ? scheduleRes.activeWorkoutId : null;

      if (activeId == null) {
        final activeRes = await workoutService.getActiveWorkout();
        if (activeRes != null) {
          activeId = activeRes.id;
        }
      }

      if (!mounted) return;

      final schedule = scheduleRes.exerciseStatuses;
      final autoSelected = <Exercise>{};

      for (final s in schedule) {
        if (s.alwaysInclude) {
          autoSelected.add(s.exercise);
        }
      }

      final compounds = schedule
          .where((s) => s.category == ExerciseCategory.EXERCISE_CATEGORY_COMPOUND)
          .toList();

      compounds.sort((a, b) => a.lastPerformedAt.compareTo(b.lastPerformedAt));

      for (final s in compounds) {
        if (autoSelected.length >= 3) break;
        autoSelected.add(s.exercise);
      }

      setState(() {
        _schedule = schedule;
        _activeWorkoutId = activeId;
        _selectedExercises = autoSelected;
        _isLoading = false;
      });

      if (activeId != null) {
        context.read<WorkoutProvider>().loadWorkout(activeId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startWorkout() async {
    if (_selectedExercises.isEmpty || _schedule == null) return;

    setState(() => _isStarting = true);

    try {
      final proposedSets = <ProposedSet>[];
      int order = 0;

      for (final status in _schedule!) {
        if (!_selectedExercises.contains(status.exercise)) continue;

        final warmupDefs = generateWarmupDefs(status.targetWeight.toDouble());
        for (final def in warmupDefs) {
          proposedSets.add(ProposedSet()
            ..id = _uuid.v4()
            ..workoutOrder = order++
            ..exercise = status.exercise
            ..targetReps = def.reps
            ..targetWeight = def.weight
            ..warmup = true);
        }

        for (int i = 0; i < status.defaultSets; i++) {
          proposedSets.add(ProposedSet()
            ..id = _uuid.v4()
            ..workoutOrder = order++
            ..exercise = status.exercise
            ..targetReps = status.defaultReps
            ..targetWeight = status.targetWeight
            ..warmup = false);
        }
      }

      final now = DateTime.now();
      final monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final workoutName = "${monthNames[now.month - 1]} ${now.day}";

      final workoutProvider = context.read<WorkoutProvider>();
      final workoutId = await workoutProvider.startWorkout(workoutName, proposedSets);

      if (workoutId != null && mounted) {
        context.go('/workout');
      }
    } catch (e) {
      debugPrint('Error starting workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start workout: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  void _toggleExercise(Exercise exercise) {
    setState(() {
      if (_selectedExercises.contains(exercise)) {
        _selectedExercises.remove(exercise);
      } else {
        _selectedExercises.add(exercise);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final providerHasActive = context.watch<WorkoutProvider>().hasActiveWorkout;
    final showResume = _activeWorkoutId != null || providerHasActive;
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
            FilledButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final compounds = _schedule!.where((s) => s.category == ExerciseCategory.EXERCISE_CATEGORY_COMPOUND).toList();
    final auxiliaries = _schedule!.where((s) => s.category == ExerciseCategory.EXERCISE_CATEGORY_AUXILIARY).toList();

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (showResume)
                  _buildResumeCard()
                else ...[
                  Text(
                    'GOOD ${greetingTime().toUpperCase()} ${userName.split(' ').first.toUpperCase()}.',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'READY FOR YOUR FIRST WORKOUT?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ]),
            ),
          ),

          if (!showResume) ...[
            if (compounds.isNotEmpty) _buildCategorySection('COMPOUND', compounds),
            if (auxiliaries.isNotEmpty) _buildCategorySection('AUXILIARY', auxiliaries),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _selectedExercises.isEmpty || _isStarting ? null : _startWorkout,
                    child: _isStarting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            'START WORKOUT (${_selectedExercises.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildResumeCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE SESSION',
            style: TextStyle(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'WORKOUT IN PROGRESS',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => context.go('/workout'),
              child: const Text(
                'RESUME',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, List<ExerciseStatus> items) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: colorScheme.tertiary,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final status = items[index];
                return _ExerciseCard(
                  status: status,
                  isSelected: _selectedExercises.contains(status.exercise),
                  onTap: () => _toggleExercise(status.exercise),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }

  String greetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = exerciseNames[status.exercise] ?? '?';

    final borderColor = isSelected ? colorScheme.primary : colorScheme.outline;
    final bgColor = isSelected ? colorScheme.primary.withValues(alpha: 0.05) : colorScheme.surface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check, size: 16, color: colorScheme.primary),
              ],
            ),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${status.targetWeight.toInt()}',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        TextSpan(
                          text: ' LB',
                          style: TextStyle(
                            color: colorScheme.tertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${status.defaultSets}x${status.defaultReps}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status.recovered
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatTimeSince(status.lastPerformedAt),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.tertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeSince(Int64 timestamp) {
    if (timestamp == Int64.ZERO) return 'NEW';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - timestamp.toInt();

    if (diff < 60) return 'NOW';
    if (diff < 3600) return '${(diff / 60).floor()}m';
    if (diff < 86400) return '${(diff / 3600).floor()}h';
    return '${(diff / 86400).floor()}d';
  }
}
