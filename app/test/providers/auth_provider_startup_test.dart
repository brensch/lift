import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cold start. The router holds on a blank page until `sessionLoaded`, then
/// trusts `isLoggedIn` — so the saved session has to be published as soon as
/// it is read from disk, never after a network round trip.
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

  test(
    'a saved session is published before the profile fetch finishes',
    () async {
      SharedPreferences.setMockInitialValues({
        'liftSessionToken': 'token',
        'liftUserId': 'user-1',
        'liftUsername': 'lifter',
      });
      final auth = provider();
      expect(auth.sessionLoaded, isFalse);

      final states = <(bool, bool)>[];
      auth.addListener(() => states.add((auth.sessionLoaded, auth.isLoggedIn)));

      final loading = auth.loadSession();
      // Only the disk read has to happen; the profile RPC is still in flight.
      await SharedPreferences.getInstance();
      await Future<void>.delayed(Duration.zero);

      expect(states, isNotEmpty);
      expect(states.first, (true, true));
      expect(auth.username, 'lifter');

      // And with the network down it still completes, signed in.
      await loading;
      expect(auth.isLoggedIn, isTrue);
    },
  );

  test('with nothing saved, the session is loaded and signed out', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = provider();

    await auth.loadSession();

    expect(auth.sessionLoaded, isTrue);
    expect(auth.isLoggedIn, isFalse);
  });
}
