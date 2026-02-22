import 'dart:math';
import 'package:flutter/material.dart';

class WobblyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final int seed;

  const WobblyText({
    super.key,
    required this.text,
    this.fontSize = 48,
    this.seed = 42,
    double maxOffset = 2, // Kept for signature compatibility
  });

  @override
  Widget build(BuildContext context) {
    final rng = Random(seed);
    final letters = text.split('');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final ch in letters)
          _WobblyLetter(
            char: ch,
            fontSize: fontSize,
            rng: rng,
          ),
      ],
    );
  }
}

class _WobblyLetter extends StatefulWidget {
  final String char;
  final double fontSize;
  final Random rng;

  const _WobblyLetter({
    required this.char,
    required this.fontSize,
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
        final dx = sin(t * 0.4 + dxSeed) * 0.8;
        final dy = cos(t * 0.5 + dySeed) * 0.8;
        final angle = sin(t * 0.3 + rotateSeed) * 0.01;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: Text(
              widget.char == ' ' ? '\u00A0' : widget.char,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      },
    );
  }
}
