import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../logic/user_profile.dart';
import '../logic/whimsical_emojis.dart';
import '../providers/auth_provider.dart';
import '../services/grpc_client.dart';
import '../services/user_service.dart';
import '../widgets/top_level_back_scope.dart';

class ProfileMarkerScreen extends StatefulWidget {
  const ProfileMarkerScreen({super.key});

  @override
  State<ProfileMarkerScreen> createState() => _ProfileMarkerScreenState();
}

class _ProfileMarkerScreenState extends State<ProfileMarkerScreen> {
  static const int _emojiWindowSize = 18;
  late String _selectedEmoji;
  late String _selectedColorHex;
  late List<String> _emojiChoices;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _selectedEmoji = auth.profileEmoji;
    _selectedColorHex = auth.profileColorHex;
    _emojiChoices = whimsicalEmojiCatalog.take(_emojiWindowSize).toList();
    _ensureSelectedEmojiVisible();
  }

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
      context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TopLevelBackScope(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Profile Marker',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
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
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: cs.tertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick your colour and emoji',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This controls the badge and side stripe used for you in group workouts.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ProfilePreviewCard(
                      emoji: _selectedEmoji,
                      colorHex: _selectedColorHex,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'EMOJIS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: cs.tertiary,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _refreshEmojiChoices,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
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
                            (emoji) => _EmojiChoiceChip(
                              emoji: emoji,
                              selected: emoji == _selectedEmoji,
                              onTap: () =>
                                  setState(() => _selectedEmoji = emoji),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'COLOURS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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
                            (hex) => _ColorChoiceDot(
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
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'SAVE',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  final String emoji;
  final String colorHex;

  const _ProfilePreviewCard({required this.emoji, required this.colorHex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = profileColorFromHex(colorHex);
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 88,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workout card preview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your emoji appears in the rounded side rail and the selected colour fills that rail.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiChoiceChip extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _EmojiChoiceChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}

class _ColorChoiceDot extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChoiceDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = profileColorFromHex(hex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? cs.onSurface : color.withValues(alpha: 0.6),
            width: selected ? 3 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
