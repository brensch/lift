/// Per-exercise editor: weight, reps, sets, warmup toggle.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../common/weight_picker.dart';
import 'editable_config.dart';

/// Compact exercise config row. Tap to expand settings.
class CompactExerciseConfig extends StatefulWidget {
  final EditableConfig config;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<double> onStartWeightChanged;
  final ValueChanged<double> onEndWeightChanged;
  final ValueChanged<bool> onDifferentEndWeightChanged;
  final ValueChanged<bool> onWarmupChanged;
  final ValueChanged<RestConfig> onRestChanged;

  const CompactExerciseConfig({
    super.key,
    required this.config,
    required this.isExpanded,
    required this.onTap,
    required this.onDelete,
    required this.onStartWeightChanged,
    required this.onEndWeightChanged,
    required this.onDifferentEndWeightChanged,
    required this.onWarmupChanged,
    required this.onRestChanged,
  });

  @override
  State<CompactExerciseConfig> createState() => CompactExerciseConfigState();
}

class CompactExerciseConfigState extends State<CompactExerciseConfig> {
  late FixedExtentScrollController _repsController;

  @override
  void initState() {
    super.initState();
    _repsController = FixedExtentScrollController(
      initialItem: (widget.config.reps - 1).clamp(0, 29),
    );
  }

  @override
  void didUpdateWidget(CompactExerciseConfig oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.reps != oldWidget.config.reps) {
      final targetIndex = (widget.config.reps - 1).clamp(0, 29);
      if (_repsController.selectedItem != targetIndex) {
        _repsController.jumpToItem(targetIndex);
      }
    }
  }

  @override
  void dispose() {
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _showWeightPicker(
    BuildContext context,
    double initialWeight,
    ValueChanged<double> onChanged,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          WeightPicker(initialWeight: initialWeight, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = exerciseNames[widget.config.exercise] ?? '?';
    final hasEndWeight = widget.config.differentEndWeight;

    return ClipRRect(
      borderRadius: AppTheme.brMd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: widget.isExpanded
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : Colors.transparent,
          border: Border.all(
            color: widget.isExpanded
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outline.withValues(alpha: 0.5),
          ),
          borderRadius: AppTheme.brMd,
        ),
        child: Column(
          children: [
            // Main Row
            InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(AppTheme.radiusMd),
                bottom: Radius.circular(widget.isExpanded ? 0 : AppTheme.radiusMd),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Exercise Name
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Weight Box (Start)
                    SizedBox(
                      height: 48,
                      child: WeightDisplayBox(
                        weight: widget.config.startWeight,
                        onTap: () => _showWeightPicker(
                          context,
                          widget.config.startWeight,
                          widget.onStartWeightChanged,
                        ),
                      ),
                    ),

                    // 'x' separator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'x',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ),

                    // Reps Scrollwheel
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        borderRadius: AppTheme.brSm,
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        color: colorScheme.surface,
                      ),
                      child: Stack(
                        children: [
                          ListWheelScrollView.useDelegate(
                            controller: _repsController,
                            itemExtent: 24, // Smaller extent to show neighbors
                            magnification: 1.3,
                            useMagnifier: true,
                            physics: const FixedExtentScrollPhysics(),
                            diameterRatio: 1.5,
                            squeeze: 1.2, // Squeeze items closer
                            perspective: 0.004,
                            onSelectedItemChanged: (index) {
                              widget.config.reps = index + 1;
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount:
                                  30, // Limit to 30 items (index 0 is rep 1)
                              builder: (context, index) {
                                final rep = index + 1;
                                return Center(
                                  child: Text(
                                    '$rep',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Scroll indicators (gradients)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppTheme.radiusSm),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colorScheme.surface,
                                    colorScheme.surface.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(AppTheme.radiusSm),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    colorScheme.surface,
                                    colorScheme.surface.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Settings Cog
                    Icon(
                      Icons.settings,
                      size: 20,
                      color: widget.isExpanded
                          ? colorScheme.primary
                          : colorScheme.tertiary,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded Settings
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: widget.isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),

                          // Warmup & Delete Row
                          Row(
                            children: [
                              Switch(
                                value: widget.config.includeWarmup,
                                onChanged: widget.onWarmupChanged,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'WARMUP SET',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.tertiary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              IconButton.filledTonal(
                                onPressed: widget.onDelete,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.errorContainer,
                                  foregroundColor: colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Different End Weight Row
                          Row(
                            children: [
                              Switch(
                                value: hasEndWeight,
                                onChanged: widget.onDifferentEndWeightChanged,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'DIFFERENT END WEIGHT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.tertiary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),

                          if (hasEndWeight) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  height: 48,
                                  child: WeightDisplayBox(
                                    weight: widget.config.endWeight,
                                    onTap: () => _showWeightPicker(
                                      context,
                                      widget.config.endWeight,
                                      widget.onEndWeightChanged,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const CountButton({super.key, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: AppTheme.brSm,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: AppTheme.brSm,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
