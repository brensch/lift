import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _WorkoutTabState extends State<WorkoutTab> with WidgetsBindingObserver {
  DateTime? _lastServerSyncAt;
  bool _syncInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromServer(force: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFromServer(force: true);
    }
  }

  Future<void> _syncFromServer({bool force = false}) async {
    if (!mounted || _syncInFlight) return;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    final now = DateTime.now();
    if (!force &&
        _lastServerSyncAt != null &&
        now.difference(_lastServerSyncAt!) < const Duration(seconds: 5)) {
      return;
    }

    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    _syncInFlight = true;
    try {
      await context.read<WorkoutProvider>().loadActiveWorkout(userId);
      _lastServerSyncAt = DateTime.now();
    } finally {
      _syncInFlight = false;
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromServer();
    });

    if (wp.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final child = wp.hasActiveWorkout
        ? const WorkoutScreen()
        : const HomeScreen();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: child,
    );
  }
}
