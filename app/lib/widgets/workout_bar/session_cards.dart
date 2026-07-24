/// Cards for session peers shown in the workout bar.
library;

import 'package:flutter/material.dart';
import '../participant_ticker.dart';
import '../workout_status_box.dart';
import '../common/horizontal_shaker.dart';
import '../common/rainbow_shimmer_text.dart';

class SessionMemberCard extends StatelessWidget {
  final String name;
  final String? emoji;
  final Color profileColor;
  final ParticipantVisualStatus status;
  final bool isNextToLift;
  final bool shakeActive;
  final VoidCallback? onTap;

  const SessionMemberCard({super.key, 
    required this.name,
    this.emoji,
    required this.profileColor,
    required this.status,
    required this.isNextToLift,
    required this.shakeActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = StatusBox(
      sideLabel: name,
      sideBadge: emoji,
      header: name,
      showHeader: true,
      headerTrailing: isNextToLift
          ? const RainbowShimmerText(text: 'next to schlift')
          : null,
      stateLabel: status.stateLabel,
      color: status.stateColor,
      sideColor: profileColor,
      timerText: status.timerText,
      timerColor: status.timerColor,
      set: status.proposedSet,
      isComplete: status.isComplete,
      sideLabelWidth: 44,
    );

    final shaking = HorizontalShaker(active: shakeActive, child: card);

    if (onTap == null) return shaking;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: shaking,
      ),
    );
  }
}

class MoreParticipantsCard extends StatelessWidget {
  final int hiddenCount;
  final VoidCallback? onTap;

  const MoreParticipantsCard({super.key, required this.hiddenCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.expand_less_rounded,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$hiddenCount more',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

// ─── Rainbow shimmer text ─────────────────────────────────────────────────────
