/// Onboarding, before the rotation: let a bot write the program. The steps
/// to connect one over MCP are all here (the address to copy and buttons to
/// where it goes); the person allows it on the server's
/// connect page and tells it their goals, and the program it sets streams
/// back here. While this page is up it looks again every few seconds and
/// each time the app comes back to the front; when workouts arrive it lists
/// them and finishing keeps them (the core adds no library templates to a
/// program that already has workouts).
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/workout.pb.dart' show WorkoutTemplate;
import '../../../logic/website.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/theme_spec.dart';
import '../../../widgets/common/flat.dart';
import '../widgets/onboarding_page.dart';

/// How often to look for the bot's program while this page is up.
const _poll = Duration(seconds: 4);

/// The address a bot connects to: the MCP endpoint of this build's server.
final _mcpAddress = websiteUri('/api/mcp').toString();

/// Where Claude adds a custom connector.
final _claudeConnectors = Uri.https('claude.ai', '/settings/connectors');

/// Where ChatGPT adds one.
final _chatgptConnectors = Uri.parse(
  'https://chatgpt.com/#settings/Connectors',
);

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
    if (widget.workouts.isEmpty) {
      _timer = Timer.periodic(_poll, (_) => unawaited(_refresh()));
    }
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

  Future<void> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final t = copy.onboarding.bot;
    final done = widget.workouts.isNotEmpty;

    return OnboardingPage(
      title: t.title,
      body: t.body,
      onBack: widget.onBack,
      backEnabled: !widget.isSaving,
      primary: done
          ? OnboardingNext(
              label: t.finish,
              onPressed: widget.onFinish,
              busy: widget.isSaving,
            )
          : OutlinedButton(onPressed: widget.onSkip, child: Text(t.skip)),
      children: done
          ? [
              FlatHeading(t.done),
              for (final w in widget.workouts) FlatRow(label: w.name),
            ]
          : [
              FlatHeading('1  ${t.stepAddress}'),
              _CopyRow(text: _mcpAddress),
              FlatSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _open(_claudeConnectors),
                            icon: const Icon(AppIcons.openExternal),
                            label: Text(t.openClaude),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _open(_chatgptConnectors),
                            icon: const Icon(AppIcons.openExternal),
                            label: Text(t.openChatgpt),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.anyAi,
                      style: TextStyle(
                        fontSize: tk.size.caption,
                        color: tk.muted,
                      ),
                    ),
                  ],
                ),
              ),
              FlatHeading('2  ${t.stepGoals}'),
              FlatSection(
                child: Text(
                  t.goalsText,
                  style: TextStyle(fontSize: tk.size.bodyLg, height: 1.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FlatSection.margin,
                  10,
                  FlatSection.margin,
                  10,
                ),
                child: Text(
                  t.waiting,
                  style: TextStyle(
                    fontSize: tk.size.small,
                    height: 1.4,
                    color: tk.muted,
                  ),
                ),
              ),
            ],
    );
  }
}

/// [text] as a full-width row, with a button that copies it.
class _CopyRow extends StatefulWidget {
  final String text;
  const _CopyRow({required this.text});

  @override
  State<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<_CopyRow> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final t = copy.onboarding.bot;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _copy,
        child: Container(
          padding: const EdgeInsets.fromLTRB(FlatSection.margin, 6, 4, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.text,
                  style: tk.mono(TextStyle(fontSize: tk.size.small)),
                ),
              ),
              TextButton.icon(
                onPressed: _copy,
                icon: Icon(_copied ? AppIcons.check : AppIcons.copy),
                label: Text(_copied ? t.copied : t.copy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
