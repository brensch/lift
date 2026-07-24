import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/logic/warmup.dart';

/// `app/lib/logic/warmup.dart` and `src/workout/planning.rs` are independent
/// ports of the same warmup and plate-snapping maths. The app generates warmups
/// locally for instant feedback while the server generates the authoritative
/// ones, so if the two drift the user sees the optimistic warmups replaced by
/// different numbers when the server responds.
///
/// Both sides assert against the same fixture, so drift in either fails the
/// build. Regenerate with:
///
///   LIFT_SNAPSHOT_WARMUP=1 cargo test warmup_golden
///
/// then re-run `flutter test` to confirm Dart still agrees.
void main() {
  group('warmup golden parity with the Rust backend', () {
    late List<dynamic> cases;

    setUpAll(() {
      final file = File('../testdata/warmup_golden.json');
      if (!file.existsSync()) {
        fail(
          'testdata/warmup_golden.json not found at ${file.absolute.path}. '
          'Regenerate with: LIFT_SNAPSHOT_WARMUP=1 cargo test warmup_golden',
        );
      }
      cases = (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['cases'] as List<dynamic>;
    });

    test('fixture is non-empty', () {
      expect(cases, isNotEmpty);
    });

    test('generateWarmupDefs matches the Rust output for every case', () {
      final mismatches = <String>[];

      for (final entry in cases) {
        final c = entry as Map<String, dynamic>;
        final workingWeight = (c['working_weight'] as num).toDouble();
        final expected = (c['warmups'] as List<dynamic>)
            .map((w) => (w as Map<String, dynamic>))
            .toList();

        final actual = generateWarmupDefs(workingWeight);

        if (actual.length != expected.length) {
          mismatches.add(
            'working=$workingWeight: expected ${expected.length} warmups, got ${actual.length}',
          );
          continue;
        }

        for (var i = 0; i < expected.length; i++) {
          final expectedWeight = (expected[i]['weight'] as num).toDouble();
          final expectedReps = expected[i]['reps'] as int;

          // Rust computes in f32, Dart in f64. All values here are multiples of
          // 2.5 and exactly representable, so the tolerance only absorbs the
          // f32->JSON round trip, not genuine disagreement.
          if ((actual[i].weight - expectedWeight).abs() > 0.001) {
            mismatches.add(
              'working=$workingWeight warmup[$i]: expected weight $expectedWeight, '
              'got ${actual[i].weight}',
            );
          }
          if (actual[i].reps != expectedReps) {
            mismatches.add(
              'working=$workingWeight warmup[$i]: expected $expectedReps reps, '
              'got ${actual[i].reps}',
            );
          }
        }
      }

      expect(
        mismatches,
        isEmpty,
        reason:
            'app/lib/logic/warmup.dart has drifted from src/workout/planning.rs.\n'
            'Mirror the change in both, then regenerate the fixture with\n'
            '  LIFT_SNAPSHOT_WARMUP=1 cargo test warmup_golden\n\n'
            '${mismatches.join('\n')}',
      );
    });

    test('warmups are non-decreasing and below the working weight', () {
      for (final entry in cases) {
        final workingWeight = ((entry as Map<String, dynamic>)['working_weight'] as num).toDouble();
        final defs = generateWarmupDefs(workingWeight);

        expect(defs, hasLength(4), reason: 'working=$workingWeight');

        var prev = 0.0;
        for (final def in defs) {
          expect(def.weight, greaterThanOrEqualTo(prev),
              reason: 'warmups must not decrease at working=$workingWeight');
          expect(def.weight, lessThan(workingWeight),
              reason: 'warmup must be under working weight at $workingWeight');
          expect(def.weight, greaterThanOrEqualTo(2.5),
              reason: 'warmup below minimum at working=$workingWeight');
          expect(def.reps, greaterThan(0));
          prev = def.weight;
        }
      }
    });
  });
}
