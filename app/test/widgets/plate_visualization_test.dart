/// The inline bar draws heavier plates thicker, in either unit.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart' show WeightUnit;
import 'package:schlift/logic/weight_units.dart';
import 'package:schlift/widgets/plate_visualization.dart';

void main() {
  for (final unit in WeightUnit.values.where(
    (u) => u != WeightUnit.WEIGHT_UNIT_UNSPECIFIED,
  )) {
    test('heavier plates are never thinner, ${unit.name}', () {
      final plates = standardPlates(unit); // heaviest first
      for (var i = 1; i < plates.length; i++) {
        expect(
          inlinePlateWidth(plates[i - 1], unit),
          greaterThanOrEqualTo(inlinePlateWidth(plates[i], unit)),
          reason: '${plates[i - 1]} against ${plates[i]}',
        );
      }
    });
  }

  test('a 20 kg plate is drawn wider than a 10 kg one', () {
    const kg = WeightUnit.WEIGHT_UNIT_KG;
    expect(inlinePlateWidth(20, kg), greaterThan(inlinePlateWidth(10, kg)));
    expect(inlinePlateWidth(15, kg), greaterThan(inlinePlateWidth(10, kg)));
  });

  test('pound plates keep their widths', () {
    const lb = WeightUnit.WEIGHT_UNIT_LB;
    expect(
      <double>[45, 35, 25, 10, 5, 2.5].map((p) => inlinePlateWidth(p, lb)),
      [10, 9, 8, 6, 4, 2],
    );
  });
}
