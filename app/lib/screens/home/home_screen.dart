import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/grpc_client.dart';
import '../../services/health_service.dart';
import '../../services/wearable_bridge_service.dart';
import '../../services/workout_service.dart';
import '../../logic/exercises.dart';
import '../../logic/exercise_groups.dart';
import '../../logic/utils.dart';
import '../../widgets/exercise_editor/exercise_editor_dialogs.dart';
import '../workout_start_briefing_screen.dart';
import '../../widgets/common/section_header.dart';
import 'group_grid.dart';
import 'home_selection.dart';
import 'readiness_banner.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _draftSaveDebounce = Duration(milliseconds: 400);
  List<ExerciseStatus>? _schedule;
  List<HomeSelectableGroup>? _selectableGroups;
  RegimeContext? _regimeContext;
  TrainingStatus? _trainingStatus;
  List<UserMessage> _scheduleMessages = [];
  String _suggestedWorkoutBaseName = '';
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
      final selectableGroups = <HomeSelectableGroup>[
        for (int i = 0; i < scheduleRes.proposedGroups.length; i++)
          HomeSelectableGroup.fromProposed(
            scheduleRes.proposedGroups[i],
            index: i,
          ),
        for (final group in scheduleRes.savedExerciseGroups)
          HomeSelectableGroup.fromSaved(group),
      ];

      // Auto-select all groups tagged "recommended" on each load/refresh.
      final autoSelected = <int>{};
      for (int i = 0; i < selectableGroups.length; i++) {
        if (selectableGroups[i].section == HomeGroupSection.recommended) {
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
        _scheduleMessages = scheduleRes.userMessages;
        _suggestedWorkoutBaseName = scheduleRes.suggestedWorkoutName.trim();
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

    final auth = context.read<AuthProvider>();
    final grpc = context.read<GrpcClient>();
    final workoutService = WorkoutServiceWrapper(grpc);
    final freshSchedule = await workoutService.getProposedWorkoutSchedule(
      auth.userId!,
    );
    if (!mounted) return;

    final freshStatusMap = <int, ExerciseStatus>{
      for (final status in freshSchedule.exerciseStatuses)
        status.exercise.value: status,
    };
    final selectedGroups = (_selectedGroupIndices.toList()..sort())
        .map(
          (idx) => _selectableGroups![idx].toWorkoutGroup(
            workoutOrder: idx,
            statusMap: freshStatusMap,
            forWorkoutStart: false,
          ),
        )
        .toList(growable: false);

    setState(() {
      _schedule = freshSchedule.exerciseStatuses;
      _regimeContext = freshSchedule.hasRegimeContext()
          ? freshSchedule.regimeContext
          : null;
      _trainingStatus = freshSchedule.hasTrainingStatus()
          ? freshSchedule.trainingStatus
          : null;
      _scheduleMessages = freshSchedule.userMessages;
      _suggestedWorkoutBaseName = freshSchedule.suggestedWorkoutName.trim();
    });

    final workoutName = _buildWorkoutName(
      freshSchedule.suggestedWorkoutName.trim().isNotEmpty
          ? freshSchedule.suggestedWorkoutName.trim()
          : (freshSchedule.hasRegimeContext() &&
                    freshSchedule.regimeContext.regimeDisplayName
                        .trim()
                        .isNotEmpty
                ? freshSchedule.regimeContext.regimeDisplayName.trim()
                : _currentWorkoutBaseName()),
    );
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutStartBriefingScreen(
          workoutName: workoutName,
          regimeContext: freshSchedule.hasRegimeContext()
              ? freshSchedule.regimeContext
              : null,
          scheduleMessages: freshSchedule.userMessages,
          selectedGroups: selectedGroups,
          estimatedTimeLabel: _predictedWorkoutTimeLabel(),
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
        unawaited(_setUpHealthAndWatch(wearableBridge));
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

  Future<void> _setUpHealthAndWatch(WearableBridgeService bridge) async {
    // ONE comprehensive Health permission request, fully awaited, THEN launch the
    // watch — never concurrently. Doing them at the same time made iOS re-present a
    // half-answered sheet (the "Allow read → comes back unticked" bug). Requested for
    // everyone (not just watch users) because completed workouts are saved to Health.
    await HealthService.requestWorkoutHealthPermissions();
    try {
      if (await bridge.isWatchAppAvailable()) {
        await bridge.openWatchApp();
      }
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
      if (groups[i].section == HomeGroupSection.recommended) {
        recommended.add(i);
      } else if (groups[i].section == HomeGroupSection.saved) {
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
                  HomeSelectableGroup.fromSaved(saved),
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

            if (original.section == HomeGroupSection.saved) {
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
                      HomeSelectableGroup.fromSaved(saved);
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
    if (target.section != HomeGroupSection.saved ||
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
              HomeGroupSection.recommended,
        )
        .toList(growable: false);
    final savedGroupIndices = visibleGroupIndices
        .where(
          (index) =>
              _selectableGroups![index].section == HomeGroupSection.saved,
        )
        .toList(growable: false);
    final otherGroupIndices = visibleGroupIndices
        .where(
          (index) =>
              _selectableGroups![index].section == HomeGroupSection.planLater,
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
                  child: ReadinessBanner(
                    trainingStatus: _trainingStatus,
                    regimeContext: _regimeContext,
                  ),
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
                  child: SectionHeader(
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
                        GroupGrid(
                          indices: recommendedGroupIndices,
                          groups: _selectableGroups!,
                          scheduleMessages: _scheduleMessages,
                          selectedIndices: _selectedGroupIndices,
                          onToggle: _toggleGroup,
                          onEdit: _editGroup,
                        ),
                      if (recommendedGroupIndices.isEmpty)
                        const EmptySectionText(
                          text: 'Nothing is recommended right now.',
                        ),
                      const SizedBox(height: 18),
                      SectionHeader(
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
                        GroupGrid(
                          indices: savedGroupIndices,
                          groups: _selectableGroups!,
                          scheduleMessages: _scheduleMessages,
                          selectedIndices: _selectedGroupIndices,
                          onToggle: _toggleGroup,
                          onEdit: _editGroup,
                          onDelete: _deleteSavedGroup,
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: EmptySectionText(
                            text:
                                'Save a group here to reuse it whenever you want.',
                          ),
                        ),
                      const SizedBox(height: 18),
                      const SectionHeader(
                        title: 'Not today but in your schplan',
                      ),
                      if (otherGroupIndices.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GroupGrid(
                          indices: otherGroupIndices,
                          groups: _selectableGroups!,
                          scheduleMessages: _scheduleMessages,
                          selectedIndices: _selectedGroupIndices,
                          onToggle: _toggleGroup,
                          onEdit: _editGroup,
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: EmptySectionText(
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
                onPressed: _selectedGroupIndices.isEmpty || _isStarting
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

