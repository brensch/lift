import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../gen/workout/v1/settings.pbenum.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/grpc_client.dart';
import '../../services/health_service.dart';
import '../../services/wearable_bridge_service.dart';
import '../../services/workout_service.dart';
import '../../logic/exercises.dart';
import '../../logic/exercise_groups.dart';
import '../../logic/utils.dart';
import '../../logic/weight_units.dart';
import '../../widgets/exercise_editor/exercise_editor_dialogs.dart';
import '../../widgets/phase_explanation.dart';
import '../workout_start_briefing_screen.dart';
import 'home_selection.dart';


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
  List<NextSessionOption> _selectableNextSessions = [];
  bool _isSwappingSession = false;
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
        _selectableNextSessions = scheduleRes.selectableNextSessions;
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

  Future<void> _swapNextSession(String sessionKey) async {
    if (_isSwappingSession) return;
    setState(() => _isSwappingSession = true);
    try {
      final grpc = context.read<GrpcClient>();
      final ws = WorkoutServiceWrapper(grpc);
      await ws.setNextWorkout(sessionKey);
      // Drop the saved draft: it holds the *previous* session's selection, which
      // would otherwise partially re-match (e.g. squat is in both A and B) and
      // leave the wrong exercises ticked. Clearing it makes the reload auto-select
      // the newly-recommended exercises.
      await ws.clearWorkoutDraft();
      if (!mounted) return;
      // Reload so the proposed groups, recovery strip and readiness all reflect
      // the newly-queued session.
      await _loadData(refreshOnly: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t swap: ${cleanErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSwappingSession = false);
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


  int _estimatedWorkoutMinutes() {
    if (_selectableGroups == null || _selectedGroupIndices.isEmpty) return 0;
    // The server estimates each group's duration; we just sum the selected ones.
    var totalSeconds = 0;
    for (final idx in _selectedGroupIndices) {
      totalSeconds += _selectableGroups![idx].estimatedDurationSeconds.toInt();
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

    final ts = _trainingStatus;
    final rc = _regimeContext;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final style = _readinessStyle(ts?.readinessState);
    final liftRows = _selectedLiftRows(unit);
    final canStart = _selectedGroupIndices.isNotEmpty && !_isStarting;

    return RefreshIndicator(
      onRefresh: () => _loadData(refreshOnly: true),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Readiness headline ─────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          style.headline,
                          style: TextStyle(
                            fontSize: 34,
                            height: 0.98,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child:
                            _StateTagChip(label: style.tag, accent: style.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Session line + Edit ────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sessionLine(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _EditButton(
                          onTap: _showEditSheet, accent: colorScheme.tertiary),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Recovery strip ─────────────────────────────────────
                  if (ts != null && ts.muscleRecovery.isNotEmpty)
                    _RecoveryStripRow(muscles: _stripMuscles(ts)),
                  // ── Phase explanation (clean) ──────────────────────────
                  if (rc != null) ...[
                    const SizedBox(height: 16),
                    PhaseExplanation(
                        context: rc, showHeadline: false, showNext: false),
                  ],
                  const SizedBox(height: 20),
                  // ── Today's lifts ──────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'TODAY’S LIFTS',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (_isRefreshing)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (liftRows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'No exercises selected — tap Edit to add some.',
                        style:
                            TextStyle(color: colorScheme.tertiary, fontSize: 13),
                      ),
                    )
                  else
                    ...liftRows,
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // ── Start area: swap toggle + inset rounded Start button ───────
          _buildStartArea(colorScheme, style, canStart),
        ],
      ),
    );
  }

  // ── Readiness presentation ───────────────────────────────────────────────
  _ReadinessStyle _readinessStyle(ReadinessState? state) {
    switch (state) {
      case ReadinessState.READINESS_STATE_RECOVERING:
        return const _ReadinessStyle('Rest\nday.', 'Recovering', _kBlue);
      case ReadinessState.READINESS_STATE_OVERDUE:
        return const _ReadinessStyle('Been a\nwhile.', 'Overdue', _kAmber);
      case ReadinessState.READINESS_STATE_AHEAD:
        return const _ReadinessStyle('Bonus\nround.', 'Ahead', _kGreen);
      case ReadinessState.READINESS_STATE_FIRST_TIME:
        return const _ReadinessStyle('Ready\nto lift.', 'Ready', _kGreen);
      case ReadinessState.READINESS_STATE_READY:
      default:
        return const _ReadinessStyle('Train\ntoday.', 'Train today', _kGreen);
    }
  }

  /// The session line reflects the currently-selected exercises so it stays
  /// accurate after an edit, e.g. "Squat · Bench Press · Barbell Row".
  String _sessionLine() {
    final groups = _selectableGroups;
    if (groups == null) return '';
    final names = <String>[];
    for (final i in _selectedGroupIndices.toList()..sort()) {
      if (i < 0 || i >= groups.length) continue;
      for (final c in groups[i].exerciseConfigs) {
        final n = exerciseNames[c.exercise] ?? '';
        if (n.isNotEmpty && !names.contains(n)) names.add(n);
      }
    }
    if (names.isEmpty) return _trainingStatus?.nextWorkoutLabel ?? '';
    return names.join('  ·  ');
  }

  /// Next-workout muscles first (recovering ones lead), for the strip.
  List<MuscleRecoveryStatus> _stripMuscles(TrainingStatus ts) {
    final inNext = ts.muscleRecovery.where((m) => m.inNextWorkout).toList();
    final list = inNext.isNotEmpty ? inNext : ts.muscleRecovery.toList();
    list.sort((a, b) {
      final ar = a.recovered ? 1 : 0;
      final br = b.recovered ? 1 : 0;
      if (ar != br) return ar - br;
      return a.label.compareTo(b.label);
    });
    return list;
  }

  double _resolveWeight(
    HomeSelectableGroup g,
    ExerciseTypeConfig c,
    Map<int, ExerciseStatus> statusMap,
  ) {
    if (g.useScheduleWeights) {
      return statusMap[c.exercise.value]?.targetWeight ?? c.startWeight;
    }
    return c.startWeight;
  }

  /// One row per exercise across the currently-selected groups.
  List<Widget> _selectedLiftRows(WeightUnit unit) {
    final groups = _selectableGroups;
    if (groups == null) return const [];
    final statusMap = _statusMap();
    final rows = <Widget>[];
    for (final i in _selectedGroupIndices.toList()..sort()) {
      if (i < 0 || i >= groups.length) continue;
      final g = groups[i];
      for (final c in g.exerciseConfigs) {
        final w = _resolveWeight(g, c, statusMap);
        rows.add(_LiftRow(
          emoji: exerciseEmojis[c.exercise] ?? '🏋️',
          name: exerciseNames[c.exercise] ?? g.name,
          scheme: '${g.sets}×${c.reps}',
          weight: w > 0 ? formatWeight(w, unit) : '—',
        ));
      }
    }
    return rows;
  }

  Widget _buildStartArea(ColorScheme cs, _ReadinessStyle style, bool canStart) {
    final est = _predictedWorkoutTimeLabel();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectableNextSessions.length >= 2) ...[
            _SessionSwapToggle(
              options: _selectableNextSessions,
              isSwapping: _isSwappingSession,
              onSwap: _swapNextSession,
              accent: style.accent,
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: canStart ? _startWorkout : null,
              style: FilledButton.styleFrom(
                backgroundColor: style.accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    cs.surfaceContainerHighest.withValues(alpha: 0.4),
                disabledForegroundColor: cs.onSurfaceVariant,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isStarting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Start workout',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (est != '--') ...[
                          const SizedBox(width: 8),
                          Text(
                            '· $est',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSheet() async {
    final groups = _selectableGroups;
    if (groups == null) return;
    final unit = context.read<SettingsProvider>().weightUnit;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _EditSheet(
        groups: groups,
        initialSelected: _selectedGroupIndices,
        unit: unit,
        statusMap: _statusMap(),
        resolveWeight: _resolveWeight,
        onToggle: _toggleGroup,
        onEdit: (i) {
          Navigator.of(sheetCtx).pop();
          _editGroup(i);
        },
        onDelete: _deleteSavedGroup,
        onAddSaved: () {
          Navigator.of(sheetCtx).pop();
          _showAddSavedGroupDialog();
        },
      ),
    );
  }
}

// ─── Concept B home widgets ───────────────────────────────────────────────────

const Color _kGreen = Color(0xFF3AD98B);
const Color _kAmber = Color(0xFFF5B544);
const Color _kBlue = Color(0xFF6EA8FF);

class _ReadinessStyle {
  final String headline; // may contain a newline for the big two-line title
  final String tag;
  final Color accent;
  const _ReadinessStyle(this.headline, this.tag, this.accent);
}

class _StateTagChip extends StatelessWidget {
  final String label;
  final Color accent;
  const _StateTagChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color accent;
  const _EditButton({required this.onTap, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 14, color: accent),
              const SizedBox(width: 5),
              Text('Edit',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900, color: accent)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryStripRow extends StatelessWidget {
  final List<MuscleRecoveryStatus> muscles;
  const _RecoveryStripRow({required this.muscles});

  static String _hoursLabel(int hours) {
    if (hours >= 24) {
      final days = (hours / 24).round();
      return days <= 1 ? '1d' : '${days}d';
    }
    return '${hours}h';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in muscles)
          Builder(builder: (context) {
            final accent = m.recovered ? _kGreen : _kAmber;
            final hours = m.hoursRemaining.toInt();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(m.label,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                  if (!m.recovered && hours > 0) ...[
                    const SizedBox(width: 5),
                    Text(_hoursLabel(hours),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.45))),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _LiftRow extends StatelessWidget {
  final String emoji;
  final String name;
  final String scheme;
  final String weight;
  const _LiftRow({
    required this.emoji,
    required this.name,
    required this.scheme,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          Text(scheme,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Text(weight,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _SessionSwapToggle extends StatelessWidget {
  final List<NextSessionOption> options;
  final bool isSwapping;
  final ValueChanged<String> onSwap;
  final Color accent;
  const _SessionSwapToggle({
    required this.options,
    required this.isSwapping,
    required this.onSwap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: (o.isCurrent || isSwapping) ? null : () => onSwap(o.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: o.isCurrent ? accent.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      // "Workout A · Squat, Bench, Row" → "Workout A"
                      o.label.split('·').first.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: o.isCurrent
                            ? accent
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The edit sheet: a checklist of every group (recommended / later / saved).
/// Ticking includes it in today; tapping the row opens the exercise editor.
class _EditSheet extends StatefulWidget {
  final List<HomeSelectableGroup> groups;
  final Set<int> initialSelected;
  final WeightUnit unit;
  final Map<int, ExerciseStatus> statusMap;
  final double Function(
      HomeSelectableGroup, ExerciseTypeConfig, Map<int, ExerciseStatus>) resolveWeight;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onAddSaved;

  const _EditSheet({
    required this.groups,
    required this.initialSelected,
    required this.unit,
    required this.statusMap,
    required this.resolveWeight,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSaved,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final Set<int> _selected = {...widget.initialSelected};

  void _toggle(int i) {
    setState(() {
      if (_selected.contains(i)) {
        _selected.remove(i);
      } else {
        _selected.add(i);
      }
    });
    widget.onToggle(i);
  }

  List<int> _indicesFor(HomeGroupSection section) => [
        for (int i = 0; i < widget.groups.length; i++)
          if (widget.groups[i].section == section) i,
      ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recommended = _indicesFor(HomeGroupSection.recommended);
    final later = _indicesFor(HomeGroupSection.planLater);
    final saved = _indicesFor(HomeGroupSection.saved);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Row(
              children: [
                const Text('Customize workout',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Toggle what’s in today. Tap a lift to adjust it.',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant, height: 1.3)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (recommended.isNotEmpty)
                    _section(cs, 'Recommended today', recommended),
                  if (later.isNotEmpty)
                    _section(cs, 'Later in your plan', later),
                  _section(cs, 'Saved', saved, showAdd: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ColorScheme cs, String title, List<int> indices,
      {bool showAdd = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: cs.tertiary)),
            const Spacer(),
            if (showAdd)
              GestureDetector(
                onTap: widget.onAddSaved,
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 15, color: cs.primary),
                    const SizedBox(width: 3),
                    Text('New',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: cs.primary)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (indices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
                showAdd
                    ? 'Save a group to reuse it any time.'
                    : 'Nothing here.',
                style: TextStyle(color: cs.tertiary, fontSize: 12.5)),
          )
        else
          for (final i in indices) _groupRow(cs, i),
      ],
    );
  }

  Widget _groupRow(ColorScheme cs, int i) {
    final g = widget.groups[i];
    final on = _selected.contains(i);
    final lifts = g.exerciseConfigs
        .map((c) => exerciseNames[c.exercise] ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');
    final firstCfg = g.exerciseConfigs.isNotEmpty ? g.exerciseConfigs.first : null;
    final weight = firstCfg == null
        ? ''
        : formatWeight(
            widget.resolveWeight(g, firstCfg, widget.statusMap), widget.unit);

    return InkWell(
      onTap: () => _toggle(i),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: on ? _kGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: on ? _kGreen : cs.outlineVariant, width: 2),
              ),
              child: on
                  ? const Icon(Icons.check_rounded,
                      size: 15, color: Color(0xFF04120B))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: on ? cs.onSurface : cs.onSurfaceVariant)),
                  if (lifts.isNotEmpty && lifts != g.name)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(lifts,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.7))),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${g.sets}×${firstCfg?.reps ?? 5}${weight.isNotEmpty ? ' · $weight' : ''}',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
            IconButton(
              onPressed: () => widget.onEdit(i),
              icon: Icon(Icons.tune_rounded, size: 17, color: cs.tertiary),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 10, right: 2),
            ),
            if (g.section == HomeGroupSection.saved)
              IconButton(
                onPressed: () => widget.onDelete(i),
                icon: Icon(Icons.delete_outline_rounded,
                    size: 17, color: cs.error.withValues(alpha: 0.8)),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(left: 6),
              ),
          ],
        ),
      ),
    );
  }
}

