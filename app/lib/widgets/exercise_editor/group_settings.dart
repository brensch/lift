/// Group-wide settings: superset interleaving and rest durations.
library;

import 'package:flutter/material.dart';
import '../../gen/workout/v1/workout.pb.dart';
import 'compact_exercise_config.dart';

/// Group-level settings: sets count + interleave warmups toggle.
class GroupSettings extends StatelessWidget {
  final int sets;
  final bool interleaveWarmups;
  final bool showInterleave;
  final ValueChanged<int> onSetsChanged;
  final ValueChanged<bool> onInterleaveChanged;

  const GroupSettings({super.key, 
    required this.sets,
    required this.interleaveWarmups,
    required this.showInterleave,
    required this.onSetsChanged,
    required this.onInterleaveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WORKING SETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.tertiary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CountButton(
                    icon: Icons.remove,
                    onPressed: () => onSetsChanged((sets - 1).clamp(1, 10)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$sets',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  CountButton(
                    icon: Icons.add,
                    onPressed: () => onSetsChanged((sets + 1).clamp(1, 10)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showInterleave)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'INTERLEAVE WARMUPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                    letterSpacing: 1.0,
                  ),
                ),
                Switch(
                  value: interleaveWarmups,
                  onChanged: onInterleaveChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class RestSettings extends StatelessWidget {
  final RestConfig restConfig;
  final ValueChanged<RestConfig> onChanged;

  const RestSettings({super.key, required this.restConfig, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Default values if not set
    final success = restConfig.restAfterSuccess > 0
        ? restConfig.restAfterSuccess
        : 180;
    final failure = restConfig.restAfterFailure > 0
        ? restConfig.restAfterFailure
        : 300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REST SETTINGS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colorScheme.tertiary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RestField(
                label: 'SUCCESS',
                seconds: success,
                onChanged: (v) {
                  final newRc = restConfig.deepCopy()..restAfterSuccess = v;
                  onChanged(newRc);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: RestField(
                label: 'FAILURE',
                seconds: failure,
                onChanged: (v) {
                  final newRc = restConfig.deepCopy()..restAfterFailure = v;
                  onChanged(newRc);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class RestField extends StatelessWidget {
  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  const RestField({super.key, 
    required this.label,
    required this.seconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            CountButton(
              icon: Icons.remove,
              onPressed: () => onChanged((seconds - 15).clamp(0, 600)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${seconds}s',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            CountButton(
              icon: Icons.add,
              onPressed: () => onChanged((seconds + 15).clamp(0, 600)),
            ),
          ],
        ),
      ],
    );
  }
}
