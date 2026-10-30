/// Onboarding step 5: pick a profile emoji, colour and body weight.
library;

import 'package:flutter/material.dart';

import '../../../gen/copy.dart';
import '../../../logic/user_profile.dart';
import '../../../theme/theme_spec.dart';
import '../widgets/profile_marker_widgets.dart'
    show EmojiChoiceChip, ColorChoiceDot;
import '../../../theme/app_icons.dart';

class MarkerStep extends StatelessWidget {
  final String selectedEmoji;
  final String selectedColorHex;
  final List<String> emojiChoices;
  final ValueChanged<String> onSelectEmoji;
  final ValueChanged<String> onSelectColor;
  final VoidCallback onRefreshEmojis;
  final VoidCallback onNext;

  const MarkerStep({
    super.key,
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
            copy.onboarding.marker.title,
            style: TextStyle(
              fontSize: context.tokens.size.headline,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.onboarding.marker.body,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: profileColorFromHex(selectedColorHex),
                borderRadius: context.tokens.br(28),
              ),
              alignment: Alignment.center,
              child: Text(
                selectedEmoji,
                style: TextStyle(
                  fontSize: context.tokens.size.giant,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRefreshEmojis,
              icon: const Icon(AppIcons.refresh, size: 18),
              label: Text(copy.onboarding.marker.refresh),
            ),
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
              child: Text(
                copy.onboarding.next,
                style: TextStyle(fontWeight: context.tokens.weight.heavy),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
