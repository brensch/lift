import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
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
  bool _initialSyncComplete = false;
  String? _startupError;

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
    if (userId == null) {
      if (!_initialSyncComplete && mounted) {
        setState(() => _initialSyncComplete = true);
      }
      return;
    }

    _syncInFlight = true;
    try {
      final workoutProvider = context.read<WorkoutProvider>();
      await workoutProvider.loadActiveWorkout(userId);
      if (!mounted) return;

      if (workoutProvider.lastLoadWasUnauthorized) {
        await auth.expireSession(
          message: 'Your saved session expired. Sign in again.',
        );
        return;
      }

      setState(() {
        _startupError = workoutProvider.lastLoadError;
      });
      _lastServerSyncAt = DateTime.now();
    } finally {
      _syncInFlight = false;
      if (!_initialSyncComplete && mounted) {
        setState(() => _initialSyncComplete = true);
      }
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
    final settings = context.watch<SettingsProvider>();

    if (!_initialSyncComplete) {
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
                  const Text(
                    'Could not finish startup',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(_startupError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _syncInFlight
                        ? null
                        : () => _syncFromServer(force: true),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final programState = settings.programState;
    final homeRefreshKey = ValueKey(
      'home-${programState?.regimeType.value ?? -1}-${programState?.updatedAt ?? 0}',
    );

    final child = wp.hasActiveWorkout
        ? const WorkoutScreen()
        : HomeScreen(key: homeRefreshKey);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: child,
    );
  }
}
