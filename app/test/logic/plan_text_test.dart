import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/plan_text.dart';

void main() {
  const lb = WeightUnit.WEIGHT_UNIT_LB;

  test('a plan reads sets × reps @ weight, or the ramp', () {
    final d = ExerciseDecision(sets: 3, reps: 8, weight: 185);
    expect(planLine(d, lb), '3×8 @ 185 lb');
    expect(planLine(ExerciseDecision(sets: 3, reps: 12), lb), '3×12');
    expect(
      planLine(ExerciseDecision(sets: 3, weight: 95, calibration: true), lb),
      copy.plan.ramp.replaceAll('{weight}', '95 lb'),
    );
  });

  test(
    'with no last time, the short reason is the last step that moved the max',
    () {
      final d = ExerciseDecision(
        weight: 185,
        reasons: [
          PlanReason(kind: PlanReasonKind.PLAN_REASON_KIND_MAX_UP, after: 230),
          PlanReason(
            kind: PlanReasonKind.PLAN_REASON_KIND_TIME_OFF,
            after: 207,
            daysOff: 23,
          ),
          PlanReason(
            kind: PlanReasonKind.PLAN_REASON_KIND_SETS_FROM_TIME,
            before: 2,
            after: 2,
          ),
        ],
      );
      expect(
        reasonShort(d, lb),
        copy.plan.reasons.timeOff
            .replaceAll('{days}', '23')
            .replaceAll('{max}', '207 lb'),
      );
      expect(reasonLines(d, lb), hasLength(3));
    },
  );

  PlanReason versus(
    PlanReasonKind kind,
    PlanChangeCause cause, {
    double before = 242.5,
    double after = 237,
    int repsBefore = 6,
    int repsAfter = 6,
    int setsBefore = 3,
    int setsAfter = 3,
  }) => PlanReason(
    kind: kind,
    cause: cause,
    before: before,
    after: after,
    repsBefore: repsBefore,
    repsAfter: repsAfter,
    setsBefore: setsBefore,
    setsAfter: setsAfter,
  );

  test('the short reason is the weight against last time', () {
    final v = copy.plan.versus;
    final down = ExerciseDecision(
      weight: 237,
      reasons: [
        versus(
          PlanReasonKind.PLAN_REASON_KIND_WEIGHT_DOWN,
          PlanChangeCause.PLAN_CHANGE_CAUSE_SETS,
          setsAfter: 4,
        ),
        PlanReason(kind: PlanReasonKind.PLAN_REASON_KIND_HELD, after: 300),
      ],
    );
    final head = v.weightDown.replaceAll('{after}', '237 lb');
    final why = v.sets.replaceAll('{sets}', '4').replaceAll('{last}', '3');
    expect(reasonShort(down, lb), '$head. $why.');
    // A held max never sits beside a weight that moved.
    expect(reasonLines(down, lb), ['$head. $why.']);

    final missed = ExerciseDecision(
      reasons: [
        versus(
          PlanReasonKind.PLAN_REASON_KIND_WEIGHT_DOWN,
          PlanChangeCause.PLAN_CHANGE_CAUSE_MISSED,
        ),
        PlanReason(
          kind: PlanReasonKind.PLAN_REASON_KIND_MAX_FROM_MISS,
          after: 280,
        ),
      ],
    );
    expect(reasonShort(missed, lb), '$head. ${v.missed}.');
    expect(reasonLines(missed, lb), hasLength(2));

    final more = ExerciseDecision(
      reasons: [
        versus(
          PlanReasonKind.PLAN_REASON_KIND_REPS_UP,
          PlanChangeCause.PLAN_CHANGE_CAUSE_HIT,
          after: 242.5,
          repsAfter: 7,
        ),
      ],
    );
    expect(reasonShort(more, lb), '${v.repsUpOne}. ${v.hit}.');

    final same = ExerciseDecision(
      reasons: [
        versus(
          PlanReasonKind.PLAN_REASON_KIND_SAME_AS_LAST,
          PlanChangeCause.PLAN_CHANGE_CAUSE_STOPPED_EARLY,
        ),
        PlanReason(kind: PlanReasonKind.PLAN_REASON_KIND_HELD, after: 300),
      ],
    );
    expect(reasonShort(same, lb), '${v.same}. ${v.stoppedEarly}.');
    expect(
      reasonLines(same, lb),
      hasLength(2),
      reason: 'held, and nothing moved',
    );

    // A rushed miss is its own cause, not stopping early.
    final rushed = ExerciseDecision(
      weight: 300,
      reasons: [
        versus(
          PlanReasonKind.PLAN_REASON_KIND_SAME_AS_LAST,
          PlanChangeCause.PLAN_CHANGE_CAUSE_RUSHED,
        ),
        PlanReason(
          kind: PlanReasonKind.PLAN_REASON_KIND_HELD,
          cause: PlanChangeCause.PLAN_CHANGE_CAUSE_RUSHED,
          after: 300,
        ),
      ],
    );
    expect(reasonShort(rushed, lb), '${v.same}. ${v.rushed}.');
    expect(
      reasonLines(rushed, lb)[1],
      copy.plan.reasons.heldRushed.replaceAll('{max}', '300 lb'),
    );
  });

  test('a bodyweight max is in reps', () {
    expect(maxText(12.4, lb, bodyweight: true), '12 reps');
    expect(maxText(230.6, lb, bodyweight: false), '231 lb');
  });

  test('a ramp step reads up, or down when the rung was too heavy', () {
    final c = copy.plan.changes;
    final up = WeightChange(
      cause: WeightChangeCause.WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP,
      before: 135,
      after: 150,
    );
    expect(
      changeText(up, lb),
      c.calibrationStep
          .replaceAll('{before}', '135 lb')
          .replaceAll('{after}', '150 lb'),
    );
    final down = WeightChange(
      cause: WeightChangeCause.WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP,
      before: 200,
      after: 160,
    );
    expect(
      changeText(down, lb),
      c.calibrationStepDown.replaceAll('{after}', '160 lb'),
    );
    expect(changeText(down, lb), isNot(contains('{')));
  });

  test('minutes round up', () {
    expect(planMinutes(3001), 51);
    expect(planMinutes(3000), 50);
  });
}
