/// One person's status in the workout banner. A band across the top in the
/// colour of the stage they're at — their emoji on their own colour, the
/// stage, the clock — readable from across the gym; under it, calm, the set
/// in front of them: (yours) its circle with the reps in it, what it is,
/// the weight, big, and the plates to load. Yours and every partner's are the same box; tap a
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

  /// Their turn on the rack: the plates box pulses orange.
  final bool upNext;

  /// Yours: the set's circle, the same one as in the exercise list, to
  /// start and log it from here.
  final Widget? circle;

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
    this.circle,
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
    // from the left edge; the stage; the clock hard right.
    const bandHeight = 52.0;
    final band = Container(
      height: bandHeight,
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
              style: TextStyle(fontSize: t.size.headline, height: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                stateLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bandMono(t.size.headline).copyWith(letterSpacing: 0.5),
              ),
            ),
          ),
          if (timerText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: Center(
                child: Text(timerText!, style: bandMono(t.size.headline)),
              ),
            ),
        ],
      ),
    );

    final Widget body;
    if (set == null) {
      body = Text(
        copy.workout.allDone,
        style: TextStyle(fontSize: t.size.body, color: t.muted),
      );
    } else {
      final what = Text(
        '${exerciseNames[set.exercise] ?? '?'} · ${setLineFor(set, plan)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: t.size.subtitle,
          fontWeight: t.weight.medium,
          color: t.muted,
        ),
      );
      // The weight alone, as big as it goes: the reps are in the circle
      // (a partner's box, with no circle, says them after it).
      final weightSize = t.size.giant;
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
      // What it is across the top; under it the circle, the weight and the
      // plates on one line.
      final line = Row(
        children: [
          if (circle != null) ...[circle!, const SizedBox(width: 14)],
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: load,
            ),
          ),
          if (set.targetWeight > 0) ...[
            const SizedBox(width: 12),
            // Up next on the rack: NEXT down the plates' left edge.
            if (upNext) ...[
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  copy.workout.nextLabel,
                  style: t.mono(
                    TextStyle(
                      fontSize: t.size.small,
                      fontWeight: t.weight.bold,
                      letterSpacing: 1.5,
                      color: t.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            _Plates(weight: set.targetWeight.toDouble(), upNext: upNext),
          ],
        ],
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [what, const SizedBox(height: 8), line],
      );
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
          Padding(padding: EdgeInsets.fromLTRB(14, 12, 14, 16), child: body),
        ],
      ),
    );
  }
}

/// The plates to load, in a fixed white box (so nothing moves when the
/// numbers change); tap it for the plate-by-plate breakdown. For whoever is
/// up next on the rack it pulses orange: this is what to load now.
class _Plates extends StatefulWidget {
  final double weight;
  final bool upNext;

  const _Plates({required this.weight, required this.upNext});

  @override
  State<_Plates> createState() => _PlatesState();
}

class _PlatesState extends State<_Plates> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Plates oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.upNext) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final weight = widget.weight;
    return GestureDetector(
      onTap: () => showPlateBreakdownDialog(context, weight: weight),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          width: 132,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: widget.upNext ? t.primary : t.outline,
              width: widget.upNext ? 3 : 1,
            ),
            boxShadow: widget.upNext
                ? [
                    BoxShadow(
                      color: t.primary.withValues(alpha: 0.35),
                      spreadRadius: 5 * _pulse.value,
                    ),
                  ]
                : null,
          ),
          child: child,
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
