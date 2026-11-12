import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/auth.pb.dart';
import 'package:schlift/screens/passkeys_screen.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/theme/app_theme.dart';

/// The server's passkeys, in memory; a delete fails while [failDelete], and
/// a list waits for [gate] while one is set.
class _FakeAuthService implements AuthService {
  List<PasskeyInfo> passkeys;
  bool failDelete = false;
  int lists = 0;
  Completer<void>? gate;

  _FakeAuthService(this.passkeys);

  @override
  Future<List<PasskeyInfo>> listPasskeys() async {
    lists++;
    await gate?.future;
    return List.of(passkeys);
  }

  @override
  Future<void> deletePasskey(String credentialId) async {
    if (failDelete) throw Exception('server said no');
    passkeys = passkeys.where((p) => p.credentialId != credentialId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PasskeyInfo _key(String id) => PasskeyInfo(credentialId: id, name: id);

Widget _screen(AuthService auth) => Provider<AuthService>.value(
  value: auth,
  child: MaterialApp(theme: AppTheme.theme, home: const PasskeysScreen()),
);

IconButton _deleteButton(WidgetTester tester, String name) =>
    tester.widget<IconButton>(
      find.descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(Row)),
        matching: find.byType(IconButton),
      ),
    );

void main() {
  testWidgets('the last passkey cannot be deleted', (tester) async {
    await tester.pumpWidget(_screen(_FakeAuthService([_key('phone')])));
    await tester.pumpAndSettle();
    expect(find.text('phone'), findsOneWidget);
    expect(_deleteButton(tester, 'phone').onPressed, isNull);
    // And having only one is called out.
    expect(find.text(copy.passkeys.onlyOne), findsOneWidget);
  });

  testWidgets('a failed delete says so and keeps the passkey', (tester) async {
    final auth = _FakeAuthService([_key('phone'), _key('laptop')])
      ..failDelete = true;
    await tester.pumpWidget(_screen(auth));
    await tester.pumpAndSettle();
    expect(_deleteButton(tester, 'laptop').onPressed, isNotNull);

    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text('laptop'), matching: find.byType(Row)),
        matching: find.byIcon(AppIcons.delete),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.passkeys.deleteConfirm));
    await tester.pumpAndSettle();

    expect(find.text(copy.passkeys.deleteFailed), findsOneWidget);
    expect(find.text('laptop'), findsOneWidget);
  });

  testWidgets('a refresh keeps the list on screen while it reads', (
    tester,
  ) async {
    final auth = _FakeAuthService([_key('phone'), _key('laptop')]);
    await tester.pumpWidget(_screen(auth));
    await tester.pumpAndSettle();

    auth.gate = Completer<void>();
    await tester.fling(find.text('phone'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // The read is in flight: the list stays, with no full-screen spinner.
    expect(auth.lists, 2);
    expect(find.text('phone'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('laptop'), findsOneWidget);
  });
}
