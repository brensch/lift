/// Connecting an AI over MCP, the same wherever it is offered (setup's bot
/// step, the menu's Connect AI page): the connector's address to copy,
/// buttons to where Claude and ChatGPT add one, and what to say to it. And
/// the line at the top of the screens a person edits their program on,
/// pointing at it.
library;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen/copy.dart';
import '../logic/website.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';
import 'common/flat.dart';

/// The address an AI connects to: the MCP endpoint of this build's server.
final _mcpAddress = websiteUri('/api/mcp').toString();

/// Where Claude adds a custom connector.
final _claudeConnectors = Uri.https('claude.ai', '/settings/connectors');

/// Where ChatGPT adds one.
final _chatgptConnectors = Uri.parse(
  'https://chatgpt.com/#settings/Connectors',
);

Future<void> _open(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The two steps, as full-width sections.
class ConnectAiSteps extends StatelessWidget {
  const ConnectAiSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final t = copy.onboarding.bot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                style: TextStyle(fontSize: tk.size.caption, color: tk.muted),
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

/// At the top of a screen that edits the program by hand: why not let an
/// AI do it, and a way to connect one. A full-width row like the rest.
class LetAiDoIt extends StatelessWidget {
  const LetAiDoIt({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final t = copy.connectAi;
    return Material(
      color: tk.primary.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => context.push('/connect-ai'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(FlatSection.margin, 12, 8, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tk.hairline)),
          ),
          child: Row(
            children: [
              Icon(AppIcons.bot, size: tk.size.title, color: tk.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.peasant,
                  style: TextStyle(
                    fontSize: tk.size.body,
                    fontWeight: tk.weight.bold,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t.peasantButton,
                style: TextStyle(
                  fontSize: tk.size.small,
                  fontWeight: tk.weight.heavy,
                  color: tk.primary,
                ),
              ),
              Icon(AppIcons.forward, size: tk.size.body, color: tk.primary),
            ],
          ),
        ),
      ),
    );
  }
}
