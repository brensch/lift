/// The app's flat building blocks: full-width sections split by hairlines,
/// and full-width tabs with an orange rule under the chosen one. Pages are
/// built from these rather than cards and shadows, so every screen reads as
/// the same set of simple lines.
library;

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/theme_spec.dart';

/// A small mono heading: what the section below is.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: t.mono(
              TextStyle(
                fontSize: t.size.small,
                fontWeight: t.weight.bold,
                letterSpacing: 1,
                color: t.muted,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// One full-width block of a page: an optional [label], the [child] in the
/// page margins, and a hairline under it that runs edge to edge.
class FlatSection extends StatelessWidget {
  final String? label;
  final Widget? trailing;
  final Widget child;

  /// Lets the child run to the edges (a list, a chart) instead of sitting
  /// in the margins.
  final bool bleed;
  final bool divider;

  const FlatSection({
    super.key,
    this.label,
    this.trailing,
    required this.child,
    this.bleed = false,
    this.divider = true,
  });

  static const double margin = 16;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: t.hairline))
            : const Border(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(margin, 0, margin, 10),
                child: SectionLabel(label!, trailing: trailing),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: bleed ? 0 : margin),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width tabs: the labels share the width, the chosen one in ink over
/// an orange rule, a hairline under the lot. For any pick-one-of-a-few
/// control (a date range, a view).
class FlatTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const FlatTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        labels[i],
                        style: t.mono(
                          TextStyle(
                            fontSize: t.size.body,
                            fontWeight: t.weight.bold,
                            color: i == selected ? t.text : t.muted,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 3,
                      color: i == selected ? t.primary : Colors.transparent,
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

/// A full-width row: an icon, a label over a quieter line, whatever goes on
/// the right, and a chevron when it opens something. Rows stack with a
/// hairline between them, edge to edge.
class FlatRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const FlatRow({
    super.key,
    this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.hairline)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: t.size.title, color: t.text),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: t.size.bodyLg,
                        fontWeight: t.weight.bold,
                        color: t.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: t.size.small,
                          color: t.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              if (onTap != null) Icon(AppIcons.forward, color: t.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section heading over full-width rows: the label in the margin, a
/// hairline under it.
class FlatHeading extends StatelessWidget {
  final String text;

  const FlatHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.tokens.hairline)),
      ),
      child: SectionLabel(text),
    );
  }
}

/// A page's (or sheet's) title: capitals, in the app bar's title style —
/// the buttons' face, regular weight.
class PageTitle extends StatelessWidget {
  final String text;

  const PageTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    // The app bar's title style, so a sheet's title matches a page's.
    style: Theme.of(context).appBarTheme.titleTextStyle,
  );
}
