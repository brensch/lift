/// The banner's question after a set that asks how it went (a ramp set, or
/// a lift's last set with an effort target), in the row the weight and reps
/// take: Easy, Hard, and the set's own circle ([JustDoneCircle]), which
/// takes a rep off per tap when they weren't all there. A rep off is a
/// miss, which closes the question, and the banner shows the set as any
/// set just done. No dialog, so the watch asks it the same way.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/wearable.pb.dart' show QuickAnswer;
import '../../logic/set_labels.dart';
import '../../providers/workout_provider.dart';
import '../../screens/workout/live_set_circle.dart';
import '../../screens/workout/section_workout.dart';
import '../../screens/workout/set_circle.dart';
import '../../theme/theme_spec.dart';

class QuickQuestion extends StatelessWidget {
  final String setId;

  const QuickQuestion({super.key, required this.setId});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = copy.workout;
    final wp = context.read<WorkoutProvider>();
    Widget answer(QuickAnswer answer, String label) => Expanded(
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: () => wp.answerQuick(setId, answer),
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: t.size.bodyLg,
                fontWeight: t.weight.heavy,
              ),
            ),
          ),
        ),
      ),
    );
    // The prompt itself is on the status band above; this row is the answer.
    return Row(
      children: [
        answer(QuickAnswer.QUICK_ANSWER_EASY, w.quickEasy),
        const SizedBox(width: 6),
        answer(QuickAnswer.QUICK_ANSWER_HARD, w.quickHard),
        const SizedBox(width: 10),
        // The ring held full while the question is up: the circle stays
        // tappable to take a rep off until it's answered, with no deadline.
        JustDoneCircle(setId: setId, countdown: false),
      ],
    );
  }
}

/// The banner's circle for a set just done: a tap takes a rep off (adds one
/// to as many as you can) instead of starting the next set, and a ring
/// counts down the seconds left before the banner goes on to it; each tap
/// starts the ring again. The exercise list's circles have none of this.
class JustDoneCircle extends StatelessWidget {
  final String setId;

  /// Whether the ring counts down to [askingUntil]. The "how was that"
  /// question has no deadline: its ring is held full (the circle stays
  /// tappable there until it's answered).
  final bool countdown;

  const JustDoneCircle({super.key, required this.setId, this.countdown = true});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final set = wp.proposedSetById(setId);
    if (set == null) return const SizedBox.shrink();
    final reps = wp.askingReps;
    final circle = SetCircle(
      number: reps,
      state: LiveSetCircle.setCircleState(SectionWorkout.mine(wp), set),
      text: needsLabel(set) ? repsLabel(set, reps, done: true) : null,
      onTap: reps > 0 || set.amrap
          ? () => wp.answerQuick(setId, QuickAnswer.QUICK_ANSWER_ONE_LESS)
          : null,
    );
    if (!countdown) return _Countdown.full(child: circle);
    return _Countdown(until: wp.askingUntil, child: circle);
  }
}

/// A ring just outside the circle running down to [until], when the banner
/// goes on to the next set; each tap sets a new [until] and the ring starts
/// full again. It takes no room of its own, so nothing moves.
/// Nothing while there's no window; [_Countdown.full], the ring held full.
class _Countdown extends StatelessWidget {
  final DateTime? until;
  final Widget child;
  final bool held;

  const _Countdown({required this.until, required this.child}) : held = false;

  const _Countdown.full({required this.child}) : until = null, held = true;

  @override
  Widget build(BuildContext context) {
    const width = SetCircle.outlineNext;
    if (held) return _ring(context, width, child, value: 1);
    final end = until;
    if (end == null) return child;
    final total = WorkoutProvider.oneLessWindow.inMilliseconds;
    final left = end.difference(DateTime.now()).inMilliseconds.clamp(0, total);
    return _ring(
      context,
      width,
      child,
      animated: TweenAnimationBuilder<double>(
        key: ValueKey(end),
        tween: Tween(begin: left / total, end: 0),
        duration: Duration(milliseconds: left),
        builder: (context, value, _) => _arc(context, width, value),
      ),
    );
  }

  /// [child] with a ring just outside its edge, as thick as the up-next
  /// ring: drawn over its surroundings, so it takes no room and nothing
  /// moves. [animated] draws it, or it's [value] full.
  static Widget _ring(
    BuildContext context,
    double width,
    Widget child, {
    Widget? animated,
    double value = 1,
  }) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      Positioned(
        left: -width,
        top: -width,
        right: -width,
        bottom: -width,
        child: IgnorePointer(child: animated ?? _arc(context, width, value)),
      ),
    ],
  );

  static Widget _arc(BuildContext context, double width, double value) =>
      CircularProgressIndicator(
        value: value,
        strokeWidth: width,
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.transparent,
      );
}
