/// Supporting panels for the workout screen: missing-HR notice, page tabs, column labels, empty state.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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

// ─── Session strip (top block: workout name + a single slim progress bar) ────

class SessionStrip extends StatelessWidget {
  final String name;
  final double progress; // 0..1 across all working sets

  const SessionStrip({super.key, required this.name, required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              height: 1.0,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: cs.onSurface.withValues(alpha: 0.09),
              valueColor: const AlwaysStoppedAnimation(AppTheme.successFg),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page tabs (named + swipeable — clearer than anonymous dots) ─────────────

class PageTabItem {
  final String label;
  final int? count;
  const PageTabItem(this.label, {this.count});
}

class PageTabs extends StatelessWidget {
  final List<PageTabItem> tabs;
  final int index;
  final ValueChanged<int> onTap;

  const PageTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              tabs[i].label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                                color: i == index
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            if (tabs[i].count != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  '${tabs[i].count}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        height: 2.5,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: i == index
                              ? AppTheme.successFg
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 3),
            child: Opacity(
              opacity: 0.5,
              child: Transform.rotate(
                angle: math.pi / 2,
                child: Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page indicator (legacy dots, kept for reference) ───────────────────────

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
