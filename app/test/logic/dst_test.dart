// Run in a zone with daylight saving: `TZ=America/Los_Angeles flutter test
// --tags dst` (make test-app and CI do). In UTC every day is 24 hours and
// these would pass whatever the code did.
@Tags(['dst'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/logic/utils.dart';

void main() {
  test('the zone has a spring-forward change', () {
    expect(
      DateTime(2026, 3, 8).timeZoneOffset,
      isNot(DateTime(2026, 3, 9).timeZoneOffset),
      reason: 'run with TZ=America/Los_Angeles',
    );
  });

  test('calendarDaysBetween is not a day short across it', () {
    // US clocks went forward on 2026-03-08: local midnight to local
    // midnight is 23 hours.
    expect(calendarDaysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 1);
    expect(calendarDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 4, 1)), 31);
  });
}
