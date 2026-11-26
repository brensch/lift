/// Onboarding's first step: pick a profile emoji and colour.
library;

import 'package:material_ui/material_ui.dart';

import '../../../gen/copy.dart';
import '../../../logic/user_profile.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/theme_spec.dart';
import '../../../widgets/common/flat.dart';
import '../widgets/onboarding_page.dart';
import '../widgets/profile_marker_widgets.dart'
    show EmojiChoiceWrap, ColorChoiceWrap;

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
    final t = copy.onboarding.marker;
    return OnboardingPage(
      title: t.title,
      body: t.body,
      primary: OnboardingNext(label: copy.onboarding.next, onPressed: onNext),
      children: [
        FlatSection(
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: profileColorFromHex(selectedColorHex),
                borderRadius: context.tokens.brXl,
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
        ),
        FlatSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmojiChoiceWrap(
                choices: emojiChoices,
                selected: selectedEmoji,
                onSelect: onSelectEmoji,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onRefreshEmojis,
                  icon: const Icon(AppIcons.refresh, size: 18),
                  label: Text(t.refresh),
                ),
              ),
            ],
          ),
        ),
        FlatSection(
          child: ColorChoiceWrap(
            selected: selectedColorHex,
            onSelect: onSelectColor,
          ),
        ),
      ],
    );
  }
}
