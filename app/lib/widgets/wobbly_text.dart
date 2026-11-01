import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/theme_spec.dart';

class WobblyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final int seed;

  /// How far each letter drifts, in logical pixels; its tilt scales with it.
  final double maxOffset;

  const WobblyText({
    super.key,
    required this.text,
    this.fontSize = 48,
    this.seed = 42,
    this.maxOffset = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    final rng = Random(seed);
    final letters = text.split('');

    // Shrinks rather than overflows when the slot is narrow (large font
    // scaling, a crowded app bar); never scales up.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final ch in letters)
            _WobblyLetter(
              char: ch,
              fontSize: fontSize,
              maxOffset: maxOffset,
              rng: rng,
            ),
        ],
      ),
    );
  }
}

class _WobblyLetter extends StatefulWidget {
  final String char;
  final double fontSize;
  final double maxOffset;
  final Random rng;

  const _WobblyLetter({
    required this.char,
    required this.fontSize,
    required this.maxOffset,
    required this.rng,
  });

  @override
  State<_WobblyLetter> createState() => _WobblyLetterState();
}

class _WobblyLetterState extends State<_WobblyLetter>
    with SingleTickerProviderStateMixin {
  /// Seconds since the letter appeared. A clock, not a loop: nothing here
  /// repeats, so neither does the motion.
  final _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker;

  /// Per axis (x, y, tilt): two phases and the speed of the first wave.
  late final List<double> _phases;
  late final List<double> _speeds;

  /// Seconds for the first wave to come round once.
  static const _period = 7.0;

  /// The second wave's speed over the first's. Irrational, so the two never
  /// come back into line and the sum never retraces itself.
  static const _ratio = 1.6180339887;

  @override
  void initState() {
    super.initState();
    _phases = [for (var i = 0; i < 6; i++) widget.rng.nextDouble() * 2 * pi];
    _speeds = [for (var i = 0; i < 3; i++) 0.7 + widget.rng.nextDouble() * 0.6];
    _ticker = createTicker(
      (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
    )..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  /// -1..1: the sum of two waves whose speeds never line up.
  double _drift(int axis, double t) {
    final w = t * 2 * pi / _period * _speeds[axis];
    return (sin(w + _phases[axis * 2]) +
            sin(w * _ratio + _phases[axis * 2 + 1])) /
        2;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _seconds,
      builder: (context, t, child) {
        final wobble = widget.maxOffset;
        return Transform.translate(
          offset: Offset(_drift(0, t) * wobble, _drift(1, t) * wobble),
          child: Transform.rotate(
            angle: _drift(2, t) * 0.0125 * wobble,
            child: child,
          ),
        );
      },
      child: Text(
        widget.char == ' ' ? '\u00A0' : widget.char,
        style: context.tokens.wordmark(TextStyle(fontSize: widget.fontSize)),
      ),
    );
  }
}
