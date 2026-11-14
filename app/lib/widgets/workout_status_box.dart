/// One person's status in the workout banner. A band across the top in the
/// colour of the stage they're at — their emoji on their own colour, the
/// stage, UP NEXT when the rack is theirs, the clock — readable from across
/// the gym. The band is the same for everyone, so the emoji line up. Under
/// it, the set as one row: yours says what it is on two short lines ("Squat",
/// "2 of 5"), then the plates and the weight as a button, and its circle; a
/// partner's (compact) is one small row — "Squat · 2 of 5", plates,
/// weight × reps. Tap a partner's to see their workout.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/set_labels.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/theme_spec.dart';
import '../screens/workout/set_circle.dart';
import 'plate_visualization.dart';

/// What your status row needs besides the set's label: the bar's and the
/// box's margins (48), the gaps, × and the circle (98), and the least the
/// load button is given (110). The label has the screen's width less this.
const double _rowFixedWidth = 48 + 98 + 110;

class StatusBox extends StatelessWidget {
  final String emoji;
  final Color profileColor;

  /// The stage ("Lifting", "Resting", …) and its colour: the band.
  final String stateLabel;
  final Color stateColor;
  final String? timerText;

  /// 0..1 of the rest still to go: the band's colour drains from the right as
  /// it runs out. Null when not resting.
  final double? restLeft;

  /// The set in front of them, and the plan it belongs to (for "Set 2 of
  /// 5"); null when they're done.
  final ProposedSet? set;
  final Iterable<ProposedSet> plan;

  /// Their turn on the rack: UP NEXT! in the band.
  final bool upNext;

  /// A partner's: the row under the band small, weight × reps.
  final bool compact;

  /// Yours: the set's circle, the same one as in the exercise list, to
  /// start and log it from here.
  final Widget? circle;

  /// Yours, on the first set of an exercise never done: there's no weight
  /// yet, so the box says so instead of weight and plates.
  final bool firstTime;

  /// Opens the exercise's edit sheet: a pencil left of the weight.
  final VoidCallback? onEdit;

  const StatusBox({
    super.key,
    required this.emoji,
    required this.profileColor,
    required this.stateLabel,
    required this.stateColor,
    this.timerText,
    this.restLeft,
    this.set,
    this.plan = const [],
    this.upNext = false,
    this.compact = false,
    this.circle,
    this.firstTime = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final onBand = t.inkOn(stateColor);
    final set = this.set;

    // On the band: the stage in words, the clock in figures.
    TextStyle onBandText(double size) => TextStyle(
      fontSize: size,
      fontWeight: t.weight.bold,
      color: onBand,
      height: 1,
    );

    // The band: their emoji on a block of their own colour, full height
    // from the left edge; the stage (and, compact, their set under it);
    // UP NEXT when the rack is theirs; the clock hard right. The stage and
    // the clock shrink to fit a narrow screen; nothing wraps.
    final bandHeight = compact ? 38.0 : 56.0;
    final stage = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        stateLabel,
        maxLines: 1,
        style: onBandText(compact ? t.size.title : t.size.headlineLg),
      ),
    );
    final band = SizedBox(
      height: bandHeight,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          fit: StackFit.expand,
          children: [
            // Resting: a paler track, and the colour over it shrinking to the
            // left as the rest runs out (eased across each one-second tick).
            // It shrinks to the emoji's block, not under it: the rest is over
            // when the colour is gone, not a block's width before.
            ColoredBox(
              color: restLeft == null
                  ? stateColor
                  : Color.lerp(stateColor, t.panel, 0.45)!,
            ),
            if (restLeft != null)
              Positioned.fill(
                left: bandHeight,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(seconds: 1),
                  alignment: Alignment.centerLeft,
                  widthFactor: restLeft!.clamp(0.0, 1.0),
                  child: ColoredBox(color: stateColor),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: bandHeight,
                  alignment: Alignment.center,
                  color: profileColor,
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: compact ? t.size.titleLg : t.size.display,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The stage at the left; Up next hard right, against
                      // the clock.
                      Row(
                        children: [
                          Expanded(child: stage),
                          if (upNext) ...[
                            const SizedBox(width: 8),
                            _UpNext(compact: compact),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (timerText != null)
                  // The clock is read from across the gym: the biggest thing
                  // in the band, but never more than a third of it.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth / 3),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          timerText!,
                          style: t.mono(
                            onBandText(
                              compact ? t.size.headline : t.size.displayLg,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ],
        ),
      ),
    );

    // No set in front of them (choosing, or all done): the band says it
    // all.
    final Widget? body;
    if (set == null) {
      body = null;
    } else {
      // The weight alone, as big as it goes: the reps are in the circle
      // (a partner's box, with no circle, says them after it).
      final weightSize = compact ? t.size.headlineLg : t.size.displayLg;
      final load = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: formatWeight(set.targetWeight.toDouble(), unit)),
            // The number alone, as big as it goes: the reps are beside it,
            // in the set's circle (yours) or plainly (a partner's).
          ],
        ),
        maxLines: 1,
        softWrap: false,
        style: t.mono(
          TextStyle(
            fontSize: weightSize,
            fontWeight: t.weight.bold,
            color: t.text,
            height: 1.1,
          ),
        ),
      );
      // The plates to load, the weight, then × the reps: in the circle
      // (yours), or said after the weight (a partner's).
      final exercise = exerciseName(set.exercise);
      final position = setLineFor(set, plan);
      // "Warmup 2 of 3" without its kind: "2 of 3".
      final cut = position.indexOf(' ');
      final count = cut < 0 ? position : position.substring(cut + 1);
      final small = TextStyle(
        fontSize: t.size.body,
        fontWeight: t.weight.medium,
        color: t.muted,
        height: 1.2,
      );
      final line = Row(
        children: [
          // What the set is, on two short rows at the left: the lift, then
          // which one of how many (a warmup says so). They take the width
          // their words need; the rest of the row has what is left.
          // On a screen too narrow for them, the button and the circle,
          // they are scaled down together to what is left once the button
          // has its least: never cut short, never pushing the row over.
          // A first time has them too, with its words where the button is.
          if (!compact) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (MediaQuery.sizeOf(context).width - _rowFixedWidth)
                    .clamp(60.0, double.infinity),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final text in [
                      exercise,
                      set.warmup
                          ? copy.workout.warmShort.replaceAll('{count}', count)
                          : count,
                    ])
                      if (text.isNotEmpty)
                        Text(
                          text,
                          maxLines: 1,
                          softWrap: false,
                          style: small.copyWith(fontSize: t.size.subtitle),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (firstTime)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  copy.workout.firstTimeStatus,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: t.size.titleLg,
                    fontWeight: t.weight.heavy,
                    color: t.text,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          // The plates and the weight they add up to, as one button against
          // × and the circle: it opens the exercise's edit sheet. The bar
          // runs out of the button's far side, away from the number.
          if (!firstTime)
            // The button is never scaled as a whole: it stays the circle's
            // height and its plates their size, and only the number gets
            // smaller when the row is tight.
            Expanded(
              child: Align(
                alignment: circle == null
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: _LoadButton(
                  weight: set.targetWeight.toDouble(),
                  onTap: onEdit,
                  child: load,
                ),
              ),
            ),
          if (circle != null && firstTime) ...[
            const SizedBox(width: 8),
            circle!,
          ],
          if (circle != null && !firstTime) ...[
            const SizedBox(width: 8),
            Text(
              '×',
              style: t.mono(
                TextStyle(
                  fontSize: t.size.headline,
                  fontWeight: t.weight.bold,
                  color: t.text,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            circle!,
          ],
        ],
      );
      if (compact) {
        // A partner's: laid out as yours is, smaller, and nothing in it to
        // press. What the set is on two short rows; then the end of the bar
        // with its plates and the weight, with no button round them; then
        // × and the reps, with no circle.
        final times = t.mono(
          TextStyle(
            fontSize: t.size.subtitle,
            fontWeight: t.weight.bold,
            color: t.text,
            height: 1,
          ),
        );
        body = Row(
          children: [
            // The lift and which set, on the one row: "Squat · 2 of 5".
            Expanded(
              child: Text(
                [
                  exercise,
                  set.warmup
                      ? copy.workout.warmShort.replaceAll('{count}', count)
                      : count,
                ].where((text) => text.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: small,
              ),
            ),
            const SizedBox(width: 8),
            if (set.targetWeight > 0 &&
                !isEmptyBar(set.targetWeight.toDouble(), unit)) ...[
              HalfBarbell(
                weightLb: set.targetWeight.toDouble(),
                height: 30,
                mirrored: true,
                squeeze: true,
              ),
              const SizedBox(width: 8),
            ],
            // Only the set's words stretch, so the load and the reps sit hard
            // against the right. The number has this much and shrinks to it.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: load,
              ),
            ),
            const SizedBox(width: 6),
            Text('×', style: times),
            const SizedBox(width: 6),
            Text(
              '${set.targetReps}',
              style: times.copyWith(fontSize: weightSize),
            ),
          ],
        );
      } else {
        body = line;
      }
    }

    return Container(
      // The band's colours run to the edge: they take the box's corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: context.tokens.brMd,
        border: Border.all(color: t.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          band,
          if (body != null)
            Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(12, 4, 12, 4)
                  // The circle is the row's tallest thing and its last: the
                  // same room under it as beside it.
                  : const EdgeInsets.fromLTRB(14, 8, 10, 10),
              child: body,
            ),
        ],
      ),
    );
  }
}

/// Your set's load as one button: the end of the bar with its plates, the
/// bar running out through the button's left edge, then the weight. A tap
/// opens the exercise's edit sheet ([onTap]; null when there is nothing to
/// edit, and then it is only a readout).
class _LoadButton extends StatelessWidget {
  final double weight;
  final VoidCallback? onTap;
  final Widget child;

  const _LoadButton({
    required this.weight,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final below =
        displayWeightFromPounds(weight, unit) < standardBarWeight(unit);
    return Semantics(
      button: onTap != null,
      label: copy.workoutPage.weightAndReps,
      child: Material(
        color: t.lightBackdrop,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: t.outline),
          borderRadius: t.brMd,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // As tall as the set's circle beside it, whatever is in it.
          child: SizedBox(
            height: SetCircle.diameter,
            child: Padding(
              // Nothing on the left: the bar meets the edge.
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (weight > 0 && !below) ...[
                    // Always this tall: a heavy bar is wider, not smaller.
                    HalfBarbell(
                      weightLb: weight,
                      height: 44,
                      mirrored: true,
                      squeeze: true,
                    ),
                    const SizedBox(width: 10),
                  ] else
                    const SizedBox(width: 12),
                  // The number has what is left, and shrinks to fit it.
                  Flexible(
                    child: FittedBox(fit: BoxFit.scaleDown, child: child),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// UP NEXT! on two lines, on a light block in the band, its letters
/// cycling through the theme's palette: the rack is theirs.
class _UpNext extends StatefulWidget {
  /// In a partner's shorter band: smaller.
  final bool compact;

  const _UpNext({this.compact = false});

  @override
  State<_UpNext> createState() => _UpNextState();
}

class _UpNextState extends State<_UpNext> with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = t.series;
    return AnimatedBuilder(
      animation: _cycle,
      builder: (context, _) {
        // Glide from each palette colour to the next.
        final at = _cycle.value * colors.length;
        final from = colors[at.floor() % colors.length];
        final to = colors[(at.floor() + 1) % colors.length];
        final color = Color.lerp(from, to, at - at.floor())!;
        return Container(
          padding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: t.panel, borderRadius: t.brSm),
          child: Text(
            copy.workout.upNext,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.compact ? t.size.caption : t.size.small,
              fontWeight: t.weight.bold,
              color: color,
              height: widget.compact ? 1.0 : 1.1,
            ),
          ),
        );
      },
    );
  }
}
