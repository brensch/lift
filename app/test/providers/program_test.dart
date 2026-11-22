/// The program through the phone's own core: the catalog follows it, and
/// reset goes back to the built-in rules with the workouts kept.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pbenum.dart';
import 'package:schlift/logic/exercises.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Home fills the catalog from the program, named and grouped', () async {
    final h = await ProviderHarness.boot();
    addTearDown(h.dispose);
    await h.service.completeOnboarding(
      unit: WeightUnit.WEIGHT_UNIT_LB,
      libraryIds: ['stronglifts_a'],
    );
    await h.provider.refreshHome();
    final squat = exerciseCatalog.firstWhere((e) => e.key == 'squat');
    expect(squat.name, 'Squat');
    expect(squat.bodyParts, contains(BodyPart.legs));
    expect(exerciseName('bench_press'), 'Bench Press');
    // A key nothing names still reads.
    expect(exerciseName('zercher_squat'), 'Zercher Squat');
  });

  test(
    'the onboarded program is the built-in one, and stays after reset',
    () async {
      final h = await ProviderHarness.boot();
      addTearDown(h.dispose);
      await h.service.completeOnboarding(
        unit: WeightUnit.WEIGHT_UNIT_LB,
        libraryIds: ['stronglifts_a'],
      );
      final before = await h.provider.getProgram();
      expect(before.guide, isNotEmpty);
      expect(before.programJson, contains('schlift.program/v1'));
      expect(before.summary.builtinRules, isTrue);
      await h.provider.refreshHome();
    final workouts = h.provider.templates.length;
    expect(workouts, 1);
      await h.provider.resetProgram();
      final after = await h.provider.getProgram();
      expect(after.summary.builtinRules, isTrue);
      expect(after.summary.author, 'app');
      expect(h.provider.templates.length, workouts);
    },
  );
}
