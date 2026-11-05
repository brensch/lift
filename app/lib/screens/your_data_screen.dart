import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/account_sync.dart';
import '../services/error_modal_service.dart';
import '../services/file_saver.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';

/// Settings → Your data: take a copy of the account (the export, gzipped,
/// saved where the person picks) or bring one back (an import of this
/// account's export). Each
/// says what it's doing while it does it.
class YourDataScreen extends StatefulWidget {
  const YourDataScreen({super.key});

  @override
  State<YourDataScreen> createState() => _YourDataScreenState();
}

class _YourDataScreenState extends State<YourDataScreen> {
  bool _exporting = false;
  bool _importing = false;

  /// What the last export or import came to, under its row.
  String? _exportDone;
  String? _importDone;

  bool get _busy => _exporting || _importing;

  /// Make the export, then save it where the person picks.
  Future<void> _export() async {
    final sync = context.read<AccountSync>();
    final name = context.read<AuthProvider>().username ?? '';
    final c = copy.yourData;
    setState(() {
      _exporting = true;
      _exportDone = null;
    });
    try {
      final file = await sync.export(name);
      final size = _megabytes(await file.length());
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _exportDone = c.exported.replaceAll('{size}', size);
      });
      final saved = await FileSaver.saveAs(file, file.uri.pathSegments.last);
      if (saved && mounted) {
        setState(() => _exportDone = c.saved.replaceAll('{size}', size));
      }
    } catch (e) {
      if (mounted) setState(() => _exporting = false);
      ErrorModalService.showError(c.exportFailed.replaceAll('{error}', '$e'));
    }
  }

  Future<void> _import() async {
    final sync = context.read<AccountSync>();
    final workouts = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final userId = context.read<AuthProvider>().userId;
    final c = copy.yourData;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c.importConfirmTitle),
        content: Text(c.importConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(c.importCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(c.importConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || userId == null) return;
    // A document picker only: no photo library, so no purpose string.
    final path = (await openFile())?.path;
    if (path == null || !mounted) return;
    setState(() {
      _importing = true;
      _importDone = null;
    });
    try {
      await sync.importFile(path);
      await settings.load();
      await workouts.loadActiveWorkout(userId);
      if (!mounted) return;
      setState(() {
        _importing = false;
        _importDone = c.imported;
      });
    } catch (e) {
      if (mounted) setState(() => _importing = false);
      ErrorModalService.showError(c.importFailed.replaceAll('{error}', '$e'));
    }
  }

  static String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final c = copy.yourData;
    return Scaffold(
      appBar: AppBar(title: PageTitle(c.title)),
      body: ListView(
        // A pixel on top: room for the first heading band's top line.
        padding: const EdgeInsets.only(top: 1, bottom: 24),
        children: [
          FlatHeading(c.exportHeading),
          _About(c.exportBody),
          _Action(
            icon: AppIcons.download,
            label: c.exportDownload,
            status: _exporting ? c.exporting : _exportDone,
            working: _exporting,
            onTap: _busy ? null : _export,
          ),
          FlatHeading(c.importHeading),
          _About(c.importBody),
          _Action(
            icon: AppIcons.upload,
            label: c.importButton,
            status: _importing ? c.importing : _importDone,
            working: _importing,
            onTap: _busy ? null : _import,
          ),
        ],
      ),
    );
  }
}

/// What a section does, in a sentence or two.
class _About extends StatelessWidget {
  final String text;

  const _About(this.text);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: t.size.body, color: t.muted, height: 1.35),
      ),
    );
  }
}

/// The section's action as a row: a spinner while it works, then what it
/// came to under the label.
class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? status;
  final bool working;
  final VoidCallback? onTap;

  const _Action({
    required this.icon,
    required this.label,
    required this.status,
    required this.working,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FlatRow(
      icon: icon,
      label: label,
      subtitle: status,
      trailing: working
          ? SizedBox(
              width: t.size.bodyLg,
              height: t.size.bodyLg,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: onTap,
    );
  }
}
