import 'package:flutter/material.dart';
import '../widgets/common/flat.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../gen/workout/v1/auth.pb.dart';
import '../logic/utils.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

class PasskeysScreen extends StatefulWidget {
  const PasskeysScreen({super.key});

  @override
  State<PasskeysScreen> createState() => _PasskeysScreenState();
}

class _PasskeysScreenState extends State<PasskeysScreen> {
  List<PasskeyInfo>? _passkeys;
  bool _loading = true;
  String? _deletingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPasskeys();
  }

  Future<void> _loadPasskeys() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authService = context.read<AuthService>();
      final passkeys = await authService.listPasskeys();
      if (mounted) setState(() => _passkeys = passkeys);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load passkeys');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddPasskey() async {
    final added = await context.push<bool>('/passkeys/add');
    if (added == true && mounted) {
      await _loadPasskeys();
    }
  }

  Future<void> _deletePasskey(String credentialId) async {
    // Resolved up front: every use below sits after an await, and reading from
    // the BuildContext across an async gap risks touching a defunct element.
    final authService = context.read<AuthService>();

    final confirmed = await _showDeleteConfirmDialog();
    if (confirmed != true) return;

    setState(() {
      _deletingId = credentialId;
      _error = null;
    });
    try {
      await authService.deletePasskey(credentialId);
      await _loadPasskeys();
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to delete passkey');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  Future<bool?> _showDeleteConfirmDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Passkey'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: context.tokens.brSm,
              ),
              child: Text(
                'Make sure you have one of the remaining passkeys before deleting anything. If you don\'t have a valid passkey you cannot recover your account.',
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: context.tokens.size.body,
                  fontWeight: context.tokens.weight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure? This cannot be undone.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: context.tokens.size.body,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(int timestampSeconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${shortDate(date)}, ${date.year}, $hour:$minute $amPm';
  }

  String _formatTransports(List<String> transports) {
    const labels = {
      'internal': 'This device',
      'usb': 'USB',
      'nfc': 'NFC',
      'ble': 'Bluetooth',
      'hybrid': 'Phone/Tablet',
    };
    return transports.map((t) => labels[t] ?? t).join(', ');
  }

  /// One passkey as a full-width row: its name, how it signs in and when
  /// it was added (and from where), and a delete (never the last one).
  Widget _passkeyRow(BuildContext context, int i) {
    final pk = _passkeys![i];
    final colorScheme = Theme.of(context).colorScheme;
    final isDeleting = _deletingId == pk.credentialId;
    final canDelete = _passkeys!.length > 1 && _deletingId == null;
    final details = [
      if (pk.transports.isNotEmpty) _formatTransports(pk.transports),
      if (pk.createdAt > 0) 'Added ${_formatDate(pk.createdAt.toInt())}',
      if (pk.hasCreatedAtIp()) pk.createdAtIp,
    ].join(' · ');
    return FlatRow(
      icon: AppIcons.key,
      label: pk.name.isNotEmpty ? pk.name : 'Passkey ${i + 1}',
      subtitle: details.isEmpty ? null : details,
      trailing: IconButton(
        onPressed: canDelete ? () => _deletePasskey(pk.credentialId) : null,
        visualDensity: VisualDensity.compact,
        icon: isDeleting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                AppIcons.delete,
                size: 20,
                color: canDelete
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface.withValues(alpha: 0.2),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: PageTitle('Passkeys')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPasskeys,
              child: ListView(
                // A pixel on top: room for the heading band's top line.
                padding: const EdgeInsets.only(top: 1, bottom: 24),
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: context.tokens.hairline),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: context.tokens.size.body,
                        ),
                      ),
                    ),
                  const FlatHeading('Your passkeys'),
                  if (_passkeys == null || _passkeys!.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: context.tokens.hairline),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No passkeys found',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    for (var i = 0; i < _passkeys!.length; i++)
                      _passkeyRow(context, i),
                  FlatRow(
                    icon: AppIcons.add,
                    label: 'Add passkey',
                    onTap: _openAddPasskey,
                  ),
                ],
              ),
            ),
    );
  }
}
