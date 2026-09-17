/// The walkthrough: the real home and workout screens, running on a sample
/// account inside a sandbox, with one piece at a time picked out by a
/// throbbing red outline and explained in a popover beside it. Steps and
/// every word come from app/copy.yaml (gen/copy.dart). Shown once on first
/// arrival at home, and replayable from the menu ("Tutorial").
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/grpc_client.dart';
import '../services/multiplayer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/workout_bar/workout_bottom_bar.dart';
import '../tutorial/tutorial_service.dart';
import '../tutorial/tutorial_target.dart';
import 'science_screen.dart';
import 'workout_tab.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  final TutorialRegistry _registry = TutorialRegistry();
  late final TutorialWorkoutService _service = TutorialWorkoutService();
  late final WorkoutProvider _workouts;
  late final MultiplayerProvider _multiplayer = MultiplayerProvider(
    MultiplayerServiceWrapper(GrpcClient(host: '127.0.0.1', port: 1)),
  );
  late final AnimationController _throb = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  final GlobalKey _stageKey = GlobalKey();
  int _step = 0;
  Rect? _target;
  bool _busy = false;

  List<CopyTutorialStepsItem> get _steps => copy.tutorial.steps;

  @override
  void initState() {
    super.initState();
    _workouts = WorkoutProvider(
      _service,
      context.read<SettingsProvider>(),
      persistLocally: false,
    );
    _registry.addListener(_measure);
    // The sandbox account, then the first step once home has laid out.
    unawaited(_workouts.refreshHome().then((_) => _enter(0, forward: true)));
  }

  @override
  void dispose() {
    _registry.removeListener(_measure);
    _registry.dispose();
    _throb.dispose();
    _workouts.dispose();
    _multiplayer.dispose();
    super.dispose();
  }

  /// Move to [index]: run the step's action (the sandbox's workout starts,
  /// its first set starts), give the screen a frame, then scroll the target
  /// into view and measure it.
  Future<void> _enter(int index, {required bool forward}) async {
    if (_busy) return;
    _busy = true;
    setState(() {
      _step = index;
      _target = null;
    });
    final step = _steps[index];
    try {
      if (step.screen == 'workout' && !_workouts.hasActiveWorkout) {
        await _workouts.startWorkout(
          '',
          templateId: TutorialWorkoutService.suggestedTemplateId,
        );
      } else if (step.screen == 'home' && _workouts.hasActiveWorkout) {
        await _workouts.endWorkout(fireEndedCallback: false);
        await _workouts.refreshHome();
      }
      if (forward && step.action == 'start_set') {
        final next = _workouts.nextPendingSet;
        if (next != null && _workouts.activeSetId == null) {
          await _workouts.startSet(next.id);
        }
      }
    } finally {
      _busy = false;
    }
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    await _measure();
  }

  Future<void> _measure() async {
    if (!mounted) return;
    final ctx = _registry.contextFor(_steps[_step].target);
    if (ctx == null) {
      setState(() => _target = null);
      return;
    }
    // Bring it on screen first; the ListView on home is tall.
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (!mounted || !ctx.mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !ctx.mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final overlay = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    setState(() => _target = topLeft & box.size);
  }

  void _next() {
    if (_step == _steps.length - 1) {
      Navigator.pop(context);
    } else {
      _enter(_step + 1, forward: true);
    }
  }

  void _previous() {
    if (_step > 0) _enter(_step - 1, forward: false);
  }

  @override
  Widget build(BuildContext context) {
    final t = copy.tutorial;
    final step = _steps[_step];
    final last = _step == _steps.length - 1;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkoutProvider>.value(value: _workouts),
        ChangeNotifierProvider<MultiplayerProvider>.value(value: _multiplayer),
      ],
      child: TutorialScope(
        registry: _registry,
        child: Scaffold(
          body: Column(
            children: [
              // The stage: the real screens on the sandbox account, not
              // tappable, with the dim layer and the popover over them.
              Expanded(
                child: LayoutBuilder(
                  key: _stageKey,
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: Scaffold(
                            body: const WorkoutTab(),
                            bottomNavigationBar: WorkoutBottomBar(
                              key: ValueKey(
                                _workouts.activeWorkout?.id ?? 'none',
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _throb,
                            builder: (context, _) => CustomPaint(
                              painter: _SpotlightPainter(
                                target: _target,
                                throb: Curves.easeInOut.transform(_throb.value),
                              ),
                            ),
                          ),
                        ),
                        _Popover(
                          step: step,
                          target: _target,
                          bounds: Offset.zero & constraints.biggest,
                          last: last,
                        ),
                        Positioned(
                          top: MediaQuery.paddingOf(context).top + 4,
                          right: 8,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              t.skip,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _BottomBar(
                step: _step,
                count: _steps.length,
                onPrevious: _step > 0 ? _previous : null,
                onNext: _next,
                nextLabel: last ? t.finish : t.next,
                previousLabel: t.previous,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dim layer with a hole around the target and the throbbing outline.
class _SpotlightPainter extends CustomPainter {
  final Rect? target;
  final double throb;

  _SpotlightPainter({required this.target, required this.throb});

  static const _radius = Radius.circular(18);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final t = target;
    if (t == null) {
      canvas.drawPath(full, scrim);
      return;
    }
    final hole = t.inflate(6);
    final holePath = Path()..addRRect(RRect.fromRectAndRadius(hole, _radius));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, holePath),
      scrim,
    );
    // Glow, then the outline on top.
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, _radius),
      Paint()
        ..color = AppTheme.accentRed.withValues(alpha: 0.35 + 0.35 * throb)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 + 10 * throb
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 10 * throb),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, _radius),
      Paint()
        ..color = AppTheme.accentRed.withValues(alpha: 0.8 + 0.2 * throb)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target || old.throb != throb;
}

/// The explanation, placed below the target when there is room, otherwise
/// above, never over it; centred when there is no target to point at.
class _Popover extends StatelessWidget {
  final CopyTutorialStepsItem step;
  final Rect? target;
  final Rect bounds;
  final bool last;

  const _Popover({
    required this.step,
    required this.target,
    required this.bounds,
    required this.last,
  });

  static const _margin = 16.0;
  static const _gap = 18.0;

  @override
  Widget build(BuildContext context) {
    final card = _card(context);
    final t = target;
    if (t == null) {
      return Positioned(
        left: _margin,
        right: _margin,
        top: bounds.height * 0.3,
        child: card,
      );
    }
    final topSafe = MediaQuery.paddingOf(context).top + 48;
    final roomBelow = bounds.bottom - _margin - (t.bottom + _gap);
    final roomAbove = t.top - _gap - topSafe;
    final below = roomBelow >= roomAbove;
    return Positioned(
      left: _margin,
      right: _margin,
      top: below ? t.bottom + _gap : null,
      bottom: below ? null : bounds.height - (t.top - _gap),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (below ? roomBelow : roomAbove).clamp(120.0, 420.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (below) _Arrow(up: true),
            Flexible(child: card),
            if (!below) _Arrow(up: false),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 16,
      shadowColor: Colors.black,
      borderRadius: AppTheme.brLg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.body,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
              if (last)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ScienceScreen(),
                      ),
                    ),
                    icon: const Text('🧠', style: TextStyle(fontSize: 15)),
                    label: Text(
                      copy.tutorial.papersButton,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final bool up;
  const _Arrow({required this.up});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(22, 11),
        painter: _ArrowPainter(color: cs.surface, up: up),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool up;
  _ArrowPainter({required this.color, required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height)
            ..close())
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0)
            ..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color || old.up != up;
}

class _BottomBar extends StatelessWidget {
  final int step;
  final int count;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final String nextLabel;
  final String previousLabel;

  const _BottomBar({
    required this.step,
    required this.count,
    required this.onPrevious,
    required this.onNext,
    required this.nextLabel,
    required this.previousLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 48,
            child: OutlinedButton(
              onPressed: onPrevious,
              child: Text(
                previousLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(count, (i) {
                return Container(
                  width: i == step ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: i == step
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
          SizedBox(
            width: 124,
            height: 48,
            child: FilledButton(
              onPressed: onNext,
              child: Text(
                nextLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
