/// One person's status in the workout banner. A band across the top in the
/// colour of the stage they're at — their emoji on their own colour, the
/// stage, UP NEXT when the rack is theirs, the clock — readable from across
/// the gym. The band is the same for everyone, so the emoji line up. Under
/// it, the set: yours says what it is along the top ("Squat · Set 2 of 5"),
/// then the plates, the weight, big, and its circle; a partner's (compact)
/// is one small row — plates, what it is on two lines, weight × reps. Tap a
/// partner's to see their workout.
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
import 'plate_visualization.dart';

class StatusBox extends StatelessWidget {
  final String emoji;
  final Color profileColor;

  /// The stage ("Lifting", "Resting", …) and its colour: the band.
  final String stateLabel;
  final Color stateColor;
  final String? timerText;

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

  const StatusBox({
    super.key,
    required this.emoji,
    required this.profileColor,
    required this.stateLabel,
    required this.stateColor,
    this.timerText,
    this.set,
    this.plan = const [],
    this.upNext = false,
    this.compact = false,
    this.circle,
    this.firstTime = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final onBand =
        ThemeData.estimateBrightnessForColor(stateColor) == Brightness.dark
        ? Colors.white
        : t.text;
    final set = this.set;

    TextStyle bandMono(double size) => t.mono(
      TextStyle(
        fontSize: size,
        fontWeight: t.weight.bold,
        letterSpacing: 1.5,
        color: onBand,
        height: 1,
      ),
    );

    // The band: their emoji on a block of their own colour, full height
    // from the left edge; the stage (and, compact, their set under it);
    // UP NEXT when the rack is theirs; the clock hard right. The stage and
    // the clock shrink to fit a narrow screen; nothing wraps.
    const bandHeight = 64.0;
    final stage = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        stateLabel.toUpperCase(),
        maxLines: 1,
        style: bandMono(t.size.headlineLg).copyWith(letterSpacing: 0.5),
      ),
    );
    final band = SizedBox(
      height: bandHeight,
      child: LayoutBuilder(
        builder: (context, box) => Container(
          color: stateColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: bandHeight,
                alignment: Alignment.center,
                color: profileColor,
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: t.size.headlineLg, height: 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The stage alone, and UP NEXT straight after it.
                    Row(
                      children: [
                        Flexible(child: stage),
                        if (upNext) ...[
                          const SizedBox(width: 8),
                          const _UpNext(),
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
                        style: bandMono(
                          t.size.displayLg,
                        ).copyWith(letterSpacing: 0),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
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
      final weightSize = compact ? t.size.headlineLg : t.size.giant;
      final load = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: formatWeight(set.targetWeight.toDouble(), unit)),
            TextSpan(
              text: ' ${weightUnitSuffix(unit)}',
              style: TextStyle(fontSize: weightSize * 0.4),
            ),
            if (circle == null) TextSpan(text: ' × ${set.targetReps}'),
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
      final line = Row(
        children: [
          if (firstTime)
            Expanded(
              child: Text(
                copy.workout.firstTimeStatus,
                style: TextStyle(
                  fontSize: t.size.display,
                  fontWeight: t.weight.heavy,
                  color: t.text,
                  height: 1.1,
                ),
              ),
            ),
          if (!firstTime && set.targetWeight > 0) ...[
            _Plates(weight: set.targetWeight.toDouble(), compact: compact),
            const SizedBox(width: 12),
          ],
          if (!firstTime)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // Yours sits against × and the circle, as one "45 lb × 5".
                alignment: circle == null
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: load,
              ),
            ),
          if (circle != null && firstTime) circle!,
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
      final exercise = exerciseNames[set.exercise] ?? '?';
      final position = setLineFor(set, plan);
      final small = TextStyle(
        fontSize: t.size.body,
        fontWeight: t.weight.medium,
        color: t.muted,
        height: 1.2,
      );
      if (compact) {
        // A partner's: plates, what the set is on two short rows, then the
        // weight × reps.
        body = Row(
          children: [
            if (set.targetWeight > 0) ...[
              _Plates(weight: set.targetWeight.toDouble(), compact: true),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final text in [exercise, position])
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Shares the room with the two lines, shrinking on a narrow
            // screen.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: load,
              ),
            ),
          ],
        );
      } else {
        // Yours: what the set is along the top, then the row.
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$exercise · $position',
                maxLines: 1,
                style: small.copyWith(fontSize: t.size.subtitle),
              ),
            ),
            const SizedBox(height: 6),
            line,
          ],
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          band,
          if (body != null)
            Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(14, 6, 14, 6)
                  : const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: body,
            ),
        ],
      ),
    );
  }
}

/// The plates to load, in a fixed white box (so nothing moves when the
/// numbers change); tap it for the plate-by-plate breakdown.
class _Plates extends StatelessWidget {
  final double weight;

  /// A partner's: smaller.
  final bool compact;

  const _Plates({required this.weight, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    return GestureDetector(
      onTap: () => showPlateBreakdownDialog(context, weight: weight),
      child: Container(
        width: compact ? 72 : 104,
        height: compact ? 36 : 56,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: t.outline),
        ),
        child: isEmptyBar(weight, unit)
            ? Text(
                copy.workout.emptyBar,
                style: TextStyle(
                  fontSize: t.size.body,
                  fontWeight: t.weight.heavy,
                  color: Colors.black,
                ),
              )
            : FittedBox(
                child: PlateVisualization(weight: weight, isInteractive: false),
              ),
      ),
    );
  }
}

/// UP NEXT! on two lines, on a light block in the band, its letters
/// cycling through the theme's palette: the rack is theirs.
class _UpNext extends StatefulWidget {
  const _UpNext();

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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: t.panel,
          child: Text(
            copy.workout.upNext,
            textAlign: TextAlign.center,
            style: t.mono(
              TextStyle(
                fontSize: t.size.small,
                fontWeight: t.weight.bold,
                letterSpacing: 0.5,
                color: color,
                height: 1.1,
              ),
            ),
          ),
        );
      },
    );
  }
}
