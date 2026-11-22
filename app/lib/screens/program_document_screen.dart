/// One program, opened from Settings → Program: who set it and why, the
/// document itself (to read or copy), and for an earlier one, a way back to
/// its rules with today's workouts kept.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../providers/workout_provider.dart';
import '../services/toast.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';
import '../widgets/dialogs/confirm_dialog.dart';

/// Open [summary]. [json] is the document when it is in hand (the
/// program in use); otherwise it is read. Returns whether the program
/// changed.
Future<bool> showProgramDocument(
  BuildContext context, {
  required ProgramSummary summary,
  required String byline,
  String? json,
  required bool current,
}) async {
  final provider = context.read<WorkoutProvider>();
  final changed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/program/document'),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: ProgramDocumentScreen(
          summary: summary,
          byline: byline,
          json: json,
          current: current,
        ),
      ),
    ),
  );
  return changed ?? false;
}

class ProgramDocumentScreen extends StatefulWidget {
  final ProgramSummary summary;
  final String byline;
  final String? json;
  final bool current;

  const ProgramDocumentScreen({
    super.key,
    required this.summary,
    required this.byline,
    required this.json,
    required this.current,
  });

  @override
  State<ProgramDocumentScreen> createState() => _ProgramDocumentScreenState();
}

class _ProgramDocumentScreenState extends State<ProgramDocumentScreen> {
  String? _json;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _json = widget.json;
    if (_json == null) _load();
  }

  Future<void> _load() async {
    try {
      final version = await context.read<WorkoutProvider>().getProgramVersion(
        widget.summary.id,
      );
      if (mounted) setState(() => _json = version.programJson);
    } catch (_) {
      if (mounted) setState(() => _error = copy.program.loadFailed);
    }
  }

  Future<void> _copy() async {
    final cs = Theme.of(context).colorScheme;
    await Clipboard.setData(ClipboardData(text: _json ?? ''));
    showToast(
      msg: copy.program.copied,
      backgroundColor: cs.inverseSurface,
      textColor: cs.onInverseSurface,
    );
  }

  Future<void> _goBack() async {
    final t = copy.program;
    final provider = context.read<WorkoutProvider>();
    final sure = await confirmDialog(
      context,
      title: t.useTitle,
      body: t.useBody,
      confirm: t.useConfirm,
      cancel: copy.home.deleteCancel,
    );
    if (!sure || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await provider.resetProgram(to: widget.summary.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = t.useFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = copy.program;
    final cs = Theme.of(context).colorScheme;
    final s = widget.summary;
    final quiet = TextStyle(
      fontSize: context.tokens.size.body,
      color: cs.onSurface.withValues(alpha: 0.6),
    );
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(s.name.isEmpty ? t.builtin : s.name),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.copy),
            tooltip: t.copy,
            onPressed: _json == null ? null : _copy,
          ),
        ],
      ),
      body: ListView(
        children: [
          FlatSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.byline, style: quiet),
                if (s.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.note,
                    style: TextStyle(fontSize: context.tokens.size.body),
                  ),
                ],
                if (widget.current) ...[
                  const SizedBox(height: 8),
                  Text(t.current, style: context.tokens.label()),
                ],
              ],
            ),
          ),
          if (!widget.current)
            FlatRow(
              icon: AppIcons.history,
              label: t.use,
              onTap: _busy || _json == null ? null : _goBack,
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: cs.error)),
            ),
          FlatHeading(t.documentHeading),
          if (_json == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_json != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _json!,
                style: context.tokens.mono(
                  TextStyle(fontSize: context.tokens.size.caption),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
