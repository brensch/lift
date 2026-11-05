/// Ending on the phone goes the watch's way: the end is recorded, then the
/// app shell's onWorkoutEnded opens the summary and any template offer.
/// Accepting an offer for an existing template changes only its lifts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/dialogs/end_workout_dialog.dart';
import 'package:schlift/widgets/dialogs/template_update_dialog.dart';

import '../support/provider_harness.dart';

void main() {
  late ProviderHarness h;
  final navigator = GlobalKey<NavigatorState>();

  const squat = Exercise.EXERCISE_SQUAT;
  const raise = Exercise.EXERCISE_LATERAL_RAISE;

  Future<void> boot(WidgetTester tester) async {
    await tester.runAsync(() async {
      h = await ProviderHarness.boot();
      await h.seedHistory({squat: (185, 5), raise: (20, 10)});
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: h.settings),
          ChangeNotifierProvider<WorkoutProvider>.value(value: h.provider),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.theme,
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
  }

  /// Pumps until [done]: the core answers on another thread, and the
  /// dialogs spin while it does, so pumpAndSettle would never settle.
  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  tearDown(() => h.dispose());

  testWidgets('End on the phone opens the summary once the end is recorded', (
    tester,
  ) async {
    await boot(tester);
    await tester.runAsync(() => h.start([raise]));
    final workoutId = h.provider.workout!.id;
    final opened = <(String, bool)>[];
    h.provider.onWorkoutEnded = (id) =>
        opened.add((id, h.provider.isWorkoutEnded));

    var ended = false;
    endWorkout(navigator.currentContext!).then((_) => ended = true);
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.endWorkoutDialog.confirm));
    await until(tester, () => ended);

    expect(opened, [(workoutId, true)]);
  });

  testWidgets('updating a template in rotation keeps it in rotation', (
    tester,
  ) async {
    await boot(tester);
    late WorkoutTemplate template;
    await tester.runAsync(() async {
      await h.provider.saveTemplate(
        WorkoutTemplate(name: 'Legs', exercises: [squat], inRotation: true),
      );
      template = h.provider.templates.singleWhere((t) => t.name == 'Legs');
    });
    expect(template.inRotation, isTrue);

    final offer = TemplateOffer(
      templateId: template.id,
      templateName: template.name,
      exercises: [squat, raise],
    );
    showTemplateUpdateDialog(
      navigator.currentContext!,
      offer: offer,
      provider: h.provider,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.templateUpdate.updateConfirm));
    await until(tester, () => find.byType(AlertDialog).evaluate().isEmpty);

    final saved = h.provider.templates.singleWhere((t) => t.id == template.id);
    expect(saved.exercises, [squat, raise]);
    expect(saved.name, 'Legs');
    expect(saved.inRotation, isTrue);
  });
}
