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

    test('is not a day short across a spring-forward change', () {
      // US clocks went forward on 2026-03-08 and Europe's on 2026-03-29:
      // local midnight to local midnight is 23 hours there.
      expect(
        calendarDaysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 29), DateTime(2026, 3, 30)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 4, 1)),
        31,
      );
    });
  });

  test('shortMonth and monthYear', () {
    expect(shortMonth(DateTime(2026, 9, 3)), 'Sep');
    expect(monthYear(DateTime(2026, 9, 3)), 'September 2026');
  });
}
