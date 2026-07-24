import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/logic/weight_units.dart';

const lb = WeightUnit.WEIGHT_UNIT_LB;
const kg = WeightUnit.WEIGHT_UNIT_KG;

void main() {
  group('conversion', () {
    test('pounds and kilograms round-trip', () {
      // `poundsPerKilogram` is the reciprocal of `kilogramsPerPound` truncated
      // to 11 digits, so a round trip drifts by roughly 1 part in 10^9 — a few
      // nanopounds on a heavy barbell. The tolerance is set at a millionth of a
      // pound, which is still far below anything that can be loaded or shown.
      for (final pounds in [45.0, 135.0, 225.0, 315.5]) {
        final back = kilogramsToPounds(poundsToKilograms(pounds));
        expect(back, closeTo(pounds, 1e-6));
      }
    });

    test('uses the exact international pound', () {
      // 1 lb is defined as exactly 0.45359237 kg.
      expect(poundsToKilograms(1), closeTo(0.45359237, 1e-12));
      expect(kilogramsToPounds(1), closeTo(2.2046226218, 1e-9));
    });
  });

  group('display conversion', () {
    test('pounds pass through unchanged in imperial', () {
      expect(displayWeightFromPounds(135, lb), 135);
      expect(poundsFromDisplayWeight(135, lb), 135);
    });

    test('metric converts in both directions', () {
      expect(displayWeightFromPounds(100, kg), closeTo(45.359237, 1e-6));
      expect(poundsFromDisplayWeight(45.359237, kg), closeTo(100, 1e-6));
    });
  });

  group('snapping', () {
    test('imperial snaps to 5 lb by default', () {
      expect(snapDisplayWeight(133, lb), 135);
      expect(snapDisplayWeight(132, lb), 130);
      expect(snapDisplayWeight(137.5, lb), 140);
    });

    test('metric snaps to 2.5 kg by default', () {
      expect(snapDisplayWeight(61, kg), 60);
      expect(snapDisplayWeight(61.5, kg), 62.5);
    });

    test('custom steps are honoured', () {
      expect(snapDisplayWeight(133, lb, poundStep: 2.5), 132.5);
      expect(snapDisplayWeight(61, kg, kilogramStep: 1), 61);
    });

    test('snapPoundsForUnit lands on a loadable metric weight', () {
      // 100 lb is 45.36 kg; the nearest 2.5 kg is 45 kg, which is 99.2 lb.
      final snapped = snapPoundsForUnit(100, kg);
      expect(poundsToKilograms(snapped), closeTo(45, 1e-6));
    });

    test('snapPoundsForUnit is a no-op for weights already on the step', () {
      expect(snapPoundsForUnit(135, lb), 135);
    });

    test('snapping is idempotent', () {
      for (final unit in [lb, kg]) {
        for (final w in [37.0, 100.0, 183.5, 271.0]) {
          final once = snapPoundsForUnit(w, unit);
          expect(snapPoundsForUnit(once, unit), closeTo(once, 1e-6),
              reason: 'unit=$unit weight=$w');
        }
      }
    });
  });

  group('formatting', () {
    test('drops the decimal for whole numbers', () {
      expect(formatWeight(135, lb), '135');
      expect(formatWeight(137.5, lb), '137.5');
    });

    test('appends the unit only when asked', () {
      expect(formatWeight(135, lb, includeUnit: true), '135 lb');
      expect(formatWeight(100, kg, includeUnit: true), '45.4 kg');
    });

    test('suffixes match the unit', () {
      expect(weightUnitSuffix(lb), 'lb');
      expect(weightUnitSuffix(kg), 'kg');
      expect(weightUnitSuffixPlural(lb), 'lbs');
      expect(weightUnitSuffixPlural(kg), 'kg');
    });
  });

  group('bar and plates', () {
    test('bar weight matches the unit', () {
      expect(standardBarWeight(lb), 45);
      expect(standardBarWeight(kg), 20);
    });

    test('plates are listed heaviest first', () {
      for (final unit in [lb, kg]) {
        final plates = standardPlates(unit);
        expect(plates, isNotEmpty);
        for (var i = 1; i < plates.length; i++) {
          expect(plates[i], lessThan(plates[i - 1]),
              reason: 'plates must descend so the greedy loader works');
        }
      }
    });
  });
}
