import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/grpc_client.dart';
import '../services/wearable_bridge_service.dart';
import '../services/workout_service.dart';
import '../logic/exercises.dart';
import '../logic/exercise_groups.dart';
import '../logic/warmup.dart';
import '../logic/weight_units.dart';
import '../logic/utils.dart';
import '../widgets/workout_modals.dart';
import 'package:uuid/uuid.dart';
import 'workout_start_briefing_screen.dart';

const _uuid = Uuid();

enum _HomeGroupSection { recommended, saved, planLater }

class _HomeSelectableGroup {
  final String selectionKey;
  final _HomeGroupSection section;
  final String? templateId;
  final String name;
  final int sets;
  final bool interleaveWarmups;
  final List<ExerciseTypeConfig> exerciseConfigs;
  final RestConfig? restConfig;
  final String explanation;
  final bool prescribedByRegime;
  final bool useScheduleWeights;

  const _HomeSelectableGroup({
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
  });

  factory _HomeSelectableGroup.fromProposed(
    ProposedExerciseGroup group, {
    required int index,
  }) {
    final isRecommended = group.tags.contains('recommended');
    return _HomeSelectableGroup(
      selectionKey:
          '${isRecommended ? 'recommended' : 'planLater'}:${group.name}:$index',
      section: isRecommended
          ? _HomeGroupSection.recommended
          : _HomeGroupSection.planLater,
      templateId: null,
      name: group.name,
      sets: group.sets,
      interleaveWarmups: group.interleaveWarmups,
      exerciseConfigs: group.exerciseConfigs.map((c) => c.deepCopy()).toList(),
      restConfig: group.hasRestConfig() ? group.restConfig.deepCopy() : null,
      explanation: group.explanation,
      prescribedByRegime: group.prescribedByRegime,
      useScheduleWeights: true,
    );
  }

  factory _HomeSelectableGroup.fromSaved(ExerciseGroup group) {
    return _HomeSelectableGroup(
      selectionKey: 'saved:${group.id}',
      section: _HomeGroupSection.saved,
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
    if (section == _HomeGroupSection.saved && templateId != null) {
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
      ..instruction = explanation
      ..exerciseConfigs.addAll(configs);
    if (restConfig != null) {
      group.restConfig = RestConfig()..mergeFromMessage(restConfig!);
    }
    return group;
  }

  _HomeSelectableGroup copyWith({
    String? name,
    int? sets,
    bool? interleaveWarmups,
    List<ExerciseTypeConfig>? exerciseConfigs,
    RestConfig? restConfig,
    String? explanation,
  }) {
    return _HomeSelectableGroup(
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
      useScheduleWeights: useScheduleWeights,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _draftSaveDebounce = Duration(milliseconds: 400);
  List<ExerciseStatus>? _schedule;
  List<_HomeSelectableGroup>? _selectableGroups;
  RegimeContext? _regimeContext;
  TrainingStatus? _trainingStatus;
  List<PendingStateUpdate> _pendingUpdates = [];
  String _suggestedWorkoutBaseName = '';
  bool _canStartWorkout = true;
  Set<int> _selectedGroupIndices = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isStarting = false;
  String? _error;
  Timer? _draftSaveTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    super.dispose();
  }

  String _getDefaultWorkoutName() {
    return 'Workout';
  }

  Future<void> _loadData({bool refreshOnly = false}) async {
    final auth = context.read<AuthProvider>();
    final grpc = context.read<GrpcClient>();
    final workoutService = WorkoutServiceWrapper(grpc);

    setState(() {
      if (refreshOnly && !_isLoading) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
        _error = null;
      }
    });

    try {
      final scheduleRes = await workoutService.getProposedWorkoutSchedule(
        auth.userId!,
      );

      if (!mounted) return;

      final schedule = scheduleRes.exerciseStatuses;
      final selectableGroups = <_HomeSelectableGroup>[
        for (int i = 0; i < scheduleRes.proposedGroups.length; i++)
          _HomeSelectableGroup.fromProposed(
            scheduleRes.proposedGroups[i],
            index: i,
          ),
        for (final group in scheduleRes.savedExerciseGroups)
          _HomeSelectableGroup.fromSaved(group),
      ];

      // Auto-select all groups tagged "recommended" on each load/refresh.
      final autoSelected = <int>{};
      for (int i = 0; i < selectableGroups.length; i++) {
        if (selectableGroups[i].section == _HomeGroupSection.recommended) {
          autoSelected.add(i);
        }
      }

      final draft = scheduleRes.hasDraft() ? scheduleRes.draft : null;
      final selectedFromDraft = <int>{};
      if (draft != null && draft.exerciseGroups.isNotEmpty) {
        for (final group in draft.exerciseGroups) {
          final idx = selectableGroups.indexWhere(
            (candidate) => candidate.matchesDraftGroup(group),
          );
          if (idx != -1) selectedFromDraft.add(idx);
        }
      }

      setState(() {
        _schedule = schedule;
        _selectableGroups = selectableGroups;
        _regimeContext = scheduleRes.hasRegimeContext()
            ? scheduleRes.regimeContext
            : null;
        _trainingStatus = scheduleRes.hasTrainingStatus()
            ? scheduleRes.trainingStatus
            : null;
        _pendingUpdates = scheduleRes.pendingStateUpdates;
        _suggestedWorkoutBaseName = scheduleRes.suggestedWorkoutName.trim();
        _canStartWorkout = scheduleRes.canStartWorkout;
        _selectedGroupIndices = selectedFromDraft.isNotEmpty
            ? selectedFromDraft
            : autoSelected;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (isUnauthenticatedError(e)) {
        await auth.expireSession(
          message: 'Your saved session expired. Sign in again.',
        );
        return;
      }
      if (mounted) {
        setState(() {
          if (_isLoading) {
            _error = cleanErrorMessage(e);
          }
          _isLoading = false;
          _isRefreshing = false;
        });
        if (refreshOnly && (_schedule != null || _selectableGroups != null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Refresh failed: ${cleanErrorMessage(e)}')),
          );
        }
      }
    }
  }

  Future<void> _startWorkout() async {
    if (_selectedGroupIndices.isEmpty || _selectableGroups == null) return;

    final selectedGroups = (_selectedGroupIndices.toList()..sort())
        .map(
          (idx) => _selectableGroups![idx].toWorkoutGroup(
            workoutOrder: idx,
            statusMap: _statusMap(),
            forWorkoutStart: false,
          ),
        )
        .toList(growable: false);

    final workoutName = await _resolveLatestWorkoutName();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutStartBriefingScreen(
          workoutName: workoutName,
          regimeContext: _regimeContext,
          selectedGroups: selectedGroups,
          onStartWorkout: _performWorkoutStart,
        ),
      ),
    );
  }

  Future<void> _performWorkoutStart() async {
    if (_selectedGroupIndices.isEmpty || _selectableGroups == null) return;

    if (mounted) {
      setState(() => _isStarting = true);
    }

    try {
      final exerciseGroups = _buildExerciseGroupsFromSelection(
        forWorkoutStart: true,
      );
      final grpc = context.read<GrpcClient>();
      final wearableBridge = context.read<WearableBridgeService>();
      final workoutProvider = context.read<WorkoutProvider>();

      final workoutName = await _resolveLatestWorkoutName();

      final workoutId = await workoutProvider.startWorkout(
        workoutName,
        exerciseGroups,
      );

      if (workoutId != null && mounted) {
        await WorkoutServiceWrapper(grpc).clearWorkoutDraft();
        unawaited(_attemptAutoLaunchWatchApp(wearableBridge));
      }
    } catch (e) {
      debugPrint('Error starting workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start workout: $e')));
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  Future<void> _attemptAutoLaunchWatchApp(WearableBridgeService bridge) async {
    try {
      await bridge.openWatchApp();
    } catch (e) {
      debugPrint('Auto watch launch failed: $e');
    }
  }

  void _toggleGroup(int index) {
    setState(() {
      if (_selectedGroupIndices.contains(index)) {
        _selectedGroupIndices.remove(index);
      } else {
        _selectedGroupIndices.add(index);
      }
    });
    _queueDraftSave();
  }

  Map<int, ExerciseStatus> _statusMap() {
    final statusMap = <int, ExerciseStatus>{};
    if (_schedule != null) {
      for (final s in _schedule!) {
        statusMap[s.exercise.value] = s;
      }
    }
    return statusMap;
  }

  List<ExerciseGroup> _buildExerciseGroupsFromSelection({
    required bool forWorkoutStart,
  }) {
    final exerciseGroups = <ExerciseGroup>[];
    int groupOrder = 0;
    final statusMap = _statusMap();

    for (final idx in _selectedGroupIndices.toList()..sort()) {
      final selected = _selectableGroups![idx];
      exerciseGroups.add(
        selected.toWorkoutGroup(
          workoutOrder: groupOrder++,
          statusMap: statusMap,
          forWorkoutStart: forWorkoutStart,
        ),
      );
    }
    return exerciseGroups;
  }

  void _queueDraftSave() {
    if (!mounted) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDebounce, () {
      unawaited(_saveDraftToServer());
    });
  }

  Future<void> _saveDraftToServer() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final grpc = context.read<GrpcClient>();
    final workoutService = WorkoutServiceWrapper(grpc);
    try {
      final draft = WorkoutDraft()
        ..exerciseGroups.addAll(
          _buildExerciseGroupsFromSelection(forWorkoutStart: false),
        )
        ..updatedAt = Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await workoutService.saveWorkoutDraft(draft);
    } catch (e) {
      debugPrint('Failed to save workout draft: $e');
    }
  }

  List<int> _buildVisibleGroupIndices() {
    final groups = _selectableGroups;
    if (groups == null) return [];
    final recommended = <int>[];
    final saved = <int>[];
    final rest = <int>[];
    for (int i = 0; i < groups.length; i++) {
      if (groups[i].section == _HomeGroupSection.recommended) {
        recommended.add(i);
      } else if (groups[i].section == _HomeGroupSection.saved) {
        saved.add(i);
      } else {
        rest.add(i);
      }
    }
    return [...recommended, ...saved, ...rest];
  }

  int _estimatedWorkoutMinutes() {
    if (_selectableGroups == null || _selectedGroupIndices.isEmpty) return 0;

    const workingSetSeconds = 45;
    const warmupSetSeconds = 30;
    const setupSecondsPerExercise = 75;
    const transitionSecondsPerGroup = 90;
    const defaultWorkingRest = 180;
    const defaultWarmupRest = 30;

    int totalSeconds = 0;

    for (final idx in _selectedGroupIndices.toList()..sort()) {
      final group = _selectableGroups![idx];
      totalSeconds += transitionSecondsPerGroup;

      for (final cfg in group.exerciseConfigs) {
        totalSeconds += setupSecondsPerExercise;

        final workingSets = cfg.workingSets.isNotEmpty
            ? cfg.workingSets.length
            : (group.sets <= 0 ? 1 : group.sets);
        final warmupSets = cfg.includeWarmup ? 2 : 0;
        final restConfig = cfg.hasRestConfig()
            ? cfg.restConfig
            : group.restConfig;
        final workingRest = restConfig?.restAfterSuccess ?? defaultWorkingRest;
        final warmupRest = restConfig?.restAfterWarmup ?? defaultWarmupRest;

        totalSeconds += workingSets * workingSetSeconds;
        totalSeconds += warmupSets * warmupSetSeconds;
        totalSeconds += (workingSets > 0 ? workingSets - 1 : 0) * workingRest;
        totalSeconds += warmupSets * warmupRest;
      }
    }

    return (totalSeconds / 60).ceil();
  }

  String _predictedWorkoutTimeLabel() {
    final minutes = _estimatedWorkoutMinutes();
    if (minutes <= 0) return '--';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return '${hours}h';
    return '${hours}h ${rem}m';
  }

  String _currentWorkoutBaseName() {
    final regimeSuggested = _regimeContext?.regimeDisplayName.trim() ?? '';
    final scheduleSuggested = _suggestedWorkoutBaseName.trim();
    if (scheduleSuggested.isNotEmpty) return scheduleSuggested;
    if (regimeSuggested.isNotEmpty) return regimeSuggested;
    return _getDefaultWorkoutName();
  }

  Future<String> _resolveLatestWorkoutName() async {
    final auth = context.read<AuthProvider>();
    final fallbackBaseName = _currentWorkoutBaseName();
    if (auth.userId == null) {
      return _buildWorkoutName(fallbackBaseName);
    }

    try {
      final grpc = context.read<GrpcClient>();
      final scheduleRes = await WorkoutServiceWrapper(
        grpc,
      ).getProposedWorkoutSchedule(auth.userId!);
      final latestBaseName = scheduleRes.suggestedWorkoutName.trim().isNotEmpty
          ? scheduleRes.suggestedWorkoutName.trim()
          : (scheduleRes.hasRegimeContext() &&
                    scheduleRes.regimeContext.regimeDisplayName
                        .trim()
                        .isNotEmpty
                ? scheduleRes.regimeContext.regimeDisplayName.trim()
                : fallbackBaseName);
      return _buildWorkoutName(latestBaseName);
    } catch (e) {
      debugPrint('Failed to refresh workout name before start: $e');
      return _buildWorkoutName(fallbackBaseName);
    }
  }

  String _buildWorkoutName(String baseName) {
    final now = DateTime.now();
    final dateStr =
        "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";
    return "$dateStr - $baseName";
  }

  Future<void> _showAddSavedGroupDialog() async {
    final exerciseStatuses = _schedule ?? const <ExerciseStatus>[];
    await showAddExerciseDialog(
      context,
      exerciseStatuses: exerciseStatuses,
      onAdd:
          (name, sets, interleaveWarmups, exerciseConfigs, restConfig) async {
            final finalName = name.trim().isNotEmpty
                ? name.trim()
                : exerciseConfigs
                      .map((c) => exerciseNames[c.exercise] ?? 'Exercise')
                      .join(' / ');
            final group = ExerciseGroup()
              ..name = finalName
              ..sets = sets
              ..interleaveWarmups = interleaveWarmups
              ..exerciseConfigs.addAll(exerciseConfigs)
              ..instruction = '';
            group.restConfig = restConfig;

            try {
              final saved = await WorkoutServiceWrapper(
                context.read<GrpcClient>(),
              ).saveProfileExerciseGroup(group);
              if (!mounted) return;
              setState(() {
                _selectableGroups = [
                  ...?_selectableGroups,
                  _HomeSelectableGroup.fromSaved(saved),
                ];
                _selectedGroupIndices = {
                  ..._selectedGroupIndices,
                  (_selectableGroups?.length ?? 1) - 1,
                };
              });
              _queueDraftSave();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to save group: ${cleanErrorMessage(e)}',
                  ),
                ),
              );
            }
          },
    );
  }

  Future<void> _editGroup(int index) async {
    final groups = _selectableGroups;
    if (groups == null || index < 0 || index >= groups.length) return;
    final target = groups[index];
    final backingGroup = target.toWorkoutGroup(
      workoutOrder: index,
      statusMap: _statusMap(),
      forWorkoutStart: false,
    );

    await showEditExerciseDialog(
      context,
      group: ExerciseGroupData(
        exercise: target.exerciseConfigs.isNotEmpty
            ? target.exerciseConfigs.first.exercise
            : Exercise.EXERCISE_UNSPECIFIED,
        sets: const [],
        group: backingGroup,
        exercises: target.exerciseConfigs
            .map((cfg) => cfg.exercise)
            .toSet()
            .toList(),
      ),
      groupIndex: index,
      exerciseStatuses: _schedule ?? const <ExerciseStatus>[],
      isSetDone: (_) => false,
      onSave:
          (
            groupIndex, {
            required int sets,
            required bool interleaveWarmups,
            required List<ExerciseTypeConfig> exerciseConfigs,
            RestConfig? restConfig,
          }) async {
            final original = _selectableGroups![groupIndex];
            final updated = original.copyWith(
              sets: sets,
              interleaveWarmups: interleaveWarmups,
              exerciseConfigs: exerciseConfigs,
              restConfig: restConfig ?? RestConfig(),
            );

            if (original.section == _HomeGroupSection.saved) {
              final saveGroup = ExerciseGroup()
                ..id = original.templateId ?? ''
                ..name = updated.name
                ..sets = updated.sets
                ..interleaveWarmups = updated.interleaveWarmups
                ..instruction = updated.explanation
                ..exerciseConfigs.addAll(
                  updated.exerciseConfigs.map((c) => c.deepCopy()),
                );
              if (updated.restConfig != null) {
                saveGroup.restConfig = updated.restConfig!.deepCopy();
              }

              try {
                final saved = await WorkoutServiceWrapper(
                  context.read<GrpcClient>(),
                ).saveProfileExerciseGroup(saveGroup);
                if (!mounted) return;
                setState(() {
                  _selectableGroups![groupIndex] =
                      _HomeSelectableGroup.fromSaved(saved);
                });
                _queueDraftSave();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to save group changes: ${cleanErrorMessage(e)}',
                    ),
                  ),
                );
              }
            } else {
              if (!mounted) return;
              setState(() {
                _selectableGroups![groupIndex] = updated;
              });
              _queueDraftSave();
            }
          },
    );
  }

  Future<void> _deleteSavedGroup(int index) async {
    final groups = _selectableGroups;
    if (groups == null || index < 0 || index >= groups.length) return;
    final target = groups[index];
    if (target.section != _HomeGroupSection.saved ||
        target.templateId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(
            'Delete ${target.name}?',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This will remove the saved group from your profile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await WorkoutServiceWrapper(
        context.read<GrpcClient>(),
      ).deleteProfileExerciseGroup(target.templateId!);
      if (!mounted) return;
      setState(() {
        _selectableGroups!.removeAt(index);
        _selectedGroupIndices = _selectedGroupIndices
            .where((selected) => selected != index)
            .map((selected) => selected > index ? selected - 1 : selected)
            .toSet();
      });
      _queueDraftSave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete saved group: ${cleanErrorMessage(e)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final visibleGroupIndices = _buildVisibleGroupIndices();
    final recommendedGroupIndices = visibleGroupIndices
        .where(
          (index) =>
              _selectableGroups![index].section ==
              _HomeGroupSection.recommended,
        )
        .toList(growable: false);
    final savedGroupIndices = visibleGroupIndices
        .where(
          (index) =>
              _selectableGroups![index].section == _HomeGroupSection.saved,
        )
        .toList(growable: false);
    final otherGroupIndices = visibleGroupIndices
        .where(
          (index) =>
              _selectableGroups![index].section == _HomeGroupSection.planLater,
        )
        .toList(growable: false);

    final workoutPanelColor = colorScheme.brightness == Brightness.dark
        ? const Color(0xFF222222)
        : const Color(0xFFF0F0F0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _loadData(refreshOnly: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            if (_trainingStatus != null || _regimeContext != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _ReadinessBanner(
                    trainingStatus: _trainingStatus,
                    regimeContext: _regimeContext,
                  ),
                ),
              ),
            if (_pendingUpdates.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final update in _pendingUpdates)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PendingUpdateCard(
                          update: update,
                          onResolved: () => _loadData(refreshOnly: true),
                        ),
                      ),
                  ]),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                (_trainingStatus != null || _regimeContext != null) ? 12 : 20,
                20,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SectionHeader(
                    title: 'Schplanner recommends',
                    trailing: _isRefreshing
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.tertiary,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recommendedGroupIndices.isNotEmpty)
                        _GroupGrid(
                          indices: recommendedGroupIndices,
                          groups: _selectableGroups!,
                          selectedIndices: _selectedGroupIndices,
                          onToggle: _toggleGroup,
                          onEdit: _editGroup,
                        ),
                      if (recommendedGroupIndices.isEmpty)
                        const _EmptySectionText(
                          text: 'Nothing is recommended right now.',
                        ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: 'Your saved ones',
                        trailing: IconButton(
                          onPressed: _showAddSavedGroupDialog,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          tooltip: 'Save a workout group',
                        ),
                      ),
                      if (savedGroupIndices.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _GroupGrid(
                          indices: savedGroupIndices,
                          groups: _selectableGroups!,
                          selectedIndices: _selectedGroupIndices,
                          onToggle: _toggleGroup,
                          onEdit: _editGroup,
                          onDelete: _deleteSavedGroup,
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: _EmptySectionText(
                            text:
                                'Save a group here to reuse it whenever you want.',
                          ),
                        ),
                      const SizedBox(height: 18),
                      const _SectionHeader(title: 'Not today but in your schplan'),
                      if (otherGroupIndices.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _GroupGrid(
                          indices: otherGroupIndices,
                          groups: _selectableGroups!,
                          selectedIndices: _selectedGroupIndices,
                          onToggle: _toggleGroup,
                          onEdit: _editGroup,
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: _EmptySectionText(
                            text:
                                'Everything in your plan is already recommended today.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: workoutPanelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: colorScheme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.10),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Predicted workout time:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _predictedWorkoutTimeLabel(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton(
                onPressed:
                    _selectedGroupIndices.isEmpty ||
                        _isStarting ||
                        !_canStartWorkout
                    ? null
                    : _startWorkout,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isStarting
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        'START WORKOUT',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Readiness banner ─────────────────────────────────────────────────────────

class _ReadinessBanner extends StatelessWidget {
  final TrainingStatus? trainingStatus;
  final RegimeContext? regimeContext;

  const _ReadinessBanner({this.trainingStatus, this.regimeContext});

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
            _ProgramChip(
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
                _StatusChip(
                  label:
                      '${ts.completedSessionsPer7Days}/${ts.targetSessionsPer7Days} sessions',
                  textColor: textColor,
                ),
                _StatusChip(
                  label: '${ts.completedSetsPer7Days}/${ts.targetSetsPer7Days} sets',
                  textColor: textColor,
                ),
                if (ts.remainingSessionsPer7Days > 0)
                  _StatusChip(
                    label: '${ts.remainingSessionsPer7Days} sessions left',
                    textColor: textColor,
                  ),
                if (ts.remainingSetsPer7Days > 0)
                  _StatusChip(
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color textColor;

  const _StatusChip({required this.label, required this.textColor});

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

class _ProgramChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _ProgramChip({
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
              Icon(
                Icons.menu_book_rounded,
                size: 12,
                color: accentColor,
              ),
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
              Icon(
                Icons.arrow_outward_rounded,
                size: 13,
                color: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Variable-column grid of group chips ───────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              color: colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _EmptySectionText extends StatelessWidget {
  final String text;

  const _EmptySectionText({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.35,
        color: colorScheme.onSurface.withValues(alpha: 0.62),
      ),
    );
  }
}

class _GroupGrid extends StatelessWidget {
  final List<int> indices;
  final List<_HomeSelectableGroup> groups;
  final Set<int> selectedIndices;
  final void Function(int) onToggle;
  final void Function(int) onEdit;
  final void Function(int)? onDelete;

  const _GroupGrid({
    required this.indices,
    required this.groups,
    required this.selectedIndices,
    required this.onToggle,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < indices.length; i++) ...[
          _GroupChip(
            group: groups[indices[i]],
            isSelected: selectedIndices.contains(indices[i]),
            onTap: () => onToggle(indices[i]),
            onEdit: () => onEdit(indices[i]),
            onDelete: onDelete == null ? null : () => onDelete!(indices[i]),
          ),
          if (i < indices.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─── Group chip ───────────────────────────────────────────────────────────────

class _GroupChip extends StatelessWidget {
  final _HomeSelectableGroup group;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _GroupChip({
    required this.group,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });

  List<WorkingSetSpec> _workingSetsForConfig(ExerciseTypeConfig cfg) {
    if (cfg.workingSets.isNotEmpty) return cfg.workingSets;
    final count = group.sets <= 0 ? 1 : group.sets;
    return List.generate(
      count,
      (i) => WorkingSetSpec()
        ..targetWeight = count <= 1
            ? cfg.startWeight
            : (cfg.startWeight +
                  (i / (count - 1)) * (cfg.endWeight - cfg.startWeight))
        ..targetReps = cfg.reps
        ..isAmrap = cfg.lastSetAmrap && i == count - 1,
    );
  }

  String _formatSetLine(WorkingSetSpec set, WeightUnit unit) {
    final reps = set.isAmrap ? '${set.targetReps}+' : '${set.targetReps}';
    return '${formatWeight(set.targetWeight.toDouble(), unit, includeUnit: true)} x $reps';
  }

  List<_SetLine> _warmupLinesForConfig(
    ExerciseTypeConfig cfg,
    WeightUnit unit,
  ) {
    if (!cfg.includeWarmup) return const [];
    final workingSets = _workingSetsForConfig(cfg);
    if (workingSets.isEmpty) return const [];
    final workingWeight = workingSets.first.targetWeight.toDouble();
    final defs = generateWarmupDefs(workingWeight);
    return [
      for (int i = 0; i < defs.length; i++)
        (
          index: i + 1,
          text:
              '${formatWeight(defs[i].weight, unit, includeUnit: true)} x ${defs[i].reps}',
          note: i == defs.length - 1 ? 'Last warmup before work sets.' : '',
        ),
    ];
  }

  List<_SetLine> _workingLinesForConfig(
    ExerciseTypeConfig cfg,
    WeightUnit unit,
  ) {
    final workingSets = _workingSetsForConfig(cfg);
    return [
      for (int i = 0; i < workingSets.length; i++)
        (
          index: i + 1,
          text: _formatSetLine(workingSets[i], unit),
          note: workingSets[i].instruction,
        ),
    ];
  }

  double? _maxWorkingWeight() {
    double? maxWeight;
    for (final cfg in group.exerciseConfigs) {
      for (final set in _workingSetsForConfig(cfg)) {
        final weight = set.targetWeight.toDouble();
        if (maxWeight == null || weight > maxWeight) {
          maxWeight = weight;
        }
      }
    }
    return maxWeight;
  }

  int _workingSetCount() => group.exerciseConfigs
      .map(_workingSetsForConfig)
      .fold(0, (total, sets) => total + sets.length);

  int _exerciseCount() => group.exerciseConfigs.length;

  bool get _isRecommended => group.section == _HomeGroupSection.recommended;

  Widget _chip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
  }

  Widget _recommendedIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        size: 14,
        color: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    final unit = context.read<SettingsProvider>().weightUnit;
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (int i = 0; i < group.exerciseConfigs.length; i++)
                  _ExerciseConfigDetailsCard(
                    title:
                        exerciseNames[group.exerciseConfigs[i].exercise] ??
                        'Exercise',
                    explanation: i == 0 ? group.explanation : '',
                    warmupLines: _warmupLinesForConfig(
                      group.exerciseConfigs[i],
                      unit,
                    ),
                    workingSetLines: _workingLinesForConfig(
                      group.exerciseConfigs[i],
                      unit,
                    ),
                    meta: [
                      if (group.exerciseConfigs[i].hasRestConfig())
                        'Rest ${group.exerciseConfigs[i].restConfig.restAfterSuccess}s',
                      if (group.exerciseConfigs[i].lastSetAmrap)
                        'Last set AMRAP',
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final maxWeight = _maxWorkingWeight();
    final weightLabel = maxWeight == null
        ? 'No weight'
        : formatWeight(maxWeight, unit, includeUnit: true);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 0),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.45),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isRecommended) ...[
                    _recommendedIcon(context),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        height: 1.0,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    weightLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.9)
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chip(context, '${_workingSetCount()} sets'),
                      if (_exerciseCount() > 1) ...[
                        const SizedBox(width: 6),
                        _chip(context, '${_exerciseCount()} ex'),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 17,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    tooltip: 'Edit group',
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(28, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: colorScheme.error.withValues(alpha: 0.85),
                      ),
                      tooltip: 'Delete saved group',
                    ),
                  IconButton(
                    onPressed: () => _showDetails(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _SetLine = ({int index, String text, String note});

class _ExerciseConfigDetailsCard extends StatelessWidget {
  final String title;
  final String explanation;
  final List<_SetLine> warmupLines;
  final List<_SetLine> workingSetLines;
  final List<String> meta;

  const _ExerciseConfigDetailsCard({
    required this.title,
    required this.explanation,
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
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanation,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colorScheme.onSurface.withValues(alpha: 0.76),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (warmupLines.isNotEmpty) ...[
            _DetailsSection(
              title: 'Warmups',
              tint: colorScheme.tertiary,
              icon: Icons.whatshot_outlined,
              setLines: warmupLines,
            ),
            const SizedBox(height: 10),
          ],
          _DetailsSection(
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

class _DetailsSection extends StatelessWidget {
  final String title;
  final Color tint;
  final IconData icon;
  final List<_SetLine> setLines;

  const _DetailsSection({
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

// ─── Pending update card ──────────────────────────────────────────────────────

class _PendingUpdateCard extends StatelessWidget {
  final PendingStateUpdate update;
  final VoidCallback onResolved;

  const _PendingUpdateCard({required this.update, required this.onResolved});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: cs.onErrorContainer,
                  ),
                ),
                if (update.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    update.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onErrorContainer.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _showResolveDialog(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Resolve',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResolveDialog(BuildContext context) async {
    final controllers = <String, TextEditingController>{};
    for (final f in update.fields) {
      final defaultText = _defaultText(f);
      controllers[f.key] = TextEditingController(text: defaultText);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _PendingUpdateDialog(update: update, controllers: controllers),
    );

    for (final c in controllers.values) {
      c.dispose();
    }

    if (confirmed != true || !context.mounted) return;

    final settingsProvider = context.read<SettingsProvider>();
    final fieldValues = <String, StateFieldValue>{};
    for (final f in update.fields) {
      final text = controllers[f.key]?.text.trim() ?? '';
      // Convert PendingStateUpdateField to StateFieldKind for value building
      final schema = TrainingProgramStateFieldSchema(key: f.key, kind: f.kind);
      final val = SettingsProvider.fieldValueFromText(
        schema,
        text,
        unit: settingsProvider.weightUnit,
      );
      if (val != null) fieldValues[f.key] = val;
    }

    try {
      await settingsProvider.applyPendingStateUpdate(
        updateId: update.updateId,
        fieldValues: fieldValues,
      );
      onResolved();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply update: $e')));
      }
    }
  }

  String _defaultText(PendingStateUpdateField f) {
    switch (f.defaultValue.whichValue()) {
      case StateFieldValue_Value.floatVal:
        return f.defaultValue.floatVal.toStringAsFixed(0);
      case StateFieldValue_Value.intVal:
        return f.defaultValue.intVal.toString();
      case StateFieldValue_Value.boolVal:
        return f.defaultValue.boolVal ? 'true' : 'false';
      case StateFieldValue_Value.stringVal:
        return f.defaultValue.stringVal;
      default:
        return '';
    }
  }
}

class _PendingUpdateDialog extends StatefulWidget {
  final PendingStateUpdate update;
  final Map<String, TextEditingController> controllers;

  const _PendingUpdateDialog({required this.update, required this.controllers});

  @override
  State<_PendingUpdateDialog> createState() => _PendingUpdateDialogState();
}

class _PendingUpdateDialogState extends State<_PendingUpdateDialog> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        widget.update.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.update.message.isNotEmpty) ...[
              Text(
                widget.update.message,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final f in widget.update.fields)
              _buildFieldInput(context, f, cs),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildFieldInput(
    BuildContext context,
    PendingStateUpdateField f,
    ColorScheme cs,
  ) {
    final controller = widget.controllers[f.key]!;
    if (f.kind == StateFieldKind.STATE_FIELD_KIND_ENUM &&
        f.enumOptions.isNotEmpty) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: f.enumOptions.map((opt) {
                    return ChoiceChip(
                      label: Text(opt.label.isNotEmpty ? opt.label : opt.value),
                      selected: opt.value == controller.text,
                      onSelected: (_) =>
                          setState(() => controller.text = opt.value),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      );
    }

    final isNumeric =
        f.kind == StateFieldKind.STATE_FIELD_KIND_FLOAT ||
        f.kind == StateFieldKind.STATE_FIELD_KIND_INT;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final isWeightField =
        '${f.label} ${f.key}'.toLowerCase().contains('weight') ||
        '${f.label} ${f.key}'.toLowerCase().contains('max');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              suffixText: isWeightField ? weightUnitSuffixPlural(unit) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
