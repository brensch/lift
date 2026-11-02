/// A lift's plan in words: "3×8 @ 185 lb" and why ("Hit every rep. Max up
/// to 231 lb."), from the decision the core made (core/src/plan.rs). Home,
/// the template editor, the live workout and the summary all read these, so
/// they say the same thing.
library;

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'exercises.dart';
import 'utils.dart';
import 'weight_units.dart';

/// Whole minutes, rounded up: a plan never claims less than it takes.
int planMinutes(int seconds) => (seconds + 59) ~/ 60;

/// "3×8 @ 185 lb", "3×12" (bodyweight), "Ramp from 95 lb" (never done).
String planLine(ExerciseDecision d, WeightUnit unit) {
  if (d.calibration) {
    return copy.plan.ramp.replaceAll(
      '{weight}',
      formatWeight(d.weight, unit, includeUnit: true),
    );
  }
  final setsReps = '${d.sets}×${d.reps}';
  if (d.weight <= 0) return setsReps;
  return '$setsReps @ ${formatWeight(d.weight, unit, includeUnit: true)}';
}

/// An estimated max as people read it: whole numbers, in the user's unit,
/// or reps for a bodyweight lift.
String maxText(double max, WeightUnit unit, {required bool bodyweight}) {
  if (bodyweight) return '${max.round()} reps';
  final display = displayWeightFromPounds(max, unit).round();
  return '$display ${weightUnitSuffix(unit)}';
}

/// A bodyweight lift's decision: no weight and no ramp.
bool isBodyweightDecision(ExerciseDecision d) =>
    d.weight <= 0 && !d.calibration;

/// One step of a decision in words.
String reasonText(
  PlanReason r,
  WeightUnit unit, {
  required bool bodyweight,
}) {
  final c = copy.plan.reasons;
  String max(double v) => maxText(v, unit, bodyweight: bodyweight);
  switch (r.kind) {
    case PlanReasonKind.PLAN_REASON_KIND_MAX_UP:
      return c.maxUp.replaceAll('{max}', max(r.after));
    case PlanReasonKind.PLAN_REASON_KIND_MAX_FROM_MISS:
      return c.maxFromMiss.replaceAll('{max}', max(r.after));
    case PlanReasonKind.PLAN_REASON_KIND_HELD:
      return c.held.replaceAll('{max}', max(r.after));
    case PlanReasonKind.PLAN_REASON_KIND_TIME_OFF:
      return c.timeOff
          .replaceAll('{days}', '${r.daysOff}')
          .replaceAll('{max}', max(r.after));
    case PlanReasonKind.PLAN_REASON_KIND_FIRST_TIME:
      return bodyweight ? c.firstTimeBodyweight : c.firstTime;
    case PlanReasonKind.PLAN_REASON_KIND_USER_SET:
      final date = DateTime.fromMillisecondsSinceEpoch(r.at.toInt() * 1000);
      return c.userSet.replaceAll('{date}', shortDate(date));
    case PlanReasonKind.PLAN_REASON_KIND_SETS_FROM_TIME:
      final sets = '${r.after.round()}';
      if (r.after > r.before) {
        return c.setsExtra
            .replaceAll('{sets}', sets)
            .replaceAll('{muscle}', muscleShortLabels[r.muscle] ?? 'That muscle');
      }
      return c.setsFloor.replaceAll('{sets}', sets);
    default:
      return '';
  }
}

/// Every step of a decision, in the order they applied.
List<String> reasonLines(ExerciseDecision d, WeightUnit unit) {
  final bodyweight = isBodyweightDecision(d);
  return [
    for (final r in d.reasons) reasonText(r, unit, bodyweight: bodyweight),
  ].where((line) => line.isNotEmpty).toList();
}

/// The one line that says why the weight is what it is: the last step that
/// moved the max (time off comes after the session it follows). The sets
/// step only when there is nothing else.
String reasonShort(ExerciseDecision d, WeightUnit unit) {
  final bodyweight = isBodyweightDecision(d);
  PlanReason? weight;
  PlanReason? sets;
  for (final r in d.reasons) {
    if (r.kind == PlanReasonKind.PLAN_REASON_KIND_SETS_FROM_TIME) {
      sets = r;
    } else {
      weight = r;
    }
  }
  final pick = weight ?? sets;
  return pick == null ? '' : reasonText(pick, unit, bodyweight: bodyweight);
}

/// A weight change during a workout in words.
String changeText(WeightChange change, WeightUnit unit) {
  final c = copy.plan.changes;
  final template = switch (change.cause) {
    WeightChangeCause.WEIGHT_CHANGE_CAUSE_USER_ADJUST => c.userAdjust,
    WeightChangeCause.WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP => c.calibrationStep,
    WeightChangeCause.WEIGHT_CHANGE_CAUSE_CALIBRATION_SETTLED =>
      c.calibrationSettled,
    WeightChangeCause.WEIGHT_CHANGE_CAUSE_CORRECTION => c.correction,
    _ => '',
  };
  return template
      .replaceAll(
        '{before}',
        formatWeight(change.before, unit, includeUnit: true),
      )
      .replaceAll('{after}', formatWeight(change.after, unit, includeUnit: true));
}
