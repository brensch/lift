/// The two lines that describe a set to a person: "Set 2 of 3" / "Warmup 1
/// of 4", and the set itself in the user's unit,
/// "135 lb × 5". The phone bar and the watch snapshot both read these so
/// the two devices say the same thing.
library;

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'weight_units.dart';

/// The 1-based position of [set] among its exercise's sets of the same
/// kind: warmups, calibration sets (counted as they are added), or working
/// sets.
String setLineFor(ProposedSet set, Iterable<ProposedSet> proposedSets) {
  final peers =
      proposedSets
          .where(
            (s) =>
                !s.cancelled &&
                s.calibration == set.calibration &&
                s.exercise == set.exercise &&
                s.warmup == set.warmup,
          )
          .toList()
        ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  final index = peers.indexWhere((s) => s.id == set.id);
  final n = index < 0 ? 1 : index + 1;
  final m = index < 0 ? 1 : peers.length;
  final template = set.warmup ? copy.workout.warmupLine : copy.workout.setLine;
  return template.replaceAll('{n}', '$n').replaceAll('{m}', '$m');
}

/// "60 kg × 5" / "135 lb × 5": the set in the user's unit. The watch never
/// formats a weight itself.
String setTextFor(ProposedSet set, WeightUnit unit) {
  final weight = formatWeight(set.targetWeight.toDouble(), unit);
  return '$weight ${weightUnitSuffix(unit)} × ${set.targetReps}';
}
