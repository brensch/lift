import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys/exceptions.dart';
import 'package:schlift/logic/utils.dart';

void main() {
  testWidgets('App placeholder test', (WidgetTester tester) async {
    // Placeholder test
    expect(true, isTrue);
  });

  test('formatPasskeyError includes native passkey code', () {
    final message = formatPasskeyError(
      DomainNotAssociatedException(
        'The app is not associated with the requested domain.',
      ),
    );

    expect(message, contains('Passkey error (domain-not-associated)'));
    expect(message, contains('not associated'));
  });
}
