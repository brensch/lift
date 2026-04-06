import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../gen/workout/v1/auth.pb.dart';

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
    final confirmed = await _showDeleteConfirmDialog();
    if (confirmed != true) return;

    setState(() {
      _deletingId = credentialId;
      _error = null;
    });
    try {
      final authService = context.read<AuthService>();
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Make sure you have one of the remaining passkeys before deleting anything. If you don\'t have a valid passkey you cannot recover your account.',
                style: TextStyle(
                  color: colorScheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure? This cannot be undone.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year}, $hour:$minute $amPm';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Passkeys',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPasskeys,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  // Add passkey button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openAddPasskey,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Passkey'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Passkey list
                  if (_passkeys == null || _passkeys!.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No passkeys found',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_passkeys!.length, (i) {
                      final pk = _passkeys![i];
                      final isDeleting = _deletingId == pk.credentialId;
                      final canDelete =
                          _passkeys!.length > 1 && _deletingId == null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.key,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          pk.name.isNotEmpty
                                              ? pk.name
                                              : 'Passkey ${i + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (pk.hasCreatedAtIp()) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              pk.createdAtIp,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontFamily: 'monospace',
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (pk.transports.isNotEmpty)
                                          _formatTransports(pk.transports),
                                        if (pk.createdAt > 0)
                                          'Added ${_formatDate(pk.createdAt.toInt())}',
                                      ].join(' · '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: canDelete
                                    ? () => _deletePasskey(pk.credentialId)
                                    : null,
                                icon: isDeleting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: canDelete
                                            ? colorScheme.onSurfaceVariant
                                            : colorScheme.onSurface.withValues(
                                                alpha: 0.2,
                                              ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
