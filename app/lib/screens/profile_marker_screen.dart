import 'dart:math';

import '../widgets/common/flat.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/user_profile.dart';
import '../logic/whimsical_emojis.dart';
import '../providers/auth_provider.dart';
import '../services/grpc_client.dart';
import '../services/user_service.dart';
import '../theme/theme_spec.dart';
import 'onboarding/widgets/profile_marker_widgets.dart';
import '../theme/app_icons.dart';

class ProfileMarkerScreen extends StatefulWidget {
  const ProfileMarkerScreen({super.key});

  @override
  State<ProfileMarkerScreen> createState() => _ProfileMarkerScreenState();
}

class _ProfileMarkerScreenState extends State<ProfileMarkerScreen> {
  static const int _emojiWindowSize = 18;
  late String _savedEmoji;
  late String _savedColorHex;
  late String _selectedEmoji;
  late String _selectedColorHex;
  late List<String> _emojiChoices;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _savedEmoji = auth.profileEmoji;
    _savedColorHex = auth.profileColorHex;
    _selectedEmoji = _savedEmoji;
    _selectedColorHex = _savedColorHex;
    _emojiChoices = whimsicalEmojiCatalog.take(_emojiWindowSize).toList();
    _ensureSelectedEmojiVisible();
  }

  bool get _hasUnsavedChanges =>
      _selectedEmoji != _savedEmoji || _selectedColorHex != _savedColorHex;

  void _ensureSelectedEmojiVisible() {
    if (_emojiChoices.contains(_selectedEmoji)) return;
    _emojiChoices = [
      _selectedEmoji,
      ..._emojiChoices.take(_emojiWindowSize - 1),
    ];
  }

  void _refreshEmojiChoices() {
    final pool = <String>{...whimsicalEmojiCatalog, _selectedEmoji}.toList();
    pool.shuffle(Random());
    setState(() {
      _emojiChoices = pool.take(_emojiWindowSize).toList();
      _ensureSelectedEmojiVisible();
    });
  }

  Future<void> _save() async {
    if (_isSaving || !_hasUnsavedChanges) return;
    setState(() => _isSaving = true);
    try {
      final user = await UserServiceWrapper(context.read<GrpcClient>())
          .updateMyProfile(
            profileEmoji: _selectedEmoji,
            profileColorHex: _selectedColorHex,
          );
      if (!mounted) return;
      context.read<AuthProvider>().setProfile(
        profileEmoji: user.profileEmoji,
        profileColorHex: user.profileColorHex,
      );
      setState(() {
        _savedEmoji = user.profileEmoji;
        _savedColorHex = user.profileColorHex;
        _selectedEmoji = user.profileEmoji;
        _selectedColorHex = user.profileColorHex;
        _ensureSelectedEmojiVisible();
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: PageTitle('Profile Marker'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  Text(
                    'GROUP LOOK',
                    style: TextStyle(
                      fontSize: context.tokens.size.small,
                      fontWeight: context.tokens.weight.heavy,
                      letterSpacing: 1.4,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick your colour and emoji',
                    style: TextStyle(
                      fontSize: context.tokens.size.headline,
                      fontWeight: context.tokens.weight.heavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This controls the badge and side stripe used for you in group workouts.',
                    style: TextStyle(
                      fontSize: context.tokens.size.body,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ProfilePreviewCard(
                    emoji: _selectedEmoji,
                    colorHex: _selectedColorHex,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'EMOJIS',
                        style: TextStyle(
                          fontSize: context.tokens.size.small,
                          fontWeight: context.tokens.weight.heavy,
                          letterSpacing: 1.2,
                          color: cs.tertiary,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _refreshEmojiChoices,
                        icon: const Icon(AppIcons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _emojiChoices
                        .map(
                          (emoji) => EmojiChoiceChip(
                            emoji: emoji,
                            selected: emoji == _selectedEmoji,
                            onTap: () => setState(() => _selectedEmoji = emoji),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'COLOURS',
                    style: TextStyle(
                      fontSize: context.tokens.size.small,
                      fontWeight: context.tokens.weight.heavy,
                      letterSpacing: 1.2,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: profileColorHexOptions
                        .map(
                          (hex) => ColorChoiceDot(
                            hex: hex,
                            selected: hex == _selectedColorHex,
                            onTap: () =>
                                setState(() => _selectedColorHex = hex),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: (!_isSaving && _hasUnsavedChanges) ? _save : null,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'SAVE',
                          style: TextStyle(
                            fontWeight: context.tokens.weight.heavy,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
