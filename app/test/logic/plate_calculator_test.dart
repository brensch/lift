import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/logic/plate_calculator.dart';
import 'package:schlift/logic/weight_units.dart';

const lb = WeightUnit.WEIGHT_UNIT_LB;
const kg = WeightUnit.WEIGHT_UNIT_KG;

/// What the loaded bar actually weighs given the plates picked for one side.
double loadedWeight(List<double> plates, WeightUnit unit) =>
    standardBarWeight(unit) + plates.fold(0.0, (a, b) => a + b) * 2;

void main() {
  group('imperial', () {
    test('an empty or sub-bar weight needs no plates', () {
      for (final w in [0.0, 20.0, 44.9, 45.0]) {
        expect(calcPlatesPerSide(w, lb), isEmpty, reason: 'weight=$w');
      }
    });

    test('135 lb is a 45 per side', () {
      expect(calcPlatesPerSide(135, lb), [45.0]);
    });

    test('225 lb is two 45s per side', () {
      expect(calcPlatesPerSide(225, lb), [45.0, 45.0]);
    });

    test('picks the heaviest plates first', () {
      expect(calcPlatesPerSide(185, lb), [45.0, 25.0]);
    });
  });

  group('metric', () {
    test('60 kg is a 20 per side on a 20 kg bar', () {
      expect(calcPlatesPerSide(60, kg), [20.0]);
    });

    test('uses the metric bar, not the imperial one', () {
      expect(calcPlatesPerSide(20, kg), isEmpty);
      expect(calcPlatesPerSide(22.5, kg), [1.25]);
    });

    // Weights are stored in pounds (as float32): back in kg they come out a
    // hair under, and must still load the same plates.
    test('a kg weight stored in pounds loads the same plates', () {
      double roundTrip(double kgWeight) => displayWeightFromPounds(
        Float32List.fromList([poundsFromDisplayWeight(kgWeight, kg)])[0],
        kg,
      );
      expect(calcPlatesPerSide(roundTrip(22.5), kg), [1.25]);
      expect(calcPlatesPerSide(roundTrip(70), kg), [25.0]);
      expect(calcPlatesPerSide(roundTrip(102.5), kg), [25.0, 15.0, 1.25]);
      expect(calcPlatesPerSide(roundTrip(60), kg), [20.0]);
    });
  });

  group('invariants across a sweep', () {
    test('never loads more than requested', () {
      for (final unit in [lb, kg]) {
        final bar = standardBarWeight(unit);
        for (var w = bar; w <= bar + 400; w += 2.5) {
          expect(
            loadedWeight(calcPlatesPerSide(w, unit), unit),
            lessThanOrEqualTo(w + 1e-6),
            reason: 'unit=$unit weight=$w',
          );
        }
      }
    });

    test('what is left over per side is smaller than the smallest plate', () {
      for (final unit in [lb, kg]) {
        final smallest = standardPlates(unit).last;
        final bar = standardBarWeight(unit);
        for (var w = bar; w <= bar + 400; w += 1) {
          final leftover = w - loadedWeight(calcPlatesPerSide(w, unit), unit);
          expect(
            leftover / 2,
            lessThan(smallest),
            reason: 'a full plate was left unloaded at $w ($unit)',
          );
        }
      }
    });

    test('plates come back in descending order', () {
      for (var w = 45.0; w <= 500; w += 5) {
        final plates = calcPlatesPerSide(w, lb);
        for (var i = 1; i < plates.length; i++) {
          expect(
            plates[i],
            lessThanOrEqualTo(plates[i - 1]),
            reason: 'weight=$w',
          );
        }
      }
    });
  });
}
