/// Text with an animated rainbow shimmer. Generic celebration effect.
library;

import 'package:flutter/material.dart';

class RainbowShimmerText extends StatefulWidget {
  final String text;
  const RainbowShimmerText({super.key, required this.text});

  @override
  State<RainbowShimmerText> createState() => RainbowShimmerTextState();
}

class RainbowShimmerTextState extends State<RainbowShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
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
        final t = _controller.value;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
            stops: const [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0],
            begin: Alignment(-2.0 + 4 * t, 0),
            end: Alignment(0.0 + 4 * t, 0),
            tileMode: TileMode.repeated,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: child!,
        );
      },
      child: Text(
        widget.text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
          color: Colors.white, // overridden by ShaderMask
        ),
      ),
    );
  }
}

// ─── Horizontal shake wrapper ─────────────────────────────────────────────────
