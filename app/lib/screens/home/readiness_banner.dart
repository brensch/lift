/// Banner summarising training status and regime context: are you ready to train, what does the program have planned, with status and program chips.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../gen/workout/v1/workout.pb.dart';

class ReadinessBanner extends StatelessWidget {
  final TrainingStatus? trainingStatus;
  final RegimeContext? regimeContext;

  const ReadinessBanner({super.key, this.trainingStatus, this.regimeContext});

  @override
  Widget build(BuildContext context) {
    final ts = trainingStatus;
    final rc = regimeContext;

    Color bannerColor;
    Color textColor;
    Color accentColor;
    IconData icon;
    String label;

    if (ts != null && ts.headline.isNotEmpty) {
      if (ts.shouldTrainNow) {
        bannerColor = const Color(0xFF1F6F43);
        textColor = Colors.white;
        accentColor = const Color(0xFFDDF5E6);
        icon = Icons.fitness_center_rounded;
      } else {
        bannerColor = const Color(0xFF1E4F8C);
        textColor = Colors.white;
        accentColor = const Color(0xFFE0ECFF);
        icon = Icons.schedule_rounded;
      }
      label = ts.headline;
    } else {
      bannerColor = const Color(0xFF304255);
      textColor = Colors.white;
      accentColor = const Color(0xFFE4EDF7);
      icon = Icons.fitness_center_rounded;
      label = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rc != null && rc.regimeDisplayName.isNotEmpty) ...[
            ProgramChip(
              label: rc.regimeDisplayName,
              textColor: textColor,
              accentColor: accentColor,
              onTap: () => context.go('/training-program'),
            ),
            const SizedBox(height: 6),
          ],
          if (label.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'Training status',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: textColor,
              ),
            ),
          if (rc != null && rc.sessionDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rc.sessionDescription,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: textColor.withValues(alpha: 0.92),
              ),
            ),
          ],
          if (ts != null) ...[
            const SizedBox(height: 12),
            Text(
              'This week',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  label:
                      '${ts.completedSessionsPer7Days}/${ts.targetSessionsPer7Days} sessions',
                  textColor: textColor,
                ),
                StatusChip(
                  label:
                      '${ts.completedSetsPer7Days}/${ts.targetSetsPer7Days} sets',
                  textColor: textColor,
                ),
                if (ts.remainingSessionsPer7Days > 0)
                  StatusChip(
                    label: '${ts.remainingSessionsPer7Days} sessions left',
                    textColor: textColor,
                  ),
                if (ts.remainingSetsPer7Days > 0)
                  StatusChip(
                    label: '${ts.remainingSetsPer7Days} sets left',
                    textColor: textColor,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color textColor;

  const StatusChip({super.key, required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class ProgramChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color accentColor;
  final VoidCallback onTap;

  const ProgramChip({super.key, 
    required this.label,
    required this.textColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, size: 12, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_outward_rounded, size: 13, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Variable-column grid of group chips ───────────────────────────────────────────
