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

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: double.infinity,
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
    );
  }
}

/// One full-width block of a page: an optional [label] as a heading band,
/// the [child] in the page margins, and a hairline under it that runs edge
/// to edge.
class FlatSection extends StatelessWidget {
  final String? label;
  final Widget child;

  /// The child runs edge to edge, from right under the [label]'s band to
  /// the divider (a chart, a grid whose vertical lines must meet both),
  /// instead of sitting in the margins.
  final bool flush;

  const FlatSection({
    super.key,
    this.label,
    required this.child,
    this.flush = false,
  });

  static const double margin = 16;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) FlatHeading(label!),
          Padding(
            padding: flush
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: margin, vertical: 14),
            child: child,
          ),
        ],
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

/// A section heading over full-width rows: the label in the margin, on a
/// darker band than the rows with a hairline above and below, so headings
/// and content tell apart.
class FlatHeading extends StatelessWidget {
  final String text;

  const FlatHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 9),
          decoration: BoxDecoration(
            color: t.headingBand,
            border: Border(bottom: BorderSide(color: t.hairline)),
          ),
          child: SectionLabel(text),
        ),
        // The top line a pixel up, over the hairline that ends the row
        // above, so the two read as one line rather than a doubled one.
        Positioned(
          top: -1,
          left: 0,
          right: 0,
          height: 1,
          child: ColoredBox(color: t.hairline),
        ),
      ],
    );
  }
}

/// A headline number over its label, at the top of a page.
class HeadStat extends StatelessWidget {
  final String value;
  final String label;

  /// The number's text size; the theme's titleLg when null.
  final double? size;
  final Color? color;

  const HeadStat(this.value, this.label, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: size ?? t.size.titleLg,
            fontWeight: t.weight.heavy,
            height: 1,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: t.muted, fontSize: t.size.small),
        ),
      ],
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

/// Figures in a full-width grid, [columns] to a row: each a label (in its
/// colour, or muted) over its value, and under that its note if it has one,
/// the cells split by hairlines that meet the lines above and below.
class FlatMetricGrid extends StatelessWidget {
  final List<(String, String, Color?)> metrics;

  /// A line under each metric's value, by position; null for none.
  final List<String?>? notes;
  final int columns;

  /// Lines along the grid's top and bottom; off where a heading band's
  /// line (or a section's) already runs there.
  final bool topLine;
  final bool bottomLine;

  const FlatMetricGrid({
    super.key,
    required this.metrics,
    this.notes,
    this.columns = 3,
    this.topLine = false,
    this.bottomLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget cell(
      (String, String, Color?) m,
      String? note, {
      required bool last,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : BorderSide(color: t.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.$1.toUpperCase(),
              style: t.mono(
                TextStyle(
                  fontSize: t.size.small,
                  fontWeight: t.weight.bold,
                  letterSpacing: 1,
                  color: m.$3 ?? t.muted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                m.$2,
                maxLines: 1,
                style: t.mono(
                  TextStyle(
                    fontSize: t.size.titleLg,
                    fontWeight: t.weight.bold,
                    color: t.text,
                  ),
                ),
              ),
            ),
            if (note != null)
              Text(
                note,
                style: TextStyle(fontSize: t.size.small, color: t.muted),
              ),
          ],
        ),
      ),
    );

    final rows = <Widget>[];
    for (var i = 0; i < metrics.length; i += columns) {
      final end = (i + columns).clamp(0, metrics.length);
      rows.add(
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: i == 0 && !topLine
                  ? BorderSide.none
                  : BorderSide(color: t.hairline),
              bottom: i + columns >= metrics.length && bottomLine
                  ? BorderSide(color: t.hairline)
                  : BorderSide.none,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = i; j < i + columns; j++)
                  j < end
                      ? cell(metrics[j], notes?[j], last: j == i + columns - 1)
                      : const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
