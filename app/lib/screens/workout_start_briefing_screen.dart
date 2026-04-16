import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pbenum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../widgets/user_message_chip.dart';

List<String> _slotKeysForStartConfig(ExerciseTypeConfig config) {
  final keys = <String>{};
  for (final set in config.workingSets) {
    if (set.hasProgressionHint() && set.progressionHint.slotKey.isNotEmpty) {
      keys.add(set.progressionHint.slotKey);
    }
  }
  return keys.toList(growable: false);
}

class WorkoutStartBriefingScreen extends StatefulWidget {
  final String workoutName;
  final RegimeContext? regimeContext;
  final List<UserMessage> scheduleMessages;
  final List<ExerciseGroup> selectedGroups;
  final Future<void> Function() onStartWorkout;

  const WorkoutStartBriefingScreen({
    super.key,
    required this.workoutName,
    required this.regimeContext,
    required this.scheduleMessages,
    required this.selectedGroups,
    required this.onStartWorkout,
  });

  @override
  State<WorkoutStartBriefingScreen> createState() =>
      _WorkoutStartBriefingScreenState();
}

class _WorkoutStartBriefingScreenState
    extends State<WorkoutStartBriefingScreen> {
  bool _starting = false;

  List<UserMessage> _displayMessages() {
    return widget.scheduleMessages
        .where(
          (message) => message.body.trim().isNotEmpty || message.hasDetails(),
        )
        .toList(growable: false);
  }

  List<UserMessage> _globalMessages(List<UserMessage> messages) {
    return messages
        .where(
          (message) =>
              message.exercise == Exercise.EXERCISE_UNSPECIFIED &&
              message.slotKey.isEmpty,
        )
        .toList(growable: false);
  }

  List<UserMessage> _messagesForConfig(
    ExerciseTypeConfig config,
    List<UserMessage> messages,
  ) {
    final slotKeys = _slotKeysForStartConfig(config).toSet();
    final seen = <String>{};
    final out = <UserMessage>[];
    for (final message in messages) {
      if (message.exercise == Exercise.EXERCISE_UNSPECIFIED &&
          message.slotKey.isEmpty) {
        continue;
      }
      final matchesSlot =
          message.slotKey.isNotEmpty && slotKeys.contains(message.slotKey);
      final matchesExercise = message.exercise == config.exercise;
      if (!matchesSlot && !matchesExercise) continue;
      if (!seen.add(message.messageKey)) continue;
      out.add(message);
    }
    return out;
  }

  Future<void> _handleStart() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await widget.onStartWorkout();
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final regimeContext = widget.regimeContext;
    final displayMessages = _displayMessages();
    final globalMessages = _globalMessages(displayMessages);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Start')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Message from the schplanner.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.workoutName,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
                height: 0.98,
              ),
            ),
            if (regimeContext != null &&
                regimeContext.regimeDisplayName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                regimeContext.regimeDisplayName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
            if (regimeContext != null &&
                regimeContext.sessionDescription.isNotEmpty) ...[
              const SizedBox(height: 18),
              _BriefingSection(
                title: 'Today\'s brief',
                child: Text(
                  regimeContext.sessionDescription,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            if (globalMessages.isNotEmpty) ...[
              const SizedBox(height: 14),
              _BriefingSection(
                title: 'Recommendation notes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final message in globalMessages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: UserMessageChip(message: message, compact: true),
                      ),
                  ],
                ),
              ),
            ],
            if (regimeContext != null &&
                regimeContext.nextSessionPreview.isNotEmpty) ...[
              const SizedBox(height: 14),
              _BriefingSection(
                title: 'What follows',
                child: Text(
                  regimeContext.nextSessionPreview,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _BriefingSection(
              title: 'Planned sets',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in widget.selectedGroups)
                    _GroupWeightCard(
                      group: group,
                      unit: unit,
                      messagesForConfig: (config) =>
                          _messagesForConfig(config, displayMessages),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _starting ? null : _handleStart,
              icon: _starting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_starting ? 'Starting...' : 'Start workout'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BriefingSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _BriefingSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _GroupWeightCard extends StatelessWidget {
  final ExerciseGroup group;
  final WeightUnit unit;
  final List<UserMessage> Function(ExerciseTypeConfig config) messagesForConfig;

  const _GroupWeightCard({
    required this.group,
    required this.unit,
    required this.messagesForConfig,
  });

  List<WorkingSetSpec> _workingSets(ExerciseTypeConfig config) {
    if (config.workingSets.isNotEmpty) return config.workingSets;
    final count = group.sets <= 0 ? 1 : group.sets;
    return List.generate(
      count,
      (i) => WorkingSetSpec()
        ..targetWeight = count <= 1
            ? config.startWeight
            : (config.startWeight +
                  (i / (count - 1)) * (config.endWeight - config.startWeight))
        ..targetReps = config.reps
        ..isAmrap = config.lastSetAmrap && i == count - 1,
    );
  }

  String _exerciseSummary(ExerciseTypeConfig config) {
    final sets = _workingSets(config);
    if (sets.isEmpty) return 'No working sets planned.';
    return sets
        .map(
          (set) =>
              '${formatWeight(set.targetWeight.toDouble(), unit, includeUnit: true)} x '
              '${set.isAmrap ? '${set.targetReps}+' : set.targetReps}',
        )
        .join('  •  ');
  }

  String _instructionReason(ExerciseTypeConfig config) {
    final notes = _workingSets(config)
        .map((set) => set.instruction.trim())
        .where((note) => note.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (notes.isEmpty) return '';
    return notes.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (final config in group.exerciseConfigs) ...[
            Builder(
              builder: (context) {
                final instructionReason = _instructionReason(config);
                final messages = messagesForConfig(config);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseNames[config.exercise] ?? 'Exercise',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _exerciseSummary(config),
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (messages.isNotEmpty) ...[
                      for (final message in messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: UserMessageChip(
                            message: message,
                            compact: true,
                          ),
                        ),
                      const SizedBox(height: 4),
                    ],
                    if (instructionReason.isNotEmpty) ...[
                      Text(
                        instructionReason,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
