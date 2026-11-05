import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart' show WeightUnit;
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/plan_text.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:schlift/screens/home/template_editor.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

/// The editor on [template] behind an OPEN button.
Widget _opener(
  ProviderHarness h,
  WorkoutTemplate template, {
  bool personalise = false,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<WorkoutProvider>.value(value: h.provider),
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
              personalise: personalise,
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  ),
);

/// Let the core answer, then draw.
Future<void> _settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}

/// Dragging an exercise in the editor moves it, and SAVE keeps the order.
void main() {
  testWidgets('the rows read as Home, and Clone records nothing until Save', (
    tester,
  ) async {
    final h = (await tester.runAsync(() async {
      final h = await ProviderHarness.boot();
      await h.service.completeOnboarding(
        unit: WeightUnit.WEIGHT_UNIT_LB,
        libraryIds: ['stronglifts_a'],
      );
      await h.seedHistory({
        Exercise.EXERCISE_SQUAT: (185, 5),
        Exercise.EXERCISE_BENCH_PRESS: (135, 5),
        Exercise.EXERCISE_BARBELL_ROW: (115, 5),
      });
      await h.provider.loadActiveWorkout('test');
      // Half an hour: three lifts share it, one alone gets all of it.
      await h.provider.stepBudget(-6);
      return h;
    }))!;
    addTearDown(h.dispose);
    final template = h.provider.templates.single;
    expect(template.coupled, isTrue);
    await tester.pumpWidget(_opener(h, template, personalise: true));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // Each row is the lift's plan in the template, as Home's card has it.
    final home = h.provider.templatePlanFor(template.id)!;
    final squat = home.plans.first.decision;
    final line = planLine(squat, WeightUnit.WEIGHT_UNIT_LB);
    await _settle(
      tester,
      () => find.textContaining(line).evaluate().isNotEmpty,
    );
    expect(find.textContaining(line), findsOneWidget);
    // Not the squat on its own, which gets the whole half hour.
    final alone = planLine(
      h.provider.planFor(Exercise.EXERCISE_SQUAT)!.decision,
      WeightUnit.WEIGHT_UNIT_LB,
    );
    expect(alone, isNot(line));
    expect(find.textContaining(alone), findsNothing);

    // Backing out leaves it following the library.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(h.provider.templates.single.coupled, isTrue);

    // Save, unchanged, makes it the user's own.
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await _settle(tester, () => !h.provider.templates.single.coupled);
    expect(h.provider.templates.single.coupled, isFalse);
    expect(h.provider.templates.single.id, template.id);
  });

  testWidgets('the override sheet needs a weight, and reads a comma', (
    tester,
  ) async {
    final h = (await tester.runAsync(() async {
      final h = await ProviderHarness.boot();
      await h.seedHistory({Exercise.EXERCISE_SQUAT: (185, 5)});
      await h.provider.loadActiveWorkout('test');
      return h;
    }))!;
    addTearDown(h.dispose);
    final plan = h.provider.planFor(Exercise.EXERCISE_SQUAT)!;
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
                  onPressed: () => showOverrideSheet(
                    context,
                    plan: plan,
                    unit: WeightUnit.WEIGHT_UNIT_LB,
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

    FilledButton save() => tester.widget<FilledButton>(
      find.ancestor(of: find.text('SAVE'), matching: find.byType(FilledButton)),
    );
    final weight = find.byType(TextField);

    // Blank: nothing to plan from, so no save (it would record 0 lb).
    await tester.enterText(weight, '');
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(weight, '0');
    await tester.pump();
    expect(save().onPressed, isNull);

    // A decimal-comma keypad's "95,0" is 95 (a weight the plates make
    // exactly), not nothing.
    await tester.enterText(weight, '95,0');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text('SAVE'));
    await _settle(
      tester,
      () => h.provider.planFor(Exercise.EXERCISE_SQUAT)!.overridden,
    );
    final after = h.provider.planFor(Exercise.EXERCISE_SQUAT)!;
    expect(after.overridden, isTrue);
    expect(after.decision.weight, closeTo(95, 0.01));
  });

  testWidgets('a drag down one place sticks', (tester) async {
    final h = (await tester.runAsync(() => ProviderHarness.boot()))!;
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
