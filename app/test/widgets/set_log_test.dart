/// The set log's gap between two sets, split the way the core's summary
/// and the heart chart split it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/widgets/set_log.dart';

void main() {
  test('resting until the rest runs out, yapping after', () {
    expect(splitGap(ended: 100, restUntil: 190, began: 250), (
      rest: 90,
      yap: 60,
    ));
  });

  test('a set begun before the rest ran out is all rest', () {
    expect(splitGap(ended: 100, restUntil: 190, began: 150), (
      rest: 50,
      yap: 0,
    ));
  });

  test('no rest after the set (rest_seconds 0, or none recorded) is all '
      'yapping', () {
    expect(splitGap(ended: 100, restUntil: 100, began: 190), (
      rest: 0,
      yap: 90,
    ));
    expect(splitGap(ended: 100, restUntil: 0, began: 190), (rest: 0, yap: 90));
  });
}
