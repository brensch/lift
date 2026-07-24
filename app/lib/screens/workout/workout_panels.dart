/// Supporting panels for the workout screen: missing-HR notice, page dots, column labels, empty state.
library;

import 'package:flutter/material.dart';

class NoHeartRateMonitor extends StatelessWidget {
  const NoHeartRateMonitor({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.watch_outlined, size: 52, color: colorScheme.tertiary),
            const SizedBox(height: 18),
            Text(
              'No heart rate yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get the watch app and you can see how hard you are pumping '
              'your heart while schlifting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page indicator ────────────────────────────────────────────────────────

class PageDots extends StatelessWidget {
  final int count;
  final int index;
  final ValueChanged<int> onTap;

  const PageDots({super.key, 
    required this.count,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: i == index ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == index
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Two-column scaffolding ────────────────────────────────────────────────

class ColumnLabel extends StatelessWidget {
  final String text;
  final TextAlign align;
  const ColumnLabel(this.text, {super.key, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: colorScheme.tertiary,
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  final String text;
  const EmptyPanel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colorScheme.tertiary,
        ),
      ),
    );
  }
}
