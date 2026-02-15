import 'dart:math';
import 'package:flutter/material.dart';

class WobblyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final int seed;
  final double maxOffset;

  const WobblyText({
    super.key,
    required this.text,
    this.fontSize = 48,
    this.seed = 42,
    this.maxOffset = 2,
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
          Transform.translate(
            offset: Offset(
              (rng.nextDouble() * 2 - 1) * maxOffset,
              (rng.nextDouble() * 2 - 1) * maxOffset,
            ),
            child: Transform.rotate(
              angle: (rng.nextDouble() * 2 - 1) * 0.05,
              child: Text(
                ch,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
