import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart' as app_links;

import 'services/notification_service.dart';
import 'services/grpc_client.dart';
import 'services/auth_service.dart';
import 'services/workout_service.dart';
import 'services/multiplayer_service.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/multiplayer_provider.dart';
import 'providers/sound_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/workout_tab.dart';
import 'screens/completed_workout_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/history_screen.dart';
import 'screens/sound_settings_screen.dart';
import 'screens/debug_notifications_screen.dart';
import 'screens/passkeys_screen.dart';
import 'widgets/main_layout.dart';

// Configure server address - change for production
const serverHost = kReleaseMode ? 'lift.snek2.ddns.net' : 'localhost';
const serverPort = kReleaseMode ? 443 : 50051;
const serverBaseUrl = kReleaseMode ? 'https://$serverHost' : 'http://$serverHost:$serverPort';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
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
  late final ThemeProvider _themeProvider;
  late final GoRouter _router;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();

    _grpcClient = GrpcClient(host: serverHost, port: serverPort);
    _authService = AuthService(grpcClient: _grpcClient);

    _authProvider = AuthProvider(
      authService: _authService,
      grpcClient: _grpcClient,
    );

    _soundProvider = SoundProvider();
    _workoutProvider = WorkoutProvider(WorkoutServiceWrapper(_grpcClient));
    _workoutProvider.setSoundProvider(_soundProvider);
    _multiplayerProvider = MultiplayerProvider(MultiplayerServiceWrapper(_grpcClient));
    _themeProvider = ThemeProvider();

    // Listen to auth changes to clear state on logout
    _authProvider.addListener(() {
      if (!_authProvider.isLoggedIn) {
        _workoutProvider.clear();
        _multiplayerProvider.clear();
      }
    });

    // Load persisted state
    _authProvider.loadSession().then((_) {
      if (_authProvider.isLoggedIn) {
        _workoutProvider.loadActiveWorkout(_authProvider.userId!);
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

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        ShellRoute(
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const WorkoutTab()),
            GoRoute(
              path: '/workout/:id/completed',
              builder: (_, state) => CompletedWorkoutScreen(
                workoutId: state.pathParameters['id']!,
                isHistory: state.uri.queryParameters['isHistory'] == 'true',
              ),
            ),
            GoRoute(path: '/progress', builder: (_, __) => const ProgressScreen()),
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
            GoRoute(path: '/sound-settings', builder: (_, __) => const SoundSettingsScreen()),
            GoRoute(path: '/passkeys', builder: (_, __) => const PasskeysScreen()),
            GoRoute(path: '/debug-notifications', builder: (_, __) => const DebugNotificationsScreen()),
          ],
        ),
      ],
    );

    // Initial deep link
    app_links.AppLinks().getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Subscribed deep links
    _linkSubscription = app_links.AppLinks().uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Deferred join check via clipboard
    _checkClipboardForJoin();
  }

  Future<void> _checkClipboardForJoin() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.startsWith('lift-join:')) {
      final joinId = data.text!.replaceFirst('lift-join:', '');
      // Clear clipboard so we don't keep joining
      await Clipboard.setData(const ClipboardData(text: ''));
      _joinById(joinId);
    }
  }

  void _handleDeepLink(Uri uri) {
    final joinId = uri.queryParameters['join'];
    if (joinId != null) {
      _joinById(joinId);
    }
  }

  void _joinById(String joinId) {
    if (_authProvider.isLoggedIn) {
      final workoutId = _workoutProvider.hasActiveWorkout ? _workoutProvider.workout?.id : null;
      _multiplayerProvider.joinSession(joinId, workoutId: workoutId);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _grpcClient.shutdown();
    _authProvider.dispose();
    _workoutProvider.dispose();
    _multiplayerProvider.dispose();
    _soundProvider.dispose();
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GrpcClient>.value(value: _grpcClient),
        Provider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<WorkoutProvider>.value(value: _workoutProvider),
        ChangeNotifierProvider<MultiplayerProvider>.value(value: _multiplayerProvider),
        ChangeNotifierProvider<SoundProvider>.value(value: _soundProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp.router(
          title: 'Lift',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
          routerConfig: _router,
        ),
      ),
    );
  }
}
