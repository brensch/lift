import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../providers/workout_provider.dart';
import '../widgets/exercise_group_widget.dart';

class CompletedWorkoutScreen extends StatelessWidget {
  final String workoutId;

  const CompletedWorkoutScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();

    if (wp.workout == null) {
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
      appBar: AppBar(title: const Text('Workout Complete')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Great Work!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completedWorking working sets  \u2022  ${_formatDuration(duration)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
          FilledButton(
            onPressed: () {
              wp.clear();
            },
            child: const Text('Done'),
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
