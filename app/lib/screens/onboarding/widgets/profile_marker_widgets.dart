/// Profile-marker pieces: live preview card, emoji chips, colour dots.
library;

import 'package:flutter/material.dart';

import '../../../logic/user_profile.dart';
import '../../../theme/theme_spec.dart';

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
        borderRadius: context.tokens.br(16),
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
                left: context.tokens.radius(16),
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
                    'Group workout preview',
                    style: TextStyle(
                      fontSize: context.tokens.size.body,
                      fontWeight: context.tokens.weight.heavy,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your emoji replaces the vertical name and your colour owns the sidebar.',
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
      borderRadius: context.tokens.br(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerLowest,
          borderRadius: context.tokens.br(14),
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
          border: Border.all(
            color: selected ? cs.onSurface : color.withValues(alpha: 0.6),
            width: selected ? 3 : 1.5,
          ),
        ),
      ),
    );
  }
}
