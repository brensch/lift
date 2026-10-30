/// The log of done sets, newest first: a full-width row per set — when, how
/// long the rest before it was, a small circle like the set's own on the
/// workout page, whose (in a session), what, and weight × reps — split by
/// hairlines.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pbenum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/set_labels.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';
import 'common/flat.dart';

class SetLog extends StatelessWidget {
  final List<ProposedSet> proposedSets;
  final List<CompletedSet> completedSets;
  final void Function(String completedSetId)? onDelete;
  final String? deletableWorkoutId;
  final Map<String, String>? workoutOwnerLabels;
  final Map<String, String>? workoutOwnerEmojis;

  /// When true the heading stays pinned and only the rows scroll. Requires
  /// the widget to be given a bounded height (e.g. inside Expanded).
  final bool stickyHeader;

  const SetLog({
    super.key,
    required this.proposedSets,
    required this.completedSets,
    this.onDelete,
    this.deletableWorkoutId,
    this.workoutOwnerLabels,
    this.workoutOwnerEmojis,
    this.stickyHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final proposedById = <String, ProposedSet>{
      for (final p in proposedSets) p.id: p,
    };
    final done = completedSets.where((c) => c.endedAt.toInt() > 0).toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    if (done.isEmpty) {
      if (!stickyHeader) return const SizedBox.shrink();
      return _emptyState(context);
    }

    // Whose set only matters with more than one person's sets in the log.
    final hasOwners = done.map((c) => c.workoutId).toSet().length > 1;

    // The rest before each set: from the previous done set of the same
    // workout to this one's start (or its finish, if it was never started).
    final restBefore = <String, int>{};
    final oldestFirst = done.reversed.toList();
    final lastEnd = <String, int>{};
    for (final c in oldestFirst) {
      final prev = lastEnd[c.workoutId];
      final began = c.startedAt.toInt() > 0
          ? c.startedAt.toInt()
          : c.endedAt.toInt();
      if (prev != null && began > prev) restBefore[c.id] = began - prev;
      lastEnd[c.workoutId] = c.endedAt.toInt();
    }

    final heading = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: SectionLabel('Completed sets · ${done.length}'),
    );

    final rows = [
      for (final c in done)
        _LogRow(
          completed: c,
          proposed: proposedById[c.proposedSetId],
          plan: proposedSets,
          unit: unit,
          ownerEmoji: hasOwners
              ? (workoutOwnerEmojis?[c.workoutId] ?? '')
              : null,
          restBefore: restBefore[c.id],
          onDelete:
              onDelete != null &&
                  (deletableWorkoutId == null ||
                      c.workoutId == deletableWorkoutId)
              ? () => _delete(context, c)
              : null,
        ),
    ];

    if (!stickyHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [heading, ...rows],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            children: rows,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'NO SETS YET',
            style: t.mono(
              TextStyle(
                fontSize: t.size.bodyLg,
                fontWeight: t.weight.bold,
                letterSpacing: 1,
                color: t.text,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Get schlifting mate',
            style: TextStyle(fontSize: t.size.body, color: t.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, CompletedSet completed) async {
    final weightText = formatWeight(
      completed.actualWeight.toDouble(),
      context.read<SettingsProvider>().weightUnit,
      includeUnit: true,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Delete Completed Set?'),
          content: Text(
            'Remove set $weightText × ${completed.actualReps}? This cannot '
            'be undone.',
          ),
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
    if (confirmed == true) onDelete!(completed.id);
  }
}

class _LogRow extends StatelessWidget {
  final CompletedSet completed;
  final ProposedSet? proposed;
  final List<ProposedSet> plan;
  final WeightUnit unit;

  /// Whose set, in a session; null when it's only ever yours.
  final String? ownerEmoji;

  /// Seconds from the set before to this one, if there was one.
  final int? restBefore;
  final VoidCallback? onDelete;

  const _LogRow({
    required this.completed,
    required this.proposed,
    required this.plan,
    required this.unit,
    required this.ownerEmoji,
    required this.restBefore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final proposed = this.proposed;
    final warmup = proposed?.warmup ?? false;
    final target = proposed?.targetReps ?? completed.actualReps;
    final reps = completed.actualReps;
    final finished = DateTime.fromMillisecondsSinceEpoch(
      completed.endedAt.toInt() * 1000,
    );
    String two(int n) => n.toString().padLeft(2, '0');
    final rest = restBefore;

    final line = proposed == null ? '' : setLineFor(proposed, plan);
    final weight = formatWeight(completed.actualWeight.toDouble(), unit);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          // When, and the rest before it.
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${two(finished.hour)}:${two(finished.minute)}',
                  style: t.mono(
                    TextStyle(
                      fontSize: t.size.small,
                      fontWeight: t.weight.bold,
                      color: t.text,
                    ),
                  ),
                ),
                if (rest != null)
                  Text(
                    '+${rest ~/ 60}:${two(rest % 60)}',
                    style: t.mono(
                      TextStyle(fontSize: t.size.caption, color: t.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniCircle(reps: reps, target: target, warmup: warmup),
          if (ownerEmoji != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              child: Text(
                ownerEmoji!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: t.size.bodyLg),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposed == null
                      ? '?'
                      : (exerciseNames[proposed.exercise] ?? '?'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.size.body,
                    fontWeight: t.weight.bold,
                    color: warmup ? t.muted : t.text,
                  ),
                ),
                if (line.isNotEmpty)
                  Text(
                    line,
                    style: TextStyle(fontSize: t.size.small, color: t.muted),
                  ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: weight),
                TextSpan(
                  text: ' ${weightUnitSuffix(unit)} ',
                  style: TextStyle(fontSize: t.size.caption, color: t.muted),
                ),
                TextSpan(text: '× $reps'),
              ],
            ),
            style: t.mono(
              TextStyle(
                fontSize: t.size.bodyLg,
                fontWeight: t.weight.bold,
                color: warmup ? t.muted : t.text,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: onDelete == null
                ? null
                : IconButton(
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      AppIcons.delete,
                      size: t.size.bodyLg,
                      color: t.muted,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The set's circle in small, as on the workout page: ink for every rep,
/// amber when short, an outline for a warmup.
class _MiniCircle extends StatelessWidget {
  final int reps;
  final int target;
  final bool warmup;

  const _MiniCircle({
    required this.reps,
    required this.target,
    required this.warmup,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (fill, ring, ink) = warmup
        ? (Colors.transparent, t.outline, t.muted)
        : reps >= target
        ? (t.text, t.text, t.background)
        : reps == 0
        ? (Colors.transparent, t.effort, t.effort)
        : (t.effort, t.effort, t.text);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 1.5),
      ),
      child: Text(
        '$reps',
        style: t.mono(
          TextStyle(
            fontSize: t.size.small,
            fontWeight: t.weight.bold,
            color: ink,
            height: 1,
          ),
        ),
      ),
    );
  }
}
