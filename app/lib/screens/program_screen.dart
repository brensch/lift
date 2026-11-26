/// Settings → Program: the document that plans every workout — who set it
/// (the app, or an assistant over MCP) and why, the ones before it, a way
/// back to the built-in rules — and the assistants allowed to set it.
library;

import 'package:fixnum/fixnum.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/assistant.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/utils.dart';
import '../logic/website.dart';
import '../providers/workout_provider.dart';
import '../services/grpc_client.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';
import '../widgets/suggestion_screen.dart';
import '../widgets/common/flat.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import 'program_document_screen.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  GetProgramResponse? _program;
  List<AssistantGrant>? _grants;
  bool _grantsFailed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The program is the phone's own (the core); the assistants are the
  /// server's, so they can be out of reach while the program isn't.
  Future<void> _load() async {
    final provider = context.read<WorkoutProvider>();
    final grpc = context.read<GrpcClient>();
    final program = await provider.getProgram();
    if (mounted) setState(() => _program = program);
    try {
      final listed = await grpc.assistantService.listAssistants(
        ListAssistantsRequest(),
      );
      if (mounted) {
        setState(() {
          _grants = listed.grants;
          _grantsFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _grantsFailed = true);
    }
  }

  Future<void> _reset() async {
    final t = copy.program;
    final provider = context.read<WorkoutProvider>();
    final sure = await confirmDialog(
      context,
      title: t.resetTitle,
      body: t.resetBody,
      confirm: t.resetConfirm,
      cancel: copy.home.deleteCancel,
      destructive: true,
    );
    if (!sure) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await provider.resetProgram();
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = t.resetFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(AssistantGrant grant) async {
    final grpc = context.read<GrpcClient>();
    setState(() => _error = null);
    try {
      await grpc.assistantService.revokeAssistant(
        RevokeAssistantRequest(grantId: grant.grantId),
      );
      if (mounted) {
        setState(
          () => _grants = [
            for (final g in _grants ?? const <AssistantGrant>[])
              if (g.grantId != grant.grantId) g,
          ],
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = copy.program.revokeFailed);
    }
  }

  /// Who an author is, in words: the app, Schlift, or the assistant's name.
  static String _author(String author) {
    final t = copy.program;
    if (author.startsWith('mcp:')) return author.substring(4);
    // Accepted from someone's suggestion: them, by name.
    if (author.startsWith('person:')) return author.substring(7);
    return switch (author) {
      'app' => t.authorApp,
      'migration' || 'builtin' || '' => t.authorBuiltin,
      _ => author,
    };
  }

  static String _date(Int64 seconds) =>
      dayDate(DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000));

  /// Who set [s] and when.
  static String _byline(ProgramSummary s) {
    final t = copy.program;
    if (s.id.isEmpty) return t.builtin;
    return [
      t.setBy.replaceAll('{author}', _author(s.author)),
      if (s.setAt > 0) t.setOn.replaceAll('{date}', _date(s.setAt)),
    ].join(' ');
  }

  /// One program: its name, who set it and when, and its note. Tapped, it
  /// opens: the program in use with its document in hand, an earlier one
  /// read, with a way back to it.
  Widget _summaryRow(
    ProgramSummary s, {
    required IconData icon,
    required bool current,
  }) {
    final by = _byline(s);
    return FlatRow(
      icon: icon,
      label: s.name.isEmpty ? copy.program.builtin : s.name,
      subtitle: s.note.isEmpty ? by : '$by\n${s.note}',
      onTap: () async {
        final changed = await showProgramDocument(
          context,
          summary: s,
          byline: by,
          json: current ? _program?.programJson : null,
          current: current,
        );
        if (changed) await _load();
      },
    );
  }

  Widget _grantRow(AssistantGrant g) {
    final t = copy.program;
    return FlatRow(
      icon: AppIcons.bot,
      label: g.clientName,
      subtitle: g.lastUsedAt > 0
          ? t.lastUsed.replaceAll('{date}', _date(g.lastUsedAt))
          : t.neverUsed,
      trailing: TextButton(onPressed: () => _revoke(g), child: Text(t.revoke)),
    );
  }

  /// A quiet line of text in a section.
  Widget _note(BuildContext context, String text, {bool error = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: context.tokens.size.body,
          color: error ? cs.error : cs.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = copy.program;
    final program = _program;
    return Scaffold(
      appBar: AppBar(title: PageTitle(t.title)),
      body: program == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _summaryRow(
                  program.summary,
                  icon: AppIcons.maths,
                  current: true,
                ),
                if (!program.summary.builtinRules)
                  FlatRow(
                    icon: AppIcons.refresh,
                    label: t.reset,
                    onTap: _busy ? null : _reset,
                  ),
                if (_error != null) _note(context, _error!, error: true),
                // Waiting suggestions, above what was set before.
                if (context
                    .watch<WorkoutProvider>()
                    .pendingSuggestions
                    .isNotEmpty) ...[
                  FlatHeading(copy.suggestions.programHeading),
                  for (final suggestion
                      in context.watch<WorkoutProvider>().pendingSuggestions)
                    FlatRow(
                      icon: AppIcons.multiplayer,
                      label: suggestion.title,
                      subtitle: [
                        copy.suggestions.from.replaceAll(
                          '{name}',
                          suggestion.fromName,
                        ),
                        if (suggestion.note.isNotEmpty) suggestion.note,
                      ].join('\n'),
                      onTap: () => openSuggestion(context, suggestion),
                    ),
                ],
                FlatHeading(t.historyHeading),
                if (program.history.isEmpty) _note(context, t.historyEmpty),
                for (final s in program.history)
                  _summaryRow(
                    s,
                    icon: AppIcons.history,
                    current: s.id == program.summary.id,
                  ),
                FlatHeading(t.assistantsHeading),
                _note(context, t.assistantsBody),
                if (_grantsFailed)
                  _note(context, t.assistantsOffline)
                else if (_grants == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_grants!.isEmpty)
                  _note(context, t.assistantsEmpty)
                else
                  for (final g in _grants!) _grantRow(g),
                FlatRow(
                  icon: AppIcons.bot,
                  label: t.assistantsConnect,
                  subtitle: t.assistantsConnectSub,
                  onTap: () => launchUrl(
                    websiteUri('/bot'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
    );
  }
}
