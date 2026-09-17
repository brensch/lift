/// The workout bar's controls: drag handle, timer/heart box, the big action button, and rep-count buttons.
library;

import 'package:flutter/material.dart';
import '../dialogs/health_dialogs.dart';

class DragHandle extends StatelessWidget {
  /// Height of the pill itself; the bar uses this to centre it in its slot.
  static const double thickness = 4.0;

  final bool isExpanded;
  const DragHandle({super.key, required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: thickness,
      decoration: BoxDecoration(
        color: colorScheme.onSecondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── Session member card ──────────────────────────────────────────────────────

class TimerHeartBox extends StatelessWidget {
  final String elapsedText;
  final String heartRateText;
  final bool heartRateDetected;
  const TimerHeartBox({super.key, 
    required this.elapsedText,
    required this.heartRateText,
    required this.heartRateDetected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      width: 84,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 14, color: colorScheme.tertiary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  elapsedText,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // When no heart rate is detected, tapping shows OS-specific instructions
          // on enabling live BPM. Once HR is streaming there's nothing to fix, so the
          // row is just a static readout.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: heartRateDetected
                ? null
                : () => showHeartRateHelpDialog(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, size: 14, color: Color(0xFFE11D48)),
                const SizedBox(width: 4),
                Text(
                  heartRateText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface,
                    height: 1.0,
                  ),
                ),
                if (!heartRateDetected) ...[
                  const SizedBox(width: 3),
                  Icon(
                    Icons.help_outline,
                    size: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Big full-width action button ─────────────────────────────────────────────

class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const BigButton({super.key, 
    required this.label,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (secondaryLabel != null && onSecondary != null) ...[
          SizedBox(
            height: 64,
            child: OutlinedButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: SizedBox(
            height: 64,
            child: FilledButton(
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Rep picker + complete button ─────────────────────────────────────────────

class RepButtons extends StatefulWidget {
  final int targetReps;
  final void Function(int reps) onComplete;
  final VoidCallback? onSkipWarmup;

  const RepButtons({
    super.key,
    required this.targetReps,
    required this.onComplete,
    this.onSkipWarmup,
  });

  @override
  State<RepButtons> createState() => RepButtonsState();
}

class RepButtonsState extends State<RepButtons> {
  late final FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(
      initialItem: widget.targetReps.clamp(0, 50),
    );
  }

  @override
  void didUpdateWidget(RepButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetReps != widget.targetReps) {
      _scrollController.jumpToItem(widget.targetReps.clamp(0, 50));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline),
              ),
              child: ListWheelScrollView.useDelegate(
                controller: _scrollController,
                itemExtent: 24,
                magnification: 1.5,
                useMagnifier: true,
                physics: const FixedExtentScrollPhysics(),
                diameterRatio: 1.2,
                perspective: 0.003,
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) {
                    if (index < 0 || index > 50) return null;
                    return Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                  childCount: 51,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 64,
                child: FilledButton(
                  onPressed: () =>
                      widget.onComplete(_scrollController.selectedItem),
                  child: const Text(
                    'Complete Set',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.onSkipWarmup != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: widget.onSkipWarmup,
              child: Text(
                'Skip',
                style: TextStyle(fontSize: 13, color: colorScheme.tertiary),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
