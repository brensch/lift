import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../gen/copy.dart';
import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/workout.pb.dart' show User;
import '../logic/exercises.dart';
import '../logic/set_labels.dart';
import '../logic/user_profile.dart';
import '../providers/settings_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../theme/app_theme.dart';
import 'common/flat.dart';
import '../theme/theme_spec.dart';
import '../logic/session_state.dart';
import 'participant_ticker.dart';
import '../theme/app_icons.dart';

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
    final error = await context.read<MultiplayerProvider>().joinViaInvite(
      scanned,
    );
    if (error == null && mounted) Navigator.pop(context);
  }

  Future<void> _shareInvite(String inviteToken) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: copy.multiplayer.shareText.replaceAll(
            '{url}',
            _shareUrl(inviteToken),
          ),
        ),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? copy.multiplayer.asked.replaceAll('{name}', name),
        ),
      ),
    );
  }

  String _partnerSubtitle(TrainingPartner p) {
    final sessions = p.sessionsTogether;
    final label = sessions == 1
        ? copy.multiplayer.sessionsOne
        : copy.multiplayer.sessions.replaceAll('{n}', '$sessions');
    return '$label · ${_relativeDay(p.lastTrainedAt.toInt())}';
  }

  String _relativeDay(int unixSeconds) {
    if (unixSeconds <= 0) return copy.multiplayer.recently;
    final then = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    final days = DateTime.now().difference(then).inDays;
    if (days <= 0) return copy.multiplayer.today;
    if (days == 1) return copy.multiplayer.yesterday;
    if (days < 7) return copy.multiplayer.daysAgo.replaceAll('{n}', '$days');
    if (days < 30) {
      return copy.multiplayer.weeksAgo.replaceAll(
        '{n}',
        '${(days / 7).floor()}',
      );
    }
    return copy.multiplayer.monthsAgo.replaceAll(
      '{n}',
      '${(days / 30).floor()}',
    );
  }

  /// Who's currently in your session, with their live status. Hidden when you're
  /// training solo.
  Widget _currentSession(MultiplayerProvider mp, ColorScheme cs) {
    final participants = mp.participants;
    if (participants.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlatHeading(copy.multiplayer.inSession),
        // Full-width rows: their emoji on their colour, name, stage. The
        // heading's own line is the one over the first row, and the last
        // row's is the one the next heading sits on: no second line, no gap.
        _Rows(
          topLine: false,
          children: [
            for (final p in participants)
              Builder(
                builder: (_) {
                  final status = describeParticipantStatus(
                    p,
                    tokens: context.tokens,
                  );
                  final set = status.proposedSet;
                  final unit = context.watch<SettingsProvider>().weightUnit;
                  return _SessionRow(
                    user: p.user,
                    name: participantDisplayName(p),
                    // What they are on, when they are on something.
                    doing: set == null
                        ? null
                        : '${exerciseName(set.exercise)} · '
                              '${setTextFor(set, unit)}',
                    stage: status.stateLabel,
                    stageColor: status.stateColor,
                  );
                },
              ),
          ],
        ),
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
        FlatHeading(copy.multiplayer.friends),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            copy.multiplayer.friendsBody,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.35,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (partners.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: context.tokens.hairline),
              ),
            ),
            child: Text(
              copy.multiplayer.friendsEmpty,
              style: TextStyle(
                fontSize: context.tokens.size.small,
                height: 1.4,
                fontWeight: context.tokens.weight.bold,
                color: cs.tertiary,
              ),
            ),
          )
        else
          _Rows(
            children: [
              for (final p in partners)
                ListTile(
                  dense: true,
                  leading: _Avatar(user: p.user),
                  title: Text(
                    p.user.name,
                    style: TextStyle(
                      fontWeight: context.tokens.weight.bold,
                      fontSize: context.tokens.size.body,
                    ),
                  ),
                  subtitle: Text(
                    _partnerSubtitle(p),
                    style: TextStyle(
                      fontSize: context.tokens.size.small,
                      color: cs.tertiary,
                    ),
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
                          child: Text(copy.multiplayer.ask),
                        ),
                ),
            ],
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
        // No side borders: the Scan band and lists run to the very edge.
        color: AppTheme.sheetColor(context),
        padding: const EdgeInsets.only(bottom: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: AppTheme.sheetHandle(context)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: PageTitle(copy.multiplayer.title),
              ),
              const SizedBox(height: 12),
              if (_isScanning)
                Column(
                  children: [
                    SizedBox(
                      height: 320,
                      child: MobileScanner(onDetect: _handleScan),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      copy.multiplayer.scanPrompt,
                      style: TextStyle(
                        fontSize: context.tokens.size.body,
                        fontWeight: context.tokens.weight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => setState(() => _isScanning = false),
                      child: Text(copy.multiplayer.scanCancel),
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
                // The hero: scan a friend's code to join them. Edge to edge.
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () => setState(() => _isScanning = true),
                    icon: const Icon(AppIcons.camera, size: 24),
                    label: Text(
                      copy.multiplayer.scan,
                      style: TextStyle(
                        fontSize: context.tokens.size.bodyLg,
                        fontWeight: context.tokens.weight.heavy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Your own code, for a friend to scan you back.
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.tokens.lightBackdrop,
                      borderRadius: context.tokens.brMd,
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
                    icon: const Icon(AppIcons.export, size: 18),
                    label: Text(copy.multiplayer.shareLink),
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

/// Rows split by hairlines, with one above the first: a list that reads as
/// part of the page rather than a box on it.
class _Rows extends StatelessWidget {
  final List<Widget> children;

  /// A line over the first row; false straight under a heading, which
  /// ends in one.
  final bool topLine;

  const _Rows({required this.children, this.topLine = true});

  @override
  Widget build(BuildContext context) {
    final line = BorderSide(color: context.tokens.hairline);
    return DecoratedBox(
      decoration: BoxDecoration(border: topLine ? Border(top: line) : null),
      child: Column(
        children: [
          for (final c in children)
            DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: c,
            ),
        ],
      ),
    );
  }
}

/// Someone in your session: their emoji on their colour, their name over
/// what they are lifting, and their stage on a block of its colour, as on
/// the workout's status box.
class _SessionRow extends StatelessWidget {
  final User user;
  final String name;
  final String? doing;
  final String stage;
  final Color stageColor;

  const _SessionRow({
    required this.user,
    required this.name,
    required this.doing,
    required this.stage,
    required this.stageColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _Avatar(user: user, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.size.bodyLg,
                    fontWeight: t.weight.bold,
                    color: t.text,
                  ),
                ),
                if (doing != null)
                  Text(
                    doing!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: t.size.body, color: t.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: stageColor, borderRadius: t.brSm),
            child: Text(
              stage,
              style: TextStyle(
                fontSize: t.size.body,
                fontWeight: t.weight.bold,
                color: t.inkOn(stageColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Someone's emoji on a square of their colour, as on the workout banner.
class _Avatar extends StatelessWidget {
  final User user;
  final double size;

  const _Avatar({required this.user, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: profileColorFromHex(user.profileColorHex),
        borderRadius: context.tokens.brSm,
      ),
      child: Text(
        normalizedProfileEmoji(user.profileEmoji),
        style: TextStyle(fontSize: context.tokens.size.bodyLg, height: 1),
      ),
    );
  }
}
