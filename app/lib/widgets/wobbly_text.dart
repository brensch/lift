import 'dart:math';
import 'package:flutter/material.dart';

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
  late AnimationController _controller;
  late double dxSeed;
  late double dySeed;
  late double rotateSeed;
  late double durationFactor;

  @override
  void initState() {
    super.initState();
    dxSeed = widget.rng.nextDouble() * 2 * pi;
    dySeed = widget.rng.nextDouble() * 2 * pi;
    rotateSeed = widget.rng.nextDouble() * 2 * pi;
    durationFactor = 0.5 + widget.rng.nextDouble();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * pi;
        final wobble = widget.maxOffset;
        final dx = sin(t * 0.4 + dxSeed) * wobble;
        final dy = cos(t * 0.5 + dySeed) * wobble;
        final angle = sin(t * 0.3 + rotateSeed) * 0.0125 * wobble;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: Text(
              widget.char == ' ' ? '\u00A0' : widget.char,
              style: context.tokens.wordmark(
                TextStyle(fontSize: widget.fontSize),
              ),
            ),
          ),
        );
      },
    );
  }
}
