/// The current-exercise card: what set you are on, set progress, chips (including the celebratory rainbow chip).
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_groups.dart';
import '../../logic/exercises.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class CurrentExerciseCard extends StatelessWidget {
  final ExerciseGroupData group;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final VoidCallback onEdit;

  const CurrentExerciseCard({super.key, 
    required this.group,
    required this.completedSets,
    required this.activeSetId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title =
        group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (group.sets.any((set) => set.warmup)) ...[
            SetProgressSection(
              label: 'Warmup',
              children: group.sets
                  .where((set) => set.warmup)
                  .map(
                    (set) => CurrentSetChip(
                      set: set,
                      completedSets: completedSets,
                      activeSetId: activeSetId,
                      isSuperset: group.exercises.length > 1,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          if (group.sets.any((set) => !set.warmup))
            SetProgressSection(
              label: 'Working Sets',
              children: group.sets
                  .where((set) => !set.warmup)
                  .map(
                    (set) => CurrentSetChip(
                      set: set,
                      completedSets: completedSets,
                      activeSetId: activeSetId,
                      isSuperset: group.exercises.length > 1,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class SetProgressSection extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const SetProgressSection({super.key, required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class CurrentSetChip extends StatelessWidget {
  final ProposedSet set;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final bool isSuperset;

  const CurrentSetChip({super.key, 
    required this.set,
    required this.completedSets,
    required this.activeSetId,
    required this.isSuperset,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final exerciseName = exerciseNames[set.exercise] ?? '?';
    final exerciseMarker = exerciseName.isNotEmpty ? exerciseName[0] : '?';
    final completed = completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.proposedSetId == set.id && c.endedAt != Int64.ZERO,
      orElse: () => null,
    );
    final isActive = set.id == activeSetId;
    final weight = formatWeight(set.targetWeight.toDouble(), unit);
    final targetText = set.isAmrap ? '${set.targetReps}+' : '${set.targetReps}';

    // The set you're currently lifting shimmers through a rainbow.
    if (isActive && completed == null) {
      final base = '$weight · $targetText';
      return RainbowSetChip(
        text: isSuperset ? '$exerciseMarker $base' : base,
      );
    }

    Color bg;
    Color fg;
    Color borderColor;
    String mainText;

    if (completed != null) {
      final hitTarget = completed.actualReps >= set.targetReps;
      bg = hitTarget ? AppTheme.successBg : AppTheme.warningBg;
      fg = hitTarget ? AppTheme.successFg : AppTheme.warningFg;
      borderColor = fg.withValues(alpha: 0.25);
      mainText = '${completed.actualReps}/$targetText';
    } else if (set.warmup) {
      bg = isActive
          ? AppTheme.warmupLight
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
      fg = isActive
          ? AppTheme.warmupFg
          : colorScheme.onSurface.withValues(alpha: 0.78);
      borderColor = isActive
          ? AppTheme.warmupFg.withValues(alpha: 0.4)
          : colorScheme.outline.withValues(alpha: 0.22);
      mainText = '$weight · $targetText';
    } else if (isActive) {
      bg = AppTheme.workoutLiftingBg;
      fg = AppTheme.workoutLiftingFg;
      borderColor = AppTheme.workoutLiftingFg.withValues(alpha: 0.4);
      mainText = '$weight · $targetText';
    } else {
      bg = colorScheme.surfaceContainerLowest;
      fg = colorScheme.onSurface;
      borderColor = colorScheme.outline.withValues(alpha: 0.22);
      mainText = '$weight · $targetText';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        isSuperset ? '$exerciseMarker $mainText' : mainText,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
          color: fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The set chip for whatever you're lifting right now: a rainbow gradient that
/// sweeps across both the border and the text.
class RainbowSetChip extends StatefulWidget {
  final String text;
  const RainbowSetChip({super.key, required this.text});

  @override
  State<RainbowSetChip> createState() => RainbowSetChipState();
}

class RainbowSetChipState extends State<RainbowSetChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 2),
    vsync: this,
  )..repeat();

  static const _colors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.red,
  ];
  static const _stops = [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final gradient = LinearGradient(
          colors: _colors,
          stops: _stops,
          begin: Alignment(-2.0 + 4 * t, 0),
          end: Alignment(0.0 + 4 * t, 0),
          tileMode: TileMode.repeated,
        );
        return Container(
          // Gradient border drawn as a 1.5px frame behind the inner fill.
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12.5),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: Colors.white, // replaced by the shader
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
