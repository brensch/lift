import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/workout_provider.dart';

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
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final url = Uri.tryParse(barcode.rawValue!);
        if (url != null) {
          final joinId = url.queryParameters['join'];
          if (joinId != null) {
            _joinSession(joinId);
            return;
          }
        }
      }
    }
  }

  Future<void> _joinSession(String sessionIdOrUrl) async {
    if (!mounted) return;

    String sessionId = sessionIdOrUrl.trim();
    // If it's a URL, try to extract the join parameter
    final uri = Uri.tryParse(sessionId);
    if (uri != null && uri.queryParameters.containsKey('join')) {
      sessionId = uri.queryParameters['join']!;
    }

    setState(() => _isScanning = false);

    final mp = context.read<MultiplayerProvider>();
    final wp = context.read<WorkoutProvider>();
    final workoutId = wp.hasActiveWorkout ? wp.workout?.id : null;

    final error = await mp.joinSession(sessionId, workoutId: workoutId);
    if (error == null && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _leaveSession() async {
    final mp = context.read<MultiplayerProvider>();
    await mp.leaveSession();
  }

  Future<void> _shareSession(String joinId) async {
    try {
      await Share.share(
        'Join my workout on Lift: https://lift.snek2.ddns.net/?join=$joinId',
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

  Future<void> _copyLink(String joinId) async {
    await Clipboard.setData(
      ClipboardData(text: 'https://lift.snek2.ddns.net/?join=$joinId'),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final sessionId = mp.sessionId;
    final userId = auth.userId ?? '';

    final modalSurface = colorScheme.brightness == Brightness.dark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;

    return Container(
      decoration: BoxDecoration(
        color: modalSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(24),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Center(
                  child: QrImageView(
                    data: 'https://lift.snek2.ddns.net/?join=$userId',
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your join code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userId,
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
                        onPressed: () => setState(() => _isScanning = true),
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => _copyLink(userId),
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
                        onPressed: () => _shareSession(userId),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                      ),
                    ),
                  ),
                ],
              ),
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
                    children: mp.participants.map((p) {
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            p.user.name.isNotEmpty
                                ? p.user.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          p.user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _leaveSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text('Leave Session'),
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
                          _joinSession(_idController.text.trim());
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
    );
  }
}
