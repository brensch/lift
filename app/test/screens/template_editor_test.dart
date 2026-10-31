import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/screens/home/template_editor.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

/// Dragging an exercise in the editor moves it, and SAVE keeps the order.
void main() {
  testWidgets('a drag down one place sticks', (tester) async {
    final h = (await tester.runAsync(
      () => ProviderHarness.boot(sandbox: true),
    ))!;
    addTearDown(h.dispose);
    final template = WorkoutTemplate(
      name: 'Mine',
      exercises: [
        Exercise.EXERCISE_SQUAT,
        Exercise.EXERCISE_BENCH_PRESS,
        Exercise.EXERCISE_BARBELL_ROW,
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: h.provider),
          ChangeNotifierProvider.value(value: h.settings),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showTemplateEditor(
                    context,
                    template: template,
                    provider: h.provider,
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // Squat's grip, dragged down past bench.
    final grip = find.byIcon(AppIcons.drag).first;
    final rowHeight =
        tester.getCenter(find.byIcon(AppIcons.drag).at(1)).dy -
        tester.getCenter(grip).dy;
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(0, rowHeight * 1.2 / 6));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Bench Press')).dy,
      lessThan(tester.getTopLeft(find.text('Squat')).dy),
      reason: 'bench is above squat on screen',
    );

    await tester.tap(find.text('SAVE'));
    for (var i = 0; i < 20 && h.provider.templates.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(h.provider.templates.single.exercises, [
      Exercise.EXERCISE_BENCH_PRESS,
      Exercise.EXERCISE_SQUAT,
      Exercise.EXERCISE_BARBELL_ROW,
    ]);
  });
}
