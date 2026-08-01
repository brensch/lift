/// The selectable grid of exercise groups on the home screen and its chips.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../gen/workout/v1/settings.pb.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../providers/settings_provider.dart';
import '../../logic/exercises.dart';
import '../../logic/weight_units.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_message_chip.dart';
import 'exercise_config_details.dart';
import 'home_selection.dart';

class GroupGrid extends StatelessWidget {
  final List<int> indices;
  final List<HomeSelectableGroup> groups;
  final List<UserMessage> scheduleMessages;
  final Set<int> selectedIndices;
  final void Function(int) onToggle;
  final void Function(int) onEdit;
  final void Function(int)? onDelete;

  const GroupGrid({super.key, 
    required this.indices,
    required this.groups,
    required this.scheduleMessages,
    required this.selectedIndices,
    required this.onToggle,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < indices.length; i++) ...[
          GroupChip(
            group: groups[indices[i]],
            scheduleMessages: scheduleMessages,
            isSelected: selectedIndices.contains(indices[i]),
            onTap: () => onToggle(indices[i]),
            onEdit: () => onEdit(indices[i]),
            onDelete: onDelete == null ? null : () => onDelete!(indices[i]),
          ),
          if (i < indices.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─── Group chip ───────────────────────────────────────────────────────────────

class GroupChip extends StatelessWidget {
  final HomeSelectableGroup group;
  final List<UserMessage> scheduleMessages;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const GroupChip({super.key, 
    required this.group,
    required this.scheduleMessages,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  // The server materializes each group's sets (warmups + working, plate-snapped);
  // the chip just filters and formats them — no client-side generation.
  List<ProposedSet> _setsForConfig(ExerciseTypeConfig cfg, {required bool warmup}) =>
      group.materializedSets
          .where((s) =>
              s.exercise == cfg.exercise && s.warmup == warmup && !s.cancelled)
          .toList();

  String _formatProposedSetLine(ProposedSet s, WeightUnit unit) {
    final reps = s.isAmrap ? '${s.targetReps}+' : '${s.targetReps}';
    return '${formatWeight(s.targetWeight.toDouble(), unit, includeUnit: true)} × $reps';
  }

  List<SetLine> _warmupLinesForConfig(
    ExerciseTypeConfig cfg,
    WeightUnit unit,
  ) {
    final warmups = _setsForConfig(cfg, warmup: true);
    return [
      for (int i = 0; i < warmups.length; i++)
        (
          index: i + 1,
          text: _formatProposedSetLine(warmups[i], unit),
          note: i == warmups.length - 1 ? 'Last warmup before work sets.' : '',
        ),
    ];
  }

  List<SetLine> _workingLinesForConfig(
    ExerciseTypeConfig cfg,
    WeightUnit unit,
  ) {
    final working = _setsForConfig(cfg, warmup: false);
    return [
      for (int i = 0; i < working.length; i++)
        (
          index: i + 1,
          text: _formatProposedSetLine(working[i], unit),
          note: working[i].instruction,
        ),
    ];
  }

  double? _maxWorkingWeight() {
    double? maxWeight;
    for (final s in group.materializedSets.where((s) => !s.warmup && !s.cancelled)) {
      final weight = s.targetWeight.toDouble();
      if (maxWeight == null || weight > maxWeight) maxWeight = weight;
    }
    return maxWeight;
  }

  int _workingSetCount() =>
      group.materializedSets.where((s) => !s.warmup && !s.cancelled).length;

  int _exerciseCount() => group.exerciseConfigs.length;

  bool get _isRecommended => group.section == HomeGroupSection.recommended;

  Widget _chip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
  }

  Widget _recommendedIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        size: 14,
        color: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    final unit = context.read<SettingsProvider>().weightUnit;
    final groupMessages = messagesForHomeGroup(group, scheduleMessages);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.sheetColor(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLg),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (int i = 0; i < group.exerciseConfigs.length; i++)
                  ExerciseConfigDetailsCard(
                    title:
                        exerciseNames[group.exerciseConfigs[i].exercise] ??
                        'Exercise',
                    notes: [
                      for (final message in messagesForExerciseConfig(
                        group.exerciseConfigs[i],
                        groupMessages,
                      ))
                        UserMessageChip(message: message, compact: true),
                      if (i == 0 &&
                          group.explanation.isNotEmpty &&
                          groupMessages.isEmpty)
                        Builder(
                          builder: (context) {
                            final colorScheme = Theme.of(context).colorScheme;
                            return Text(
                              group.explanation,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.76,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                    warmupLines: _warmupLinesForConfig(
                      group.exerciseConfigs[i],
                      unit,
                    ),
                    workingSetLines: _workingLinesForConfig(
                      group.exerciseConfigs[i],
                      unit,
                    ),
                    meta: [
                      if (group.exerciseConfigs[i].hasRestConfig())
                        'Rest ${group.exerciseConfigs[i].restConfig.restAfterSuccess}s',
                      if (group.exerciseConfigs[i].lastSetAmrap)
                        'Last set AMRAP',
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final maxWeight = _maxWorkingWeight();
    final weightLabel = maxWeight == null
        ? 'No weight'
        : formatWeight(maxWeight, unit, includeUnit: true);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppTheme.brMd,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 0),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerLowest,
            borderRadius: AppTheme.brMd,
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.45),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isRecommended) ...[
                    _recommendedIcon(context),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        height: 1.0,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    weightLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.9)
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chip(context, '${_workingSetCount()} sets'),
                      if (_exerciseCount() > 1) ...[
                        const SizedBox(width: 6),
                        _chip(context, '${_exerciseCount()} ex'),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 17,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    tooltip: 'Edit group',
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(28, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: colorScheme.error.withValues(alpha: 0.85),
                      ),
                      tooltip: 'Delete saved group',
                    ),
                  IconButton(
                    onPressed: () => _showDetails(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
