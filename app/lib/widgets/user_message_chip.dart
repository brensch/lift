import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';

class UserMessageChip extends StatelessWidget {
  final UserMessage message;
  final VoidCallback? onDismiss;
  final bool compact;

  const UserMessageChip({
    super.key,
    required this.message,
    this.onDismiss,
    this.compact = false,
  });

  ProgressionDetails? get _progressionDetails {
    if (!message.hasDetails()) return null;
    if (message.details.whichDetail() !=
        UserMessageDetails_Detail.progression) {
      return null;
    }
    return message.details.progression;
  }

  @override
  Widget build(BuildContext context) {
    final progression = _progressionDetails;
    if (progression != null) {
      return _ProgressionMessageChip(
        message: message,
        details: progression,
        onDismiss: onDismiss,
        compact: compact,
      );
    }
    return _FallbackMessageChip(
      message: message,
      onDismiss: onDismiss,
      compact: compact,
    );
  }
}

class _ProgressionMessageChip extends StatelessWidget {
  final UserMessage message;
  final ProgressionDetails details;
  final VoidCallback? onDismiss;
  final bool compact;

  const _ProgressionMessageChip({
    required this.message,
    required this.details,
    required this.onDismiss,
    required this.compact,
  });

  String _exerciseLabel() =>
      exerciseNames[message.exercise] ?? message.title.ifEmpty('Workout note');

  String _formatWeightLabel(double pounds, WeightUnit unit) =>
      formatWeight(pounds, unit, includeUnit: true);

  String _stageLabel(String stage) => stage.replaceAll('_', ' ');

  String _metricBadge() {
    switch (details.metricKind) {
      case ProgressionMetricKind.PROGRESSION_METRIC_KIND_TRAINING_MAX:
        return 'TM';
      case ProgressionMetricKind.PROGRESSION_METRIC_KIND_WORKING_WEIGHT:
      case ProgressionMetricKind.PROGRESSION_METRIC_KIND_UNSPECIFIED:
        return '';
    }
    return '';
  }

  IconData _icon() {
    switch (details.changeKind) {
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_INCREASE:
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE:
        return Icons.arrow_upward_rounded;
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_HOLD:
        return Icons.pause_rounded;
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_DELOAD:
        return Icons.arrow_downward_rounded;
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_UNSPECIFIED:
        return Icons.info_outline_rounded;
    }
    return Icons.info_outline_rounded;
  }

  String _headline() {
    switch (details.changeKind) {
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_INCREASE:
        return 'Progressed';
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_HOLD:
        return 'Held';
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_DELOAD:
        return 'Reset';
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE:
        return 'Cycle advance';
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_UNSPECIFIED:
        return message.title.ifEmpty('Workout note');
    }
    return message.title.ifEmpty('Workout note');
  }

  String _subtitle() {
    if (details.changeKind ==
            ProgressionChangeKind.PROGRESSION_CHANGE_KIND_HOLD &&
        details.previousStage.isNotEmpty &&
        details.nextStage.isNotEmpty &&
        details.previousStage != details.nextStage) {
      return '${_stageLabel(details.previousStage)} -> ${_stageLabel(details.nextStage)}';
    }
    if (details.metricKind ==
        ProgressionMetricKind.PROGRESSION_METRIC_KIND_TRAINING_MAX) {
      return 'Training Max';
    }
    return '';
  }

  _ChipPalette _palette(ColorScheme colorScheme) {
    switch (details.changeKind) {
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_INCREASE:
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE:
        return const _ChipPalette(
          accent: Color(0xFF147D4A),
          background: Color(0xFFEAF7F0),
          border: Color(0xFFB7DEC7),
        );
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_HOLD:
        return const _ChipPalette(
          accent: Color(0xFF9A6B16),
          background: Color(0xFFFFF6E6),
          border: Color(0xFFECCB87),
        );
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_DELOAD:
        return const _ChipPalette(
          accent: Color(0xFFAA4B36),
          background: Color(0xFFFFEFEA),
          border: Color(0xFFE8B7AB),
        );
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_UNSPECIFIED:
        return _ChipPalette(
          accent: colorScheme.primary,
          background: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          border: colorScheme.outline.withValues(alpha: 0.25),
        );
    }
    return _ChipPalette(
      accent: colorScheme.primary,
      background: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: colorScheme.outline.withValues(alpha: 0.25),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.select<SettingsProvider, WeightUnit>(
      (provider) => provider.weightUnit,
    );
    final palette = _palette(colorScheme);
    final metricBadge = _metricBadge();
    final subtitle = _subtitle();
    final horizontal = compact ? 12.0 : 14.0;
    final vertical = compact ? 10.0 : 12.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _icon(),
              color: palette.accent,
              size: compact ? 18 : 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _exerciseLabel(),
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (details.contextLabel.isNotEmpty)
                      _MetaBadge(
                        label: details.contextLabel,
                        accent: palette.accent,
                      ),
                    if (metricBadge.isNotEmpty)
                      _MetaBadge(label: metricBadge, accent: palette.accent),
                    _MetaBadge(label: _headline(), accent: palette.accent),
                  ],
                ),
                const SizedBox(height: 8),
                if (details.changeKind ==
                    ProgressionChangeKind.PROGRESSION_CHANGE_KIND_HOLD)
                  _SingleValueRow(
                    label: _formatWeightLabel(details.nextWeight, unit),
                    accent: palette.accent,
                    compact: compact,
                  )
                else
                  _DeltaRow(
                    previous: _formatWeightLabel(details.previousWeight, unit),
                    next: _formatWeightLabel(details.nextWeight, unit),
                    accent: palette.accent,
                    compact: compact,
                  ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      height: 1.3,
                      color: colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ],
      ),
    );
  }
}

class _FallbackMessageChip extends StatelessWidget {
  final UserMessage message;
  final VoidCallback? onDismiss;
  final bool compact;

  const _FallbackMessageChip({
    required this.message,
    required this.onDismiss,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.title.isNotEmpty) ...[
                  Text(
                    message.title,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (message.body.isNotEmpty)
                  Text(
                    message.body,
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 13,
                      height: 1.35,
                      color: colorScheme.onSurface.withValues(alpha: 0.82),
                    ),
                  ),
              ],
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color accent;

  const _MetaBadge({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  final String previous;
  final String next;
  final Color accent;
  final bool compact;

  const _DeltaRow({
    required this.previous,
    required this.next,
    required this.accent,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _ValuePill(label: previous, accent: accent, compact: compact),
        Icon(
          Icons.arrow_forward_rounded,
          color: accent,
          size: compact ? 17 : 19,
        ),
        _ValuePill(label: next, accent: accent, compact: compact),
      ],
    );
  }
}

class _SingleValueRow extends StatelessWidget {
  final String label;
  final Color accent;
  final bool compact;

  const _SingleValueRow({
    required this.label,
    required this.accent,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return _ValuePill(label: label, accent: accent, compact: compact);
  }
}

class _ValuePill extends StatelessWidget {
  final String label;
  final Color accent;
  final bool compact;

  const _ValuePill({
    required this.label,
    required this.accent,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }
}

class _ChipPalette {
  final Color accent;
  final Color background;
  final Color border;

  const _ChipPalette({
    required this.accent,
    required this.background,
    required this.border,
  });
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
