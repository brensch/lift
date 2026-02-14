import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'services/grpc_client.dart';
import 'services/auth_service.dart';
import 'services/workout_service.dart';
import 'services/multiplayer_service.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/multiplayer_provider.dart';
import 'providers/sound_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/completed_workout_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/history_screen.dart';
import 'screens/sound_settings_screen.dart';
import 'screens/passkeys_screen.dart';
import 'widgets/session_header.dart';

// Configure server address - change for production
const serverHost = 'localhost';
const serverPort = 50051;
const serverBaseUrl = 'http://$serverHost:$serverPort';

void main() {
  runApp(const LiftApp());
}

class LiftApp extends StatefulWidget {
  const LiftApp({super.key});

  @override
  State<LiftApp> createState() => _LiftAppState();
}

class _LiftAppState extends State<LiftApp> {
  late final GrpcClient _grpcClient;
  late final AuthService _authService;
  late final AuthProvider _authProvider;
  late final WorkoutProvider _workoutProvider;
  late final MultiplayerProvider _multiplayerProvider;
  late final SoundProvider _soundProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _grpcClient = GrpcClient(host: serverHost, port: serverPort);
    _authService = AuthService(baseUrl: serverBaseUrl);

    _authProvider = AuthProvider(
      authService: _authService,
      grpcClient: _grpcClient,
    );

    _workoutProvider = WorkoutProvider(WorkoutServiceWrapper(_grpcClient));
    _multiplayerProvider = MultiplayerProvider(MultiplayerServiceWrapper(_grpcClient));
    _soundProvider = SoundProvider();

    // Load persisted state
    _authProvider.loadSession().then((_) {
      if (_authProvider.isLoggedIn) {
        _workoutProvider.loadActiveWorkout();
        _multiplayerProvider.checkForSession();
        _soundProvider.load();
      }
    });

    _router = GoRouter(
      refreshListenable: _authProvider,
      redirect: (context, state) {
        final loggedIn = _authProvider.isLoggedIn;
        final isLogin = state.matchedLocation == '/login';

        if (!loggedIn && !isLogin) return '/login';
        if (loggedIn && isLogin) return '/';

        // Auto-redirect to workout if one is active
        if (loggedIn &&
            state.matchedLocation == '/' &&
            _workoutProvider.hasActiveWorkout) {
          return '/workout';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        ShellRoute(
          builder: (context, state, child) => ScaffoldWithDrawer(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            GoRoute(path: '/workout', builder: (_, __) => const WorkoutScreen()),
            GoRoute(
              path: '/workout/:id/completed',
              builder: (_, state) => CompletedWorkoutScreen(
                workoutId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
            GoRoute(path: '/sound-settings', builder: (_, __) => const SoundSettingsScreen()),
            GoRoute(path: '/passkeys', builder: (_, __) => const PasskeysScreen()),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _grpcClient.shutdown();
    _authProvider.dispose();
    _workoutProvider.dispose();
    _multiplayerProvider.dispose();
    _soundProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GrpcClient>.value(value: _grpcClient),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<WorkoutProvider>.value(value: _workoutProvider),
        ChangeNotifierProvider<MultiplayerProvider>.value(value: _multiplayerProvider),
        ChangeNotifierProvider<SoundProvider>.value(value: _soundProvider),
      ],
      child: MaterialApp.router(
        title: 'Lift',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        routerConfig: _router,
      ),
    );
  }
}

class ScaffoldWithDrawer extends StatelessWidget {
  final Widget child;

  const ScaffoldWithDrawer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SessionHeader(),
        Expanded(child: child),
      ],
    );
  }
}
