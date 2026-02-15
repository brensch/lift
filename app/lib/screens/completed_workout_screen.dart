import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_group_widget.dart';

class CompletedWorkoutScreen extends StatefulWidget {
  final String workoutId;

  const CompletedWorkoutScreen({super.key, required this.workoutId});

  @override
  State<CompletedWorkoutScreen> createState() => _CompletedWorkoutScreenState();
}

class _CompletedWorkoutScreenState extends State<CompletedWorkoutScreen> {
  @override
  void initState() {
    super.initState();
    final wp = context.read<WorkoutProvider>();
    // Load workout if not already loaded or if it's a different workout
    if (wp.workout == null || wp.workout!.id != widget.workoutId) {
      wp.loadWorkout(widget.workoutId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (wp.workout == null || wp.workout!.id != widget.workoutId) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final groups = wp.exerciseGroups;
    final duration = wp.workout!.endTime != Int64.ZERO
        ? Duration(seconds: (wp.workout!.endTime - wp.workout!.startTime).toInt())
        : Duration.zero;
    final completedWorking = wp.completedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .where((c) {
          final proposed = wp.proposedSets.cast<ProposedSet?>().firstWhere(
            (p) => p!.id == c.proposedSetId,
            orElse: () => null,
          );
          return proposed != null && !proposed.warmup;
        })
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SUMMARY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successFg, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'GREAT WORK',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completedWorking working sets  \u2022  ${_formatDuration(duration)}',
                  style: TextStyle(color: colorScheme.tertiary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...groups.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ExerciseGroupWidget(
                  group: group,
                  groupIndex: 0,
                  totalGroups: groups.length,
                  completedSets: wp.completedSets,
                  isWorkoutEnded: true,
                ),
              )),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () {
                wp.clear();
                context.go('/');
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
