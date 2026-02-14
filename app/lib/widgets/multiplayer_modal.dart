import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/workout_provider.dart';

class MultiplayerModal extends StatefulWidget {
  const MultiplayerModal({super.key});

  @override
  State<MultiplayerModal> createState() => _MultiplayerModalState();
}

class _MultiplayerModalState extends State<MultiplayerModal> {
  bool _isScanning = false;
  final _sessionIdController = TextEditingController();

  @override
  void dispose() {
    _sessionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final wp = context.read<WorkoutProvider>();

    if (mp.isInSession) {
      return _buildInSession(context, mp);
    }

    return _buildJoinOrCreate(context, mp, wp);
  }

  Widget _buildInSession(BuildContext context, MultiplayerProvider mp) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Session Active', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          QrImageView(
            data: mp.sessionId!,
            size: 200,
          ),
          const SizedBox(height: 8),
          SelectableText(
            mp.sessionId!,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              mp.leaveSession();
              Navigator.pop(context);
            },
            child: const Text('Leave Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinOrCreate(BuildContext context, MultiplayerProvider mp, WorkoutProvider wp) {
    if (_isScanning) {
      return SizedBox(
        height: 400,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Scan Session QR Code', style: TextStyle(fontSize: 16)),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final value = barcode.rawValue;
                    if (value != null && value.isNotEmpty) {
                      setState(() => _isScanning = false);
                      _joinSession(context, mp, wp, value);
                      break;
                    }
                  }
                },
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isScanning = false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Multiplayer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: mp.isLoading
                  ? null
                  : () async {
                      final sessionId = await mp.startSession(
                        workoutId: wp.workout?.id,
                      );
                      if (sessionId != null && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
              icon: const Icon(Icons.add),
              label: const Text('Start Session'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          TextField(
            controller: _sessionIdController,
            decoration: const InputDecoration(
              labelText: 'Session ID',
              border: OutlineInputBorder(),
              hintText: 'Enter or scan session ID',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _isScanning = true),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: mp.isLoading || _sessionIdController.text.isEmpty
                      ? null
                      : () => _joinSession(
                            context,
                            mp,
                            wp,
                            _sessionIdController.text.trim(),
                          ),
                  child: const Text('Join'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _joinSession(
    BuildContext context,
    MultiplayerProvider mp,
    WorkoutProvider wp,
    String sessionId,
  ) async {
    final success = await mp.joinSession(
      sessionId,
      workoutId: wp.workout?.id,
    );
    if (success && context.mounted) {
      Navigator.pop(context);
    }
  }
}
