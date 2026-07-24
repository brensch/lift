/// Onboarding step 5: pick a profile emoji, colour and body weight.
library;

import 'package:flutter/material.dart';
import '../../../logic/user_profile.dart';
import '../widgets/profile_marker_widgets.dart';

class MarkerStep extends StatelessWidget {
  final String selectedEmoji;
  final String selectedColorHex;
  final List<String> emojiChoices;
  final ValueChanged<String> onSelectEmoji;
  final ValueChanged<String> onSelectColor;
  final VoidCallback onRefreshEmojis;
  final VoidCallback onNext;

  const MarkerStep({super.key, 
    required this.selectedEmoji,
    required this.selectedColorHex,
    required this.emojiChoices,
    required this.onSelectEmoji,
    required this.onSelectColor,
    required this.onRefreshEmojis,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PICK YOUR MARKER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your colour and creature',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'In group workouts this becomes your side stripe and emoji badge.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          ProfilePreviewCard(emoji: selectedEmoji, colorHex: selectedColorHex),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'WHIMSICAL EMOJIS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: cs.tertiary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onRefreshEmojis,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: emojiChoices
                        .map(
                          (emoji) => EmojiChoiceChip(
                            emoji: emoji,
                            selected: emoji == selectedEmoji,
                            onTap: () => onSelectEmoji(emoji),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'COLOUR',
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
                          (hex) => ColorChoiceDot(
                            hex: hex,
                            selected: hex == selectedColorHex,
                            onTap: () => onSelectColor(hex),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onNext,
              child: const Text(
                'NEXT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
