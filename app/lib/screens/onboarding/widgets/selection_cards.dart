/// Selection cards: program card, unit card, and the preview pill.
library;

import 'package:flutter/material.dart';
import '../../../gen/workout/v1/settings.pb.dart';

class ProgramCard extends StatelessWidget {
  final TrainingProgramDefinition program;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  const ProgramCard({super.key, 
    required this.program,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outline,
                    width: 2,
                  ),
                  color: selected ? cs.primary : Colors.transparent,
                ),
                child: selected
                    ? Icon(Icons.check, size: 10, color: cs.onPrimary)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          program.headline,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        if (program.hasAtAGlance()) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              PreviewPill(
                                emoji: '📅',
                                text: program.atAGlance.daysPerWeek,
                              ),
                              PreviewPill(
                                emoji: '🎯',
                                text: program.atAGlance.bestFor,
                              ),
                              PreviewPill(
                                emoji: '⏱️',
                                text: program.atAGlance.averageSessionTime,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: -1,
                    right: 0,
                    child: IconButton(
                      onPressed: onInfo,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 24,
                        height: 24,
                      ),
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      icon: const Icon(Icons.info_outline_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UnitCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  const UnitCard({super.key, 
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Text(
                badge,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, height: 1.0),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.primary : cs.outline,
                  width: 2,
                ),
                color: selected ? cs.primary : Colors.transparent,
              ),
              child: selected
                  ? Icon(Icons.check, size: 10, color: cs.onPrimary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class PreviewPill extends StatelessWidget {
  final String emoji;
  final String text;
  const PreviewPill({super.key, required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$emoji $text',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
