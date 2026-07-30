import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../gen/workout/v1/group.pb.dart';
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
  String? _joiningPartnerId;

  @override
  void initState() {
    super.initState();
    // Populate the "trained with" list for quick re-pairing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MultiplayerProvider>().loadTrainingPartners();
    });
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

  /// People the caller has trained with before — tap Ask to request a spot in a
  /// partner's current session without needing a fresh link.
  Widget _buildTrainedWith(MultiplayerProvider mp, ColorScheme colorScheme) {
    final partners = mp.trainingPartners;
    if (partners.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'TRAINED WITH',
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
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final p in partners)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    child: Text(
                      p.user.name.isNotEmpty
                          ? p.user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
                  subtitle: Text(
                    _partnerSubtitle(p),
                    style: TextStyle(fontSize: 11, color: colorScheme.tertiary),
                  ),
                  trailing: _joiningPartnerId == p.user.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => _askPartner(p.user.id, p.user.name),
                          child: const Text('Ask'),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
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
          content: Text('Invite link rotated — old link no longer works'),
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
              if (mp.isLoading || inviteToken == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
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
                Text(
                  'Share your link. Opening it on their phone drops them straight '
                  'into your session — or point their camera at this code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () => _copyInviteLink(inviteToken),
                          icon: const Icon(Icons.link_rounded, size: 18),
                          label: const Text('Copy link'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: () => _shareInvite(inviteToken),
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _rotateInvite,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Rotate link'),
                  ),
                ),
                const SizedBox(height: 24),
                if (sessionId != null) ...[
                  Text(
                    'SESSION MEMBERS',
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
                            color: colorScheme.outline.withValues(alpha: 0.3),
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
                ] else
                  _buildTrainedWith(mp, colorScheme),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
