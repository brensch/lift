/// The walkthrough: the real app (header, home, active workout, bottom
/// bar) running on a sample account inside a sandbox, with one piece at a
/// time picked out by a throbbing red outline and explained in a popover
/// beside it. The popover carries BACK / NEXT / SKIP. Steps and every word
/// come from app/copy.yaml (gen/copy.dart). Shown once on first arrival at
/// home, and replayable from the menu ("Tutorial").
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
import '../tutorial/tutorial_service.dart';
import '../tutorial/tutorial_target.dart';
import '../widgets/main_layout.dart';
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
    // The old step stays on screen, outline and all, until the new one
    // has been measured; then text and position change in one frame.
    _pending = index;
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

  /// The step being moved to while its target is measured; null once
  /// shown. Registry notifications re-measure the shown step.
  int? _pending;

  Future<void> _measure() async {
    if (!mounted) return;
    final index = _pending ?? _step;
    final ctx = _registry.contextFor(_steps[index].target);
    if (ctx == null) {
      setState(() {
        _step = index;
        _pending = null;
        _target = null;
      });
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
    setState(() {
      _step = index;
      _pending = null;
      _target = topLeft & box.size;
    });
  }

  void _next() {
    if (_busy) return;
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
    final step = _steps[_step];

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WorkoutProvider>.value(value: _workouts),
        ChangeNotifierProvider<MultiplayerProvider>.value(value: _multiplayer),
      ],
      child: TutorialScope(
        registry: _registry,
        // The sandbox's layout guards the back button for the real app;
        // here it is ours.
        child: PopScope(
          canPop: false,
          // The system back button steps back; on the first step it
          // leaves the tutorial.
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !mounted) return;
            if (_step > 0) {
              _previous();
            } else {
              Navigator.pop(context);
            }
          },
          child: LayoutBuilder(
            key: _stageKey,
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // The real app on the sandbox account, not tappable:
                  // header, home or workout, and the bottom bar.
                  const IgnorePointer(
                    child: MainLayout(currentPath: '/', child: WorkoutTab()),
                  ),
                  // Everything else dims; the target shows through.
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
                    index: _step,
                    count: _steps.length,
                    target: _target,
                    bounds: Offset.zero & constraints.biggest,
                    onPrevious: _step > 0 ? _previous : null,
                    onNext: _next,
                    onSkip: () => Navigator.pop(context),
                  ),
                ],
              );
            },
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

/// The explanation with the controls: placed below the target when there
/// is room, otherwise above, never over it; centred when there is no
/// target to point at.
class _Popover extends StatelessWidget {
  final CopyTutorialStepsItem step;
  final int index;
  final int count;
  final Rect? target;
  final Rect bounds;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _Popover({
    required this.step,
    required this.index,
    required this.count,
    required this.target,
    required this.bounds,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
  });

  static const _margin = 12.0;
  static const _gap = 16.0;
  static const _needed = 210.0; // title, three lines, the buttons

  bool get _last => index == count - 1;

  @override
  Widget build(BuildContext context) {
    final card = _card(context);
    final t = target;
    final topSafe = MediaQuery.paddingOf(context).top + _margin;
    final bottomSafe = MediaQuery.paddingOf(context).bottom + _margin;
    if (t == null) {
      return Positioned(
        left: _margin,
        right: _margin,
        top: bounds.height * 0.3,
        child: card,
      );
    }
    final roomBelow = bounds.bottom - bottomSafe - (t.bottom + _gap);
    final roomAbove = t.top - _gap - topSafe;
    final below = roomBelow >= roomAbove;
    // A tall target on a short screen can leave less than the card needs
    // on either side; then the card creeps over the target's far edge by
    // the shortfall rather than clipping its text.
    final room = below ? roomBelow : roomAbove;
    final overlap = (_needed - room).clamp(0.0, _needed);
    return Positioned(
      left: _margin,
      right: _margin,
      top: below ? t.bottom + _gap - overlap : null,
      bottom: below ? null : bounds.height - (t.top - _gap) - overlap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (room + overlap).clamp(_needed, 460.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (below) const _Arrow(up: true),
            Flexible(child: card),
            if (!below) const _Arrow(up: false),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.tutorial;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    return Material(
      color: cs.surface,
      elevation: 16,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.brLg,
        side: BorderSide(color: cs.onSurface.withValues(alpha: 0.35), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
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
                    if (_last)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ScienceScreen(),
                            ),
                          ),
                          icon: const Text(
                            '🧠',
                            style: TextStyle(fontSize: 15),
                          ),
                          label: Text(
                            t.papersButton,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!_last)
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: muted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                      t.skip,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: onPrevious,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      t.previous,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Text(
                      _last ? t.finish : t.next,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    return CustomPaint(
      size: const Size(24, 12),
      painter: _ArrowPainter(
        fill: cs.surface,
        edge: cs.onSurface.withValues(alpha: 0.35),
        up: up,
      ),
    );
  }
}

/// The popover's pointer, outlined on its two exposed sides so it reads as
/// part of the card.
class _ArrowPainter extends CustomPainter {
  final Color fill;
  final Color edge;
  final bool up;
  _ArrowPainter({required this.fill, required this.edge, required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final tip = Offset(size.width / 2, up ? 0 : size.height);
    final left = Offset(0, up ? size.height : 0);
    final right = Offset(size.width, up ? size.height : 0);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      Paint()..color = fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(right.dx, right.dy),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.fill != fill || old.edge != edge || old.up != up;
}
