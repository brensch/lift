import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/auth.pb.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/recovery_alert_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server's requests to get into the account, in memory.
class _FakeAuthService implements AuthService {
  List<PendingRecovery> waiting;
  int asked = 0;
  final denied = <String>[];

  _FakeAuthService(this.waiting);

  @override
  Future<List<PendingRecovery>> listMyRecoveries() async {
    asked++;
    return List.of(waiting);
  }

  @override
  Future<void> denyMyRecovery(String requestId) async {
    denied.add(requestId);
    waiting = waiting.where((r) => r.requestId != requestId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<AuthProvider> boot(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    // Nothing listens here: the profile refresh fails, as with no signal.
    final client = GrpcClient(host: '127.0.0.1', port: 1);
    final auth = AuthProvider(
      authService: AuthService(grpcClient: client),
      grpcClient: client,
    );
    await auth.loadSession();
    return auth;
  }

  const signedIn = {
    'liftSessionToken': 'token',
    'liftUserId': 'user-1',
    'liftUsername': 'lifter',
  };

  Future<void> pumpBanner(
    WidgetTester tester,
    AuthProvider auth,
    AuthService service,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          Provider<AuthService>.value(value: service),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: const RecoveryAlertBanner(
            child: Scaffold(body: Text('the page')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a request to get into the account is shown and can be refused', (
    tester,
  ) async {
    final auth = await tester.runAsync(() => boot(signedIn));
    final service = _FakeAuthService([PendingRecovery(requestId: 'r1')]);
    await pumpBanner(tester, auth!, service);

    expect(find.text(copy.recoveryAlert.body), findsOneWidget);
    expect(find.text('the page'), findsOneWidget);

    await tester.tap(find.text(copy.recoveryAlert.deny));
    await tester.pump();
    await tester.pump();

    expect(service.denied, ['r1']);
    expect(find.text(copy.recoveryAlert.body), findsNothing);
    expect(find.text('the page'), findsOneWidget);
  });

  testWidgets('nothing waiting, nothing shown', (tester) async {
    final auth = await tester.runAsync(() => boot(signedIn));
    final service = _FakeAuthService([]);
    await pumpBanner(tester, auth!, service);

    expect(service.asked, 1);
    expect(find.text(copy.recoveryAlert.body), findsNothing);
  });

  testWidgets('with no session the server is not asked', (tester) async {
    final auth = await tester.runAsync(() => boot({}));
    final service = _FakeAuthService([PendingRecovery(requestId: 'r1')]);
    await pumpBanner(tester, auth!, service);

    expect(service.asked, 0);
    expect(find.text(copy.recoveryAlert.body), findsNothing);
  });
}
