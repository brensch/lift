import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart' show MuscleGroup;
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/rotation_text.dart';

SuggestionMuscle behind(MuscleGroup muscle, double sets) =>
    SuggestionMuscle(muscle: muscle, sets7d: sets, target: 10);

RecoveringMuscle recovering(MuscleGroup muscle, int hours) =>
    RecoveringMuscle(muscle: muscle, hoursRemaining: hours);

void main() {
  final r = copy.rotation;

  group('suggestionLine', () {
    test('two rested muscles, then what is recovering', () {
      final line = suggestionLine(
        SuggestionReason(
          behind: [
            behind(MuscleGroup.MUSCLE_GROUP_CHEST, 2),
            behind(MuscleGroup.MUSCLE_GROUP_BACK, 0),
            behind(MuscleGroup.MUSCLE_GROUP_BICEPS, 1.5),
          ],
          recovering: [recovering(MuscleGroup.MUSCLE_GROUP_QUADS, 20)],
        ),
      );
      final muscles = 'chest 2/10 ${r.and} back 0/10';
      final rested = r.restedTwo.replaceAll('{muscles}', muscles);
      final out = r.recovering
          .replaceAll('{muscle}', 'quads')
          .replaceAll('{hours}', '20');
      final expected = '$rested · $out';
      expect(line, expected[0].toUpperCase() + expected.substring(1));
    });

    test('one muscle, half sets shown to one place', () {
      final line = suggestionLine(
        SuggestionReason(behind: [behind(MuscleGroup.MUSCLE_GROUP_CORE, 4.5)]),
      );
      expect(line, contains('4.5/10'));
      expect(line, startsWith('C'));
    });

    test('every first lift recovering, and the fallback, say so', () {
      final waiting = suggestionLine(
        SuggestionReason(
          firstLiftRecovering: recovering(MuscleGroup.MUSCLE_GROUP_CHEST, 5),
          behind: [behind(MuscleGroup.MUSCLE_GROUP_BACK, 8)],
        ),
      );
      expect(
        waiting,
        r.firstLift.replaceAll('{muscle}', 'Chest').replaceAll('{hours}', '5'),
      );
      final fallback = suggestionLine(
        SuggestionReason(
          fallback: true,
          recovering: [recovering(MuscleGroup.MUSCLE_GROUP_BACK, 3)],
        ),
      );
      expect(fallback, startsWith(r.fallback));
      expect(fallback, contains('3'));
    });

    test('no reason, no line', () {
      expect(suggestionLine(SuggestionReason()), isEmpty);
    });
  });

  group('rotationWarningLines', () {
    test('one line per warning, the gap left unsaid', () {
      final check = RotationCheck(
        warnings: [
          RotationWarning(
            kind: RotationWarningKind.ROTATION_WARNING_KIND_GAP,
            muscles: [MuscleGroup.MUSCLE_GROUP_CALVES],
          ),
          RotationWarning(
            kind: RotationWarningKind.ROTATION_WARNING_KIND_OVERLAP,
            templateIds: ['a', 'b'],
            shared: 3,
            of: 3,
          ),
        ],
      );
      expect(
        rotationWarningLines(check, {'a': 'Full Body', 'b': 'StrongLifts A'}),
        [
          r.overlap
              .replaceAll('{a}', 'Full Body')
              .replaceAll('{b}', 'StrongLifts A')
              .replaceAll('{shared}', '3')
              .replaceAll('{of}', '3'),
        ],
      );
      expect(rotationWarningLines(RotationCheck(), {}), isEmpty);
    });
  });

  group('additionLine', () {
    test('names the muscles; nothing added, no line', () {
      expect(
        additionLine([
          MuscleGroup.MUSCLE_GROUP_CALVES,
          MuscleGroup.MUSCLE_GROUP_CORE,
        ]),
        r.adds.replaceAll('{muscles}', 'calves ${r.and} core'),
      );
      expect(additionLine([]), isEmpty);
    });

    test('additionsOf splits templates from library entries', () {
      final got = additionsOf(
        RotationCheck(
          additions: [
            RotationAddition(
              templateId: 't',
              muscles: [MuscleGroup.MUSCLE_GROUP_CORE],
            ),
            RotationAddition(
              libraryId: 'lower',
              muscles: [MuscleGroup.MUSCLE_GROUP_CALVES],
            ),
          ],
        ),
      );
      expect(got.templates, {
        't': [MuscleGroup.MUSCLE_GROUP_CORE],
      });
      expect(got.library, {
        'lower': [MuscleGroup.MUSCLE_GROUP_CALVES],
      });
      expect(additionsOf(null).templates, isEmpty);
    });
  });
}
