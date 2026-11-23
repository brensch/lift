/// The words that describe a set to a person: its line ("Set 2 of 3",
/// "Back-off 1 of 2 · each side"), the set itself in the user's unit
/// ("135 lb × 5", "45 lb × 30s"), and its number as a circle shows it
/// ("8", "8+", "30s"). The phone and the watch snapshot both read these so
/// the two devices say the same thing.
library;

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'weight_units.dart';

/// A drop or a mini-set: work taken to failure after a main set.
bool isPartial(ProposedSet set) =>
    set.role == SetRole.SET_ROLE_DROP || set.role == SetRole.SET_ROLE_MINI;

/// A set's number as its circle shows it: reps, or seconds ("30s") or
/// metres ("20m"), with a "+" while an as-many-as-you-can set is still to
/// do. A done set shows what was done.
String repsLabel(ProposedSet set, int reps, {bool done = false}) {
  final unit = switch (set.measure) {
    Measure.MEASURE_SECONDS => 's',
    Measure.MEASURE_METRES => 'm',
    _ => '',
  };
  final plus = set.amrap && !done ? '+' : '';
  return '$reps$unit$plus';
}

/// Whether a circle needs [repsLabel] rather than a bare number.
bool needsLabel(ProposedSet set) =>
    set.amrap || set.measure != Measure.MEASURE_UNSPECIFIED;

/// The set's line: its position among its exercise's sets of the same
/// kind (warmups, ramp sets, plain sets, top sets, back-offs, drops,
/// minis), then what else it asks: as many as you can, each side, a tempo.
/// [short] is the banner's, under the lift's name: a plain set says only
/// "2 of 3" and a warmup "Warm 2 of 3"; any other kind keeps its name.
String setLineFor(
  ProposedSet set,
  Iterable<ProposedSet> proposedSets, {
  bool short = false,
}) {
  final peers =
      proposedSets
          .where(
            (s) =>
                !s.cancelled &&
                s.exercise == set.exercise &&
                s.calibration == set.calibration &&
                s.warmup == set.warmup &&
                (s.warmup || s.calibration || s.role == set.role),
          )
          .toList()
        ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  final index = peers.indexWhere((s) => s.id == set.id);
  final n = index < 0 ? 1 : index + 1;
  final m = index < 0 ? 1 : peers.length;
  final w = copy.workout;
  final template = set.warmup
      ? w.warmupLine
      : set.calibration
      ? w.setLine
      : switch (set.role) {
          SetRole.SET_ROLE_TOP when m == 1 => w.topLine,
          SetRole.SET_ROLE_BACKOFF => w.backoffLine,
          SetRole.SET_ROLE_DROP => w.dropLine,
          SetRole.SET_ROLE_MINI => w.miniLine,
          _ => w.setLine,
        };
  var line = template.replaceAll('{n}', '$n').replaceAll('{m}', '$m');
  if (short && (template == w.setLine || template == w.warmupLine)) {
    // "Set 2 of 3" without its kind: "2 of 3".
    final cut = line.indexOf(' ');
    final count = cut < 0 ? line : line.substring(cut + 1);
    line = set.warmup ? w.warmShort.replaceAll('{count}', count) : count;
  }
  return [
    line,
    if (set.amrap) w.asManyAsYouCan,
    if (set.perSide) w.eachSide,
    if (set.tempo.isNotEmpty) w.tempoLine.replaceAll('{tempo}', set.tempo),
  ].join(' · ');
}

/// "60 kg × 5" / "135 lb × 5+" / "135 lb × 30s": the set in the user's
/// unit; with no weight (a plank, a pull-up), just its number: "30s".
/// The watch never formats a weight itself.
String setTextFor(ProposedSet set, WeightUnit unit) {
  final reps = repsLabel(set, set.targetReps);
  if (set.targetWeight <= 0) return reps;
  final weight = formatWeight(set.targetWeight.toDouble(), unit);
  return '$weight ${weightUnitSuffix(unit)} × $reps';
}
