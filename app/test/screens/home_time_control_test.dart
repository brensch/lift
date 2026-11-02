import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/screens/home/home_screen.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

/// The time control shows what the workout can use: at or past its
/// longest, + is off and the estimate says so; under it, + moves the
/// budget.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int budget,
    required TemplatePlan plan,
    ValueChanged<int>? onStep,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SelectedTemplateCard(
            template: WorkoutTemplate(name: 'StrongLifts B', coupled: true),
            plan: plan,
            budgetMinutes: budget,
            onBudgetStep: onStep ?? (_) {},
            unit: WeightUnit.WEIGHT_UNIT_KG,
            recommended: false,
            reason: '',
            isStarting: false,
            onStart: () {},
            onEdit: () {},
            onClone: () {},
            onDelete: () {},
            onToggleRotation: () {},
          ),
        ),
      ),
    ),
  );

  final plus = find.widgetWithIcon(IconButton, AppIcons.addCircle);

  /// Pumps the card and taps +; how far the budget was stepped.
  Future<int> pumpCard(
    WidgetTester tester, {
    required int budget,
    required TemplatePlan plan,
  }) async {
    var stepped = 0;
    await pump(tester, budget: budget, plan: plan, onStep: (n) => stepped += n);
    await tester.tap(plus);
    await tester.pump();
    return stepped;
  }

  bool plusEnabled(WidgetTester tester) =>
      tester.widget<IconButton>(plus).onPressed != null;

  testWidgets('a lift never done: no time control, the calibration line', (
    tester,
  ) async {
    await pump(
      tester,
      budget: 60,
      plan: TemplatePlan(
        plans: [
          ExercisePlan(
            decision: ExerciseDecision(
              exercise: Exercise.EXERCISE_DEADLIFT,
              calibration: true,
              weight: 135,
            ),
          ),
        ],
        estimatedSeconds: 1800,
        maxSeconds: 2400,
      ),
    );
    expect(find.text(copy.plan.calibration), findsOneWidget);
    expect(plus, findsNothing);
    expect(find.textContaining(copy.plan.longest), findsNothing);
  });

  testWidgets('at the cap + is off and the estimate says so', (tester) async {
    final plan = TemplatePlan(estimatedSeconds: 62 * 60, maxSeconds: 62 * 60);
    final stepped = await pumpCard(tester, budget: 75, plan: plan);
    expect(plusEnabled(tester), isFalse);
    expect(stepped, 0);
    expect(
      find.text(copy.plan.longest.replaceAll('{min}', '62')),
      findsOneWidget,
    );
  });

  testWidgets('under the cap + moves the budget', (tester) async {
    final plan = TemplatePlan(estimatedSeconds: 44 * 60, maxSeconds: 62 * 60);
    final stepped = await pumpCard(tester, budget: 45, plan: plan);
    expect(plusEnabled(tester), isTrue);
    expect(stepped, 1);
    expect(
      find.text(copy.plan.estimate.replaceAll('{min}', '44')),
      findsOneWidget,
    );
  });

  test('StrongLifts B in a roomy budget plans its longest', () async {
    final h = await ProviderHarness.boot(sandbox: true);
    addTearDown(h.dispose);
    await h.service.completeOnboarding(
      unit: WeightUnit.WEIGHT_UNIT_KG,
      libraryIds: ['stronglifts_a', 'stronglifts_b'],
    );
    await h.provider.loadActiveWorkout('test');
    final b = h.provider.home!.templates.firstWhere(
      (t) => t.libraryId == 'stronglifts_b',
    );
    while (h.provider.budgetMinutes * 60 <
        h.provider.templatePlanFor(b.id)!.maxSeconds) {
      await h.provider.stepBudget(1);
    }
    final plan = h.provider.templatePlanFor(b.id)!;
    expect(plan.estimatedSeconds, plan.maxSeconds);
    expect(
      plan.plans.map((p) => p.decision.sets).toSet(),
      {5},
      reason: 'every lift at its most sets',
    );
  });
}
