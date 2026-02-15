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
      // Load schedule and check for active workout
      // We could also call listWorkouts to check history for active ones if schedule doesn't return it
      final scheduleRes = await workoutService.getProposedWorkoutSchedule(auth.userId!);
      
      String? activeId = scheduleRes.activeWorkoutId.isNotEmpty ? scheduleRes.activeWorkoutId : null;
      
      // Also check provider state or listWorkouts if schedule doesn't have it (redundancy)
      if (activeId == null) {
        final activeRes = await workoutService.getActiveWorkout();
        if (activeRes != null) {
          activeId = activeRes.id;
        }
      }

      if (!mounted) return;

      final schedule = scheduleRes.exerciseStatuses;
      final autoSelected = <Exercise>{};

      // Freshness Logic:
      // 1. Add always_include
      for (final s in schedule) {
        if (s.alwaysInclude) {
          autoSelected.add(s.exercise);
        }
      }

      // 2. Fill up to 3 from the oldest compounds
      // Filter for compounds
      final compounds = schedule
          .where((s) => s.category == ExerciseCategory.EXERCISE_CATEGORY_COMPOUND)
          .toList();
      
      // Sort by lastPerformedAt (ascending: oldest first)
      // 0 means never performed, so treat 0 as very old (or handle separately if we want to prioritize new)
      // Web logic: sort((a, b) => Number(a.lastPerformedAt - b.lastPerformedAt))
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

      // If there is an active workout, ensure provider knows about it
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

      // Follow the order of the schedule (rotation order)
      for (final status in _schedule!) {
        if (!_selectedExercises.contains(status.exercise)) continue;

        // Generate warmup + working sets
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
      // Format: "Feb 14"
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
    // If we have an active workout in provider, ensure UI reflects it
    final providerHasActive = context.watch<WorkoutProvider>().hasActiveWorkout;
    final showResume = _activeWorkoutId != null || providerHasActive;
    final userName = context.read<AuthProvider>().username ?? '';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Group exercises by category
    final compounds = _schedule!.where((s) => s.category == ExerciseCategory.EXERCISE_CATEGORY_COMPOUND).toList();
    final auxiliaries = _schedule!.where((s) => s.category == ExerciseCategory.EXERCISE_CATEGORY_AUXILIARY).toList();

    return RefreshIndicator(
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
                  // Could add "last workout time" here if we fetched history
                  const Text(
                    'READY FOR YOUR FIRST WORKOUT?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey,
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
                  height: 64,
                  child: FilledButton(
                    onPressed: _selectedExercises.isEmpty || _isStarting ? null : _startWorkout,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isStarting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'START WORKOUT (${_selectedExercises.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
          
          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildResumeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACTIVE SESSION',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
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
              height: 56,
              child: FilledButton(
                onPressed: () => context.go('/workout'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'RESUME',
                  style: TextStyle(
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

  Widget _buildCategorySection(String title, List<ExerciseStatus> items) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1, // Adjusted to be less tall
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
    final theme = Theme.of(context);
    final name = exerciseNames[status.exercise] ?? '?';
    // Use short names if available, basically split by space and take 1-2 words or custom map
    // For now, simple truncation logic or just use full name with overflow
    
    final borderColor = isSelected ? theme.colorScheme.primary : theme.dividerColor;
    final bgColor = isSelected ? theme.colorScheme.primary.withValues(alpha: 0.05) : theme.cardColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header
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
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
              ],
            ),
            
            // Center Content (Weight/Sets)
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
                            color: theme.colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        TextSpan(
                          text: ' LB',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${status.defaultSets}x${status.defaultReps}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer (Time ago)
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status.recovered ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatTimeSince(status.lastPerformedAt),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
