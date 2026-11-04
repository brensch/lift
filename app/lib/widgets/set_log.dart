/// The log of done sets, newest first: a full-width row per set — when, how
/// long the rest before it was, a small circle like the set's own on the
/// workout page, whose (in a session), what, and weight × reps — split by
/// hairlines.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pbenum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/session_state.dart';
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
    this.workoutOwnerEmojis,
    this.stickyHeader = false,
  });

  @override
  Widget build(BuildContext context) {
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

    // The gap before each set, from the previous done set of the same
    // workout to this one's start (or its finish, if it was never started):
    // resting until that set's rest ran out, yapping after it, as the heart
    // chart's bands split it.
    final gapBefore = <String, ({int rest, int yap})>{};
    final previous = <String, CompletedSet>{};
    for (final c in done.reversed) {
      final prev = previous[c.workoutId];
      if (prev != null) {
        final ended = prev.endedAt.toInt();
        final began = c.startedAt.toInt() > 0
            ? c.startedAt.toInt()
            : c.endedAt.toInt();
        final restUntil = prev.restUntil.toInt() > ended
            ? prev.restUntil.toInt()
            : began;
        final restEnd = restUntil < began ? restUntil : began;
        final rest = restEnd - ended;
        final yap = began - restEnd;
        if (rest > 0 || yap > 0) {
          gapBefore[c.id] = (rest: rest > 0 ? rest : 0, yap: yap);
        }
      }
      previous[c.workoutId] = c;
    }

    final heading = FlatHeading('Completed sets · ${done.length}');

    // Newest first: each set, then the gap before it (the yap, then the
    // rest), then the set before.
    final rows = [
      for (final c in done) ...[
        _LogRow(
          completed: c,
          proposed: proposedById[c.proposedSetId],
          plan: proposedSets,
          unit: unit,
          ownerEmoji: hasOwners
              ? (workoutOwnerEmojis?[c.workoutId] ?? '')
              : null,
          onDelete:
              onDelete != null &&
                  (deletableWorkoutId == null ||
                      c.workoutId == deletableWorkoutId)
              ? () => _delete(context, c)
              : null,
        ),
        if (gapBefore[c.id] case final gap?)
          _GapRow(rest: gap.rest, yap: gap.yap),
      ],
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

  final VoidCallback? onDelete;

  const _LogRow({
    required this.completed,
    required this.proposed,
    required this.plan,
    required this.unit,
    required this.ownerEmoji,
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

    final line = proposed == null ? '' : setLineFor(proposed, plan);
    final weight = formatWeight(completed.actualWeight.toDouble(), unit);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          // When it finished; the gap before it has rows of its own.
          SizedBox(
            width: 50,
            child: Text(
              '${two(finished.hour)}:${two(finished.minute)}',
              style: t.mono(
                TextStyle(
                  fontSize: t.size.small,
                  fontWeight: t.weight.bold,
                  color: t.text,
                ),
              ),
            ),
          ),
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
                  proposed == null ? '?' : exerciseName(proposed.exercise),
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
          // The weight, then the reps once: in the set's circle.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: weight),
                TextSpan(
                  text: ' ${weightUnitSuffix(unit)} ',
                  style: TextStyle(fontSize: t.size.caption, color: t.muted),
                ),
                const TextSpan(text: '×'),
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
          const SizedBox(width: 8),
          _MiniCircle(reps: reps, target: target, warmup: warmup),
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

/// The stretch between two sets, as one thin row: resting (the set
/// before's rest running) then yapping (rest over, the next set not begun),
/// each as wide as its share of the time, its text in the heart chart's
/// colour, a hairline between them.
class _GapRow extends StatelessWidget {
  final int rest;
  final int yap;

  const _GapRow({required this.rest, required this.yap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget part(int seconds, String label, Color color, bool leading) =>
        _GapPart(
          seconds: seconds,
          label: label,
          color: color,
          leading: leading,
        );
    final resting = part(rest, copy.workout.resting, t.resting, true);
    final yapping = part(yap, copy.workout.yapping, t.yapping, rest <= 0);
    return Container(
      height: 24,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: rest <= 0 || yap <= 0
          ? (rest > 0 ? resting : yapping)
          : LayoutBuilder(
              builder: (context, constraints) {
                // Split by time, but neither part narrower than its words.
                final total = constraints.maxWidth - 1;
                final restLeast = _GapPart.least(
                  context,
                  rest,
                  copy.workout.resting,
                  leading: true,
                );
                final yapLeast = _GapPart.least(
                  context,
                  yap,
                  copy.workout.yapping,
                  leading: false,
                );
                var restWidth = total * rest / (rest + yap);
                if (restLeast + yapLeast <= total) {
                  restWidth = restWidth.clamp(restLeast, total - yapLeast);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: restWidth, child: resting),
                    VerticalDivider(width: 1, thickness: 1, color: t.hairline),
                    Expanded(child: yapping),
                  ],
                );
              },
            ),
    );
  }
}

/// One part of a gap: its time and what it was, as much of that as fits.
class _GapPart extends StatelessWidget {
  final int seconds;
  final String label;
  final Color color;

  /// First in its row: its text lines up with the sets' times.
  final bool leading;

  const _GapPart({
    required this.seconds,
    required this.label,
    required this.color,
    required this.leading,
  });

  static TextStyle _style(BuildContext context, Color? color) {
    final t = context.tokens;
    return t.mono(
      TextStyle(
        fontSize: t.size.caption,
        fontWeight: t.weight.bold,
        letterSpacing: 0.5,
        color: color,
      ),
    );
  }

  static String _full(int seconds, String label) =>
      '${formatRestClock(seconds)}  ${label.toUpperCase()}';

  static double _start(bool leading) => leading ? 16 : 8;

  static double _width(BuildContext context, String text) => (TextPainter(
    text: TextSpan(text: text, style: _style(context, null)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout()).width;

  /// The width a part needs to show its time and label whole.
  static double least(
    BuildContext context,
    int seconds,
    String label, {
    required bool leading,
  }) => _start(leading) + _width(context, _full(seconds, label)) + 8;

  @override
  Widget build(BuildContext context) {
    final style = _style(context, color);
    final time = formatRestClock(seconds);
    final full = _full(seconds, label);
    final start = _start(leading);
    return LayoutBuilder(
      builder: (context, constraints) {
        // On a row too narrow for both parts whole, as much as fits.
        final room = constraints.maxWidth - start - 8;
        final text = _width(context, full) <= room
            ? full
            : _width(context, time) <= room
            ? time
            : null;
        return Padding(
          padding: EdgeInsets.only(left: start, right: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: text == null
                ? null
                : Text(text, maxLines: 1, softWrap: false, style: style),
          ),
        );
      },
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
        ? (Colors.transparent, t.short, t.short)
        : (t.short, t.short, t.text);
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
