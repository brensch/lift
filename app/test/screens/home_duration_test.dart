import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/screens/home/home_screen.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/theme/app_theme.dart';

/// The card says how long the workout takes, or that a lift never done
/// ramps; there's no time to pick.
void main() {
  Future<void> pump(WidgetTester tester, {required TemplatePlan plan}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SelectedTemplateCard(
                template: WorkoutTemplate(
                  name: 'StrongLifts B',
                  originLibraryId: 'stronglifts_b',
                ),
                plan: plan,
                unit: WeightUnit.WEIGHT_UNIT_KG,
                recommended: false,
                reason: '',
                isStarting: false,
                onStart: () {},
                onEdit: () {},
                onDelete: () {},
                onToggleRotation: () {},
              ),
            ),
          ),
        ),
      );

  testWidgets('a lift never done: no time control, the calibration line', (
    tester,
  ) async {
    await pump(
      tester,
      plan: TemplatePlan(
        plans: [
          ExercisePlan(
            decision: ExerciseDecision(
              exercise: 'deadlift',
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
    expect(find.byIcon(AppIcons.addCircle), findsNothing);
  });

  testWidgets('the estimate, and no time control', (tester) async {
    await pump(
      tester,
      plan: TemplatePlan(estimatedSeconds: 44 * 60, maxSeconds: 44 * 60),
    );
    expect(
      find.text(copy.plan.estimate.replaceAll('{min}', '44')),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.addCircle), findsNothing);
  });
}
