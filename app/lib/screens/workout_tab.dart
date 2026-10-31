import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../tutorial/tutorial_target.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import 'home/home_screen.dart';
import 'workout/workout_screen.dart';
import '../theme/theme_spec.dart';

class WorkoutTab extends StatefulWidget {
  const WorkoutTab({super.key});

  @override
  State<WorkoutTab> createState() => _WorkoutTabState();
}

class _WorkoutTabState extends State<WorkoutTab> {
  bool _initialSyncComplete = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// The account is on this phone, so this is a read, not a round trip.
  Future<void> _load() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      final workoutProvider = context.read<WorkoutProvider>();
      await workoutProvider.loadActiveWorkout(userId);
      _startupError = workoutProvider.lastLoadError;
    }
    if (mounted) setState(() => _initialSyncComplete = true);
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Are you sure you want to quit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('EXIT'),
          ),
        ],
      ),
    );
    if (result == true) {
      SystemNavigator.pop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();

    if (!_initialSyncComplete && !wp.hasActiveWorkout) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_startupError != null && !wp.hasActiveWorkout) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not finish startup',
                    style: TextStyle(
                      fontSize: context.tokens.size.title,
                      fontWeight: context.tokens.weight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(_startupError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final child = wp.hasActiveWorkout
        ? const WorkoutScreen()
        : const HomeScreen();

    // Inside the tutorial's sandbox the tutorial owns the back button.
    if (TutorialScope.maybeOf(context) != null) return child;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: child,
    );
  }
}
