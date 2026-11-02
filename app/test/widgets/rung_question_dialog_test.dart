/// The ramp's "how many more could you have done?": shown by the app shell
/// when a ramp set is done in full (the provider's onRungQuestion), its
/// buttons answer, and it goes when the question does.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart' show WeightUnit;
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/weight_units.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/dialogs/rung_question_dialog.dart';

import '../support/provider_harness.dart';

void main() {
  late ProviderHarness h;
  final navigator = GlobalKey<NavigatorState>();

  /// A deadlift never done, its first ramp set done with every rep, and
  /// the dialog shown as the app shell shows it.
  Future<ProposedSet> boot(WidgetTester tester) async {
    final asked = <String>[];
    final first = (await tester.runAsync(() async {
      h = await ProviderHarness.boot(sandbox: true);
      h.provider.onRungQuestion = asked.add;
      await h.start([Exercise.EXERCISE_DEADLIFT]);
      final first = h.provider.doneTargetSet!;
      await h.provider.completeSet(
        first.id,
        first.targetReps,
        first.targetWeight,
      );
      return first;
    }))!;
    expect(asked, [first.id]);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: h.settings,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.theme,
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
    showRungQuestionDialog(navigator.currentContext!, h.provider, first.id);
    await tester.pumpAndSettle();
    return first;
  }

  /// Let the core answer, then let the dialog go.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() => h.dispose());

  testWidgets('a tap answers and closes it', (tester) async {
    final first = await boot(tester);
    expect(find.text(copy.workout.rungQuestion), findsOneWidget);
    for (final text in [
      copy.workout.rungAnswerZeroToOne,
      copy.workout.rungAnswerTwoToFour,
      copy.workout.rungAnswerFivePlus,
    ]) {
      expect(find.text(text), findsOneWidget);
    }

    await tester.tap(find.text(copy.workout.rungAnswerFivePlus));
    await settle(tester);
    expect(find.byType(RungQuestionDialog), findsNothing);
    expect(h.provider.rungQuestionSetId, isEmpty);
    expect(
      h.provider.activeCompletedSets
          .firstWhere((c) => c.proposedSetId == first.id)
          .repsLeft,
      RepsLeft.REPS_LEFT_FIVE_PLUS,
    );
  });

  testWidgets('under the answers: a line with "or", a jump and its button', (
    tester,
  ) async {
    await boot(tester);
    expect(find.text(copy.workout.rungOr), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RungQuestionDialog),
        matching: find.byType(Divider),
      ),
      findsOneWidget,
    );
    expect(find.text(copy.workout.rungJumpLabel), findsOneWidget);
    expect(find.byKey(RungQuestionDialog.jumpFieldKey), findsOneWidget);
    expect(find.text('lb'), findsOneWidget, reason: "the user's unit");
    expect(find.text(copy.workout.rungJumpApply), findsOneWidget);
  });

  testWidgets('the button is off at nothing, zero or too much', (tester) async {
    await boot(tester);
    bool enabled() => tester
        .widget<OutlinedButton>(find.byKey(RungQuestionDialog.jumpApplyKey))
        .enabled;
    expect(enabled(), isFalse, reason: 'empty');
    final field = find.byKey(RungQuestionDialog.jumpFieldKey);
    await tester.enterText(field, '0');
    await tester.pump();
    expect(enabled(), isFalse, reason: 'zero');
    await tester.enterText(field, '5000');
    await tester.pump();
    expect(enabled(), isFalse, reason: 'over twice the set');
    await tester.enterText(field, '20');
    await tester.pump();
    expect(enabled(), isTrue);
  });

  testWidgets('a jump applied goes in pounds and the ramp climbs by it', (
    tester,
  ) async {
    final first = await boot(tester);
    await tester.enterText(find.byKey(RungQuestionDialog.jumpFieldKey), '50');
    await tester.pump();
    await tester.tap(find.byKey(RungQuestionDialog.jumpApplyKey));
    await settle(tester);
    expect(find.byType(RungQuestionDialog), findsNothing);
    expect(h.provider.rungQuestionSetId, isEmpty);
    final done = h.provider.activeCompletedSets.firstWhere(
      (c) => c.proposedSetId == first.id,
    );
    expect(done.jumpLb, 50);
    expect(done.repsLeft, RepsLeft.REPS_LEFT_UNSPECIFIED);
    final next = h.provider.doneTargetSet!;
    expect(next.calibration, isTrue, reason: 'the ramp goes on');
    expect(next.targetWeight, first.targetWeight + 50);
  });

  testWidgets('in kilograms the field says kg and sends pounds', (
    tester,
  ) async {
    final first = await boot(tester);
    await tester.runAsync(
      () => h.settings.updateWeightUnit(WeightUnit.WEIGHT_UNIT_KG),
    );
    await tester.pump();
    expect(find.text('kg'), findsOneWidget);
    await tester.enterText(find.byKey(RungQuestionDialog.jumpFieldKey), '10');
    await tester.pump();
    await tester.tap(find.byKey(RungQuestionDialog.jumpApplyKey));
    await settle(tester);
    final done = h.provider.activeCompletedSets.firstWhere(
      (c) => c.proposedSetId == first.id,
    );
    expect(done.jumpLb, closeTo(kilogramsToPounds(10), 0.01));
  });

  testWidgets('dismissed, it stays unanswered', (tester) async {
    final first = await boot(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(RungQuestionDialog), findsNothing);
    expect(h.provider.rungQuestionSetId, first.id);
  });

  testWidgets('answered elsewhere (the watch), it goes on its own', (
    tester,
  ) async {
    final first = await boot(tester);
    await tester.runAsync(
      () => h.provider.answerRung(first.id, RepsLeft.REPS_LEFT_TWO_TO_FOUR),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RungQuestionDialog), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget, reason: 'and nothing else');
  });
}
