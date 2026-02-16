import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/warmup.dart';
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
  Set<Exercise> _selectedExercises = {};
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;
  late final TextEditingController _nameController = TextEditingController(text: _getDefaultWorkoutName());

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
      final scheduleRes = await workoutService.getProposedWorkoutSchedule(auth.userId!);

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
        _selectedExercises = autoSelected;
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
    if (_selectedExercises.isEmpty || _schedule == null) return;

    setState(() => _isStarting = true);

    try {
      final proposedSets = <ProposedSet>[];
      final exerciseGroups = <ExerciseGroup>[];
      int setOrder = 0;
      int groupOrder = 0;

      for (final status in _schedule!) {
        if (!_selectedExercises.contains(status.exercise)) continue;

        final groupId = _uuid.v4();
        exerciseGroups.add(ExerciseGroup()
          ..id = groupId
          ..name = exerciseNames[status.exercise] ?? status.exercise.name
          ..type = ExerciseGroupType.EXERCISE_GROUP_TYPE_STRAIGHT
          ..includeWarmup = true
          ..workoutOrder = groupOrder++);

        final warmupDefs = generateWarmupDefs(status.targetWeight.toDouble());
        for (final def in warmupDefs) {
          proposedSets.add(ProposedSet()
            ..id = _uuid.v4()
            ..workoutOrder = setOrder++
            ..exercise = status.exercise
            ..targetReps = def.reps
            ..targetWeight = def.weight
            ..warmup = true
            ..exerciseGroupId = groupId);
        }

        for (int i = 0; i < status.defaultSets; i++) {
          proposedSets.add(ProposedSet()
            ..id = _uuid.v4()
            ..workoutOrder = setOrder++
            ..exercise = status.exercise
            ..targetReps = status.defaultReps
            ..targetWeight = status.targetWeight
            ..warmup = false
            ..exerciseGroupId = groupId);
        }
      }

      final now = DateTime.now();
      final dateStr = "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";
      final exerciseSummary = _selectedExercises
          .map((e) => shortNames[e] ?? "")
          .where((s) => s.isNotEmpty)
          .join(' ');
      
      final baseName = _nameController.text.trim().isEmpty 
          ? _getDefaultWorkoutName() 
          : _nameController.text.trim().toUpperCase();

      final workoutName = "$dateStr - $exerciseSummary - $baseName".toUpperCase();

      final workoutProvider = context.read<WorkoutProvider>();
      
      // We need to pass the weights for each group
      // The startWorkout wrapper should handle this if I updated it correctly
      // But wait, the startWorkout method in WorkoutProvider currently takes (String name, List<ExerciseGroup> groups, List<ProposedSet> sets)
      // The groups already contain the configuration? No, ExerciseGroup proto doesn't have weights.
      // The weights are in the ProposedSet objects.
      
      final workoutId = await workoutProvider.startWorkout(workoutName, exerciseGroups, proposedSets);

      if (workoutId != null && mounted) {
        final mp = context.read<MultiplayerProvider>();
        if (mp.isInSession) {
          await mp.updateActiveWorkout(workoutId);
        }
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'SELECT YOUR EXERCISES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ),
          if (compounds.isNotEmpty) _buildCategorySection('COMPOUND', compounds),
          if (auxiliaries.isNotEmpty) _buildCategorySection('AUXILIARY', auxiliaries),
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            left: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            right: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: _selectedExercises.isEmpty || _isStarting ? null : _startWorkout,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        'START WORKOUT (${_selectedExercises.length})',
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

  Widget _buildCategorySection(String title, List<ExerciseStatus> items) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
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
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
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
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      height: 1.1,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${status.targetWeight.toInt()}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  'LB',
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${status.defaultSets}x${status.defaultReps}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            if (status.explanation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  status.explanation.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                    height: 1.1,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status.recovered
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTimeSince(status.lastPerformedAt),
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
