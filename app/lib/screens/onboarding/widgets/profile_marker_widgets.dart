/// Profile-marker pieces, shared by onboarding and the Profile Marker
/// screen: the emoji window, live preview card, emoji chips, colour dots.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../gen/copy.dart';
import '../../../logic/user_profile.dart';
import '../../../logic/whimsical_emojis.dart';
import '../../../theme/theme_spec.dart';

/// How many emojis the picker offers at once.
const int emojiWindowSize = 18;

/// [window], with [selected] put first if it is not already in it.
List<String> withSelectedVisible(List<String> window, String selected) =>
    window.contains(selected)
    ? window
    : [selected, ...window.take(emojiWindowSize - 1)];

/// A fresh random window from the catalog that still shows [selected].
List<String> shuffledEmojiWindow(String selected, [Random? random]) {
  final pool = <String>{...whimsicalEmojiCatalog, selected}.toList()
    ..shuffle(random);
  return withSelectedVisible(pool.take(emojiWindowSize).toList(), selected);
}

/// The emoji choices as chips, [selected] highlighted.
class EmojiChoiceWrap extends StatelessWidget {
  final List<String> choices;
  final String selected;
  final ValueChanged<String> onSelect;

  const EmojiChoiceWrap({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final emoji in choices)
          EmojiChoiceChip(
            emoji: emoji,
            selected: emoji == selected,
            onTap: () => onSelect(emoji),
          ),
      ],
    );
  }
}

/// Every profile colour as a dot, [selected] framed.
class ColorChoiceWrap extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const ColorChoiceWrap({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final hex in profileColorHexOptions)
          ColorChoiceDot(
            hex: hex,
            selected: hex == selected,
            onTap: () => onSelect(hex),
          ),
      ],
    );
  }
}

class ProfilePreviewCard extends StatelessWidget {
  final String emoji;
  final String colorHex;

  const ProfilePreviewCard({
    super.key,
    required this.emoji,
    required this.colorHex,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = profileColorFromHex(colorHex);
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: context.tokens.brLg,
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 88,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(context.tokens.radiusLg),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: TextStyle(fontSize: context.tokens.size.headline),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.profileMarker.previewTitle,
                    style: TextStyle(
                      fontSize: context.tokens.size.body,
                      fontWeight: context.tokens.weight.heavy,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    copy.profileMarker.previewBody,
                    style: TextStyle(
                      fontSize: context.tokens.size.body,
                      fontWeight: context.tokens.weight.bold,
                    ),
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

class EmojiChoiceChip extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const EmojiChoiceChip({
    super.key,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: context.tokens.brMd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerLowest,
          borderRadius: context.tokens.brMd,
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          emoji,
          style: TextStyle(fontSize: context.tokens.size.titleLg),
        ),
      ),
    );
  }
}

class ColorChoiceDot extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const ColorChoiceDot({
    super.key,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = profileColorFromHex(hex);
    // A flat square of the colour, like the block it fills behind your
    // emoji; the chosen one framed in ink.
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          borderRadius: context.tokens.brMd,
          border: Border.all(
            color: selected ? cs.onSurface : color.withValues(alpha: 0.6),
            width: selected ? 3 : 1.5,
          ),
        ),
      ),
    );
  }
}
