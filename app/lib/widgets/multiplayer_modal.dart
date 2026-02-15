import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/workout_provider.dart';

class MultiplayerModal extends StatefulWidget {
  const MultiplayerModal({super.key});

  @override
  State<MultiplayerModal> createState() => _MultiplayerModalState();
}

class _MultiplayerModalState extends State<MultiplayerModal> {
  bool _isScanning = false;

  void _handleScan(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final url = Uri.tryParse(barcode.rawValue!);
        if (url != null) {
          final joinId = url.queryParameters['join'];
          if (joinId != null) {
            _joinSession(joinId);
            return; // Only join the first valid one
          }
        }
      }
    }
  }

  Future<void> _joinSession(String sessionId) async {
    // If we're already processing a scan, don't do it again immediately
    if (!mounted) return;
    
    // Stop scanning
    setState(() => _isScanning = false);

    final mp = context.read<MultiplayerProvider>();
    final wp = context.read<WorkoutProvider>();
    final workoutId = wp.hasActiveWorkout ? wp.workout?.id : null;

    final success = await mp.joinSession(sessionId, workoutId: workoutId);
    if (success && mounted) {
      Navigator.pop(context); // Close modal on success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined session successfully')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join session')),
      );
    }
  }

  Future<void> _startSession() async {
    final mp = context.read<MultiplayerProvider>();
    final wp = context.read<WorkoutProvider>();
    final workoutId = wp.hasActiveWorkout ? wp.workout?.id : null;

    await mp.startSession(workoutId: workoutId);
  }

  Future<void> _leaveSession() async {
    final mp = context.read<MultiplayerProvider>();
    await mp.leaveSession();
  }

  Future<void> _shareSession(String sessionId) async {
    try {
      await Share.share('Join my workout on Lift: https://lift.brensch.com/?join=$sessionId');
    } catch (e) {
      debugPrint('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing not supported on this device. Use "Copy" instead.')),
        );
      }
    }
  }

  Future<void> _copyLink(String sessionId) async {
    await Clipboard.setData(ClipboardData(text: 'https://lift.brensch.com/?join=$sessionId'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final theme = Theme.of(context);
    final sessionId = mp.sessionId;

    // Use a fixed height or make it scrollable
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MULTIPLAYER',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (mp.isLoading)
             const Center(child: Padding(
               padding: EdgeInsets.all(32.0),
               child: CircularProgressIndicator(),
             ))
          else if (sessionId == null) ...[
            if (_isScanning)
              SizedBox(
                height: 300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: MobileScanner(
                    onDetect: _handleScan,
                  ),
                ),
              )
            else ...[
              FilledButton(
                onPressed: _startSession,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Start a Session'),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('OR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _isScanning = true),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
            if (_isScanning)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton(
                  onPressed: () => setState(() => _isScanning = false),
                  child: const Text('Cancel Scan'),
                ),
              ),
          ] else ...[
            // In Session
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: QrImageView(
                  data: 'https://lift.brensch.com/?join=$sessionId', // Replace with actual domain if needed
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Session Active',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: $sessionId',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _leaveSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Leave'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _copyLink(sessionId),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _shareSession(sessionId),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
