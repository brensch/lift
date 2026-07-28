import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/logic/weight_units.dart';

// Mirrors src/weight_units.rs `plate_math_tests`. The generic plate helpers must
// behave identically in both units — a new unit is just another bar+plate list.

const lb = WeightUnit.WEIGHT_UNIT_LB;
const kg = WeightUnit.WEIGHT_UNIT_KG;
const units = [lb, kg];

List<double> loadableSweep(WeightUnit unit) {
  final bar = standardBarWeight(unit);
  final step = loadableStep(standardPlates(unit));
  final out = <double>[];
  for (var w = bar; w <= bar + 300; w += step) {
    out.add(w);
  }
  return out;
}

void main() {
  test('loadable step is two of the smallest plate', () {
    expect(loadableStep(standardPlates(lb)), 5);
    expect(loadableStep(standardPlates(kg)), 2.5);
  });

  test('snap lands on exactly loadable weights in both units', () {
    for (final unit in units) {
      final bar = standardBarWeight(unit);
      final plates = standardPlates(unit);
      final step = loadableStep(plates);
      for (var t = bar; t <= bar + 250; t += step) {
        for (final off in [0.0, step * 0.1, step * 0.49, step * 0.5, step * 0.9]) {
          final snapped = snapLoadable(t + off, bar, plates);
          expect(plateCountPerSide(snapped, bar, plates).isFinite, isTrue,
              reason: 'unit=$unit target=${t + off} snapped=$snapped not loadable');
        }
      }
    }
  });

  test('plates reconstruct the weight minus remainder', () {
    for (final unit in units) {
      final bar = standardBarWeight(unit);
      final plates = standardPlates(unit);
      for (final w in loadableSweep(unit)) {
        final r = platesForSide(w, bar, plates);
        final loaded = bar + r.plates.fold(0.0, (a, b) => a + b) * 2;
        expect(loaded + r.remainder * 2, closeTo(w, 1e-3), reason: 'unit=$unit w=$w');
        expect(r.remainder, lessThan(1e-3), reason: 'loadable $w left a remainder ($unit)');
      }
    }
  });

  test('snapLoadableLb round-trips to a clean display value and is idempotent', () {
    for (final unit in units) {
      for (final lbWeight in [37.0, 100.0, 133.0, 183.5, 218.0, 271.0, 315.0]) {
        final once = snapLoadableLb(lbWeight, unit);
        final display = displayWeightFromPounds(once, unit);
        expect(plateCountPerSide(display, standardBarWeight(unit), standardPlates(unit)).isFinite,
            isTrue,
            reason: 'unit=$unit lb=$lbWeight -> $once displays un-loadable $display');
        final twice = snapLoadableLb(once, unit);
        expect(twice, closeTo(once, 1e-2), reason: 'unit=$unit not idempotent');
      }
    }
  });

  test('simplest prefers fewer plates and stays near target', () {
    for (final unit in units) {
      final bar = standardBarWeight(unit);
      final plates = standardPlates(unit);
      final step = loadableStep(plates);
      final min = plates.last;
      final max = bar + 400;
      for (var target = bar; target <= bar + 250; target += step) {
        final naive = snapLoadable(target, bar, plates).clamp(min, max).toDouble();
        final simple = simplestLoadableNear(target, bar, plates, min, max);
        expect(plateCountPerSide(simple, bar, plates),
            lessThanOrEqualTo(plateCountPerSide(naive, bar, plates)),
            reason: 'unit=$unit target=$target: simple uses more plates');
        expect((simple - naive).abs(), lessThanOrEqualTo(step + 1e-4),
            reason: 'unit=$unit target=$target: simple $simple too far from $naive');
        expect(plateCountPerSide(simple, bar, plates).isFinite, isTrue);
      }
    }
  });

  test('opts for one big plate over many small, in each unit', () {
    // lb: 133 -> 135 (one 45/side) rather than 130 (25+10+5+2.5).
    final simpleLb = simplestLoadableNear(133, standardBarWeight(lb), standardPlates(lb), 5, 500);
    expect(simpleLb, 135);
    expect(plateCountPerSide(135, standardBarWeight(lb), standardPlates(lb)), 1);

    // kg: 24 -> 25 kg (one 2.5/side) rather than 22.5 (one 1.25) — both 1 plate,
    // closest wins; and 27.5 (two plates) is rejected.
    final simpleKg =
        simplestLoadableNear(24, standardBarWeight(kg), standardPlates(kg), 1.25, 300);
    expect(simpleKg, 25);
    expect(plateCountPerSide(25, standardBarWeight(kg), standardPlates(kg)), 1);
  });

  test('warmups end up as clean loadable numbers in the display unit', () {
    // Regression for the original bug: a kg user must not see junk decimals.
    // 135 lb working (61.2 kg) -> warmups display as whole kg on the plate grid.
    for (final lbWorking in [95.0, 135.0, 225.0, 315.0]) {
      final snapped = snapLoadableLb(lbWorking, kg);
      final kgValue = displayWeightFromPounds(snapped, kg);
      // Must be an exact multiple of the finest kg step (1.25).
      expect((kgValue / 1.25 - (kgValue / 1.25).round()).abs(), lessThan(1e-6),
          reason: 'kg value $kgValue is not on the 1.25 kg grid');
    }
  });
}
