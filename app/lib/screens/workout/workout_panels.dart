/// Supporting panels for the workout screen: missing-HR notice, the session
/// strip, page tabs, the add-exercise row.
library;

import 'package:flutter/material.dart';
import '../../theme/theme_spec.dart';
import '../../theme/app_icons.dart';

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
            Icon(AppIcons.watch, size: 52, color: colorScheme.tertiary),
            const SizedBox(height: 18),
            Text(
              'No heart rate yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.tokens.size.subtitle,
                fontWeight: context.tokens.weight.heavy,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get the watch app and you can see how hard you are pumping '
              'your heart while schlifting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.tokens.size.body,
                height: 1.45,
                fontWeight: context.tokens.weight.bold,
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

/// The workout's name, its overall progress, and how long it has been
/// going: one full-width row, the exercises themselves right below.
class SessionStrip extends StatelessWidget {
  final String title; // e.g. "5×5 Workout A"
  final double progress; // 0..1 across all working sets
  final String elapsedText; // the workout's running time
  final String? heartRateText; // your heart rate, when something sends one

  const SessionStrip({
    super.key,
    required this.title,
    required this.progress,
    required this.elapsedText,
    this.heartRateText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      // The name takes the width it needs (at most 70%, then ellipsis); the
      // bar fills everything after it.
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.7),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.tokens.size.title,
                  fontWeight: context.tokens.weight.heavy,
                  letterSpacing: -0.4,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: context.tokens.br(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(cs.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // The session's clock, and under it your heart.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  elapsedText,
                  style: context.tokens.mono(
                    TextStyle(
                      fontSize: context.tokens.size.body,
                      fontWeight: context.tokens.weight.bold,
                      color: context.tokens.muted,
                    ),
                  ),
                ),
                if (heartRateText != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.heart,
                        size: context.tokens.size.body,
                        color: context.tokens.heart,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        heartRateText!,
                        style: context.tokens.mono(
                          TextStyle(
                            fontSize: context.tokens.size.body,
                            fontWeight: context.tokens.weight.bold,
                            color: context.tokens.text,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page tabs: the views by name, switched by a tap ─────────────────────────

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
                                fontSize: context.tokens.size.subtitle,
                                fontWeight: context.tokens.weight.heavy,
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
                                    fontSize: context.tokens.size.small,
                                    fontWeight: context.tokens.weight.heavy,
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
                          color: i == index ? cs.primary : Colors.transparent,
                          borderRadius: context.tokens.br(3),
                        ),
                      ),
                    ],
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

// ─── Add exercise (a full-width row, like the sections above it) ────────────

class AddExerciseRow extends StatelessWidget {
  final VoidCallback onTap;

  const AddExerciseRow({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(AppIcons.add, size: t.size.title, color: t.muted),
            const SizedBox(width: 8),
            Text(
              'Add exercise',
              style: TextStyle(
                fontSize: t.size.bodyLg,
                fontWeight: t.weight.bold,
                color: t.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
