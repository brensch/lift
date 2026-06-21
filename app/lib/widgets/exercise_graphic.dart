import 'package:flutter/material.dart';

import '../gen/workout/v1/workout.pbenum.dart';
import 'exercise_art/registry.dart';
import 'exercise_art/toolkit.dart';

/// A themed, animated line-art illustration of an exercise.
///
/// Looks the drawing up in the exercise-art registry (one file per proto name)
/// and loops its key poses back and forth so the movement animates. The figure
/// adapts to light/dark via [color]; machines render grey.
class ExerciseGraphic extends StatefulWidget {
  final Exercise exercise;
  final double size;

  /// Figure stroke colour. Defaults to the theme's onSurface.
  final Color? color;

  /// Loop the movement. Set false for a still (renders the end pose).
  final bool animate;

  const ExerciseGraphic({
    super.key,
    required this.exercise,
    this.size = 48,
    this.color,
    this.animate = true,
  });

  @override
  State<ExerciseGraphic> createState() => _ExerciseGraphicState();
}

class _ExerciseGraphicState extends State<ExerciseGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    // Ease in/out and hold briefly at each end so the movement reads.
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ExerciseGraphic old) {
    super.didUpdateWidget(old);
    if (widget.animate != old.animate) {
      if (widget.animate) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final figure = widget.color ?? Theme.of(context).colorScheme.onSurface;
    final art = artFor(widget.exercise);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) => CustomPaint(
          painter: ExerciseArtPainter(
            art: art,
            figureColor: figure,
            t: widget.animate ? _t.value : 1.0,
          ),
        ),
      ),
    );
  }
}
