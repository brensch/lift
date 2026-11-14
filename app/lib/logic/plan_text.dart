/// A lift's plan in words: "3×8 @ 185 lb" and why ("Down to 180 lb: missed
/// reps last time."), from the decision the core made (core/src/plan.rs). Home,
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

/// The reasons that compare a plan with the lift's last session.
const _versusKinds = {
  PlanReasonKind.PLAN_REASON_KIND_WEIGHT_UP,
  PlanReasonKind.PLAN_REASON_KIND_WEIGHT_DOWN,
  PlanReasonKind.PLAN_REASON_KIND_REPS_UP,
  PlanReasonKind.PLAN_REASON_KIND_REPS_DOWN,
  PlanReasonKind.PLAN_REASON_KIND_SAME_AS_LAST,
};

bool _isVersus(PlanReason r) => _versusKinds.contains(r.kind);

/// The plan against last time, what changed and then why: "Added one rep.
/// You got every rep last time."
String _versusText(PlanReason r, WeightUnit unit) {
  final c = copy.plan.versus;
  final reps = (r.repsAfter - r.repsBefore).abs();
  final change = switch (r.kind) {
    PlanReasonKind.PLAN_REASON_KIND_WEIGHT_UP => c.weightUp,
    PlanReasonKind.PLAN_REASON_KIND_WEIGHT_DOWN => c.weightDown,
    PlanReasonKind.PLAN_REASON_KIND_REPS_UP =>
      reps == 1 ? c.repsUpOne : c.repsUp,
    PlanReasonKind.PLAN_REASON_KIND_REPS_DOWN =>
      reps == 1 ? c.repsDownOne : c.repsDown,
    _ => c.same,
  };
  final why = switch (r.cause) {
    PlanChangeCause.PLAN_CHANGE_CAUSE_HIT => c.hit,
    PlanChangeCause.PLAN_CHANGE_CAUSE_MISSED => c.missed,
    PlanChangeCause.PLAN_CHANGE_CAUSE_STOPPED_EARLY => c.stoppedEarly,
    PlanChangeCause.PLAN_CHANGE_CAUSE_RUSHED => c.rushed,
    PlanChangeCause.PLAN_CHANGE_CAUSE_SETS => c.sets,
    PlanChangeCause.PLAN_CHANGE_CAUSE_TIME_OFF => c.timeOff,
    _ => '',
  };
  final head = change
      .replaceAll('{after}', formatWeight(r.after, unit, includeUnit: true))
      .replaceAll('{n}', '$reps');
  final tail = why
      .replaceAll('{sets}', '${r.setsAfter}')
      .replaceAll('{last}', '${r.setsBefore}')
      .replaceAll('{days}', '${r.daysOff}');
  return tail.isEmpty ? '$head.' : '$head. $tail.';
}

/// One step of a decision in words.
String reasonText(PlanReason r, WeightUnit unit, {required bool bodyweight}) {
  final c = copy.plan.reasons;
  String max(double v) => maxText(v, unit, bodyweight: bodyweight);
  if (_isVersus(r)) return _versusText(r, unit);
  switch (r.kind) {
    case PlanReasonKind.PLAN_REASON_KIND_MAX_UP:
      return c.maxUp.replaceAll('{max}', max(r.after));
    case PlanReasonKind.PLAN_REASON_KIND_MAX_FROM_MISS:
      return c.maxFromMiss.replaceAll('{max}', max(r.after));
    case PlanReasonKind.PLAN_REASON_KIND_HELD:
      final held = switch (r.cause) {
        PlanChangeCause.PLAN_CHANGE_CAUSE_RUSHED => c.heldRushed,
        PlanChangeCause.PLAN_CHANGE_CAUSE_STOPPED_EARLY => c.heldStoppedEarly,
        _ => c.held,
      };
      return held.replaceAll('{max}', max(r.after));
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
            .replaceAll(
              '{muscle}',
              muscleShortLabels[r.muscle] ?? 'That muscle',
            );
      }
      return c.setsFloor.replaceAll('{sets}', sets);
    default:
      return '';
  }
}

/// Whether the plan moved from last time: a "held" max beside it would
/// read as if nothing changed.
bool _moved(ExerciseDecision d) => d.reasons.any(
  (r) => _isVersus(r) && r.kind != PlanReasonKind.PLAN_REASON_KIND_SAME_AS_LAST,
);

/// Every step of a decision, in the order they applied: the plan against
/// last time first, then what the max did. A held max is left out when
/// the weight or reps moved.
List<String> reasonLines(ExerciseDecision d, WeightUnit unit) {
  final bodyweight = isBodyweightDecision(d);
  final moved = _moved(d);
  return [
    for (final r in d.reasons)
      if (!(moved && r.kind == PlanReasonKind.PLAN_REASON_KIND_HELD))
        reasonText(r, unit, bodyweight: bodyweight),
  ].where((line) => line.isNotEmpty).toList();
}

/// The one line that says why the weight is what it is: the plan against
/// last time when there is a last time; otherwise the last step that moved
/// the max (time off comes after the session it follows); the sets step
/// only when there is nothing else.
String reasonShort(ExerciseDecision d, WeightUnit unit) {
  final bodyweight = isBodyweightDecision(d);
  PlanReason? versus;
  PlanReason? weight;
  PlanReason? sets;
  for (final r in d.reasons) {
    if (_isVersus(r)) {
      versus ??= r;
    } else if (r.kind == PlanReasonKind.PLAN_REASON_KIND_SETS_FROM_TIME) {
      sets = r;
    } else {
      weight = r;
    }
  }
  final pick = versus ?? weight ?? sets;
  return pick == null ? '' : reasonText(pick, unit, bodyweight: bodyweight);
}

/// A weight change during a workout in words.
String changeText(WeightChange change, WeightUnit unit) {
  final c = copy.plan.changes;
  final template = switch (change.cause) {
    WeightChangeCause.WEIGHT_CHANGE_CAUSE_USER_ADJUST => c.userAdjust,
    // A rung too heavy steps the ramp down: the next rung is lighter.
    WeightChangeCause.WEIGHT_CHANGE_CAUSE_CALIBRATION_STEP
        when change.after < change.before =>
      c.calibrationStepDown,
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
      .replaceAll(
        '{after}',
        formatWeight(change.after, unit, includeUnit: true),
      );
}
