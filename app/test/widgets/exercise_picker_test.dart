/// The exercise picker is a staged selection: closing it with picks that
/// weren't saved asks first, however it's closed, a drag down included.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/workout.pbenum.dart';
import 'package:schlift/logic/exercises.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/exercise_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The exercise drawings animate for ever, so there is no settling: pump
  // past the sheet's and the dialog's transitions instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<List<Set<Exercise>>> open(WidgetTester tester) async {
    final saved = <Set<Exercise>>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showExercisePicker(
                context: context,
                initialSelected: const {},
                onSave: saved.add,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text(copy.exercisePicker.title), findsOneWidget);
    return saved;
  }

  /// Drag the list down, far enough to take the sheet to its smallest size.
  Future<void> dragDown(WidgetTester tester) async {
    await tester.drag(
      find.text(exerciseCatalog[1].name),
      const Offset(0, 500),
      warnIfMissed: false,
    );
    await settle(tester);
  }

  testWidgets('dragging it down with a pick unsaved asks first', (
    tester,
  ) async {
    final saved = await open(tester);
    await tester.tap(find.text(exerciseCatalog.first.name));
    await tester.pump();

    await dragDown(tester);
    expect(find.text(copy.exercisePicker.discardTitle), findsOneWidget);

    // Keep editing: the sheet and the pick are still there.
    await tester.tap(find.text(copy.exercisePicker.discardCancel));
    await settle(tester);
    expect(find.text(copy.exercisePicker.discardTitle), findsNothing);
    expect(find.text(copy.exercisePicker.title), findsOneWidget);

    await tester.tap(find.text(copy.exercisePicker.save));
    await settle(tester);
    expect(saved, [
      {exerciseCatalog.first.exercise},
    ]);
    expect(find.text(copy.exercisePicker.title), findsNothing);
  });

  testWidgets('discarding from the prompt closes it without saving', (
    tester,
  ) async {
    final saved = await open(tester);
    await tester.tap(find.text(exerciseCatalog.first.name));
    await tester.pump();

    await dragDown(tester);
    await tester.tap(find.text(copy.exercisePicker.discardConfirm));
    await settle(tester);
    expect(find.text(copy.exercisePicker.title), findsNothing);
    expect(saved, isEmpty);
  });

  testWidgets('dragging it down with nothing changed just closes it', (
    tester,
  ) async {
    await open(tester);
    await dragDown(tester);
    expect(find.text(copy.exercisePicker.discardTitle), findsNothing);
    expect(find.text(copy.exercisePicker.title), findsNothing);
  });
}
