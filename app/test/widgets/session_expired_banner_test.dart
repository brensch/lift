import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/screens/login_screen.dart';
import 'package:schlift/services/account_sync.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/session_expired_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An AccountSync the test can turn away as too old, as the server would.
class _Sync extends AccountSync {
  _Sync() : super(GrpcClient(host: '127.0.0.1', port: 1));

  bool tooOld = false;

  @override
  bool get updateRequired => tooOld;

  void turnAway() {
    tooOld = true;
    notifyListeners();
  }
}

/// The login screen never settles (its hint cycles), so a few frames do.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AuthProvider auth;
  late _Sync sync;

  Future<void> boot(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    // Nothing listens here: every RPC fails, as on a phone with no signal.
    final client = GrpcClient(host: '127.0.0.1', port: 1);
    auth = AuthProvider(
      authService: AuthService(grpcClient: client),
      grpcClient: client,
    );
    await auth.loadSession();
    sync = _Sync();
  }

  const signedIn = {
    'liftSessionToken': 'token',
    'liftUserId': 'user-1',
    'liftUsername': 'lifter',
  };

  Future<void> pumpApp(WidgetTester tester, {String at = '/'}) =>
      tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AccountSync>.value(value: sync),
          ],
          child: MaterialApp.router(
            theme: AppTheme.theme,
            routerConfig: GoRouter(
              initialLocation: at,
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, __) => const Scaffold(
                    body: SessionExpiredBanner(child: Text('home')),
                  ),
                ),
                GoRoute(
                  path: '/login',
                  builder: (_, __) => const LoginScreen(),
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('a lapsed session leads to /login, and back home', (
    tester,
  ) async {
    await tester.runAsync(() => boot(signedIn));
    await pumpApp(tester);
    expect(find.text(copy.sessionExpired), findsNothing);

    await auth.expireSession(message: copy.sessionExpired);
    await tester.pump();
    expect(find.text(copy.sessionExpired), findsOneWidget);
    expect(find.text('home'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, copy.login.signIn));
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    // Not a trap: the account is open, so home is a tap away.
    await tester.tap(find.byIcon(AppIcons.back));
    await settle(tester);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the update banner takes its place', (tester) async {
    await tester.runAsync(() => boot(signedIn));
    await pumpApp(tester);
    await auth.expireSession(message: copy.sessionExpired);
    sync.turnAway();
    await tester.pump();
    expect(find.text(copy.sessionExpired), findsNothing);
  });

  testWidgets('signed out of the phone: no back from /login', (tester) async {
    await tester.runAsync(() => boot({}));
    await pumpApp(tester);
    GoRouter.of(tester.element(find.text('home'))).go('/login');
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byIcon(AppIcons.back), findsNothing);
  });
}
