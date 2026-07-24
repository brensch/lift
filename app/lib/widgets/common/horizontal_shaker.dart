/// Shakes its child horizontally on demand. Generic attention effect.
library;

import 'package:flutter/material.dart';

class HorizontalShaker extends StatefulWidget {
  final Widget child;
  final bool active;
  const HorizontalShaker({super.key, required this.child, required this.active});

  @override
  State<HorizontalShaker> createState() => HorizontalShakerState();
}

class HorizontalShakerState extends State<HorizontalShaker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _cycling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.active) _startCycle();
  }

  @override
  void didUpdateWidget(HorizontalShaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !old.active) _startCycle();
  }

  Future<void> _startCycle() async {
    if (_cycling) return;
    _cycling = true;
    while (mounted && widget.active) {
      await Future.delayed(const Duration(seconds: 4));
      if (mounted && widget.active) await _controller.forward(from: 0);
    }
    _cycling = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Transform.translate(
        offset: Offset(_animation.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─── Timer + heart rate box ───────────────────────────────────────────────────
