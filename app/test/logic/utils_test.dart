import 'package:flutter_test/flutter_test.dart';
import 'package:passkeys/exceptions.dart';
import 'package:schlift/logic/utils.dart';

void main() {
  test('formatPasskeyError includes native passkey code', () {
    final message = formatPasskeyError(
      DomainNotAssociatedException(
        'The app is not associated with the requested domain.',
      ),
    );

    expect(message, contains('Passkey error (domain-not-associated)'));
    expect(message, contains('not associated'));
  });

  group('calendarDaysBetween', () {
    test('counts dates, not elapsed time', () {
      expect(
        calendarDaysBetween(DateTime(2026, 3, 1, 23, 59), DateTime(2026, 3, 2)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 2, 8), DateTime(2026, 3, 2, 20)),
        0,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 9), DateTime(2026, 3, 2)),
        -7,
      );
    });
    // Across a daylight-saving change: dst_test.dart.
  });

  test('shortMonth and monthYear', () {
    expect(shortMonth(DateTime(2026, 9, 3)), 'Sep');
    expect(monthYear(DateTime(2026, 9, 3)), 'September 2026');
  });
}
