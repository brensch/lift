import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signing out and a lapsed session: what this phone keeps, and what the
/// next account on it starts from.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AuthProvider provider() {
    // Nothing listens here: every RPC fails, as on a phone with no signal.
    final client = GrpcClient(host: '127.0.0.1', port: 1);
    return AuthProvider(
      authService: AuthService(grpcClient: client),
      grpcClient: client,
    );
  }

  const saved = {
    'liftSessionToken': 'token',
    'liftUserId': 'user-1',
    'liftUsername': 'lifter',
  };

  test('logout forgets the account, its body weight included', () async {
    SharedPreferences.setMockInitialValues(saved);
    final auth = provider();
    await auth.loadSession();
    auth.setBodyWeight(92);

    await auth.logout();

    expect(auth.isLoggedIn, isFalse);
    expect(auth.hasServerSession, isFalse);
    expect(auth.bodyWeightKg, 0, reason: "the next account isn't this one");
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });

  test('an expired session keeps the account open on the phone', () async {
    SharedPreferences.setMockInitialValues(saved);
    final auth = provider();
    await auth.loadSession();

    await auth.expireSession(message: 'sign in again');

    expect(auth.isLoggedIn, isTrue);
    expect(auth.hasServerSession, isFalse);
    expect(auth.userId, 'user-1');
    expect(auth.error, 'sign in again');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('liftSessionToken'), isNull);
    expect(prefs.getString('liftUserId'), 'user-1');
  });
}
