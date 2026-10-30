import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

/// Debug-only page (Settings → Wordmark lab): SCHLIFT banner candidates,
/// each in a mock of the real app bar, built around the app's fonts (Space
/// Grotesk, Space Mono) plus the current Krona One. Pick one by number;
/// the winner goes into schlift_spec.dart. The fonts here are deliberate
/// one-offs for comparison, which is why this page names them directly.
class WordmarkLabScreen extends StatelessWidget {
  const WordmarkLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    TextStyle grotesk(double size, FontWeight w, {double tracking = 0}) =>
        GoogleFonts.spaceGrotesk(
          fontSize: size,
          fontWeight: w,
          letterSpacing: tracking,
          color: t.text,
          height: 1,
        );
    TextStyle mono(double size, FontWeight w, {double tracking = 0}) =>
        GoogleFonts.spaceMono(
          fontSize: size,
          fontWeight: w,
          letterSpacing: tracking,
          color: t.text,
          height: 1,
        );
    TextStyle krona(double size, {double tracking = 0}) => GoogleFonts.kronaOne(
      fontSize: size,
      letterSpacing: tracking,
      color: t.text,
      height: 1,
    );

    final banners = <(String, Widget)>[
      ('Krona One', Text('SCHLIFT', style: krona(26, tracking: 1.5))),
      (
        'Krona One with a full stop in orange',
        Text.rich(
          TextSpan(
            text: 'SCHLIFT',
            style: krona(26, tracking: 1.5),
            children: [
              TextSpan(
                text: '.',
                style: krona(26).copyWith(color: t.primary),
              ),
            ],
          ),
        ),
      ),
      (
        'Space Grotesk bold, tight',
        Text('SCHLIFT', style: grotesk(32, FontWeight.w700, tracking: -1.2)),
      ),
      (
        'Space Grotesk light, wide',
        Text('SCHLIFT', style: grotesk(28, FontWeight.w300, tracking: 7)),
      ),
      (
        'Space Grotesk, split weight',
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'SCH',
                style: grotesk(32, FontWeight.w700, tracking: -0.5),
              ),
              TextSpan(
                text: 'LIFT',
                style: grotesk(32, FontWeight.w300, tracking: -0.5),
              ),
            ],
          ),
        ),
      ),
      (
        'Space Grotesk lowercase',
        Text('schlift', style: grotesk(34, FontWeight.w700, tracking: -1.5)),
      ),
      (
        'Stacked',
        Text(
          'SCH\nLIFT',
          style: grotesk(
            22,
            FontWeight.w700,
            tracking: 1,
          ).copyWith(height: 0.95),
        ),
      ),
      (
        'Space Mono bold, spaced',
        Text('SCHLIFT', style: mono(26, FontWeight.w700, tracking: 4)),
      ),
      (
        'Space Mono with a cursor',
        Text.rich(
          TextSpan(
            text: 'SCHLIFT',
            style: mono(26, FontWeight.w700, tracking: 1),
            children: [
              TextSpan(
                text: '_',
                style: mono(26, FontWeight.w700).copyWith(color: t.primary),
              ),
            ],
          ),
        ),
      ),
      (
        'Space Mono in brackets',
        Text('[SCHLIFT]', style: mono(24, FontWeight.w400, tracking: 2)),
      ),
      ('Dotted', Text('S·C·H·L·I·F·T', style: mono(20, FontWeight.w700))),
      (
        'Model number',
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SCHLIFT', style: grotesk(30, FontWeight.w700, tracking: -1)),
            const SizedBox(width: 4),
            Text(
              'SL-1',
              style: mono(11, FontWeight.w700).copyWith(color: t.primary),
            ),
          ],
        ),
      ),
      (
        'Orange square bullet',
        Row(
          children: [
            Container(width: 14, height: 14, color: t.primary),
            const SizedBox(width: 10),
            Text('schlift', style: mono(26, FontWeight.w700)),
          ],
        ),
      ),
      (
        'Label tape: orange block',
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: t.primary,
          child: Text(
            'SCHLIFT',
            style: mono(
              22,
              FontWeight.w700,
              tracking: 3,
            ).copyWith(color: t.onPrimary),
          ),
        ),
      ),
      (
        'Ink block',
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: t.text,
          child: Text(
            'SCHLIFT',
            style: grotesk(
              24,
              FontWeight.w700,
              tracking: 2,
            ).copyWith(color: t.background),
          ),
        ),
      ),
      (
        'Device label: outlined',
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: t.text, width: 1.5),
          ),
          child: Text(
            'SCHLIFT',
            style: grotesk(22, FontWeight.w500, tracking: 4),
          ),
        ),
      ),
      (
        'Orange rule',
        Row(
          children: [
            Container(width: 4, height: 30, color: t.primary),
            const SizedBox(width: 10),
            Text('SCHLIFT', style: grotesk(28, FontWeight.w600, tracking: 1)),
          ],
        ),
      ),
      (
        'Two-tone',
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'SCH', style: krona(24, tracking: 1)),
              TextSpan(
                text: 'LIFT',
                style: krona(24, tracking: 1).copyWith(color: t.primary),
              ),
            ],
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Wordmark lab')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        itemCount: banners.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final (label, mark) = banners[i];
          return _MockBar(number: i + 1, label: label, wordmark: mark);
        },
      ),
    );
  }
}

/// One banner in a stand-in for the real app bar: wordmark left, the bar's
/// usual buttons right.
class _MockBar extends StatelessWidget {
  final int number;
  final String label;
  final Widget wordmark;

  const _MockBar({
    required this.number,
    required this.label,
    required this.wordmark,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. $label',
          style: TextStyle(color: t.muted, fontSize: t.size.small),
        ),
        const SizedBox(height: 6),
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.background,
            border: Border.all(color: t.hairline),
            borderRadius: t.brSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(fit: BoxFit.scaleDown, child: wordmark),
                ),
              ),
              Icon(AppIcons.watch, color: t.text),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                color: t.primary,
                child: Icon(AppIcons.multiplayer, size: 18, color: t.onPrimary),
              ),
              const SizedBox(width: 10),
              Icon(AppIcons.menu, color: t.text),
            ],
          ),
        ),
      ],
    );
  }
}
