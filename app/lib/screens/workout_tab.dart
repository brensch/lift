import 'dart:async';

import 'package:flutter/material.dart';
import '../gen/copy.dart';
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
  /// The app shell opens and loads the account; this only retries.
  void _retry() {
    final wp = context.read<WorkoutProvider>();
    final retry = wp.onRetryStartup;
    if (retry != null) {
      unawaited(retry());
      return;
    }
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) wp.loadActiveWorkout(userId);
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.startup.exitTitle),
        content: Text(copy.startup.exitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copy.startup.exitCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(copy.startup.exitConfirm),
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

    // Until the first load has answered there is nothing to show.
    final startupError = wp.home == null ? wp.lastLoadError : null;
    if (wp.home == null && startupError == null && !wp.hasActiveWorkout) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (startupError != null && !wp.hasActiveWorkout) {
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
                    copy.startup.failed,
                    style: TextStyle(
                      fontSize: context.tokens.size.title,
                      fontWeight: context.tokens.weight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(startupError, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _retry,
                    child: Text(copy.startup.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // The shell has no bar: this page runs to the top of the screen and
    // keeps clear of the system's status bar itself.
    final child = SafeArea(
      bottom: false,
      child: wp.hasActiveWorkout
          ? const WorkoutScreen()
          : const Column(
              children: [
                HomeHeader(),
                Expanded(child: HomeScreen()),
              ],
            ),
    );

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
