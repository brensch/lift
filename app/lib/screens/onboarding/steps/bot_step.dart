/// Onboarding, before the rotation: let a bot write the program. The
/// button opens the website's /bot page (how to connect an assistant over
/// MCP); the person allows it there and tells it their goals, and the
/// program it sets streams back here. While this page is up it looks
/// again each time the app comes back to the front, and every few seconds
/// once the person has gone to connect; when workouts arrive it lists them
/// and finishing keeps them (the core adds no library templates to a
/// program that already has workouts).
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/workout.pb.dart' show WorkoutTemplate;
import '../../../logic/website.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/theme_spec.dart';

/// How often to look for the bot's program once the person went to connect.
const _poll = Duration(seconds: 4);

class BotStep extends StatefulWidget {
  /// The program's workouts as they are now: empty until a bot sets some.
  final List<WorkoutTemplate> workouts;

  /// Look again for workouts (the home, refreshed).
  final Future<void> Function() onRefresh;
  final bool isSaving;
  final VoidCallback onBack;

  /// On to picking a rotation from the library.
  final VoidCallback onSkip;

  /// Finish setup with the workouts the bot set.
  final VoidCallback onFinish;

  const BotStep({
    super.key,
    required this.workouts,
    required this.onRefresh,
    required this.isSaving,
    required this.onBack,
    required this.onSkip,
    required this.onFinish,
  });

  @override
  State<BotStep> createState() => _BotStepState();
}

class _BotStepState extends State<BotStep> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_refresh()));
  }

  @override
  void didUpdateWidget(BotStep old) {
    super.didUpdateWidget(old);
    // It arrived: nothing more to wait for.
    if (widget.workouts.isNotEmpty) _stopPolling();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _stopPolling();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (widget.workouts.isNotEmpty) return;
    await widget.onRefresh();
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _connect() async {
    _timer ??= Timer.periodic(_poll, (_) => unawaited(_refresh()));
    await launchUrl(websiteUri('/bot'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.onboarding.bot;
    final done = widget.workouts.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.title,
            style: TextStyle(
              fontSize: context.tokens.size.headline,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.body,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          if (done) ...[
            Text(
              t.done,
              style: TextStyle(
                fontSize: context.tokens.size.small,
                fontWeight: context.tokens.weight.heavy,
                color: cs.tertiary,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final w in widget.workouts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        w.name,
                        style: TextStyle(
                          fontSize: context.tokens.size.title,
                          fontWeight: context.tokens.weight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _connect,
                icon: const Icon(AppIcons.bot),
                label: Text(
                  t.button,
                  style: TextStyle(fontWeight: context.tokens.weight.heavy),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.hint,
              style: TextStyle(
                fontSize: context.tokens.size.small,
                height: 1.4,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
          ],
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: widget.isSaving ? null : widget.onBack,
                    child: Text(copy.onboarding.back),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: done
                      ? FilledButton(
                          onPressed: widget.isSaving ? null : widget.onFinish,
                          child: widget.isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  t.finish,
                                  style: TextStyle(
                                    fontWeight: context.tokens.weight.heavy,
                                  ),
                                ),
                        )
                      : OutlinedButton(
                          onPressed: widget.onSkip,
                          child: Text(t.skip),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
