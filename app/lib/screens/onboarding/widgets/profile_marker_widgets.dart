/// Profile-marker pieces, shared by onboarding and the Profile Marker
/// screen: the emoji window, live preview card, emoji chips, colour dots.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../logic/user_profile.dart';
import '../../../logic/whimsical_emojis.dart';
import '../../../theme/theme_spec.dart';

/// How many emojis the picker offers at once.
const int emojiWindowSize = 15;

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

  static const columns = 5;
  static const double gap = 8;

  const EmojiChoiceWrap({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Five across, whatever the screen: the chips grow with it and the gap
    // between them stays small, the same across as down. It fills the width
    // exactly, as the colours' grid under it does.
    return LayoutBuilder(
      builder: (context, box) {
        final size = (box.maxWidth - (columns - 1) * gap) / columns;
        return SizedBox(
          width: box.maxWidth,
          child: Wrap(
            spacing: gap - 0.01,
            runSpacing: gap,
            children: [
              for (final emoji in choices)
                EmojiChoiceChip(
                  emoji: emoji,
                  selected: emoji == selected,
                  onTap: () => onSelect(emoji),
                  size: size,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The profile colour: a slider along every hue, all as bright and as vivid
/// as each other.
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
    return _HueSlider(
      hue: profileHueOf(profileColorFromHex(selected)),
      onHue: (hue) => onSelect(colorHex(profileHueColor(hue))),
    );
  }
}

/// A line of every hue with a ball on it, to drag along or tap. The ball is
/// the colour it is on, framed in ink.
class _HueSlider extends StatefulWidget {
  /// Where the ball is, in degrees.
  final double hue;
  final ValueChanged<double> onHue;

  const _HueSlider({required this.hue, required this.onHue});

  @override
  State<_HueSlider> createState() => _HueSliderState();
}

class _HueSliderState extends State<_HueSlider> {
  static const double _height = 38;
  static const double _thumbWidth = 30;
  static const double _line = 6;

  /// Short of 360, where the band would be back at the colour it starts on.
  static const double _maxHue = 345;

  /// The hue under the finger, kept while it drags: the colour it becomes
  /// is rounded to a hex, and reading the hue back off that would jitter.
  double? _dragged;

  static final _band = [
    for (var i = 0; i <= 23; i++) profileHueColor(_maxHue * i / 23),
  ];

  void _at(double x, double width) {
    final travel = width - _thumbWidth;
    final hue = ((x - _thumbWidth / 2) / travel).clamp(0.0, 1.0) * _maxHue;
    setState(() => _dragged = hue);
    widget.onHue(hue);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final hue = _dragged ?? widget.hue;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _at(d.localPosition.dx, width),
          onHorizontalDragStart: (d) => _at(d.localPosition.dx, width),
          onHorizontalDragUpdate: (d) => _at(d.localPosition.dx, width),
          onHorizontalDragEnd: (_) => _dragged = null,
          child: SizedBox(
            height: _height,
            child: Stack(
              children: [
                Positioned(
                  // Edge to edge, as wide as the emoji grid over it.
                  left: 0,
                  right: 0,
                  top: (_height - _line) / 2,
                  height: _line,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _band),
                      borderRadius: t.brSm,
                    ),
                  ),
                ),
                Positioned(
                  left: (hue / _maxHue).clamp(0.0, 1.0) * (width - _thumbWidth),
                  top: (_height - _thumbWidth) / 2,
                  width: _thumbWidth,
                  height: _thumbWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: profileHueColor(hue),
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.onSurface, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// You, as you'll be shown: the emoji picked, large, on a rounded square of
/// the colour picked. No words.
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
    final t = context.tokens;
    return Center(
      child: Container(
        width: 128,
        height: 128,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: profileColorFromHex(colorHex),
          borderRadius: t.brXl,
          border: Border.all(color: t.outline),
        ),
        child: Text(emoji, style: TextStyle(fontSize: t.size.giant, height: 1)),
      ),
    );
  }
}

class EmojiChoiceChip extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  /// Its side: the grid gives each a fifth of its width, less the gaps.
  final double size;

  const EmojiChoiceChip({
    super.key,
    required this.emoji,
    required this.selected,
    required this.onTap,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: context.tokens.brMd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
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
          // As big as the chip allows: about half its side.
          style: TextStyle(fontSize: size * 0.5, height: 1),
        ),
      ),
    );
  }
}
