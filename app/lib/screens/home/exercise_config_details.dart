/// Expanded details for one exercise group: per-exercise config, sets and rest breakdown.
library;

import 'package:flutter/material.dart';

import 'home_selection.dart' show SetLine;

class ExerciseConfigDetailsCard extends StatelessWidget {
  final String title;
  final List<Widget> notes;
  final List<SetLine> warmupLines;
  final List<SetLine> workingSetLines;
  final List<String> meta;

  const ExerciseConfigDetailsCard({super.key, 
    required this.title,
    required this.notes,
    required this.warmupLines,
    required this.workingSetLines,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: note,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (warmupLines.isNotEmpty) ...[
            DetailsSection(
              title: 'Warmups',
              tint: colorScheme.tertiary,
              icon: Icons.whatshot_outlined,
              setLines: warmupLines,
            ),
            const SizedBox(height: 10),
          ],
          DetailsSection(
            title: 'Working sets',
            tint: colorScheme.primary,
            icon: Icons.fitness_center_rounded,
            setLines: workingSetLines,
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in meta)
                  Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Divider(
            height: 18,
            thickness: 1,
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

class DetailsSection extends StatelessWidget {
  final String title;
  final Color tint;
  final IconData icon;
  final List<SetLine> setLines;

  const DetailsSection({super.key, 
    required this.title,
    required this.tint,
    required this.icon,
    required this.setLines,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: tint),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final set in setLines) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${set.index}.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface.withValues(alpha: 0.46),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        set.text,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (set.note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          set.note,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.62,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
