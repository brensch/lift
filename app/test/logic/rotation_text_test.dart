import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
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

    test('overdue and fallback say so', () {
      final overdue = suggestionLine(
        SuggestionReason(
          overdue: true,
          behind: [behind(MuscleGroup.MUSCLE_GROUP_CHEST, 8)],
        ),
      );
      expect(overdue, startsWith(r.overdue));
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
    test('one line per warning, names filled in', () {
      final check = RotationCheck(
        warnings: [
          RotationWarning(
            kind: RotationWarningKind.ROTATION_WARNING_KIND_GAP,
            muscles: [
              MuscleGroup.MUSCLE_GROUP_CALVES,
              MuscleGroup.MUSCLE_GROUP_CORE,
            ],
          ),
          RotationWarning(
            kind: RotationWarningKind.ROTATION_WARNING_KIND_OVERLAP,
            templateIds: ['a', 'b'],
            shared: 3,
            of: 3,
          ),
          RotationWarning(
            kind: RotationWarningKind.ROTATION_WARNING_KIND_LOPSIDED,
            muscles: [
              MuscleGroup.MUSCLE_GROUP_BACK,
              MuscleGroup.MUSCLE_GROUP_CALVES,
            ],
          ),
          RotationWarning(
            kind: RotationWarningKind.ROTATION_WARNING_KIND_TOO_FEW,
          ),
        ],
      );
      final lines = rotationWarningLines(check, {
        'a': 'Full Body',
        'b': 'StrongLifts A',
      });
      expect(lines, [
        r.gap.replaceAll('{muscles}', 'calves ${r.and} core'),
        r.overlap
            .replaceAll('{a}', 'Full Body')
            .replaceAll('{b}', 'StrongLifts A')
            .replaceAll('{shared}', '3')
            .replaceAll('{of}', '3'),
        r.lopsided
            .replaceAll('{most}', 'Back')
            .replaceAll('{least}', 'calves'),
        r.tooFew,
      ]);
    });

    test('nothing wrong, nothing said', () {
      expect(rotationWarningLines(RotationCheck(), {}), isEmpty);
    });
  });
}
