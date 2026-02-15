import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import 'home_screen.dart';
import 'workout_screen.dart';

class WorkoutTab extends StatelessWidget {
  const WorkoutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();

    if (wp.hasActiveWorkout) {
      return const WorkoutScreen();
    }

    return const HomeScreen();
  }
}
