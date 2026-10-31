import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/workout_status_box.dart';

import '../support/provider_harness.dart';

/// The band never overflows: the stage and the clock shrink to fit, with
/// UP NEXT and a long label, on a small phone and a big one.
void main() {
  late ProviderHarness h;

  setUp(() async {
    h = await ProviderHarness.boot(sandbox: true);
  });

  tearDown(() => h.dispose());

  for (final width in [320.0, 360.0, 430.0]) {
    for (final compact in [false, true]) {
      testWidgets('fits ${width}dp wide${compact ? ', compact' : ''}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 900 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: h.settings,
            child: MaterialApp(
              theme: AppTheme.theme,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: StatusBox(
                      emoji: '🎃',
                      profileColor: Colors.green,
                      stateLabel: 'Choosing workout',
                      stateColor: Colors.blue,
                      timerText: '10:25',
                      upNext: true,
                      compact: compact,
                      set: ProposedSet(
                        exercise: Exercise.EXERCISE_DUMBBELL_SHOULDER_PRESS,
                        targetReps: 12,
                        targetWeight: 315,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
