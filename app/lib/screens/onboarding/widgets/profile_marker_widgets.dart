/// Profile-marker pieces: live preview card, emoji chips, colour dots.
library;

import 'package:flutter/material.dart';
import '../../../logic/user_profile.dart';

class ProfilePreviewCard extends StatelessWidget {
  final String emoji;
  final String colorHex;

  const ProfilePreviewCard({super.key, required this.emoji, required this.colorHex});

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
                    'Group workout preview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your emoji replaces the vertical name and your colour owns the sidebar.',
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

class EmojiChoiceChip extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const EmojiChoiceChip({super.key, 
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

class ColorChoiceDot extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const ColorChoiceDot({super.key, 
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
