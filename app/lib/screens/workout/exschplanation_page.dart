/// The regime-explanation pages shown inside a workout (section model + page widget).
library;

import 'package:flutter/material.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../widgets/user_message_chip.dart';

/// One titled section of the Exschplanation sheet — a session-wide or
/// per-exercise group of schplanner messages.
class ExschplanationSection {
  final String title;
  final List<UserMessage> messages;
  const ExschplanationSection(this.title, this.messages);
}

/// PAGE 3 — the schplanner's reasoning for today's workout.
class ExschplanationPage extends StatelessWidget {
  final List<ExschplanationSection> sections;

  const ExschplanationPage({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Icon(
              Icons.psychology_alt_rounded,
              size: 22,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 10),
            const Text(
              'Exschplanation',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Why the schplanner planned today this way.',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (sections.isEmpty)
          Text(
            'No notes for this workout.',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          )
        else
          for (final section in sections) ...[
            Text(
              section.title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 10),
            for (final message in section.messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: UserMessageChip(message: message),
              ),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}
