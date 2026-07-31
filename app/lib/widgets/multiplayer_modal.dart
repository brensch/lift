import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../gen/workout/v1/group.pb.dart';
import '../providers/multiplayer_provider.dart';
import '../theme/app_theme.dart';
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
  String? _joiningPartnerId;

  @override
  void initState() {
    super.initState();
    // Populate the friends list for quick re-pairing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MultiplayerProvider>().loadTrainingPartners();
    });
  }

  void _handleScan(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _joinViaScan(raw);
      return;
    }
  }

  Future<void> _joinViaScan(String scanned) async {
    if (!mounted) return;
    setState(() => _isScanning = false);
    // The QR holds the invite link; joinViaInvite pulls the token out of it.
    final error =
        await context.read<MultiplayerProvider>().joinViaInvite(scanned);
    if (error == null && mounted) Navigator.pop(context);
  }

  Future<void> _shareInvite(String inviteToken) async {
    try {
      await Share.share('Join my workout on Schlift: ${_shareUrl(inviteToken)}');
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  Future<void> _askPartner(String partnerUserId, String name) async {
    setState(() => _joiningPartnerId = partnerUserId);
    final mp = context.read<MultiplayerProvider>();
    final error = await mp.requestJoinPartner(partnerUserId);
    if (!mounted) return;
    setState(() => _joiningPartnerId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Asked $name to train — waiting for them to accept'),
    ));
  }

  String _partnerSubtitle(TrainingPartner p) {
    final sessions = p.sessionsTogether;
    final label = sessions == 1 ? '1 session' : '$sessions sessions';
    return '$label · ${_relativeDay(p.lastTrainedAt.toInt())}';
  }

  String _relativeDay(int unixSeconds) {
    if (unixSeconds <= 0) return 'recently';
    final then = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final days = DateTime.now().difference(then).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) return '${(days / 7).floor()}w ago';
    return '${(days / 30).floor()}mo ago';
  }

  /// Who's currently in your session, with their live status. Hidden when you're
  /// training solo.
  Widget _currentSession(MultiplayerProvider mp, ColorScheme cs) {
    final participants = mp.participants;
    if (participants.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IN YOUR SESSION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: cs.tertiary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final p in participants)
                Builder(
                  builder: (_) {
                    final status = describeParticipantStatus(p);
                    final name = participantDisplayName(p);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: status.stateColor,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 11,
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
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Text(
                        status.stateLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: status.stateColor,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// The friends section — people you've trained with (minus whoever is already
  /// in your session). Always shown (with a hint when empty) so it's a
  /// first-class part of the screen, not a footnote.
  Widget _friends(List<TrainingPartner> partners, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FRIENDS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: cs.tertiary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'People you’ve trained with. Tap Ask and they get a request to join '
          'your session.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (partners.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
            ),
            child: Text(
              'No training partners yet. Do a session with someone — scan their '
              'code or open their link — and they’ll show up here to re-invite '
              'in one tap.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: cs.tertiary,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final p in partners)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text(
                        p.user.name.isNotEmpty
                            ? p.user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      p.user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      _partnerSubtitle(p),
                      style: TextStyle(fontSize: 11.5, color: cs.tertiary),
                    ),
                    trailing: _joiningPartnerId == p.user.id
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FilledButton.tonal(
                            onPressed: () => _askPartner(p.user.id, p.user.name),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Ask'),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final inviteToken = mp.myInviteToken;
    // Don't offer to invite someone who's already in the session.
    final sessionMemberIds = mp.participants.map((p) => p.user.id).toSet();
    final invitablePartners = mp.trainingPartners
        .where((p) => !sessionMemberIds.contains(p.user.id))
        .toList();

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        decoration: BoxDecoration(
          color: AppTheme.sheetColor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLg),
          ),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AppTheme.sheetHandle(context)),
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
              const SizedBox(height: 20),
              if (_isScanning)
                Column(
                  children: [
                    SizedBox(
                      height: 320,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MobileScanner(onDetect: _handleScan),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Point at your friend’s code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => setState(() => _isScanning = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                )
              else if (inviteToken == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // The hero: scan a friend's code to join them.
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _isScanning = true),
                    icon: const Icon(Icons.photo_camera_rounded, size: 24),
                    label: const Text(
                      'Scan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Your own code, for a friend to scan you back.
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline),
                    ),
                    child: QrImageView(
                      data: _shareUrl(inviteToken),
                      version: QrVersions.auto,
                      size: 150,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _shareInvite(inviteToken),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share link'),
                  ),
                ),
                const SizedBox(height: 26),
                _currentSession(mp, cs),
                _friends(invitablePartners, cs),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
