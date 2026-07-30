import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart' as app_links;

import 'services/app_logger.dart';
import 'services/notification_service.dart';
import 'services/grpc_client.dart';
import 'services/auth_service.dart';
import 'services/workout_service.dart';
import 'services/multiplayer_service.dart';
import 'services/error_modal_service.dart';
import 'services/platform_wearable_bridge_service.dart';
import 'services/wearable_bridge_service.dart';
import 'services/wearable_sync_coordinator.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/multiplayer_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/sound_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/workout_tab.dart';
import 'screens/completed_workout_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/history_screen.dart';
import 'screens/exercise_detail_screen.dart';
import 'gen/workout/v1/workout.pbenum.dart';
import 'screens/sound_settings_screen.dart';
import 'screens/debug_notifications_screen.dart';
import 'screens/debug_logs_screen.dart';
import 'screens/add_passkey_screen.dart';
import 'screens/passkeys_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/plate_colors_screen.dart';
import 'screens/maths_screen.dart';
import 'screens/profile_marker_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/passkey_notice_screen.dart';
import 'screens/regime_settings_screen.dart';
import 'screens/build_info_screen.dart';
import 'widgets/main_layout.dart';

// Configure server address. Debug builds default to localhost, but can be
// overridden with --dart-define=SERVER_HOST=... and --dart-define=SERVER_PORT=...
const _defaultServerHost = kReleaseMode ? 'schlift.com' : 'localhost';
const _defaultServerPort = kReleaseMode ? '443' : '50051';
const serverHost = String.fromEnvironment(
  'SERVER_HOST',
  defaultValue: _defaultServerHost,
);
const _serverPortValue = String.fromEnvironment(
  'SERVER_PORT',
  defaultValue: _defaultServerPort,
);
final int serverPort = int.parse(_serverPortValue);
final String serverBaseUrl = serverPort == 443
    ? 'https://$serverHost'
    : 'http://$serverHost:$serverPort';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await NotificationService.init();
  runApp(const SchliftApp());
}

class SchliftApp extends StatefulWidget {
  const SchliftApp({super.key, this.serverHostOverride, this.serverPortOverride});

  /// Point the app at a specific backend, overriding the compile-time
  /// SERVER_HOST/SERVER_PORT. Used by the end-to-end test harness to connect to
  /// a backend it spawned on a dynamic port; null in normal builds.
  final String? serverHostOverride;
  final int? serverPortOverride;

  @override
  State<SchliftApp> createState() => _SchliftAppState();
}

class _SchliftAppState extends State<SchliftApp> with WidgetsBindingObserver {
  late final GrpcClient _grpcClient;
  late final AuthService _authService;
  late final AuthProvider _authProvider;
  late final WorkoutProvider _workoutProvider;
  late final MultiplayerProvider _multiplayerProvider;
  late final SettingsProvider _settingsProvider;
  late final SoundProvider _soundProvider;
  late final ThemeProvider _themeProvider;
  late final WearableBridgeService _wearableBridgeService;
  late final WearableSyncCoordinator _wearableSyncCoordinator;
  late final GoRouter _router;
  StreamSubscription? _linkSubscription;
  // A join token from a link tapped before login/signup — held until auth lands,
  // then completed. Lets an invite work on a cold first open, not just when
  // already signed in.
  String? _pendingJoinToken;
  bool _wasLoggedIn = false;

  Future<void> _syncBodyWeightOnAppLoad() async {
    final importedKg = await _authProvider.syncBodyWeightFromHealth(
      requestPermissions: false,
    );
    if (importedKg != null) {
      _workoutProvider.setBodyWeightKg(importedKg);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _grpcClient = GrpcClient(
      host: widget.serverHostOverride ?? serverHost,
      port: widget.serverPortOverride ?? serverPort,
    );
    _authService = AuthService(grpcClient: _grpcClient);

    _authProvider = AuthProvider(
      authService: _authService,
      grpcClient: _grpcClient,
    );

    _settingsProvider = SettingsProvider(_grpcClient);
    _soundProvider = SoundProvider();
    _workoutProvider = WorkoutProvider(
      WorkoutServiceWrapper(_grpcClient),
      _settingsProvider,
    );
    _workoutProvider.setSoundProvider(_soundProvider);
    _multiplayerProvider = MultiplayerProvider(
      MultiplayerServiceWrapper(_grpcClient),
    );
    _themeProvider = ThemeProvider();
    _wearableBridgeService = createWearableBridgeService();
    _wearableSyncCoordinator = WearableSyncCoordinator(
      workoutProvider: _workoutProvider,
      multiplayerProvider: _multiplayerProvider,
      bridgeService: _wearableBridgeService,
      myUserId: () => _authProvider.userId ?? '',
      myProfileEmoji: () => _authProvider.profileEmoji,
    );
    unawaited(_wearableSyncCoordinator.init());
    _workoutProvider.onSessionRefreshNeeded = () {
      _multiplayerProvider.checkForSession();
    };
    _workoutProvider.onWorkoutEnded = (workoutId) {
      final navigator = ErrorModalService.rootNavigatorKey.currentState;
      navigator?.push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => CompletedWorkoutScreen(workoutId: workoutId),
        ),
      );
      unawaited(_settingsProvider.refreshActiveTrainingProgramState());
    };

    // Listen to auth changes: clear state on logout, load settings on login.
    // This covers mid-session signups/logins (not just app startup).
    _authProvider.addListener(() {
      final isLoggedIn = _authProvider.isLoggedIn;
      _workoutProvider.setBodyWeightKg(_authProvider.bodyWeightKg);
      if (isLoggedIn && !_wasLoggedIn) {
        _settingsProvider.load();
        _soundProvider.load();
        final userId = _authProvider.userId;
        if (userId != null) {
          unawaited(_workoutProvider.loadActiveWorkout(userId));
        }
        unawaited(_syncBodyWeightOnAppLoad());
        _multiplayerProvider.startSync();
        // Complete a join from a link tapped before this login/signup.
        if (_pendingJoinToken != null) {
          final token = _pendingJoinToken!;
          _pendingJoinToken = null;
          _multiplayerProvider.joinViaInvite(token);
        }
      } else if (!isLoggedIn && _wasLoggedIn) {
        _settingsProvider.clear();
        unawaited(_soundProvider.reset());
        unawaited(_themeProvider.reset());
        _workoutProvider.clear();
        _multiplayerProvider.stopSync(clearSession: true, clearInviteToken: true);
      }
      _wasLoggedIn = isLoggedIn;
    });

    // Load persisted state at app startup. The auth listener above handles
    // login-transition side effects after this notifies.
    _authProvider.loadSession();

    _router = GoRouter(
      navigatorKey: ErrorModalService.rootNavigatorKey,
      refreshListenable: Listenable.merge([_authProvider, _settingsProvider]),
      redirect: (context, state) {
        final loggedIn = _authProvider.isLoggedIn;
        final isLogin = state.matchedLocation == '/login';
        final isOnboarding = state.matchedLocation == '/onboarding';
        final isPasskeyNotice = state.matchedLocation == '/passkey-notice';

        if (!loggedIn && !isLogin) return '/login';
        if (loggedIn && _authProvider.needsPasskeyNotice && !isPasskeyNotice) {
          return '/passkey-notice';
        }
        if (loggedIn && !_authProvider.needsPasskeyNotice && isPasskeyNotice) {
          return '/';
        }
        if (loggedIn && isLogin) return '/';

        // Redirect new users to onboarding if they haven't set up a training program.
        if (loggedIn &&
            !isOnboarding &&
            !isPasskeyNotice &&
            _settingsProvider.loaded &&
            !_settingsProvider.hasProgramState) {
          return '/onboarding';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
          path: '/passkey-notice',
          builder: (_, __) => const PasskeyNoticeScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              MainLayout(currentPath: state.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const WorkoutTab()),
            GoRoute(
              path: '/workout/:id/completed',
              builder: (_, state) => CompletedWorkoutScreen(
                workoutId: state.pathParameters['id']!,
                isHistory: state.uri.queryParameters['isHistory'] == 'true',
              ),
            ),
            GoRoute(
              path: '/training-program',
              builder: (_, __) => const RegimeSettingsScreen(),
            ),
            GoRoute(
              path: '/settings/regime',
              redirect: (_, __) => '/training-program',
            ),
            GoRoute(
              path: '/progress',
              builder: (_, __) => const ProgressScreen(),
            ),
            GoRoute(
              path: '/history',
              builder: (_, __) => const HistoryScreen(),
            ),
            GoRoute(
              path: '/exercise/:ex',
              builder: (_, state) {
                final v = int.tryParse(state.pathParameters['ex'] ?? '') ?? 0;
                return ExerciseDetailScreen(
                  exercise:
                      Exercise.valueOf(v) ?? Exercise.EXERCISE_UNSPECIFIED,
                );
              },
            ),
            GoRoute(
              path: '/sound-settings',
              builder: (_, __) => const SoundSettingsScreen(),
            ),
            GoRoute(
              path: '/passkeys',
              builder: (_, __) => const PasskeysScreen(),
            ),
            GoRoute(
              path: '/passkeys/add',
              builder: (_, __) => const AddPasskeyScreen(),
            ),
            GoRoute(
              path: '/debug-notifications',
              builder: (_, __) => const DebugNotificationsScreen(),
            ),
            GoRoute(
              path: '/debug-logs',
              builder: (_, __) => const DebugLogsScreen(),
            ),
            GoRoute(
              path: '/build-info',
              builder: (_, __) => const BuildInfoScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/settings/profile-marker',
              builder: (_, __) => const ProfileMarkerScreen(),
            ),
            GoRoute(
              path: '/settings/plate-colors',
              builder: (_, __) => const PlateColorsScreen(),
            ),
            GoRoute(
              path: '/settings/maths',
              builder: (_, __) => const MathsScreen(),
            ),
          ],
        ),
      ],
    );

    // Initial deep link
    app_links.AppLinks().getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Subscribed deep links. Joining is link-only: an https://schlift.com/?join=…
    // App Link / Universal Link opens the app straight into the session. No
    // clipboard scan, no manual paste.
    _linkSubscription = app_links.AppLinks().uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final joinToken = uri.queryParameters['join'];
    if (joinToken == null || joinToken.isEmpty) return;
    if (_authProvider.isLoggedIn) {
      _multiplayerProvider.joinViaInvite(joinToken);
    } else {
      // Not signed in yet (cold open from the link) — remember it; the auth
      // listener joins as soon as login/signup completes.
      _pendingJoinToken = joinToken;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.instance.info('App', 'lifecycle', {'state': state.name});
    if (state == AppLifecycleState.resumed) {
      // Force a fresh HTTP/2 connection on resume. Mobile networks silently
      // kill idle connections; without this, every gRPC call hangs until it
      // hits the deadline.
      _grpcClient.resetChannel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    unawaited(_wearableSyncCoordinator.dispose());
    _grpcClient.shutdown();
    _authProvider.dispose();
    _workoutProvider.dispose();
    _multiplayerProvider.dispose();
    _settingsProvider.dispose();
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
        Provider<WearableBridgeService>.value(value: _wearableBridgeService),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<WorkoutProvider>.value(value: _workoutProvider),
        ChangeNotifierProvider<MultiplayerProvider>.value(
          value: _multiplayerProvider,
        ),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: _settingsProvider,
        ),
        ChangeNotifierProvider<SoundProvider>.value(value: _soundProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp.router(
          title: 'Schlift',
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
