import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/logic/plate_calculator.dart';
import 'package:schlift/logic/weight_units.dart';

const lb = WeightUnit.WEIGHT_UNIT_LB;
const kg = WeightUnit.WEIGHT_UNIT_KG;

/// What the loaded bar actually weighs given the plates picked for one side.
double loadedWeight(PlateResult result, WeightUnit unit) =>
    standardBarWeight(unit) + result.plates.fold(0.0, (a, b) => a + b) * 2;

void main() {
  group('imperial', () {
    test('an empty or sub-bar weight needs no plates', () {
      for (final w in [0.0, 20.0, 44.9, 45.0]) {
        final r = calcPlatesPerSide(w, lb);
        expect(r.plates, isEmpty, reason: 'weight=$w');
        expect(r.remainder, 0);
      }
    });

    test('135 lb is a 45 per side', () {
      final r = calcPlatesPerSide(135, lb);
      expect(r.plates, [45.0]);
      expect(r.remainder, 0);
    });

    test('225 lb is two 45s per side', () {
      expect(calcPlatesPerSide(225, lb).plates, [45.0, 45.0]);
    });

    test('picks the heaviest plates first', () {
      final r = calcPlatesPerSide(185, lb);
      expect(r.plates, [45.0, 25.0]);
      expect(r.remainder, 0);
    });

    test('reports what it cannot load as a remainder', () {
      // 1 lb per side is below the smallest 2.5 lb plate.
      final r = calcPlatesPerSide(47, lb);
      expect(r.plates, isEmpty);
      expect(r.remainder, closeTo(1, 1e-9));
    });
  });

  group('metric', () {
    test('60 kg is a 20 per side on a 20 kg bar', () {
      final r = calcPlatesPerSide(60, kg);
      expect(r.plates, [20.0]);
      expect(r.remainder, 0);
    });

    test('uses the metric bar, not the imperial one', () {
      expect(calcPlatesPerSide(20, kg).plates, isEmpty);
      expect(calcPlatesPerSide(22.5, kg).plates, [1.25]);
    });
  });

  group('invariants across a sweep', () {
    test('plates always reconstruct the requested weight, minus remainder', () {
      for (final unit in [lb, kg]) {
        final bar = standardBarWeight(unit);
        for (var w = bar; w <= bar + 400; w += 2.5) {
          final r = calcPlatesPerSide(w, unit);
          final loaded = loadedWeight(r, unit);
          expect(loaded + r.remainder * 2, closeTo(w, 1e-6),
              reason: 'unit=$unit weight=$w');
        }
      }
    });

    test('never loads more than requested', () {
      for (final unit in [lb, kg]) {
        final bar = standardBarWeight(unit);
        for (var w = bar; w <= bar + 400; w += 2.5) {
          expect(loadedWeight(calcPlatesPerSide(w, unit), unit),
              lessThanOrEqualTo(w + 1e-6),
              reason: 'unit=$unit weight=$w');
        }
      }
    });

    test('remainder is always smaller than the smallest plate', () {
      for (final unit in [lb, kg]) {
        final smallest = standardPlates(unit).last;
        final bar = standardBarWeight(unit);
        for (var w = bar; w <= bar + 400; w += 1) {
          final r = calcPlatesPerSide(w, unit);
          expect(r.remainder, lessThan(smallest),
              reason: 'a full plate was left unloaded at $w ($unit)');
          expect(r.remainder, greaterThanOrEqualTo(0));
        }
      }
    });

    test('plates come back in descending order', () {
      for (var w = 45.0; w <= 500; w += 5) {
        final plates = calcPlatesPerSide(w, lb).plates;
        for (var i = 1; i < plates.length; i++) {
          expect(plates[i], lessThanOrEqualTo(plates[i - 1]),
              reason: 'weight=$w');
        }
      }
    });
  });
}
