/// Picking a weight: the steps, the bar's floor and the top, the unit, and
/// a typed weight settled onto the step's grid at once, though shown as
/// typed until the field is left.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart' show WeightUnit;
import 'package:schlift/logic/weight_units.dart';
import 'package:schlift/providers/settings_provider.dart';
import 'package:schlift/services/local_core.dart';
import 'package:schlift/services/workout_service.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/common/weight_selector.dart';

class _NoAccount implements CoreSource {
  @override
  Future<LocalCore> get ready => Completer<LocalCore>().future;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  /// The selector as a sheet holds it: the weight it gives out comes back
  /// in. Returns every weight it gave out, in pounds.
  Future<List<double>> pump(
    WidgetTester tester, {
    required double weightLb,
    required double stepLb,
    bool barbell = true,
    WeightUnit unit = WeightUnit.WEIGHT_UNIT_LB,
  }) async {
    tester.view.physicalSize = const Size(412 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final settings = SettingsProvider(WorkoutServiceWrapper(_NoAccount()))
      ..applyWeightUnitLocally(unit);
    final given = <double>[];
    var weight = weightLb;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => WeightSelector(
                weightLb: weight,
                stepLb: stepLb,
                barbell: barbell,
                onChanged: (lb) {
                  given.add(lb);
                  setState(() => weight = lb);
                },
              ),
            ),
          ),
        ),
      ),
    );
    return given;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('steps the lift\'s step and a big plate pair, in pounds', (
    tester,
  ) async {
    final given = await pump(tester, weightLb: 135, stepLb: 5);
    await tap(tester, '+5');
    await tap(tester, '+45');
    await tap(tester, '−5');
    expect(given, [140, 185, 180]);
  });

  testWidgets('a barbell never goes under the bar, nor anything over the '
      'top', (tester) async {
    final given = await pump(tester, weightLb: 50, stepLb: 5);
    await tap(tester, '−45');
    expect(given.last, 45);

    final heavy = await pump(tester, weightLb: 640, stepLb: 5);
    await tap(tester, '+45');
    expect(heavy.last, 650);
  });

  testWidgets('a lift off the bar goes down to nothing', (tester) async {
    final given = await pump(tester, weightLb: 10, stepLb: 5, barbell: false);
    await tap(tester, '−25');
    expect(given.last, 0);
  });

  testWidgets('in kilograms it steps kilograms and gives out pounds', (
    tester,
  ) async {
    const kg = WeightUnit.WEIGHT_UNIT_KG;
    final given = await pump(
      tester,
      weightLb: kilogramsToPounds(60),
      stepLb: kilogramsToPounds(2.5),
      unit: kg,
    );
    await tap(tester, '+2.5');
    await tap(tester, '+20');
    expect(given.map((lb) => displayWeightFromPounds(lb, kg)), [
      closeTo(62.5, 1e-6),
      closeTo(82.5, 1e-6),
    ]);
  });

  testWidgets('a typed weight settles onto the grid and into range when '
      'the field is left', (tester) async {
    final given = await pump(tester, weightLb: 135, stepLb: 5);
    final field = find.byType(TextField);

    await tester.enterText(field, '137');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(given.last, 135);

    await tester.enterText(field, '4000');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(given.last, 650);
    expect(find.text('650'), findsOneWidget);
  });

  testWidgets('a typed weight is given out settled while the field still '
      'has focus, as typed on screen', (tester) async {
    // A save tapped with the keyboard up never takes the field's focus.
    final given = await pump(tester, weightLb: 135, stepLb: 5);
    final field = find.byType(TextField);

    await tester.enterText(field, '4000');
    await tester.pump();
    expect(given.last, 650);
    expect(find.text('4000'), findsOneWidget);

    await tester.enterText(field, '1');
    await tester.pump();
    expect(given.last, 45);

    await tester.enterText(field, '137');
    await tester.pump();
    expect(given.last, 135);
    expect(find.text('137'), findsOneWidget);
  });

  testWidgets('the slider stays on the step\'s grid', (tester) async {
    await pump(tester, weightLb: 135, stepLb: 5);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 45);
    expect(slider.max, 650);
    expect(slider.divisions, (650 - 45) ~/ 5);
  });
}
