import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/set_labels.dart';

/// The words the phone and the watch both show for a set.
void main() {
  const lb = WeightUnit.WEIGHT_UNIT_LB;
  final w = copy.workout;

  ProposedSet set(
    String id,
    int order, {
    SetRole role = SetRole.SET_ROLE_UNSPECIFIED,
    bool warmup = false,
    int reps = 5,
    double weight = 100,
    bool amrap = false,
    Measure measure = Measure.MEASURE_UNSPECIFIED,
    bool perSide = false,
    String tempo = '',
  }) => ProposedSet(
    id: id,
    exercise: 'bench_press',
    workoutOrder: order,
    role: role,
    warmup: warmup,
    targetReps: reps,
    targetWeight: weight,
    amrap: amrap,
    measure: measure,
    perSide: perSide,
    tempo: tempo,
  );

  test('a circle shows reps, a plus while it is open, seconds or metres', () {
    expect(repsLabel(set('a', 0), 8), '8');
    expect(repsLabel(set('a', 0, amrap: true), 8), '8+');
    expect(repsLabel(set('a', 0, amrap: true), 11, done: true), '11');
    expect(repsLabel(set('a', 0, measure: Measure.MEASURE_SECONDS), 30), '30s');
    expect(repsLabel(set('a', 0, measure: Measure.MEASURE_METRES), 20), '20m');
    expect(needsLabel(set('a', 0)), isFalse);
    expect(needsLabel(set('a', 0, amrap: true)), isTrue);
  });

  test('each kind of set names itself; the banner shortens only plain ones', () {
    final plan = [
      set('w', 0, warmup: true),
      set('t', 1, role: SetRole.SET_ROLE_TOP),
      set('b1', 2, role: SetRole.SET_ROLE_BACKOFF, perSide: true),
      set('b2', 3, role: SetRole.SET_ROLE_BACKOFF),
      set('d1', 4, role: SetRole.SET_ROLE_DROP),
      set('m1', 5, role: SetRole.SET_ROLE_MINI, tempo: '3-1-1'),
      set('p', 6, amrap: true),
    ];
    String line(String id, {bool short = false}) =>
        setLineFor(plan.firstWhere((s) => s.id == id), plan, short: short);
    expect(line('t'), w.topLine);
    expect(
      line('b1'),
      '${w.backoffLine.replaceAll('{n}', '1').replaceAll('{m}', '2')} · ${w.eachSide}',
    );
    expect(line('d1'), w.dropLine.replaceAll('{n}', '1').replaceAll('{m}', '1'));
    expect(
      line('m1'),
      '${w.miniLine.replaceAll('{n}', '1').replaceAll('{m}', '1')} · '
      '${w.tempoLine.replaceAll('{tempo}', '3-1-1')}',
    );
    expect(
      line('p'),
      '${w.setLine.replaceAll('{n}', '1').replaceAll('{m}', '1')} · ${w.asManyAsYouCan}',
    );
    // Under the lift's name: "1 of 1", "Warm 1 of 1"; a drop keeps its name.
    expect(line('p', short: true), '1 of 1 · ${w.asManyAsYouCan}');
    expect(line('w', short: true), w.warmShort.replaceAll('{count}', '1 of 1'));
    expect(line('d1', short: true), line('d1'));
  });

  test('a set with no weight says only its number', () {
    expect(setTextFor(set('a', 0), lb), '100 lb × 5');
    expect(
      setTextFor(set('a', 0, weight: 0, reps: 30, measure: Measure.MEASURE_SECONDS), lb),
      '30s',
    );
  });
}
