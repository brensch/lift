import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/weight_units.dart';
import '../logic/workout_plan_builder.dart';
import '../providers/settings_provider.dart';
import '../services/workout_service.dart';
import '../providers/sound_provider.dart';
import '../services/notification_service.dart';
import '../services/health_service.dart' show HealthService, HealthWriteResult;
import '../services/error_modal_service.dart';
import '../logic/exercises.dart';
import '../logic/utils.dart';
import '../services/grpc_client.dart' show isAppUpdateRequiredError;
import '../services/app_logger.dart';

class WorkoutProvider extends ChangeNotifier with WidgetsBindingObserver {

  static const int _maxWearHeartRateSamplesInMemory = 50000;
  static const _localWorkoutCacheKey =
      'workout_provider.local_workout_state.v1';
  static const _pendingMutationsKey = 'workout_provider.pending_mutations.v1';
  static const _mutationFlushDebounce = Duration(milliseconds: 350);
  static const _mutationRetryBaseDelay = Duration(seconds: 2);
  static const _mutationRetryMaxDelay = Duration(seconds: 15);

  final WorkoutServiceWrapper _service;
  final SettingsProvider _settingsProvider;
  SoundProvider? _soundProvider;
  final _uuid = const Uuid();
  double _bodyWeightKg = 0;

  /// Called after each set mutation so the multiplayer session view can
  /// refresh immediately instead of waiting for the next background tick.
  VoidCallback? onSessionRefreshNeeded;

  /// Called after endWorkout() completes successfully, with the finished
  /// workout's id. Used by the app shell to navigate to the summary screen
  /// when the workout is ended from a source that can't navigate itself
  /// (e.g. the watch).
  void Function(String workoutId)? onWorkoutEnded;

  void setBodyWeightKg(double kg) => _bodyWeightKg = kg;

  // Loading state
  bool _isLoading = false;
  String? _lastLoadError;
  bool _lastLoadWasUnauthorized = false;

  // Active workout state
  Workout? _activeWorkout;
  List<ExerciseGroup> _activeExerciseGroups = [];
  List<ProposedSet> _activeProposedSets = [];
  List<CompletedSet> _activeCompletedSets = [];
  ProposedSet? _backendNextUpSet;
  WorkoutStateSnapshot? _stateSnapshot;
  GetHomeResponse? _home;
  List<UserMessage> _scheduleMessages = [];
  List<UserMessage> _workoutMessages = [];
  final List<HeartRateSample> _wearHeartRateSamples = [];
  final Set<String> _wearHeartRateBatchIds = <String>{};
  final Set<int> _wearHeartRateSampleTimestamps = <int>{};
  final List<WorkoutHeartRatePoint> _pendingWearHeartRateUploads = [];
  DateTime? _lastWearHeartRateUploadAt;
  bool _wearHeartRateUploadInFlight = false;

  bool _wasResting = false;
  final List<WorkoutMutation> _pendingMutations = [];
  Timer? _mutationFlushTimer;
  bool _mutationFlushInFlight = false;
  int _mutationFlushRetryCount = 0;
  late final Future<void> _restoreLocalCacheFuture;

  Timer? _timer;
  DateTime _now = DateTime.now();
  late final ValueNotifier<DateTime> _clock = ValueNotifier<DateTime>(_now);
  final List<ExerciseGroupData> _exerciseGroupsCache = [];
  late final UnmodifiableListView<HeartRateSample> _wearHeartRateSamplesView =
      UnmodifiableListView(_wearHeartRateSamples);

  WorkoutProvider(this._service, this._settingsProvider) {
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onStartNextSet = _onStartNextSet;
    _restoreLocalCacheFuture = _restoreLocalCache();
  }

  void _onStartNextSet() {
    final next = nextPendingSet;
    if (next != null) {
      startSet(next.id);
    }
  }

  void _setNow(DateTime value) {
    _now = value;
    _clock.value = value;
  }







  void _resequenceAllProposedSets({
    String? prioritizeCompletedGroupId,
    Set<String> completedIds = const {},
  }) {
    final orderedGroups = List<ExerciseGroup>.from(_activeExerciseGroups)
      ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));

    final reordered = <ProposedSet>[];
    final cancelled = <ProposedSet>[];

    for (final group in orderedGroups) {
      final groupSets = _activeProposedSets
          .where((set) => set.exerciseGroupId == group.id)
          .toList();
      final visible = groupSets.where((set) => !set.cancelled).toList()
        ..sort((a, b) {
          if (group.id == prioritizeCompletedGroupId) {
            final aDone = completedIds.contains(a.id);
            final bDone = completedIds.contains(b.id);
            if (aDone != bDone) return aDone ? -1 : 1;
          }
          return a.workoutOrder.compareTo(b.workoutOrder);
        });
      final hidden = groupSets.where((set) => set.cancelled).toList()
        ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
      reordered.addAll(visible);
      cancelled.addAll(hidden);
    }

    final ungroupedVisible =
        _activeProposedSets
            .where((set) => set.exerciseGroupId.isEmpty && !set.cancelled)
            .toList()
          ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    final ungroupedCancelled =
        _activeProposedSets
            .where((set) => set.exerciseGroupId.isEmpty && set.cancelled)
            .toList()
          ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));

    reordered.addAll(ungroupedVisible);
    cancelled.addAll(ungroupedCancelled);

    _activeProposedSets = [...reordered, ...cancelled];
    for (int i = 0; i < _activeProposedSets.length; i++) {
      _activeProposedSets[i].workoutOrder = i;
    }
  }

  String? _applyLocalReplaceExerciseGroupPlan({
    required String name,
    required String? exerciseGroupId,
    required bool interleaveWarmups,
    required List<PlannedGroupSet> sets,
    RestConfig? restConfig,
    bool deleteGroupIfEmpty = false,
    String instruction = '',
    bool createIfMissing = false,
    GroupWarmupPlan? warmupPlan,
  }) {
    final workout = _activeWorkout;
    if (workout == null) return null;
    final normalizedSets = List<PlannedGroupSet>.from(sets);
    final completedIds = _activeCompletedSets
        .where((c) => c.proposedSetId.isNotEmpty)
        .map((c) => c.proposedSetId)
        .toSet();

    final requestedGroupId =
        (exerciseGroupId == null || exerciseGroupId.isEmpty)
        ? null
        : exerciseGroupId;

    final existingIdx = requestedGroupId == null
        ? -1
        : _activeExerciseGroups.indexWhere((g) => g.id == requestedGroupId);

    if (requestedGroupId == null || (existingIdx == -1 && createIfMissing)) {
      if (deleteGroupIfEmpty && normalizedSets.isEmpty) return null;
      final groupId = requestedGroupId ?? _uuid.v4();
      final group = ExerciseGroup()
        ..id = groupId
        ..workoutId = workout.id
        ..name = name
        ..sets = computeGroupWorkingRoundsFromSets(normalizedSets)
        ..interleaveWarmups = interleaveWarmups
        ..workoutOrder = _activeExerciseGroups.length
        ..instruction = instruction;
      if (restConfig != null) {
        group.restConfig = RestConfig()..mergeFromMessage(restConfig);
      }
      final startOrder = _activeProposedSets.isEmpty
          ? 0
          : (_activeProposedSets.last.workoutOrder + 1);
      final generated = proposedSetsFromPlannedGroupSets(
        workoutId: workout.id,
        groupId: groupId,
        sets: normalizedSets,
        startOrder: startOrder,
      );
      _activeExerciseGroups.add(group);
      _activeProposedSets.addAll(generated);
      _refreshDerivedState();
      return groupId;
    }

    if (existingIdx == -1) return null;
    final existing = _activeExerciseGroups[existingIdx];

    if (deleteGroupIfEmpty && normalizedSets.isEmpty) {
      final groupId = existing.id;
      _activeProposedSets.removeWhere(
        (p) => p.exerciseGroupId == groupId && !completedIds.contains(p.id),
      );
      _activeExerciseGroups.removeAt(existingIdx);
      _refreshDerivedState();
      return groupId;
    }

    existing
      ..name = name
      ..interleaveWarmups = interleaveWarmups
      ..sets = computeGroupWorkingRoundsFromSets(normalizedSets)
      ..instruction = instruction
      ..exerciseConfigs.clear();
    if (restConfig != null) {
      existing.restConfig = RestConfig()..mergeFromMessage(restConfig);
    } else {
      existing.clearRestConfig();
    }

    final completedGroupSets =
        _activeProposedSets
            .where(
              (p) =>
                  p.exerciseGroupId == existing.id &&
                  completedIds.contains(p.id),
            )
            .toList()
          ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));

    // Cancel the pending *working* sets optimistically — the edit replaces those.
    // Leave the existing warmups on screen: the client no longer generates them,
    // so cancelling here would blink them out until the server's recalculated
    // warmups arrive. They stay at the old weight for ~one round-trip, then the
    // response swaps in the new ladder in place — no disappear/reappear jump.
    //
    // The exception is a warmup the plan just switched off: nothing is coming
    // back to replace it, so it goes now rather than lingering until the
    // response lands.
    final droppedWarmupExercises = warmupPlan == null
        ? const <int>{}
        : _activeProposedSets
              .where((p) => p.exerciseGroupId == existing.id && p.warmup)
              .map((p) => p.exercise.value)
              .toSet()
              .difference(warmupPlan.exercises.map((e) => e.value).toSet());
    for (final set in _activeProposedSets.where(
      (p) =>
          p.exerciseGroupId == existing.id &&
          !completedIds.contains(p.id) &&
          (!p.warmup || droppedWarmupExercises.contains(p.exercise.value)),
    )) {
      set.cancelled = true;
    }

    final completedSlotsByKey = <String, int>{};
    for (final set in completedGroupSets) {
      final key = '${set.exercise.value}:${set.warmup}';
      completedSlotsByKey[key] = (completedSlotsByKey[key] ?? 0) + 1;
    }

    final pendingPlanned = <PlannedGroupSet>[];
    for (final set in normalizedSets) {
      final key = '${set.exercise.value}:${set.warmup}';
      final remaining = completedSlotsByKey[key] ?? 0;
      if (remaining > 0) {
        completedSlotsByKey[key] = remaining - 1;
        continue;
      }
      pendingPlanned.add(set);
    }

    final generated = proposedSetsFromPlannedGroupSets(
      workoutId: workout.id,
      groupId: existing.id,
      sets: pendingPlanned,
      startOrder: 0,
    );
    _activeProposedSets.addAll(generated);
    _resequenceAllProposedSets(
      prioritizeCompletedGroupId: existing.id,
      completedIds: completedIds,
    );
    _refreshDerivedState();
    return existing.id;
  }

  Future<void> _replaceExerciseGroupPlan({
    required String name,
    required String? exerciseGroupId,
    required bool interleaveWarmups,
    required List<PlannedGroupSet> sets,
    RestConfig? restConfig,
    bool deleteGroupIfEmpty = false,
    String instruction = '',
    bool createIfMissing = false,
    GroupWarmupPlan? warmupPlan,
  }) async {
    if (_activeWorkout == null) return;
    final createdAt = _now.millisecondsSinceEpoch ~/ 1000;
    final normalizedSets = sets
        .map(
          (set) => (set.clientSetId.isNotEmpty
              ? set
              : (set.deepCopy()..clientSetId = _uuid.v4())),
        )
        .toList();
    final effectiveGroupId = _applyLocalReplaceExerciseGroupPlan(
      name: name,
      exerciseGroupId: exerciseGroupId,
      interleaveWarmups: interleaveWarmups,
      sets: normalizedSets,
      restConfig: restConfig,
      deleteGroupIfEmpty: deleteGroupIfEmpty,
      instruction: instruction,
      createIfMissing: createIfMissing,
      warmupPlan: warmupPlan,
    );
    if (effectiveGroupId == null && createIfMissing) {
      _handleError('Could not apply workout group change locally.');
      return;
    }
    final req = ReplaceExerciseGroupPlanRequest()
      ..workoutId = _activeWorkout!.id
      ..exerciseGroupId = effectiveGroupId ?? (exerciseGroupId ?? '')
      ..name = name
      ..interleaveWarmups = interleaveWarmups
      ..sets.addAll(normalizedSets)
      ..deleteGroupIfEmpty = deleteGroupIfEmpty
      ..instruction = instruction
      ..createIfMissing = createIfMissing;
    if (warmupPlan != null) {
      req.warmupPlan = warmupPlan;
    }
    if (restConfig != null) {
      req.restConfig = RestConfig()..mergeFromMessage(restConfig);
    }
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        replaceExerciseGroupPlan: req,
      ),
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  void setSoundProvider(SoundProvider provider) {
    _soundProvider = provider;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setNow(DateTime.now());
      unawaited(_hydrateWearHeartRateFromApi());
      notifyListeners();
    }
  }

  /// Called every second in all lifecycle states.
  /// Primary sound path: cancels the OS notification and plays in-app audio.
  /// The OS notification is the fallback for when the app is killed (no timer).
  Future<void> _checkRestSound() async {
    final snapshot = _stateSnapshot;
    if (snapshot == null) {
      _wasResting = false;
      return;
    }
    if (snapshot.state == WorkoutState.WORKOUT_STATE_LIFTING) {
      _wasResting = false;
      return;
    }
    final nowUnix = _now.millisecondsSinceEpoch ~/ 1000;
    final isCurrentlyResting =
        snapshot.state == WorkoutState.WORKOUT_STATE_RESTING &&
        snapshot.restUntil.toInt() > nowUnix;

    if (_wasResting && !isCurrentlyResting) {
      await NotificationService.cancelRest();
      _soundProvider?.playCurrentSound();
      unawaited(NotificationService.playRestCompletionHaptic());
    }
    _wasResting = isCurrentlyResting;
  }

  void _sortState() {
    _activeExerciseGroups.sort(
      (a, b) => a.workoutOrder.compareTo(b.workoutOrder),
    );
    _activeProposedSets.sort(
      (a, b) => a.workoutOrder.compareTo(b.workoutOrder),
    );
  }

  List<ProposedSet> _visibleProposedSetsSorted() {
    final sets = _activeProposedSets.where((s) => !s.cancelled).toList();
    sets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    return sets;
  }

  ProposedSet? _firstUncompletedSet() {
    final completedIds = _activeCompletedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .map((c) => c.proposedSetId)
        .toSet();
    for (final set in _visibleProposedSetsSorted()) {
      if (!completedIds.contains(set.id)) return set;
    }
    return null;
  }

  /// The tiny optimistic layer: after a local set change, reflect a set in
  /// progress (LIFTING) or advance the highlight to the next set. The
  /// authoritative snapshot — crucially the rest timer — comes from the server
  /// response a beat later, so no rest maths is duplicated here.
  void _refreshDerivedState() {
    _sortState();
    final nextUp = _firstUncompletedSet();
    _backendNextUpSet = nextUp;

    CompletedSet? active;
    for (final s in _activeCompletedSets) {
      if (s.endedAt == Int64.ZERO &&
          (active == null || s.startedAt > active.startedAt)) {
        active = s;
      }
    }
    if (active != null) {
      final displaySet = _visibleProposedSetsSorted()
          .cast<ProposedSet?>()
          .firstWhere((p) => p?.id == active!.proposedSetId,
              orElse: () => null);
      _applyStateSnapshot(WorkoutStateSnapshot(
        state: WorkoutState.WORKOUT_STATE_LIFTING,
        displaySet: displaySet,
        activeStartedAt: active.startedAt,
      ));
      _rebuildExerciseGroupsCache();
      return;
    }

    // Resting: the most-recently-finished set still has a rest target in the
    // future. The target was stored locally on completion, so the countdown
    // keeps running off the device clock even with no connection.
    CompletedSet? lastDone;
    for (final s in _activeCompletedSets) {
      if (s.endedAt != Int64.ZERO &&
          (lastDone == null || s.endedAt > lastDone.endedAt)) {
        lastDone = s;
      }
    }
    // Only rest when there's a next set to rest *before*. After the final set
    // there's nothing to start, so fall through to ALL_DONE rather than showing a
    // rest state whose Start button would re-open the just-finished set. Mirrors
    // workout_state_snapshot_from_state in src/workout/reducer.rs.
    if (nextUp != null &&
        lastDone != null &&
        lastDone.restUntil > Int64(_nowSecs)) {
      _applyStateSnapshot(WorkoutStateSnapshot(
        state: WorkoutState.WORKOUT_STATE_RESTING,
        displaySet: nextUp,
        restUntil: lastDone.restUntil,
      ));
      _rebuildExerciseGroupsCache();
      return;
    }

    // Ready for the next set, or all done. When a set is up next, carry the
    // previous rest's end (its restUntil) as lastRestEnd so the "yapping" count-up
    // survives a re-derive — mirrors the READY branch in reducer.rs.
    _applyStateSnapshot(WorkoutStateSnapshot(
      state: nextUp == null
          ? WorkoutState.WORKOUT_STATE_ALL_DONE
          : WorkoutState.WORKOUT_STATE_READY,
      displaySet: nextUp,
      lastRestEnd: nextUp != null && lastDone != null
          ? lastDone.restUntil
          : Int64.ZERO,
    ));
    _rebuildExerciseGroupsCache();
  }

  void _rebuildExerciseGroupsCache() {
    _exerciseGroupsCache.clear();
    if (_activeExerciseGroups.isEmpty) {
      _exerciseGroupsCache.addAll(groupSetsByExercise(_activeProposedSets));
      return;
    }

    for (final group in _activeExerciseGroups) {
      final sets = _activeProposedSets
          .where((s) => s.exerciseGroupId == group.id && !s.cancelled)
          .toList();
      sets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));

      final exercise = group.exerciseConfigs.isNotEmpty
          ? Exercise.valueOf(group.exerciseConfigs.first.exercise.value) ??
                Exercise.EXERCISE_UNSPECIFIED
          : (sets.isNotEmpty
                ? sets.first.exercise
                : Exercise.EXERCISE_UNSPECIFIED);

      final exercises = <Exercise>[];
      for (final config in group.exerciseConfigs) {
        final ex = Exercise.valueOf(config.exercise.value);
        if (ex != null && !exercises.contains(ex)) exercises.add(ex);
      }

      _exerciseGroupsCache.add(
        ExerciseGroupData(
          exercise: exercise,
          sets: sets,
          group: group,
          exercises: exercises,
        ),
      );
    }
  }

  void _applyWorkoutResponse(GetWorkoutResponse response) {
    final isSameWorkout = _activeWorkout?.id == response.workout.id;
    _resetWearHeartRateBufferIfWorkoutChanged(response.workout.id);
    _activeWorkout = response.workout;
    _activeExerciseGroups = List.from(response.exerciseGroups);
    _activeProposedSets = List.from(response.proposedSets);
    _activeCompletedSets = List.from(response.completedSets);
    // Keep the schplanner explanation sticky for the duration of a workout: a
    // mid-workout refresh that returns no messages should not wipe the ones we
    // already have (only replace when we get a fresh set, or switch workouts).
    if (response.userMessages.isNotEmpty || !isSameWorkout) {
      _workoutMessages = List<UserMessage>.from(response.userMessages);
    }
    // Authoritative state comes from the server — never recomputed locally.
    _sortState();
    _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
    if (response.hasStateSnapshot()) {
      _applyStateSnapshot(response.stateSnapshot);
    }
    _rebuildExerciseGroupsCache();
  }

  String? _workoutIdForMutation(WorkoutMutation mutation) {
    final payload = mutation.whichMutation();
    switch (payload) {
      case WorkoutMutation_Mutation.startSet:
        return mutation.startSet.workoutId;
      case WorkoutMutation_Mutation.completeSet:
        return mutation.completeSet.workoutId;
      case WorkoutMutation_Mutation.cancelProposedSet:
        return mutation.cancelProposedSet.workoutId;
      case WorkoutMutation_Mutation.deleteCompletedSet:
        return mutation.deleteCompletedSet.workoutId;
      case WorkoutMutation_Mutation.endWorkout:
        return mutation.endWorkout.workoutId;
      case WorkoutMutation_Mutation.replaceExerciseGroupPlan:
        return mutation.replaceExerciseGroupPlan.workoutId;
      case WorkoutMutation_Mutation.reorderExerciseGroups:
        return mutation.reorderExerciseGroups.workoutId;
      case WorkoutMutation_Mutation.notSet:
        return null;
    }
  }

  void _applyLocalReorderExerciseGroups(List<String> groupIds) {
    if (_activeWorkout == null) return;
    final orderedGroups = <ExerciseGroup>[];
    for (final id in groupIds) {
      final idx = _activeExerciseGroups.indexWhere((g) => g.id == id);
      if (idx == -1) continue;
      final group = _activeExerciseGroups[idx];
      orderedGroups.add(group..workoutOrder = orderedGroups.length);
    }
    for (final group in _activeExerciseGroups) {
      if (orderedGroups.any((existing) => existing.id == group.id)) continue;
      orderedGroups.add(group..workoutOrder = orderedGroups.length);
    }
    _activeExerciseGroups = orderedGroups;

    final orderedSets = <ProposedSet>[];
    for (final group in orderedGroups) {
      final sets = _activeProposedSets
          .where((s) => s.exerciseGroupId == group.id)
          .toList();
      sets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
      for (final set in sets) {
        orderedSets.add(set..workoutOrder = orderedSets.length);
      }
    }
    _activeProposedSets = orderedSets;
    _refreshDerivedState();
  }

  void _overlayPendingMutationsOnActiveWorkout() {
    final workout = _activeWorkout;
    if (workout == null) return;

    for (final mutation in _pendingMutations) {
      if (_workoutIdForMutation(mutation) != workout.id) continue;
      switch (mutation.whichMutation()) {
        case WorkoutMutation_Mutation.startSet:
          _applyLocalStartSet(
            mutation.startSet.proposedSetId,
            startedAt: mutation.startSet.startedAt.toInt(),
          );
        case WorkoutMutation_Mutation.completeSet:
          _applyLocalCompleteSet(
            mutation.completeSet.proposedSetId,
            mutation.completeSet.actualReps,
            mutation.completeSet.actualWeight,
            completedAt: mutation.completeSet.completedAt.toInt(),
          );
        case WorkoutMutation_Mutation.cancelProposedSet:
          _applyLocalSkipWarmup(mutation.cancelProposedSet.proposedSetId);
        case WorkoutMutation_Mutation.deleteCompletedSet:
          _applyLocalDeleteCompletedSet(
            mutation.deleteCompletedSet.completedSetId,
          );
        case WorkoutMutation_Mutation.replaceExerciseGroupPlan:
          final req = mutation.replaceExerciseGroupPlan;
          _applyLocalReplaceExerciseGroupPlan(
            name: req.name,
            exerciseGroupId: req.exerciseGroupId,
            interleaveWarmups: req.interleaveWarmups,
            sets: req.sets,
            restConfig: req.hasRestConfig() ? req.restConfig : null,
            deleteGroupIfEmpty: req.deleteGroupIfEmpty,
            instruction: req.instruction,
            createIfMissing: req.createIfMissing,
            warmupPlan: req.hasWarmupPlan() ? req.warmupPlan : null,
          );
        case WorkoutMutation_Mutation.reorderExerciseGroups:
          _applyLocalReorderExerciseGroups(
            mutation.reorderExerciseGroups.exerciseGroupIds,
          );
        case WorkoutMutation_Mutation.endWorkout:
        case WorkoutMutation_Mutation.notSet:
          continue;
      }
    }
  }

  Future<void> _persistLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activeWorkout == null) {
      await prefs.remove(_localWorkoutCacheKey);
    } else {
      final snapshot = GetWorkoutResponse(
        workout: _activeWorkout,
        exerciseGroups: _activeExerciseGroups,
        proposedSets: _activeProposedSets,
        completedSets: _activeCompletedSets,
        nextUpSet: _backendNextUpSet,
        stateSnapshot: _stateSnapshot,
      );
      await prefs.setString(
        _localWorkoutCacheKey,
        base64Encode(snapshot.writeToBuffer()),
      );
    }

    if (_pendingMutations.isEmpty) {
      await prefs.remove(_pendingMutationsKey);
    } else {
      await prefs.setStringList(
        _pendingMutationsKey,
        _pendingMutations.map((m) => base64Encode(m.writeToBuffer())).toList(),
      );
    }
  }

  Future<void> _restoreLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final workoutEncoded = prefs.getString(_localWorkoutCacheKey);
    if (workoutEncoded != null && workoutEncoded.isNotEmpty) {
      try {
        final response = GetWorkoutResponse.fromBuffer(
          base64Decode(workoutEncoded),
        );
        if (response.hasWorkout()) {
          _applyWorkoutResponse(response);
        }
      } catch (e) {
        debugPrint('Failed to restore local workout cache: $e');
      }
    }

    final mutationStrings =
        prefs.getStringList(_pendingMutationsKey) ?? const [];
    _pendingMutations.clear();
    for (final encoded in mutationStrings) {
      try {
        _pendingMutations.add(
          WorkoutMutation.fromBuffer(base64Decode(encoded)),
        );
      } catch (e) {
        debugPrint('Failed to restore queued workout mutation: $e');
      }
    }

    if (_activeWorkout != null) {
      if (hasActiveWorkout) {
        _startTimer();
      } else {
        _stopTimer();
      }
      notifyListeners();
      unawaited(_flushPendingMutations());
    }
  }

  void _handleError(Object e) {
    if (isUnauthenticatedError(e)) return;
    if (isAppUpdateRequiredError(e)) {
      ErrorModalService.showError(
        'THIS VERSION OF SCHLIFT IS TOO OLD — PLEASE UPDATE FROM THE STORE.',
      );
      return;
    }
    final message = cleanErrorMessage(e);
    ErrorModalService.showError(message.toUpperCase());
  }

  static bool _isTransientError(Object e) {
    if (e is GrpcError) {
      return e.code == StatusCode.deadlineExceeded ||
          e.code == StatusCode.unavailable;
    }
    return false;
  }

  // Loading state
  bool get isLoading => _isLoading;
  String? get lastLoadError => _lastLoadError;
  bool get lastLoadWasUnauthorized => _lastLoadWasUnauthorized;

  // Active workout getters
  Workout? get workout => _activeWorkout;
  List<ProposedSet> get proposedSets => _activeProposedSets;
  List<CompletedSet> get completedSets => _activeCompletedSets;
  /// The last GetHome response: templates, trackers, volume, recovery,
  /// the suggestion. Null until the first load succeeds.
  GetHomeResponse? get home => _home;
  List<WorkoutTemplate> get templates => _home?.templates ?? const [];
  List<ExerciseTracker> get trackers => _home?.trackers ?? const [];
  List<UserMessage> get scheduleMessages => _scheduleMessages;

  /// The resolved tracker for one exercise. GetHome returns one for every
  /// exercise, so this only misses before the first home load.
  ExerciseTracker? trackerFor(Exercise exercise) {
    for (final tracker in trackers) {
      if (tracker.exercise == exercise) return tracker;
    }
    return null;
  }

  /// Refresh templates/trackers/volume without touching the active session.
  Future<void> refreshHome() async {
    try {
      _home = await _service.getHome();
      _scheduleMessages =
          List<UserMessage>.from(_home?.userMessages ?? const []);
      notifyListeners();
    } catch (e) {
      AppLogger.instance.warn('Workout', 'refreshHome failed', {
        'error': e.toString(),
      });
    }
  }

  Future<void> saveTemplate(WorkoutTemplate template) async {
    await _service.saveTemplate(template);
    await refreshHome();
  }

  Future<void> deleteTemplate(String templateId) async {
    await _service.deleteTemplate(templateId);
    await refreshHome();
  }

  Future<void> reorderTemplates(List<String> templateIds) async {
    await _service.reorderTemplates(templateIds);
    await refreshHome();
  }

  Future<void> setExerciseTracker({
    required Exercise exercise,
    required double workingWeightLb,
    int overrideSets = 0,
    int overrideRepLow = 0,
    int overrideRepHigh = 0,
  }) async {
    await _service.setExerciseTracker(
      exercise: exercise,
      workingWeight: workingWeightLb,
      overrideSets: overrideSets,
      overrideRepLow: overrideRepLow,
      overrideRepHigh: overrideRepHigh,
    );
    await refreshHome();
  }

  List<UserMessage> get workoutMessages => _workoutMessages;

  Workout? get activeWorkout => _activeWorkout;
  List<ProposedSet> get activeProposedSets => _activeProposedSets;
  List<CompletedSet> get activeCompletedSets => _activeCompletedSets;
  WorkoutStateSnapshot? get stateSnapshot => _stateSnapshot;
  bool get hasActiveWorkout =>
      _activeWorkout != null && _activeWorkout!.endTime == Int64.ZERO;
  bool get isWorkoutEnded =>
      _activeWorkout != null && _activeWorkout!.endTime != Int64.ZERO;
  DateTime get now => _now;
  ValueNotifier<DateTime> get clock => _clock;
  List<HeartRateSample> get wearHeartRateSamples => _wearHeartRateSamplesView;

  List<ExerciseGroupData> get exerciseGroups => _exerciseGroupsCache;

  String _nextSetBody() {
    final next = nextPendingSet;
    if (next == null) return 'All sets complete!';
    final name = exerciseNames[next.exercise] ?? '?';
    final prefix = next.warmup ? 'Warmup ' : '';
    final w = next.targetWeight.toDouble();
    final weightStr = formatWeight(w, _settingsProvider.weightUnit);
    return 'Next up: $prefix$name — $weightStr ${weightUnitSuffix(_settingsProvider.weightUnit)} × ${next.targetReps}';
  }

  bool isSetDone(String setId) {
    return _activeCompletedSets.any(
      (c) => c.proposedSetId == setId && c.endedAt != Int64.ZERO,
    );
  }

  bool isSetActive(String setId) {
    return _activeCompletedSets.any(
      (c) => c.proposedSetId == setId && c.endedAt == Int64.ZERO,
    );
  }

  String? get activeSetId {
    final snapshot = _stateSnapshot;
    if (snapshot == null) return null;
    if (snapshot.state != WorkoutState.WORKOUT_STATE_LIFTING) return null;
    if (!snapshot.hasDisplaySet()) return null;
    return snapshot.displaySet.id;
  }

  ProposedSet? get nextPendingSet {
    return _backendNextUpSet;
  }

  /// Returns true if warmup can be skipped for the given proposed set.
  bool canSkipWarmup(String proposedSetId) {
    final proposed = _activeProposedSets.cast<ProposedSet?>().firstWhere(
      (p) => p!.id == proposedSetId,
      orElse: () => null,
    );
    if (proposed == null || !proposed.warmup) return false;
    return true;
  }

  int get restSecondsRemaining {
    final snapshot = _stateSnapshot;
    if (snapshot == null) return 0;
    if (snapshot.state != WorkoutState.WORKOUT_STATE_RESTING) return 0;
    final remaining =
        snapshot.restUntil.toInt() - (_now.millisecondsSinceEpoch ~/ 1000);
    return remaining > 0 ? remaining : 0;
  }

  int? get lastRestEndTimestamp {
    final snapshot = _stateSnapshot;
    if (snapshot == null || snapshot.lastRestEnd == Int64.ZERO) return null;
    return snapshot.lastRestEnd.toInt();
  }

  void _applyStateSnapshot(WorkoutStateSnapshot? snapshot) {
    final oldRestUntil = _stateSnapshot?.restUntil.toInt();
    final oldState = _stateSnapshot?.state;

    _stateSnapshot = snapshot;

    if (snapshot == null) {
      if (oldState == WorkoutState.WORKOUT_STATE_RESTING) {
        unawaited(NotificationService.cancelRest());
      }
      return;
    }

    final isResting = snapshot.state == WorkoutState.WORKOUT_STATE_RESTING;
    final restUntil = snapshot.restUntil.toInt();

    if (isResting) {
      if (restUntil > 0) {
        _wasResting = true;
        if (restUntil != oldRestUntil ||
            oldState != WorkoutState.WORKOUT_STATE_RESTING) {
          final presetId = _soundProvider?.currentPreset ?? 'chord_strum';
          unawaited(
            NotificationService.scheduleRest(
              restUntilUnix: restUntil,
              soundPresetId: presetId,
              body: _nextSetBody(),
            ),
          );
        }
      }
    } else {
      if (oldState == WorkoutState.WORKOUT_STATE_RESTING) {
        unawaited(NotificationService.cancelRest());
        _wasResting = false;
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    var tick = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _setNow(DateTime.now());
      unawaited(_checkRestSound());
      unawaited(_flushPendingWearHeartRateUploads());
      // Every few seconds, reconcile our local active workout against the
      // backend so a workout ended elsewhere (the watch, another device, or the
      // server) doesn't leave us showing a stale in-progress workout.
      if (++tick % 5 == 0) unawaited(_reconcileActiveWorkout());
    });
  }

  bool _reconciling = false;

  /// If the workout we're displaying no longer matches the backend's active
  /// workout (ended or replaced by another client), pull fresh state. Skips
  /// while local mutations are in flight so it can't clobber optimistic edits.
  Future<void> _reconcileActiveWorkout() async {
    if (!hasActiveWorkout || _reconciling || _isLoading) return;
    if (_pendingMutations.isNotEmpty) return;
    final userId = _lastLoadUserId;
    if (userId == null) return;
    _reconciling = true;
    try {
      final active = await _service.getActiveWorkout();
      if (active?.id != _activeWorkout?.id) {
        // Ended or swapped out from under us — reload (clears to home if gone).
        await loadActiveWorkout(userId);
      }
    } catch (_) {
      // Transient; try again on the next reconcile tick.
    } finally {
      _reconciling = false;
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _resetWearHeartRateBuffer() {
    _wearHeartRateSamples.clear();
    _wearHeartRateBatchIds.clear();
    _wearHeartRateSampleTimestamps.clear();
    _pendingWearHeartRateUploads.clear();
    _lastWearHeartRateUploadAt = null;
    _wearHeartRateUploadInFlight = false;
  }

  void _resetWearHeartRateBufferIfWorkoutChanged(String? nextWorkoutId) {
    final currentId = _activeWorkout?.id;
    if (currentId != nextWorkoutId) {
      _resetWearHeartRateBuffer();
    }
  }

  Future<void> _hydrateWearHeartRateFromApi() async {
    final workout = _activeWorkout;
    if (workout == null) return;
    if (workout.id.isEmpty) return;

    try {
      final persisted = await _service.getWorkoutHeartRate(workout.id);
      if (persisted.isEmpty) return;
      _mergePersistedHeartRatePoints(persisted);
    } catch (e) {
      debugPrint('Heart rate hydrate failed: $e');
    }
  }

  void _mergePersistedHeartRatePoints(List<WorkoutHeartRatePoint> persisted) {
    var insertedAny = false;
    var needsSort = false;
    final lastTimestampBeforeMerge = _wearHeartRateSamples.isNotEmpty
        ? _wearHeartRateSamples.last.sampledAt.toInt()
        : null;

    for (final point in persisted) {
      final ts = point.sampledAt.toInt();
      if (!_wearHeartRateSampleTimestamps.add(ts)) continue;
      if (lastTimestampBeforeMerge != null && ts < lastTimestampBeforeMerge) {
        needsSort = true;
      }
      _wearHeartRateSamples.add(
        HeartRateSample()
          ..sampledAt = point.sampledAt
          ..bpm = point.bpm
          ..availability =
              HeartRateAvailability.valueOf(point.availability) ??
              HeartRateAvailability.HEART_RATE_AVAILABILITY_UNSPECIFIED,
      );
      insertedAny = true;
    }

    if (!insertedAny) return;

    if (needsSort) {
      _wearHeartRateSamples.sort((a, b) => a.sampledAt.compareTo(b.sampledAt));
    }

    if (_wearHeartRateSamples.length > _maxWearHeartRateSamplesInMemory) {
      final removeCount =
          _wearHeartRateSamples.length - _maxWearHeartRateSamplesInMemory;
      final removed = _wearHeartRateSamples.take(removeCount).toList();
      _wearHeartRateSamples.removeRange(0, removeCount);
      for (final s in removed) {
        _wearHeartRateSampleTimestamps.remove(s.sampledAt.toInt());
      }
    }

    notifyListeners();
  }

  bool _loadWorkoutRetryScheduled = false;
  String? _lastLoadUserId;

  Future<void> loadActiveWorkout(String userId) async {
    _lastLoadUserId = userId;
    await _restoreLocalCacheFuture;
    _isLoading = true;
    _lastLoadError = null;
    _lastLoadWasUnauthorized = false;
    notifyListeners();
    AppLogger.instance.info('Workout', 'loadActiveWorkout', {'userId': userId});
    try {
      final active = await _service.getActiveWorkout();
      if (active != null) {
        final response = await _service.getWorkout(active.id);
        _applyWorkoutResponse(response);
        _overlayPendingMutationsOnActiveWorkout();
        await _hydrateWearHeartRateFromApi();
        _startTimer();
      } else {
        _resetWearHeartRateBufferIfWorkoutChanged(null);
        _activeWorkout = null;
        _activeExerciseGroups = [];
        _activeProposedSets = [];
        _activeCompletedSets = [];
        _workoutMessages = [];
        _backendNextUpSet = null;
        _applyStateSnapshot(null);
        _stopTimer();
      }

      _home = await _service.getHome();
      _scheduleMessages = List<UserMessage>.from(_home?.userMessages ?? const []);
      _loadWorkoutRetryScheduled = false;
      await _persistLocalCache();
    } catch (e) {
      _lastLoadWasUnauthorized = isUnauthenticatedError(e);
      _lastLoadError = cleanErrorMessage(e);
      // Don't show a modal for transient network errors (timeout, unavailable).
      // The error is still stored in _lastLoadError so the UI can show an
      // inline retry prompt instead of a blocking dialog.
      if (!_isTransientError(e)) {
        _handleError(e);
      } else {
        AppLogger.instance.warn(
          'Workout',
          'loadActiveWorkout transient error, will retry',
          {'error': _lastLoadError ?? e.toString()},
        );
        _scheduleLoadWorkoutRetry();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _scheduleLoadWorkoutRetry() {
    if (_loadWorkoutRetryScheduled) return;
    _loadWorkoutRetryScheduled = true;
    Timer(const Duration(seconds: 5), () {
      _loadWorkoutRetryScheduled = false;
      final userId = _lastLoadUserId;
      if (userId != null) {
        loadActiveWorkout(userId);
      }
    });
  }

  Future<void> loadWorkoutFromServer(String workoutId) async {
    await _restoreLocalCacheFuture;
    try {
      final response = await _service.getWorkout(workoutId);
      _applyWorkoutResponse(response);
      _overlayPendingMutationsOnActiveWorkout();
      await _hydrateWearHeartRateFromApi();
      if (hasActiveWorkout) {
        _startTimer();
      } else {
        _stopTimer();
      }
      await _persistLocalCache();
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  void _applyStartWorkoutResponse(StartWorkoutResponse response) {
    _resetWearHeartRateBufferIfWorkoutChanged(
      response.hasWorkout() ? response.workout.id : null,
    );
    _activeWorkout = response.hasWorkout() ? response.workout : null;
    _activeExerciseGroups = List.from(response.exerciseGroups);
    _activeProposedSets = List.from(response.proposedSets);
    _activeCompletedSets = List.from(response.completedSets);
    _refreshDerivedState();
    if (hasActiveWorkout) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  Future<String?> startWorkout(
    String name,
    List<ExerciseGroup> groups, {
    String templateId = '',
  }) async {
    try {
      await NotificationService.cancelAll();
      _wasResting = false;
      final response =
          await _service.startWorkout(name, groups, templateId: templateId);
      _applyStartWorkoutResponse(response);
      _workoutMessages = List<UserMessage>.from(response.userMessages);
      await _persistLocalCache();
      notifyListeners();
      if (response.id.isNotEmpty) return response.id;
      return response.hasWorkout() ? response.workout.id : null;
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  void _queueMutation(WorkoutMutation mutation, {bool immediate = false}) {
    _pendingMutations.add(mutation);
    unawaited(_persistLocalCache());
    // Set actions flush immediately so the server-computed rest timer / state
    // lands promptly; edits stay debounced so a drag-reorder batches.
    _scheduleMutationFlush(immediate ? Duration.zero : _mutationFlushDebounce);
  }

  void _scheduleMutationFlush(Duration delay) {
    _mutationFlushTimer?.cancel();
    _mutationFlushTimer = Timer(delay, () {
      unawaited(_flushPendingMutations());
    });
  }

  Future<void> _flushPendingMutations() async {
    if (_mutationFlushInFlight) return;
    if (_pendingMutations.isEmpty) return;
    if (_activeWorkout == null) return;

    _mutationFlushInFlight = true;
    final batch = List<WorkoutMutation>.from(_pendingMutations);
    var progressMade = false;
    try {
      final response = await _service.appendWorkoutMutations(batch);
      if (response.hasWorkoutState()) {
        _applyWorkoutResponse(response.workoutState);
      }
      if (response.appliedEventIds.isNotEmpty) {
        final applied = response.appliedEventIds.toSet();
        final before = _pendingMutations.length;
        _pendingMutations.removeWhere((m) => applied.contains(m.eventId));
        progressMade = _pendingMutations.length < before;
      }
      if (progressMade || _pendingMutations.isEmpty) {
        _mutationFlushRetryCount = 0;
      }
      await _persistLocalCache();
      notifyListeners();
      onSessionRefreshNeeded?.call();
    } catch (e) {
      debugPrint('Workout mutation flush failed: $e');
    } finally {
      _mutationFlushInFlight = false;
      if (_pendingMutations.isNotEmpty) {
        if (progressMade) {
          _scheduleMutationFlush(Duration.zero);
        } else {
          _mutationFlushRetryCount++;
          final multiplier = 1 << (_mutationFlushRetryCount - 1).clamp(0, 3);
          final retryMs = _mutationRetryBaseDelay.inMilliseconds * multiplier;
          final cappedMs = retryMs > _mutationRetryMaxDelay.inMilliseconds
              ? _mutationRetryMaxDelay.inMilliseconds
              : retryMs;
          _scheduleMutationFlush(Duration(milliseconds: cappedMs));
        }
      }
    }
  }

  WorkoutMutation _buildMutation({
    required String workoutId,
    required int createdAt,
    StartSetRequest? startSet,
    CompleteSetRequest? completeSet,
    CancelProposedSetRequest? cancelProposedSet,
    DeleteCompletedSetRequest? deleteCompletedSet,
    ReplaceExerciseGroupPlanRequest? replaceExerciseGroupPlan,
    ReorderExerciseGroupsRequest? reorderExerciseGroups,
  }) {
    final mutation = WorkoutMutation()
      ..eventId = _uuid.v4()
      ..clientCreatedAt = Int64(createdAt);
    if (startSet != null) {
      mutation.startSet = startSet;
    } else if (completeSet != null) {
      mutation.completeSet = completeSet;
    } else if (cancelProposedSet != null) {
      mutation.cancelProposedSet = cancelProposedSet;
    } else if (deleteCompletedSet != null) {
      mutation.deleteCompletedSet = deleteCompletedSet;
    } else if (replaceExerciseGroupPlan != null) {
      mutation.replaceExerciseGroupPlan = replaceExerciseGroupPlan;
    } else if (reorderExerciseGroups != null) {
      mutation.reorderExerciseGroups = reorderExerciseGroups;
    }
    return mutation;
  }





  int get _nowSecs => _now.millisecondsSinceEpoch ~/ 1000;

  // Tiny optimistic set edits: mutate the local lists so the tap registers
  // instantly, then _refreshDerivedState advances the highlight. Rest timing and
  // the authoritative state come from the server response — no rest maths here.
  void _applyLocalStartSet(String proposedSetId, {int? startedAt}) {
    if (_activeWorkout == null) return;
    final alreadyActive = _activeCompletedSets.any(
      (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
    );
    if (alreadyActive) return;
    final proposed = _activeProposedSets.cast<ProposedSet?>().firstWhere(
      (p) => p?.id == proposedSetId && !(p?.cancelled ?? true),
      orElse: () => null,
    );
    if (proposed == null) return;
    _activeCompletedSets.add(
      CompletedSet()
        ..id = _uuid.v4()
        ..workoutId = _activeWorkout!.id
        ..proposedSetId = proposedSetId
        ..actualReps = proposed.targetReps
        ..actualWeight = proposed.targetWeight
        ..startedAt = Int64(startedAt ?? _nowSecs)
        ..endedAt = Int64.ZERO
        ..restUntil = Int64.ZERO,
    );
    _refreshDerivedState();
  }

  void _applyLocalCompleteSet(
    String proposedSetId,
    int actualReps,
    double actualWeight, {
    int? completedAt,
  }) {
    if (_activeWorkout == null) return;
    final endedAt = Int64(completedAt ?? _nowSecs);
    final idx = _activeCompletedSets.indexWhere(
      (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
    );
    final restUntil = _localRestUntil(proposedSetId, actualReps, endedAt);
    if (idx != -1) {
      _activeCompletedSets[idx]
        ..actualReps = actualReps
        ..actualWeight = actualWeight
        ..endedAt = endedAt
        ..restUntil = restUntil;
    } else {
      _activeCompletedSets.add(
        CompletedSet()
          ..id = _uuid.v4()
          ..workoutId = _activeWorkout!.id
          ..proposedSetId = proposedSetId
          ..actualReps = actualReps
          ..actualWeight = actualWeight
          ..startedAt = endedAt
          ..endedAt = endedAt
          ..restUntil = restUntil,
      );
    }
    _refreshDerivedState();
  }

  /// The rest-timer target for a just-completed set, computed locally so the
  /// countdown starts on the transition and survives signal loss — it's a
  /// stored target time (endedAt + rest), not a per-request server value. Mirrors
  /// `complete_set` in `src/workout/reducer.rs`: the rest *durations* are
  /// server-provided on the proposed set (`restAfterSuccess`/`restAfterFailure`);
  /// the last set in a group uses the end-of-group rest. The server reconciles
  /// with an identical target when the mutation lands.
  static const int _endOfExerciseGroupRestSeconds = 60; // END_OF_EXERCISE_GROUP_REST_SECONDS

  Int64 _localRestUntil(String proposedSetId, int actualReps, Int64 endedAt) {
    final proposed = _activeProposedSets
        .cast<ProposedSet?>()
        .firstWhere((p) => p?.id == proposedSetId && !p!.cancelled,
            orElse: () => null);
    if (proposed == null) return Int64.ZERO;
    var restSeconds = actualReps >= proposed.targetReps
        ? proposed.restAfterSuccess
        : proposed.restAfterFailure;
    if (_isFinalSetInGroupAfterCompletion(proposed)) {
      restSeconds = _endOfExerciseGroupRestSeconds;
    }
    return endedAt + Int64(restSeconds);
  }

  /// True when every other live set in this set's group is already completed —
  /// so finishing this one ends the group. Mirrors
  /// `is_final_set_in_exercise_group_after_completion` in the Rust reducer.
  bool _isFinalSetInGroupAfterCompletion(ProposedSet current) {
    final groupId = current.exerciseGroupId;
    for (final set in _activeProposedSets) {
      if (set.exerciseGroupId != groupId || set.cancelled || set.id == current.id) {
        continue;
      }
      final done = _activeCompletedSets.any(
        (c) => c.proposedSetId == set.id && c.endedAt != Int64.ZERO,
      );
      if (!done) return false;
    }
    return true;
  }

  void _applyLocalDeleteCompletedSet(String completedSetId) {
    _activeCompletedSets.removeWhere((c) => c.id == completedSetId);
    _refreshDerivedState();
  }

  void _applyLocalSkipWarmup(String proposedSetId) {
    final idx = _activeProposedSets.indexWhere((s) => s.id == proposedSetId);
    if (idx == -1 || !_activeProposedSets[idx].warmup) return;
    _activeProposedSets[idx].cancelled = true;
    _refreshDerivedState();
  }

  Future<void> reorderExerciseGroups(List<String> groupIds) async {
    if (_activeWorkout == null) return;
    final createdAt = _now.millisecondsSinceEpoch ~/ 1000;

    // Optimistically update local state
    _applyLocalReorderExerciseGroups(groupIds);
    notifyListeners();

    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        reorderExerciseGroups: ReorderExerciseGroupsRequest()
          ..workoutId = _activeWorkout!.id
          ..exerciseGroupIds.addAll(groupIds),
      ),
    );
    unawaited(_persistLocalCache());
    onSessionRefreshNeeded?.call();
  }

  Future<void> startSet(String proposedSetId) async {
    if (_activeWorkout == null) return;
    final startedAt = _now.millisecondsSinceEpoch ~/ 1000;
    _applyLocalStartSet(proposedSetId, startedAt: startedAt);
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: startedAt,
        startSet: StartSetRequest()
          ..workoutId = _activeWorkout!.id
          ..proposedSetId = proposedSetId
          ..startedAt = Int64(startedAt),
      ),
      immediate: true,
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  Future<void> completeSet(
    String proposedSetId,
    int actualReps,
    double actualWeight, {
    int? completedAt,
  }) async {
    if (_activeWorkout == null) return;
    final endedAt = completedAt ?? (_now.millisecondsSinceEpoch ~/ 1000);
    _applyLocalCompleteSet(
      proposedSetId,
      actualReps,
      actualWeight,
      completedAt: endedAt,
    );
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: endedAt,
        completeSet: CompleteSetRequest()
          ..workoutId = _activeWorkout!.id
          ..proposedSetId = proposedSetId
          ..actualReps = actualReps
          ..actualWeight = actualWeight
          ..completedAt = Int64(endedAt),
      ),
      immediate: true,
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  Future<void> deleteCompletedSet(String completedSetId) async {
    if (_activeWorkout == null) return;
    final createdAt = _now.millisecondsSinceEpoch ~/ 1000;
    _applyLocalDeleteCompletedSet(completedSetId);
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        deleteCompletedSet: DeleteCompletedSetRequest()
          ..workoutId = _activeWorkout!.id
          ..completedSetId = completedSetId,
      ),
      immediate: true,
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  Future<void> skipWarmup(String proposedSetId) async {
    if (_activeWorkout == null) return;
    final proposed = _activeProposedSets.cast<ProposedSet?>().firstWhere(
      (p) => p!.id == proposedSetId,
      orElse: () => null,
    );
    if (proposed == null) return;
    if (!proposed.warmup) return;
    final createdAt = _now.millisecondsSinceEpoch ~/ 1000;
    _applyLocalSkipWarmup(proposedSetId);
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        cancelProposedSet: CancelProposedSetRequest()
          ..workoutId = _activeWorkout!.id
          ..proposedSetId = proposedSetId,
      ),
      immediate: true,
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  Future<void> addExerciseGroup({
    required String name,
    required int sets,
    required bool interleaveWarmups,
    required List<ExerciseTypeConfig> exerciseConfigs,
    RestConfig? restConfig,
  }) async {
    if (_activeWorkout == null) return;
    try {
      final plannedSets = buildPlannedGroupSetsFromConfigs(
        sets: sets,
        interleaveWarmups: interleaveWarmups,
        exerciseConfigs: exerciseConfigs,
        unit: _settingsProvider.weightUnit,
        restConfig: restConfig,
      );
      await _replaceExerciseGroupPlan(
        name: name,
        exerciseGroupId: null,
        interleaveWarmups: interleaveWarmups,
        sets: plannedSets,
        restConfig: restConfig,
        createIfMissing: true,
        warmupPlan: warmupPlanFromConfigs(exerciseConfigs),
      );
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> updateGroup(
    int groupIndex, {
    required int sets,
    required bool interleaveWarmups,
    required List<ExerciseTypeConfig> exerciseConfigs,
    RestConfig? restConfig,
  }) async {
    final groups = exerciseGroups;
    if (groupIndex < 0 || groupIndex >= groups.length) return;
    final groupData = groups[groupIndex];
    if (groupData.group == null) return;

    try {
      final plannedSets = buildPlannedGroupSetsFromConfigs(
        sets: sets,
        interleaveWarmups: interleaveWarmups,
        exerciseConfigs: exerciseConfigs,
        unit: _settingsProvider.weightUnit,
        restConfig: restConfig,
      );
      await _replaceExerciseGroupPlan(
        name: groupData.group!.name,
        exerciseGroupId: groupData.group!.id,
        interleaveWarmups: interleaveWarmups,
        sets: plannedSets,
        restConfig: restConfig,
        instruction: groupData.group!.instruction,
        warmupPlan: warmupPlanFromConfigs(exerciseConfigs),
      );
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> deleteExerciseGroup(int groupIndex) async {
    final groups = exerciseGroups;
    if (groupIndex < 0 || groupIndex >= groups.length) return;
    final groupData = groups[groupIndex];

    if (_activeWorkout == null) return;

    if (groupData.group == null) {
      return;
    }

    try {
      await _replaceExerciseGroupPlan(
        name: groupData.group!.name,
        exerciseGroupId: groupData.group!.id,
        interleaveWarmups: groupData.group!.interleaveWarmups,
        sets: const [],
        deleteGroupIfEmpty: true,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  /// Ends the workout on the server and returns immediately.
  /// Health write happens in the background — check [lastHealthResult] after.
  ///
  /// [fireEndedCallback] controls whether [onWorkoutEnded] is called after
  /// completion. Pass false when the caller (e.g. the phone UI) will handle
  /// navigation itself.
  Future<void> endWorkout({bool fireEndedCallback = true}) async {
    if (_activeWorkout == null) return;
    try {
      await _flushPendingWearHeartRateUploads(force: true);
      await NotificationService.cancelAll();
      _wasResting = false;
      final response = await _service.endWorkout(_activeWorkout!.id);
      final ended = response.workout;
      _activeWorkout = ended;
      _workoutMessages = List<UserMessage>.from(response.userMessages);
      _pendingMutations.clear();
      _stopTimer();
      await _persistLocalCache();
      notifyListeners();

      // Fire-and-forget: never blocks workout completion
      _writeToHealthPlatform(ended);

      if (fireEndedCallback) {
        onWorkoutEnded?.call(ended.id);
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> dismissUserMessages(List<String> messageKeys) async {
    if (messageKeys.isEmpty) return;
    try {
      final dismissed = await _service.dismissUserMessages(messageKeys);
      if (dismissed.isEmpty) return;
      final dismissedSet = dismissed.toSet();
      _scheduleMessages.removeWhere((m) => dismissedSet.contains(m.messageKey));
      _workoutMessages.removeWhere((m) => dismissedSet.contains(m.messageKey));
      await _persistLocalCache();
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  void _writeToHealthPlatform(Workout workout) async {
    try {
      final startTime = DateTime.fromMillisecondsSinceEpoch(
        workout.startTime.toInt() * 1000,
      );
      final endTime = DateTime.fromMillisecondsSinceEpoch(
        workout.endTime.toInt() * 1000,
      );

      // Build title from unique exercise names in order
      final seen = <int>{};
      final names = <String>[];
      for (final set in _activeProposedSets) {
        if (!set.warmup && seen.add(set.exercise.value)) {
          names.add(shortNames[set.exercise] ?? set.exercise.name);
        }
      }
      final title = names.join(', ');

      // Calculate total volume and working set count from completed sets
      var totalVolumeKg = 0.0;
      var workingSets = 0;
      for (final cs in _activeCompletedSets) {
        if (cs.endedAt == Int64.ZERO) continue;
        final proposed = _activeProposedSets.cast<ProposedSet?>().firstWhere(
          (p) => p!.id == cs.proposedSetId,
          orElse: () => null,
        );
        if (proposed != null && !proposed.warmup) {
          totalVolumeKg += cs.actualWeight * cs.actualReps;
          workingSets++;
        }
      }

      final result = await HealthService.writeCompletedWorkout(
        startTime: startTime,
        endTime: endTime,
        title: title,
        totalVolumeKg: totalVolumeKg,
        workingSets: workingSets,
        bodyWeightKg: _bodyWeightKg,
      );

      if (result == HealthWriteResult.success) {
        final storeName = Platform.isAndroid
            ? 'Health Connect'
            : 'Apple Health';
        Fluttertoast.showToast(
          msg: 'Successfully uploaded to $storeName',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else if (result == HealthWriteResult.permissionDenied) {
        Fluttertoast.showToast(
          msg: 'Health Connect permission denied — enable in settings',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      }
    } catch (e, st) {
      debugPrint('Health: write failed: $e\n$st');
      Fluttertoast.showToast(
        msg: 'Failed to sync workout to Health Connect',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> clear() async {
    await NotificationService.cancelAll();
    _wasResting = false;
    _activeWorkout = null;
    _activeProposedSets = [];
    _activeCompletedSets = [];
    _backendNextUpSet = null;
    _applyStateSnapshot(null);
    _resetWearHeartRateBuffer();
    _pendingMutations.clear();
    _stopTimer();
    await _persistLocalCache();
    notifyListeners();
  }

  void ingestWearHeartRateBatch(WearSensorBatch batch) {
    if (_activeWorkout == null) return;
    if (batch.workoutId != _activeWorkout!.id) return;
    if (batch.batchId.isEmpty) return;
    if (!_wearHeartRateBatchIds.add(batch.batchId)) return;

    var insertedAny = false;
    var needsSort = false;
    final newSamples = <HeartRateSample>[];
    final lastTimestampBeforeIngest = _wearHeartRateSamples.isNotEmpty
        ? _wearHeartRateSamples.last.sampledAt.toInt()
        : null;

    for (final sample in batch.heartRateSamples) {
      final ts = sample.sampledAt.toInt();
      if (!_wearHeartRateSampleTimestamps.add(ts)) {
        continue;
      }
      if (lastTimestampBeforeIngest != null && ts < lastTimestampBeforeIngest) {
        needsSort = true;
      }
      _wearHeartRateSamples.add(sample);
      newSamples.add(sample);
      insertedAny = true;
    }

    if (needsSort) {
      _wearHeartRateSamples.sort((a, b) => a.sampledAt.compareTo(b.sampledAt));
    }

    // Keep a large in-memory buffer so the whole workout graph stays visible.
    if (_wearHeartRateSamples.length > _maxWearHeartRateSamplesInMemory) {
      final removeCount =
          _wearHeartRateSamples.length - _maxWearHeartRateSamplesInMemory;
      final removed = _wearHeartRateSamples.take(removeCount).toList();
      _wearHeartRateSamples.removeRange(0, removeCount);
      for (final s in removed) {
        _wearHeartRateSampleTimestamps.remove(s.sampledAt.toInt());
      }
    }
    for (final sample in newSamples) {
      _pendingWearHeartRateUploads.add(
        WorkoutHeartRatePoint()
          ..sampledAt = sample.sampledAt
          ..bpm = sample.bpm
          ..availability = sample.availability.value,
      );
    }
    if (insertedAny) {
      notifyListeners();
    }
    unawaited(_flushPendingWearHeartRateUploads());
  }

  Future<void> _flushPendingWearHeartRateUploads({bool force = false}) async {
    if (_wearHeartRateUploadInFlight) return;
    final workout = _activeWorkout;
    if (workout == null || workout.endTime != Int64.ZERO) return;
    if (_pendingWearHeartRateUploads.isEmpty) return;

    final now = DateTime.now();
    if (!force &&
        _lastWearHeartRateUploadAt != null &&
        now.difference(_lastWearHeartRateUploadAt!) <
            const Duration(seconds: 5)) {
      return;
    }

    _wearHeartRateUploadInFlight = true;
    _lastWearHeartRateUploadAt = now;
    final batch = List<WorkoutHeartRatePoint>.from(
      _pendingWearHeartRateUploads,
    );
    _pendingWearHeartRateUploads.clear();

    try {
      await _service.appendWorkoutHeartRate(workout.id, batch);
      unawaited(
        HealthService.writeHeartRateSamples(
          workoutId: workout.id,
          samples: batch,
        ),
      );
    } catch (e) {
      _pendingWearHeartRateUploads.insertAll(0, batch);
      debugPrint('Heart rate upload failed: $e');
    } finally {
      _wearHeartRateUploadInFlight = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _mutationFlushTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }
}
