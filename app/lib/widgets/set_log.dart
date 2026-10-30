import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/settings.pbenum.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

class SetLog extends StatelessWidget {
  final List<ProposedSet> proposedSets;
  final List<CompletedSet> completedSets;
  final void Function(String completedSetId)? onDelete;
  final String? deletableWorkoutId;
  final Map<String, String>? workoutOwnerLabels;
  final Map<String, String>? workoutOwnerEmojis;

  /// When true the title + column header stay pinned and only the rows scroll.
  /// Requires the widget to be given a bounded height (e.g. inside Expanded).
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

  // A fixed result-column width (rather than intrinsic) so the pinned header
  // table and the scrolling body table line their columns up identically.
  static const Map<int, TableColumnWidth> _columnWidths = {
    0: FixedColumnWidth(44), // time
    1: FixedColumnWidth(26), // type icon
    2: FixedColumnWidth(24), // owner emoji
    3: FlexColumnWidth(), // exercise name
    4: FixedColumnWidth(96), // result (weight × reps)
    5: FixedColumnWidth(26), // delete
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final proposedById = <String, ProposedSet>{
      for (final p in proposedSets) p.id: p,
    };
    final done = completedSets.toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    if (done.isEmpty) {
      if (!stickyHeader) return const SizedBox.shrink();
      return _emptyState(context, colorScheme);
    }

    final hasOwners = done.any(
      (c) => (workoutOwnerEmojis?[c.workoutId] ?? '').isNotEmpty,
    );

    final title = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'COMPLETED SETS',
        style: TextStyle(
          fontSize: context.tokens.size.small,
          fontWeight: context.tokens.weight.bold,
          letterSpacing: 1.5,
          color: colorScheme.tertiary,
        ),
      ),
    );

    final rowDivider = TableBorder(
      horizontalInside: BorderSide(
        color: colorScheme.outline.withValues(alpha: 0.12),
      ),
    );

    final bodyRows = [
      for (final c in done)
        _dataRow(context, c, proposedById, unit, colorScheme, hasOwners),
    ];

    if (!stickyHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          Table(
            columnWidths: _columnWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: rowDivider,
            children: [_headerRow(context, colorScheme), ...bodyRows],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        Table(
          columnWidths: _columnWidths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [_headerRow(context, colorScheme)],
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            child: Table(
              columnWidths: _columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: rowDivider,
              children: bodyRows,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏋️', style: TextStyle(fontSize: context.tokens.size.display)),
          const SizedBox(height: 14),
          Text(
            'No completed sets yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.tokens.size.bodyLg,
              fontWeight: context.tokens.weight.heavy,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Get schlifting mate',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              fontWeight: context.tokens.weight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _headerRow(BuildContext context, ColorScheme colorScheme) {
    Widget label(String text, TextAlign align, EdgeInsets padding) {
      return Padding(
        padding: padding,
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: context.tokens.size.caption,
            fontWeight: context.tokens.weight.heavy,
            letterSpacing: 0.6,
            color: colorScheme.tertiary.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    const headerPad = EdgeInsets.only(bottom: 8);
    return TableRow(
      children: [
        label('TIME', TextAlign.right, headerPad),
        const SizedBox.shrink(),
        const SizedBox.shrink(),
        label(
          'EXERCISE',
          TextAlign.left,
          const EdgeInsets.only(left: 10, bottom: 8),
        ),
        label(
          'RESULT',
          TextAlign.right,
          const EdgeInsets.only(left: 10, bottom: 8),
        ),
        const SizedBox.shrink(),
      ],
    );
  }

  TableRow _dataRow(
    BuildContext context,
    CompletedSet completed,
    Map<String, ProposedSet> proposedById,
    WeightUnit unit,
    ColorScheme colorScheme,
    bool hasOwners,
  ) {
    final proposed = proposedById[completed.proposedSetId];
    final exerciseName = proposed != null
        ? (exerciseNames[proposed.exercise] ?? '?')
        : '?';
    final isWarmup = proposed?.warmup ?? false;
    final weightStr = formatWeight(
      completed.actualWeight.toDouble(),
      unit,
      includeUnit: true,
    );
    final resultStr = '$weightStr × ${completed.actualReps}';

    // Colour the result by whether the set hit its target reps.
    Color resultColor = colorScheme.onSurface;
    if (!isWarmup && proposed != null) {
      resultColor = completed.actualReps >= proposed.targetReps
          ? context.tokens.successFg
          : context.tokens.warningFg;
    } else if (isWarmup) {
      resultColor = colorScheme.onSurface.withValues(alpha: 0.7);
    }

    final finishTime = DateTime.fromMillisecondsSinceEpoch(
      completed.endedAt.toInt() * 1000,
    );
    final timeStr =
        '${finishTime.hour.toString().padLeft(2, '0')}:${finishTime.minute.toString().padLeft(2, '0')}';

    final canDelete =
        onDelete != null &&
        (deletableWorkoutId == null ||
            completed.workoutId == deletableWorkoutId);
    final ownerEmoji = workoutOwnerEmojis?[completed.workoutId] ?? '';

    const cellPad = EdgeInsets.symmetric(vertical: 10);

    return TableRow(
      children: [
        Padding(
          padding: cellPad,
          child: Text(
            timeStr,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: context.tokens.size.small,
              fontWeight: context.tokens.weight.bold,
              color: colorScheme.tertiary,
            ),
          ),
        ),
        Padding(
          padding: cellPad,
          child: Text(
            isWarmup ? '🔥' : '🏋️',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: context.tokens.size.bodyLg),
          ),
        ),
        Padding(
          padding: cellPad,
          child: hasOwners
              ? Text(
                  ownerEmoji,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: context.tokens.size.bodyLg),
                )
              : const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Text(
            exerciseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: -0.2,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
          child: Text(
            resultStr,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: -0.2,
              color: resultColor,
            ),
          ),
        ),
        Padding(
          padding: cellPad,
          child: Center(
            child: canDelete
                ? _deleteButton(context, completed, colorScheme)
                : const SizedBox(width: 18, height: 18),
          ),
        ),
      ],
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
          includeUnit: true,
        );
        final confirmed = await _confirmDelete(
          context,
          setSummary: '$weightText × ${completed.actualReps}',
        );
        if (confirmed == true) onDelete!(completed.id);
      },
      child: Icon(
        AppIcons.delete,
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
