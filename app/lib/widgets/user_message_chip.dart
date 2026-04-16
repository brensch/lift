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

  _ChipPalette _palette(ColorScheme colorScheme) {
    final neutralBackground = colorScheme.surfaceContainerHigh;
    switch (details.changeKind) {
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_INCREASE:
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE:
        return _ChipPalette(
          accent: colorScheme.primary,
          background: neutralBackground,
          border: colorScheme.primary.withValues(alpha: 0.22),
        );
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_HOLD:
        return _ChipPalette(
          accent: colorScheme.tertiary,
          background: neutralBackground,
          border: colorScheme.tertiary.withValues(alpha: 0.22),
        );
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_DELOAD:
        return _ChipPalette(
          accent: colorScheme.error,
          background: neutralBackground,
          border: colorScheme.error.withValues(alpha: 0.22),
        );
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_UNSPECIFIED:
        return _ChipPalette(
          accent: colorScheme.secondary,
          background: neutralBackground,
          border: colorScheme.outlineVariant,
        );
    }
    return _ChipPalette(
      accent: colorScheme.secondary,
      background: neutralBackground,
      border: colorScheme.outlineVariant,
    );
  }

  String _summary(WeightUnit unit) {
    final exerciseLabel = _exerciseLabel();
    final metric = _metricBadge();
    final prefix = metric.isEmpty ? exerciseLabel : '$exerciseLabel $metric';
    switch (details.changeKind) {
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_INCREASE:
        return '$prefix ${_formatWeightLabel(details.previousWeight, unit)} -> ${_formatWeightLabel(details.nextWeight, unit)}';
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_HOLD:
        final weight = _formatWeightLabel(details.nextWeight, unit);
        if (details.previousStage.isNotEmpty &&
            details.nextStage.isNotEmpty &&
            details.previousStage != details.nextStage) {
          return '$prefix held at $weight · ${_stageLabel(details.previousStage)} -> ${_stageLabel(details.nextStage)}';
        }
        return '$prefix held at $weight';
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_DELOAD:
        return '$prefix ${_formatWeightLabel(details.previousWeight, unit)} -> ${_formatWeightLabel(details.nextWeight, unit)}';
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_CYCLE_ADVANCE:
        return '$prefix ${_formatWeightLabel(details.previousWeight, unit)} -> ${_formatWeightLabel(details.nextWeight, unit)}';
      case ProgressionChangeKind.PROGRESSION_CHANGE_KIND_UNSPECIFIED:
        return message.body.ifEmpty(message.title.ifEmpty('Workout note'));
    }
    return message.body.ifEmpty(message.title.ifEmpty('Workout note'));
  }

  String _reason() {
    if (details.reasonText.isNotEmpty) return details.reasonText;
    switch (details.reasonKind) {
      case ProgressionReasonKind
          .PROGRESSION_REASON_KIND_COMPLETED_ALL_WORKING_SETS:
        return 'Completed all working sets at target reps.';
      case ProgressionReasonKind.PROGRESSION_REASON_KIND_MISSED_TARGET_REPS:
        return 'Missed target reps.';
      case ProgressionReasonKind.PROGRESSION_REASON_KIND_REPEATED_MISSES:
        return 'Repeated misses triggered the change.';
      case ProgressionReasonKind.PROGRESSION_REASON_KIND_STAGE_ADVANCE:
        return 'Advanced to the next stage.';
      case ProgressionReasonKind.PROGRESSION_REASON_KIND_CYCLE_COMPLETED:
        return 'Completed the cycle.';
      case ProgressionReasonKind
          .PROGRESSION_REASON_KIND_CLEARED_PROGRESSION_CHECK:
        return 'Cleared the progression check.';
      case ProgressionReasonKind.PROGRESSION_REASON_KIND_UNSPECIFIED:
        return '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.select<SettingsProvider, WeightUnit>(
      (provider) => provider.weightUnit,
    );
    final palette = _palette(colorScheme);
    final text = _summary(unit);
    final reason = _reason();

    return _MessageShell(
      accent: palette.accent,
      background: palette.background,
      border: palette.border,
      compact: compact,
      onDismiss: onDismiss,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12.5 : 13.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              reason,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11.5 : 12,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
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
    final text = message.title.isNotEmpty && message.body.isNotEmpty
        ? '${message.title}: ${message.body}'
        : message.title.ifEmpty(message.body);
    return _MessageShell(
      accent: colorScheme.primary,
      background: colorScheme.surfaceContainerHigh,
      border: colorScheme.outlineVariant,
      compact: compact,
      onDismiss: onDismiss,
      child: Text(
        text,
        maxLines: compact ? 2 : 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 12.5 : 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface.withValues(alpha: 0.86),
        ),
      ),
    );
  }
}

class _MessageShell extends StatelessWidget {
  final Color accent;
  final Color background;
  final Color border;
  final bool compact;
  final VoidCallback? onDismiss;
  final Widget child;

  const _MessageShell({
    required this.accent,
    required this.background,
    required this.border,
    required this.compact,
    required this.onDismiss,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 26 : 28,
            height: compact ? 26 : 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: accent,
              size: compact ? 16 : 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
          if (onDismiss != null) ...[
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              icon: Icon(
                Icons.close_rounded,
                size: compact ? 17 : 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: onDismiss,
            ),
          ],
        ],
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
