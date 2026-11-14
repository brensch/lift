/// The walkthrough: the real app (header, home, bottom bar) running on a sample account inside a sandbox, with one piece at a
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
import '../services/page_tracker.dart';
import '../theme/theme_spec.dart';
import '../services/local_core.dart';
import '../services/workout_service.dart';
import '../tutorial/tutorial_account.dart';
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

  /// The sample account, in memory; ready once it's been built.
  final _account = Completer<TutorialAccount>();
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

  /// The step's target, where it is this frame.
  Rect? _target;

  /// Which side of the target the card sits, decided once a step: below,
  /// unless the step's scroll leaves too little room there. Never decided
  /// per frame, so the card doesn't hop sides mid-scroll.
  bool _below = true;

  /// The sample account is still being built: taps wait.
  bool _busy = true;

  /// The first step has been shown; until then there is nothing to point at.
  bool _started = false;

  List<CopyTutorialStepsItem> get _steps => copy.tutorial.steps;

  @override
  void initState() {
    super.initState();
    unawaited(
      TutorialAccount.create(
        context.read<SettingsProvider>().weightUnit,
      ).then(_account.complete),
    );
    _workouts = WorkoutProvider(
      WorkoutServiceWrapper(_SandboxCore(_account.future)),
      context.read<SettingsProvider>(),
      sandbox: true,
      // Short enough that every sample workout fills it: the time control
      // shows an estimate, never its cap.
      budgetMinutes: 45,
    );
    _registry.addListener(_measure);
    // The pulse ticks every frame: follow the target on it, so the outline
    // and the card stay on it as the page scrolls or its content settles.
    _throb.addListener(_follow);
    // The sandbox account, then the first step once home has laid out.
    unawaited(
      _workouts.refreshHome().then((_) async {
        _busy = false;
        await _enter(0, forward: true);
        if (mounted) setState(() => _started = true);
      }),
    );
  }

  @override
  void dispose() {
    _registry.removeListener(_measure);
    _registry.dispose();
    _throb.dispose();
    _workouts.dispose();
    unawaited(_account.future.then((account) => account.core.close()));
    _multiplayer.dispose();
    super.dispose();
  }

  /// Move to [index]: give the screen a frame, then scroll the target into
  /// view and measure it.
  Future<void> _enter(int index, {required bool forward}) async {
    if (_busy) return;
    // The old step stays on screen, outline and all, until the new one
    // has been measured; then text and position change in one frame.
    _pending = index;
    final step = _steps[index];
    // Named by position and target, not by the copy, which gets rewritten.
    PageTracker.instance.enter(
      'tutorial/${(index + 1).toString().padLeft(2, '0')}-${step.target}',
    );
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
    // The new step at once: the outline rides its target (`_follow`) while
    // the page scrolls it into view, one motion rather than two.
    setState(() {
      _step = index;
      _pending = null;
      _target = ctx == null ? null : _rectOf(ctx) ?? _target;
      _below = true;
    });
    if (ctx == null) return;
    // Near the top, so the card has room under it.
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // Measured once the scroll's last frame is laid out.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !ctx.mounted) return;
    final rect = _rectOf(ctx);
    final stage = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (rect == null || stage == null || !stage.hasSize) return;
    final below = _Popover.fitsBelow(
      rect,
      Offset.zero & stage.size,
      MediaQuery.paddingOf(context),
    );
    if (below != _below) setState(() => _below = below);
  }

  /// Where [ctx]'s box is on the stage, or null before it is laid out.
  Rect? _rectOf(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    final overlay = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || overlay == null) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  }

  /// Each frame: where the shown step's target is now, so the outline sits
  /// exactly on it as the page scrolls to it or its content settles.
  void _follow() {
    if (_pending != null || _target == null) return;
    final ctx = _registry.contextFor(_steps[_step].target);
    final now = ctx == null ? null : _rectOf(ctx);
    if (now != null && now != _target) setState(() => _target = now);
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
                  // header, home and the bottom bar.
                  const IgnorePointer(child: MainLayout(child: WorkoutTab())),
                  // Everything else dims; the target shows through.
                  if (_started) ...[
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _throb,
                        builder: (context, _) => CustomPaint(
                          painter: _SpotlightPainter(
                            outline: context.tokens.primary,
                            scrim: context.tokens.scrim,
                            radius: Radius.circular(context.tokens.radiusLg),
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
                      below: _below,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The dim layer with a hole around the target and its orange outline.
class _SpotlightPainter extends CustomPainter {
  final Rect? target;
  final double throb;
  final Color outline;
  final Color scrim;

  _SpotlightPainter({
    required this.target,
    required this.throb,
    required this.outline,
    required this.scrim,
    required Radius radius,
  }) : _radius = radius;

  final Radius _radius;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final shade = Paint()..color = scrim;
    final t = target;
    if (t == null) {
      canvas.drawPath(full, shade);
      return;
    }
    final hole = t.inflate(6);
    final holePath = Path()..addRRect(RRect.fromRectAndRadius(hole, _radius));
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, holePath),
      shade,
    );
    // A crisp orange outline that beats a little thicker, no glow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, _radius),
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + 2 * throb,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target ||
      old.throb != throb ||
      old.outline != outline ||
      old.scrim != scrim;
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

  /// The side the card sits on (the screen decides it once a step).
  final bool below;

  const _Popover({
    required this.step,
    required this.index,
    required this.count,
    required this.target,
    required this.bounds,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
    required this.below,
  });

  static const _margin = 12.0;
  static const _gap = 16.0;
  static const _needed = 210.0; // title, three lines, the buttons

  bool get _last => index == count - 1;

  /// Whether the card fits under [target]: below unless the room there is
  /// short of what it needs and the room above is more.
  static bool fitsBelow(Rect target, Rect bounds, EdgeInsets padding) {
    final roomBelow =
        bounds.bottom - padding.bottom - _margin - (target.bottom + _gap);
    final roomAbove = target.top - _gap - padding.top - _margin;
    return roomBelow >= _needed || roomBelow >= roomAbove;
  }

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
      color: context.tokens.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outline),
        borderRadius: context.tokens.brMd,
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
                      style: TextStyle(
                        fontSize: context.tokens.size.title,
                        fontWeight: context.tokens.weight.heavy,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.body,
                      style: TextStyle(
                        fontSize: context.tokens.size.bodyLg,
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
                              settings: const RouteSettings(name: 'science'),
                              builder: (_) => const ScienceScreen(),
                            ),
                          ),
                          icon: Text(
                            '🧠',
                            style: TextStyle(
                              fontSize: context.tokens.size.bodyLg,
                            ),
                          ),
                          label: Text(
                            t.papersButton,
                            style: TextStyle(
                              fontWeight: context.tokens.weight.heavy,
                            ),
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
                      style: TextStyle(fontWeight: context.tokens.weight.heavy),
                    ),
                  ),
                // The labels come from copy.yaml, so a long one wraps the
                // buttons onto a second line rather than overflowing the card.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: onPrevious,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: Text(
                            t.previous,
                            style: TextStyle(
                              fontWeight: context.tokens.weight.heavy,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: Text(
                            _last ? t.finish : t.next,
                            style: TextStyle(
                              fontWeight: context.tokens.weight.heavy,
                            ),
                          ),
                        ),
                      ),
                    ],
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

/// The sample account as a [CoreSource], open once built.
class _SandboxCore implements CoreSource {
  final Future<TutorialAccount> _account;

  const _SandboxCore(this._account);

  @override
  Future<LocalCore> get ready => _account.then((account) => account.core);
}
