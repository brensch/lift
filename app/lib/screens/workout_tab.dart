import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import 'home_screen.dart';
import 'workout_screen.dart';

class WorkoutTab extends StatefulWidget {
  const WorkoutTab({super.key});

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        if (auth.userId != null) {
          context.read<WorkoutProvider>().loadActiveWorkout(auth.userId!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();

    if (wp.hasActiveWorkout) {
      return const WorkoutScreen();
    }

    return const HomeScreen();
  }
}
