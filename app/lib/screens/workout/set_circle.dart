/// A set, drawn as a circle with a number in it: the whole of logging a
/// workout. Tap the up-next circle to start the set, tap it again when it is
/// done (every rep), and once more for each rep you missed.
library;

import 'package:flutter/material.dart';

import '../../theme/theme_spec.dart';

/// What a circle shows. The number is the target until the set is done,
/// then the reps logged.
enum SetCircleState {
  /// Still to do.
  pending,

  /// The set to do next: a ring in the workout's state colour.
  next,

  /// Started and not done: filled orange, pulsing.
  lifting,

  /// Done, every rep.
  full,

  /// Done, short of the target.
  short,

  /// Done with no reps.
  zero,

  /// A warmup skipped or moved past: a dash. It can still be started.
  skipped,
}

class SetCircle extends StatefulWidget {
  final int number;
  final SetCircleState state;

  /// A warmup: quieter, no progression rides on it.
  final bool small;

  final VoidCallback? onTap;

  /// The up-next ring's colour: the workout's current state (blue resting,
  /// pink yapping, orange otherwise).
  final Color? nextColor;

  const SetCircle({
    super.key,
    required this.number,
    required this.state,
    this.small = false,
    this.onTap,
    this.nextColor,
  });

  /// Every circle is this size; a row with more than fit scrolls.
  static const double diameter = 64;

  @override
  State<SetCircle> createState() => _SetCircleState();
}

class _SetCircleState extends State<SetCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(SetCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.state == SetCircleState.lifting) {
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
    const size = SetCircle.diameter;
    final (fill, ring, ink) = switch (widget.state) {
      SetCircleState.pending => (Colors.transparent, t.outline, t.muted),
      SetCircleState.next => (
        Colors.transparent,
        widget.nextColor ?? t.primary,
        widget.nextColor ?? t.primary,
      ),
      SetCircleState.lifting => (t.lifting, t.lifting, t.onPrimary),
      SetCircleState.full => (t.text, t.text, t.background),
      SetCircleState.short => (t.effort, t.effort, t.text),
      SetCircleState.zero => (Colors.transparent, t.effort, t.effort),
      SetCircleState.skipped => (Colors.transparent, t.hairline, t.muted),
    };
    final quiet = widget.small && widget.state == SetCircleState.pending;
    const shape = CircleBorder();

    return Semantics(
      button: widget.onTap != null,
      label: '${widget.number}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => DecoratedBox(
            decoration: ShapeDecoration(
              shape: shape,
              shadows: widget.state == SetCircleState.lifting
                  ? [
                      BoxShadow(
                        color: t.lifting.withValues(alpha: 0.28),
                        spreadRadius: 6 * _pulse.value,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: fill,
              shape: shape.copyWith(
                side: BorderSide(
                  color: quiet ? ring.withValues(alpha: 0.6) : ring,
                  width: widget.state == SetCircleState.next ? 2 : 1.5,
                ),
              ),
            ),
            child: Text(
              widget.state == SetCircleState.skipped ? '–' : '${widget.number}',
              style: t.mono(
                TextStyle(
                  fontSize: t.size.headline,
                  fontWeight: t.weight.bold,
                  color: ink,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
