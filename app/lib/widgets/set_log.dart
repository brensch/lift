import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';

class SetLog extends StatelessWidget {
  final List<ProposedSet> proposedSets;
  final List<CompletedSet> completedSets;
  final void Function(String completedSetId)? onDelete;
  final String? deletableWorkoutId;
  final Map<String, String>? workoutOwnerLabels;
  final Map<String, String>? workoutOwnerEmojis;

  const SetLog({
    super.key,
    required this.proposedSets,
    required this.completedSets,
    this.onDelete,
    this.deletableWorkoutId,
    this.workoutOwnerLabels,
    this.workoutOwnerEmojis,
  });

  static const double _timeWidth = 48;
  static const double _typeWidth = 30;
  static const double _ownerWidth = 28;
  static const double _durationWidth = 52;
  static const double _deleteWidth = 28;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final proposedById = <String, ProposedSet>{
      for (final p in proposedSets) p.id: p,
    };
    final done = completedSets.where((c) => c.endedAt != Int64.ZERO).toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    if (done.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'COMPLETED SETS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: colorScheme.tertiary,
            ),
          ),
        ),
        for (int i = 0; i < done.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outline.withValues(alpha: 0.08),
            ),
          _buildRow(context, done[i], proposedById, colorScheme),
        ],
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    CompletedSet completed,
    Map<String, ProposedSet> proposedById,
    ColorScheme colorScheme,
  ) {
    final proposed = proposedById[completed.proposedSetId];
    final unit = context.watch<SettingsProvider>().weightUnit;
    final exerciseName = proposed != null
        ? (exerciseNames[proposed.exercise] ?? '?')
        : '?';
    final isWarmup = proposed?.warmup ?? false;

    final String weightStr = formatWeight(
      completed.actualWeight.toDouble(),
      unit,
    );

    final finishTime = DateTime.fromMillisecondsSinceEpoch(
      completed.endedAt.toInt() * 1000,
    );
    final timeStr =
        '${finishTime.hour.toString().padLeft(2, '0')}:${finishTime.minute.toString().padLeft(2, '0')}';

    final durationSecs = (completed.endedAt - completed.startedAt).toInt();
    final durationStr = durationSecs < 60
        ? '${durationSecs}s'
        : '${durationSecs ~/ 60}m${(durationSecs % 60).toString().padLeft(2, '0')}s';

    final canDelete =
        onDelete != null &&
        (deletableWorkoutId == null ||
            completed.workoutId == deletableWorkoutId);
    final ownerEmoji = workoutOwnerEmojis?[completed.workoutId] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _timeWidth,
            child: Text(
              timeStr,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.tertiary,
              ),
            ),
          ),
          SizedBox(
            width: _typeWidth,
            child: Text(
              isWarmup ? '🔥' : '🏋️',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          SizedBox(
            width: _ownerWidth,
            child: Text(
              ownerEmoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  '$exerciseName  ${completed.actualReps}×$weightStr',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _durationWidth,
            child: Text(
              durationStr,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.tertiary.withValues(alpha: 0.78),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: _deleteWidth,
            child: Center(
              child: canDelete
                  ? _deleteButton(context, completed, colorScheme)
                  : const SizedBox(width: 18, height: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteButton(
    BuildContext context,
    CompletedSet completed,
    ColorScheme colorScheme,
  ) {
    return InkResponse(
      radius: 18,
      onTap: () async {
        final weight = completed.actualWeight.toDouble();
        final weightText = formatWeight(
          weight,
          context.read<SettingsProvider>().weightUnit,
        );
        final confirmed = await _confirmDelete(
          context,
          setSummary: '${completed.actualReps}×$weightText',
        );
        if (confirmed == true) onDelete!(completed.id);
      },
      child: Icon(
        Icons.delete_outline_rounded,
        size: 18,
        color: colorScheme.outline.withValues(alpha: 0.62),
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context, {
    required String setSummary,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Delete Completed Set?'),
          content: Text('Remove set $setSummary? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
