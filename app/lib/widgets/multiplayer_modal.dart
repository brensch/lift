import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/multiplayer_provider.dart';
import 'participant_ticker.dart';

String _shareUrl(String inviteToken) =>
    'https://schlift.com/?join=$inviteToken';

class MultiplayerModal extends StatefulWidget {
  const MultiplayerModal({super.key});

  @override
  State<MultiplayerModal> createState() => _MultiplayerModalState();
}

class _MultiplayerModalState extends State<MultiplayerModal> {
  bool _isScanning = false;
  final TextEditingController _idController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  void _handleScan(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _joinViaInvite(raw);
      return;
    }
  }

  Future<void> _joinViaInvite(String tokenOrUrl) async {
    if (!mounted) return;
    setState(() => _isScanning = false);
    final mp = context.read<MultiplayerProvider>();
    final error = await mp.joinViaInvite(tokenOrUrl);
    if (error == null && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _shareInvite(String inviteToken) async {
    try {
      await Share.share(
        'Join my workout on Schlift: ${_shareUrl(inviteToken)}',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sharing not supported on this device. Use "Copy" instead.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _copyInviteLink(String inviteToken) async {
    await Clipboard.setData(ClipboardData(text: _shareUrl(inviteToken)));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
    }
  }

  Future<void> _rotateInvite() async {
    final mp = context.read<MultiplayerProvider>();
    await mp.rotateInviteToken();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code rotated — old QR no longer works'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sessionId = mp.sessionId;
    final inviteToken = mp.myInviteToken;
    final username = auth.username?.trim();

    final modalSurface = colorScheme.brightness == Brightness.dark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
          decoration: BoxDecoration(
            color: modalSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Multiplayer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (mp.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  if (_isScanning)
                    Column(
                      children: [
                        SizedBox(
                          height: 300,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: MobileScanner(onDetect: _handleScan),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => setState(() => _isScanning = false),
                          child: const Text('Cancel Scan'),
                        ),
                      ],
                    )
                  else ...[
                    if (inviteToken == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Center(
                          child: QrImageView(
                            data: _shareUrl(inviteToken),
                            version: QrVersions.auto,
                            size: 200.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your invite code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inviteToken,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _isScanning = true),
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 18,
                                ),
                                label: const Text('Scan'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: () => _copyInviteLink(inviteToken),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: FilledButton.icon(
                                onPressed: () => _shareInvite(inviteToken),
                                icon: const Icon(Icons.share, size: 16),
                                label: const Text('Share'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _rotateInvite,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Rotate code'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (sessionId != null) ...[
                      Text(
                        'ACTIVE SESSION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sessionId,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Session Members',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: colorScheme.secondary,
                                child: Text(
                                  username != null && username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSecondary,
                                  ),
                                ),
                              ),
                              title: Text(
                                username != null && username.isNotEmpty
                                    ? '$username (You)'
                                    : 'You',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (mp.participants.isNotEmpty) ...[
                              Divider(
                                height: 1,
                                color: colorScheme.outline.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: screenHeight * 0.3,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: mp.participants.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: colorScheme.outline.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                  itemBuilder: (context, index) {
                                    final participant = mp.participants[index];
                                    final status = describeParticipantStatus(
                                      participant,
                                    );
                                    final displayName = participantDisplayName(
                                      participant,
                                    );
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: status.stateColor,
                                        child: Text(
                                          displayName.isNotEmpty
                                              ? displayName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                ThemeData.estimateBrightnessForColor(
                                                      status.stateColor,
                                                    ) ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      trailing: Text(
                                        status.stateLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: status.stateColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _idController,
                              decoration: InputDecoration(
                                hintText: 'Paste Join ID',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              if (_idController.text.isNotEmpty) {
                                _joinViaInvite(_idController.text.trim());
                              }
                            },
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
