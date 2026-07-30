/// Shared "where you are in your cycle, and why today looks like this" card.
/// Driven by RegimeContext (phase headline + narrative + next preview) and the
/// server-built last-session recap. Rendered on the home hero (compact), the
/// pre-workout briefing, and the in-workout Schplan tab.
library;

import 'package:flutter/material.dart';
import '../gen/workout/v1/workout.pb.dart';

class PhaseExplanation extends StatelessWidget {
  final RegimeContext context;

  /// Compact drops the narrative body and tightens spacing (for the home hero).
  final bool compact;

  /// When false, the phase headline (sessionDescription) is omitted — use where
  /// the surrounding screen already shows it (e.g. the briefing subtitle).
  final bool showHeadline;

  /// Optional color overrides for dark surfaces (e.g. the home readiness hero);
  /// defaults to the theme's on-surface colors.
  final Color? textColor;
  final Color? mutedColor;
  final Color? accentColor;

  const PhaseExplanation({
    super.key,
    required this.context,
    this.compact = false,
    this.showHeadline = true,
    this.textColor,
    this.mutedColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext buildContext) {
    final scheme = Theme.of(buildContext).colorScheme;
    final text = textColor ?? scheme.onSurface;
    final muted = mutedColor ?? scheme.onSurfaceVariant;
    final accent = accentColor ?? scheme.tertiary;

    final headline = context.sessionDescription.trim();
    final narrative = context.phaseNarrative.trim();
    final summary = context.lastSessionSummary.trim();
    final next = context.nextSessionPreview.trim();

    if (headline.isEmpty && narrative.isEmpty && summary.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    if (showHeadline && headline.isNotEmpty) {
      children.add(
        Text(
          headline,
          style: TextStyle(
            fontSize: compact ? 13.5 : 15,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
            color: text,
          ),
        ),
      );
    }

    if (!compact && narrative.isNotEmpty) {
      children.add(const SizedBox(height: 6));
      children.add(
        Text(
          narrative,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
      );
    }

    if (summary.isNotEmpty) {
      children.add(SizedBox(height: compact ? 4 : 10));
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.history_rounded, size: 14, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                // Server sends "Since last time: …"; keep it verbatim.
                summary,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: text.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!compact && next.isNotEmpty) {
      children.add(const SizedBox(height: 10));
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.arrow_forward_rounded, size: 14, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                next,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
