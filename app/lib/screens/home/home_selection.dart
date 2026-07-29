/// Selection model for the home screen: which exercise groups exist (recommended by the program, saved, plan-later) and which are picked for the next workout.
library;

import '../../gen/workout/v1/workout.pb.dart';
import 'package:uuid/uuid.dart';

enum HomeGroupSection { recommended, saved, planLater }

List<String> _slotKeysForConfig(ExerciseTypeConfig config) {
  final keys = <String>{};
  for (final set in config.workingSets) {
    if (set.hasProgressionHint() && set.progressionHint.slotKey.isNotEmpty) {
      keys.add(set.progressionHint.slotKey);
    }
  }
  return keys.toList(growable: false);
}

const _uuid = Uuid();

List<UserMessage> messagesForHomeGroup(
  HomeSelectableGroup group,
  List<UserMessage> scheduleMessages,
) {
  if (group.section == HomeGroupSection.saved) {
    return const [];
  }
  final slotKeys = <String>{
    for (final config in group.exerciseConfigs) ..._slotKeysForConfig(config),
  };
  final exercises = <int>{
    for (final config in group.exerciseConfigs) config.exercise.value,
  };
  final seen = <String>{};
  final out = <UserMessage>[];
  for (final message in scheduleMessages) {
    if (message.exerciseGroupId.isNotEmpty) continue;
    final matchesSlot =
        message.slotKey.isNotEmpty && slotKeys.contains(message.slotKey);
    final matchesExercise =
        message.exercise != Exercise.EXERCISE_UNSPECIFIED &&
        exercises.contains(message.exercise.value);
    if (!matchesSlot && !matchesExercise) continue;
    if (!seen.add(message.messageKey)) continue;
    out.add(message);
  }
  return out;
}

List<UserMessage> messagesForExerciseConfig(
  ExerciseTypeConfig config,
  List<UserMessage> groupMessages,
) {
  final slotKeys = _slotKeysForConfig(config).toSet();
  final seen = <String>{};
  final out = <UserMessage>[];
  for (final message in groupMessages) {
    final matchesSlot =
        message.slotKey.isNotEmpty && slotKeys.contains(message.slotKey);
    final matchesExercise = message.exercise == config.exercise;
    if (!matchesSlot && !matchesExercise) continue;
    if (!seen.add(message.messageKey)) continue;
    out.add(message);
  }
  return out;
}

class HomeSelectableGroup {
  final String selectionKey;
  final HomeGroupSection section;
  final String? templateId;
  final String name;
  final int sets;
  final bool interleaveWarmups;
  final List<ExerciseTypeConfig> exerciseConfigs;
  final RestConfig? restConfig;
  final String explanation;
  final bool prescribedByRegime;
  final bool useScheduleWeights;
  final int estimatedDurationSeconds; // server estimate; 0 for saved groups

  const HomeSelectableGroup({
    required this.selectionKey,
    required this.section,
    required this.templateId,
    required this.name,
    required this.sets,
    required this.interleaveWarmups,
    required this.exerciseConfigs,
    required this.restConfig,
    required this.explanation,
    required this.prescribedByRegime,
    required this.useScheduleWeights,
    this.estimatedDurationSeconds = 0,
  });

  factory HomeSelectableGroup.fromProposed(
    ProposedExerciseGroup group, {
    required int index,
  }) {
    final isRecommended = group.tags.contains('recommended');
    return HomeSelectableGroup(
      selectionKey:
          '${isRecommended ? 'recommended' : 'planLater'}:${group.name}:$index',
      section: isRecommended
          ? HomeGroupSection.recommended
          : HomeGroupSection.planLater,
      templateId: null,
      name: group.name,
      sets: group.sets,
      interleaveWarmups: group.interleaveWarmups,
      exerciseConfigs: group.exerciseConfigs.map((c) => c.deepCopy()).toList(),
      restConfig: group.hasRestConfig() ? group.restConfig.deepCopy() : null,
      explanation: '',
      prescribedByRegime: group.prescribedByRegime,
      useScheduleWeights: true,
      estimatedDurationSeconds: group.estimatedDurationSeconds.toInt(),
    );
  }

  factory HomeSelectableGroup.fromSaved(ExerciseGroup group) {
    return HomeSelectableGroup(
      selectionKey: 'saved:${group.id}',
      section: HomeGroupSection.saved,
      templateId: group.id,
      name: group.name,
      sets: group.sets,
      interleaveWarmups: group.interleaveWarmups,
      exerciseConfigs: group.exerciseConfigs.map((c) => c.deepCopy()).toList(),
      restConfig: group.hasRestConfig() ? group.restConfig.deepCopy() : null,
      explanation: group.instruction,
      prescribedByRegime: group.prescribedByRegime,
      useScheduleWeights: false,
    );
  }

  bool matchesDraftGroup(ExerciseGroup group) {
    if (section == HomeGroupSection.saved && templateId != null) {
      return group.id == templateId || group.name == name;
    }
    return group.name == name;
  }

  ExerciseGroup toWorkoutGroup({
    required int workoutOrder,
    required Map<int, ExerciseStatus> statusMap,
    required bool forWorkoutStart,
  }) {
    final configs = exerciseConfigs.map((c) {
      final status = statusMap[c.exercise.value];
      final startWeight = useScheduleWeights
          ? (status?.targetWeight ?? c.startWeight)
          : c.startWeight;
      final endWeight = (useScheduleWeights && c.endWeight == c.startWeight)
          ? startWeight
          : c.endWeight;
      final cfg = ExerciseTypeConfig()
        ..exercise = c.exercise
        ..startWeight = startWeight
        ..endWeight = endWeight
        ..reps = c.reps
        ..includeWarmup = c.includeWarmup
        ..lastSetAmrap = c.lastSetAmrap;
      cfg.workingSets.addAll(
        c.workingSets.map((ws) {
          final set = WorkingSetSpec()
            ..targetWeight = ws.targetWeight
            ..targetReps = ws.targetReps
            ..isAmrap = ws.isAmrap
            ..instruction = ws.instruction;
          if (ws.hasProgressionHint()) {
            set.progressionHint = ws.progressionHint.deepCopy();
          }
          return set;
        }),
      );
      if (c.hasRestConfig()) {
        cfg.restConfig = RestConfig()..mergeFromMessage(c.restConfig);
      }
      return cfg;
    }).toList();

    final group = ExerciseGroup()
      ..id = forWorkoutStart ? _uuid.v4() : (templateId ?? selectionKey)
      ..name = name
      ..sets = sets
      ..interleaveWarmups = interleaveWarmups
      ..workoutOrder = workoutOrder
      ..prescribedByRegime = prescribedByRegime
      ..instruction = (section == HomeGroupSection.saved) ? explanation : ''
      ..exerciseConfigs.addAll(configs);
    if (restConfig != null) {
      group.restConfig = RestConfig()..mergeFromMessage(restConfig!);
    }
    return group;
  }

  HomeSelectableGroup copyWith({
    String? name,
    int? sets,
    bool? interleaveWarmups,
    List<ExerciseTypeConfig>? exerciseConfigs,
    RestConfig? restConfig,
    String? explanation,
  }) {
    return HomeSelectableGroup(
      selectionKey: selectionKey,
      section: section,
      templateId: templateId,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      interleaveWarmups: interleaveWarmups ?? this.interleaveWarmups,
      exerciseConfigs:
          exerciseConfigs ??
          this.exerciseConfigs.map((c) => c.deepCopy()).toList(),
      restConfig: restConfig ?? this.restConfig?.deepCopy(),
      explanation: explanation ?? this.explanation,
      prescribedByRegime: prescribedByRegime,
      useScheduleWeights: exerciseConfigs != null ? false : useScheduleWeights,
    );
  }
}

/// One rendered line of a set list: "2 × 5 @ 135", with an optional note.
typedef SetLine = ({int index, String text, String note});
