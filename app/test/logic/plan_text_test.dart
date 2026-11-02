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

  test('the short reason is the last step that moved the max', () {
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
  });

  test('a bodyweight max is in reps', () {
    expect(maxText(12.4, lb, bodyweight: true), '12 reps');
    expect(maxText(230.6, lb, bodyweight: false), '231 lb');
  });

  test('minutes round up', () {
    expect(planMinutes(3001), 51);
    expect(planMinutes(3000), 50);
  });
}
