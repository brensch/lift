import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/warmup.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../services/workout_service.dart';
import '../services/grpc_client.dart';
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
  final Set<Exercise> _selectedExercises = {};
  bool _isLoading = true;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final auth = context.read<AuthProvider>();
    final grpc = context.read<GrpcClient>();
    final workoutService = WorkoutServiceWrapper(grpc);

    try {
      final response = await workoutService.getProposedWorkoutSchedule(auth.userId!);
      setState(() {
        _schedule = response.exerciseStatuses;
        _activeWorkoutId = response.activeWorkoutId.isEmpty ? null : response.activeWorkoutId;
        _isLoading = false;

        // Auto-select always_include + recovered exercises
        for (final status in _schedule!) {
          if (status.alwaysInclude || status.recovered) {
            _selectedExercises.add(status.exercise);
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading schedule: $e');
    }
  }

  Future<void> _startWorkout() async {
    if (_selectedExercises.isEmpty || _schedule == null) return;

    setState(() => _isStarting = true);

    final proposedSets = <ProposedSet>[];
    int order = 0;

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

    final workoutProvider = context.read<WorkoutProvider>();
    final workoutId = await workoutProvider.startWorkout('', proposedSets);

    setState(() => _isStarting = false);

    if (workoutId != null && mounted) {
      // Navigation handled by GoRouter redirect
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If there's an active workout, go straight to it
    if (_activeWorkoutId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final wp = context.read<WorkoutProvider>();
        if (!wp.hasActiveWorkout) {
          wp.loadWorkout(_activeWorkoutId!);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lift')),
      body: _schedule == null
          ? const Center(child: Text('Failed to load schedule'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Compound exercises section
                ..._buildSection('Compound', ExerciseCategory.EXERCISE_CATEGORY_COMPOUND),
                const SizedBox(height: 16),
                // Auxiliary exercises section
                ..._buildSection('Auxiliary', ExerciseCategory.EXERCISE_CATEGORY_AUXILIARY),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _selectedExercises.isEmpty || _isStarting ? null : _startWorkout,
                  icon: _isStarting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text('Start Workout (${_selectedExercises.length})'),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildSection(String title, ExerciseCategory category) {
    final exercises = _schedule!.where((s) => s.category == category).toList();
    if (exercises.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      ...exercises.map((status) => _ExerciseTile(
            status: status,
            isSelected: _selectedExercises.contains(status.exercise),
            onToggle: () {
              setState(() {
                if (_selectedExercises.contains(status.exercise)) {
                  _selectedExercises.remove(status.exercise);
                } else {
                  _selectedExercises.add(status.exercise);
                }
              });
            },
          )),
    ];
  }
}

class _ExerciseTile extends StatelessWidget {
  final ExerciseStatus status;
  final bool isSelected;
  final VoidCallback onToggle;

  const _ExerciseTile({
    required this.status,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = exerciseNames[status.exercise] ?? '?';
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isSelected ? colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onToggle,
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => onToggle(),
        ),
        title: Text(name),
        subtitle: Text(
          '${status.targetWeight} lbs  ${status.explanation}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: status.recovered
            ? Icon(Icons.check_circle, color: colorScheme.primary, size: 20)
            : Icon(Icons.schedule, color: colorScheme.outline, size: 20),
      ),
    );
  }
}
