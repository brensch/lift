import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/weight_units.dart';
import '../logic/warmup.dart';
import '../providers/settings_provider.dart';
import '../services/workout_service.dart';
import '../providers/sound_provider.dart';
import '../services/notification_service.dart';
import '../services/health_service.dart' show HealthService, HealthWriteResult;
import '../services/error_modal_service.dart';
import '../logic/exercises.dart';
import '../logic/utils.dart';

class WorkoutProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const int _maxWearHeartRateSamplesInMemory = 50000;

  final WorkoutServiceWrapper _service;
  final SettingsProvider _settingsProvider;
  SoundProvider? _soundProvider;

  /// Called after each set mutation so the multiplayer session view can
  /// refresh immediately instead of waiting for the next background tick.
  VoidCallback? onSessionRefreshNeeded;

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
  List<ExerciseStatus> _exerciseStatuses = [];
  List<ProposedExerciseGroup> _proposedGroups = [];
  RegimeContext? _regimeContext;
  final List<HeartRateSample> _wearHeartRateSamples = [];
  final Set<int> _wearHeartRateSampleTimestamps = <int>{};
  final List<WorkoutHeartRatePoint> _pendingWearHeartRateUploads = [];
  DateTime? _lastWearHeartRateUploadAt;
  bool _wearHeartRateUploadInFlight = false;

  bool _wasResting = false;

  Timer? _timer;
  DateTime _now = DateTime.now();

  WorkoutProvider(this._service, this._settingsProvider) {
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onStartNextSet = _onStartNextSet;
  }

  void _onStartNextSet() {
    final next = nextPendingSet;
    if (next != null) {
      startSet(next.id);
    }
  }

  int _effectiveRestSuccess({
    required ExerciseTypeConfig config,
    RestConfig? groupRest,
    required bool warmup,
    required bool lastWarmup,
  }) {
    final rc = config.hasRestConfig()
        ? config.restConfig
        : (groupRest != null && groupRestHasValues(groupRest)
              ? groupRest
              : null);
    final success = (rc != null && rc.restAfterSuccess > 0)
        ? rc.restAfterSuccess
        : 180;
    if (!warmup) return success;
    if (lastWarmup) return success;
    return (rc != null && rc.restAfterWarmup > 0) ? rc.restAfterWarmup : 10;
  }

  int _effectiveRestFailure({
    required ExerciseTypeConfig config,
    RestConfig? groupRest,
    required bool warmup,
    required bool lastWarmup,
  }) {
    final rc = config.hasRestConfig()
        ? config.restConfig
        : (groupRest != null && groupRestHasValues(groupRest)
              ? groupRest
              : null);
    final failure = (rc != null && rc.restAfterFailure > 0)
        ? rc.restAfterFailure
        : 300;
    if (!warmup) return failure;
    if (lastWarmup) {
      final success = (rc != null && rc.restAfterSuccess > 0)
          ? rc.restAfterSuccess
          : 180;
      return success;
    }
    final warm = (rc != null && rc.restAfterWarmup > 0)
        ? rc.restAfterWarmup
        : 10;
    return warm;
  }

  List<WorkingSetSpec> _materializeWorkingSetsForConfig(
    ExerciseTypeConfig config,
    int groupSets,
  ) {
    if (config.workingSets.isNotEmpty) return config.workingSets.toList();
    final count = groupSets <= 0 ? 1 : groupSets;
    final out = <WorkingSetSpec>[];
    for (var i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final weight = count <= 1
          ? config.startWeight
          : config.startWeight +
                (i / (count - 1)) * (config.endWeight - config.startWeight);
      final rounded = (weight / 5.0).round() * 5.0;
      out.add(
        WorkingSetSpec()
          ..targetWeight = rounded.toDouble()
          ..targetReps = config.reps
          ..isAmrap = config.lastSetAmrap && isLast
          ..instruction = config.lastSetAmrap && isLast
              ? 'AMRAP - push for max reps'
              : '',
      );
    }
    return out;
  }

  List<PlannedGroupSet> _buildPlannedGroupSetsFromConfigs({
    required int sets,
    required bool interleaveWarmups,
    required List<ExerciseTypeConfig> exerciseConfigs,
    RestConfig? restConfig,
  }) {
    if (exerciseConfigs.isEmpty) return const [];

    final workingByConfig = exerciseConfigs
        .map((c) => _materializeWorkingSetsForConfig(c, sets))
        .toList();
    final warmupByConfig = <List<WarmupDef>>[];
    for (var i = 0; i < exerciseConfigs.length; i++) {
      final c = exerciseConfigs[i];
      if (!c.includeWarmup) {
        warmupByConfig.add(const []);
        continue;
      }
      final warmupWeight = workingByConfig[i].isNotEmpty
          ? workingByConfig[i].first.targetWeight
          : c.startWeight;
      warmupByConfig.add(generateWarmupDefs(warmupWeight));
    }

    final out = <PlannedGroupSet>[];

    void addWarmupSet(int cfgIdx, int warmIdx) {
      final c = exerciseConfigs[cfgIdx];
      final warm = warmupByConfig[cfgIdx][warmIdx];
      final isLastWarmup = warmIdx == warmupByConfig[cfgIdx].length - 1;
      out.add(
        PlannedGroupSet()
          ..exercise = c.exercise
          ..targetReps = warm.reps
          ..targetWeight = warm.weight
          ..warmup = true
          ..restAfterSuccess = _effectiveRestSuccess(
            config: c,
            groupRest: restConfig,
            warmup: true,
            lastWarmup: isLastWarmup,
          )
          ..restAfterFailure = _effectiveRestFailure(
            config: c,
            groupRest: restConfig,
            warmup: true,
            lastWarmup: isLastWarmup,
          ),
      );
    }

    if (interleaveWarmups && exerciseConfigs.length > 1) {
      final maxWarmups = warmupByConfig.fold<int>(
        0,
        (m, w) => w.length > m ? w.length : m,
      );
      for (var round = 0; round < maxWarmups; round++) {
        for (var cfgIdx = 0; cfgIdx < exerciseConfigs.length; cfgIdx++) {
          if (round < warmupByConfig[cfgIdx].length) {
            addWarmupSet(cfgIdx, round);
          }
        }
      }
    } else {
      for (var cfgIdx = 0; cfgIdx < exerciseConfigs.length; cfgIdx++) {
        for (
          var warmIdx = 0;
          warmIdx < warmupByConfig[cfgIdx].length;
          warmIdx++
        ) {
          addWarmupSet(cfgIdx, warmIdx);
        }
      }
    }

    final maxWorking = workingByConfig.fold<int>(
      0,
      (m, w) => w.length > m ? w.length : m,
    );
    for (var round = 0; round < maxWorking; round++) {
      for (var cfgIdx = 0; cfgIdx < exerciseConfigs.length; cfgIdx++) {
        if (round >= workingByConfig[cfgIdx].length) continue;
        final c = exerciseConfigs[cfgIdx];
        final ws = workingByConfig[cfgIdx][round];
        out.add(
          PlannedGroupSet()
            ..exercise = c.exercise
            ..targetReps = ws.targetReps
            ..targetWeight = ws.targetWeight
            ..warmup = false
            ..restAfterSuccess = _effectiveRestSuccess(
              config: c,
              groupRest: restConfig,
              warmup: false,
              lastWarmup: false,
            )
            ..restAfterFailure = _effectiveRestFailure(
              config: c,
              groupRest: restConfig,
              warmup: false,
              lastWarmup: false,
            )
            ..isAmrap = ws.isAmrap
            ..instruction = ws.instruction,
        );
      }
    }

    return out;
  }

  List<PlannedGroupSet> _buildPlannedGroupSetsFromExistingGroup(
    ExerciseGroupData groupData,
  ) {
    final sets = List<ProposedSet>.from(groupData.sets)
      ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    return sets
        .map(
          (s) => PlannedGroupSet()
            ..exercise = s.exercise
            ..targetReps = s.targetReps
            ..targetWeight = s.targetWeight
            ..warmup = s.warmup
            ..restAfterSuccess = s.restAfterSuccess
            ..restAfterFailure = s.restAfterFailure
            ..isAmrap = s.isAmrap
            ..instruction = s.instruction,
        )
        .toList();
  }

  Future<void> _replaceExerciseGroupPlan({
    required String name,
    required String? exerciseGroupId,
    required bool interleaveWarmups,
    required List<PlannedGroupSet> sets,
    RestConfig? restConfig,
    bool deleteGroupIfEmpty = false,
    String instruction = '',
  }) async {
    if (_activeWorkout == null) return;
    final response = await _service.replaceExerciseGroupPlan(
      workoutId: _activeWorkout!.id,
      exerciseGroupId: exerciseGroupId,
      name: name,
      interleaveWarmups: interleaveWarmups,
      sets: sets,
      restConfig: restConfig,
      deleteGroupIfEmpty: deleteGroupIfEmpty,
      instruction: instruction,
    );

    if (exerciseGroupId != null && exerciseGroupId.isNotEmpty) {
      _activeExerciseGroups.removeWhere((g) => g.id == exerciseGroupId);
      _activeProposedSets.removeWhere(
        (s) => s.exerciseGroupId == exerciseGroupId,
      );
    }
    if (response.hasGroup()) {
      _activeExerciseGroups.add(response.group);
      _activeProposedSets.addAll(response.generatedSets);
    }
    _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
    _applyStateSnapshot(
      response.hasStateSnapshot() ? response.stateSnapshot : null,
    );
    _sortState();
    notifyListeners();
  }

  void setSoundProvider(SoundProvider provider) {
    _soundProvider = provider;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _now = DateTime.now();
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

  void _handleError(Object e) {
    if (isUnauthenticatedError(e)) return;
    final message = cleanErrorMessage(e);
    ErrorModalService.showError(message.toUpperCase());
  }

  // Loading state
  bool get isLoading => _isLoading;
  String? get lastLoadError => _lastLoadError;
  bool get lastLoadWasUnauthorized => _lastLoadWasUnauthorized;

  // Active workout getters
  Workout? get workout => _activeWorkout;
  List<ProposedSet> get proposedSets => _activeProposedSets;
  List<CompletedSet> get completedSets => _activeCompletedSets;
  List<ExerciseStatus> get exerciseStatuses => _exerciseStatuses;
  List<ProposedExerciseGroup> get proposedGroups => _proposedGroups;
  RegimeContext? get regimeContext => _regimeContext;

  Workout? get activeWorkout => _activeWorkout;
  List<ProposedSet> get activeProposedSets => _activeProposedSets;
  List<CompletedSet> get activeCompletedSets => _activeCompletedSets;
  WorkoutStateSnapshot? get stateSnapshot => _stateSnapshot;
  bool get hasActiveWorkout =>
      _activeWorkout != null && _activeWorkout!.endTime == Int64.ZERO;
  bool get isWorkoutEnded =>
      _activeWorkout != null && _activeWorkout!.endTime != Int64.ZERO;
  DateTime get now => _now;
  List<HeartRateSample> get wearHeartRateSamples =>
      List.unmodifiable(_wearHeartRateSamples);

  List<ExerciseGroupData> get exerciseGroups {
    if (_activeExerciseGroups.isEmpty) {
      return groupSetsByExercise(_activeProposedSets);
    }

    return _activeExerciseGroups.map((group) {
      final sets = _activeProposedSets
          .where((s) => s.exerciseGroupId == group.id)
          .toList();
      sets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));

      // Get primary exercise from configs, fallback to first set
      final exercise = group.exerciseConfigs.isNotEmpty
          ? Exercise.valueOf(group.exerciseConfigs.first.exercise.value) ??
                Exercise.EXERCISE_UNSPECIFIED
          : (sets.isNotEmpty
                ? sets.first.exercise
                : Exercise.EXERCISE_UNSPECIFIED);

      // Get all exercises in group
      final exercises = <Exercise>[];
      for (final config in group.exerciseConfigs) {
        final ex = Exercise.valueOf(config.exercise.value);
        if (ex != null && !exercises.contains(ex)) exercises.add(ex);
      }

      return ExerciseGroupData(
        exercise: exercise,
        sets: sets,
        group: group,
        exercises: exercises,
      );
    }).toList();
  }

  String _nextSetBody() {
    final next = nextPendingSet;
    if (next == null) return 'All sets complete!';
    final name = exerciseNames[next.exercise] ?? '?';
    final prefix = next.warmup ? 'Warmup ' : '';
    final w = next.targetWeight.toDouble();
    final weightStr = formatWeight(w, _settingsProvider.weightUnit);
    return 'Next up: $prefix$name — $weightStr ${weightUnitSuffix(_settingsProvider.weightUnit)} x ${next.targetReps}';
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      unawaited(_checkRestSound());
      unawaited(_flushPendingWearHeartRateUploads());
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _resetWearHeartRateBuffer() {
    _wearHeartRateSamples.clear();
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

  Future<void> loadActiveWorkout(String userId) async {
    _isLoading = true;
    _lastLoadError = null;
    _lastLoadWasUnauthorized = false;
    notifyListeners();
    try {
      final active = await _service.getActiveWorkout();
      if (active != null) {
        final response = await _service.getWorkout(active.id);
        _resetWearHeartRateBufferIfWorkoutChanged(response.workout.id);
        _activeWorkout = response.workout;
        _activeExerciseGroups = List.from(response.exerciseGroups);
        _activeProposedSets = List.from(response.proposedSets);
        _activeCompletedSets = List.from(response.completedSets);
        _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
        _applyStateSnapshot(
          response.hasStateSnapshot() ? response.stateSnapshot : null,
        );
        _sortState();
        await _hydrateWearHeartRateFromApi();
        _startTimer();
      } else {
        _resetWearHeartRateBufferIfWorkoutChanged(null);
        _activeWorkout = null;
        _activeExerciseGroups = [];
        _activeProposedSets = [];
        _activeCompletedSets = [];
        _backendNextUpSet = null;
        _applyStateSnapshot(null);
        _stopTimer();
      }

      final proposedSchedule = await _service.getProposedWorkoutSchedule(
        userId,
      );
      _exerciseStatuses = proposedSchedule.exerciseStatuses;
      _proposedGroups = proposedSchedule.proposedGroups;
      _regimeContext = proposedSchedule.hasRegimeContext()
          ? proposedSchedule.regimeContext
          : null;
    } catch (e) {
      _lastLoadWasUnauthorized = isUnauthenticatedError(e);
      _lastLoadError = cleanErrorMessage(e);
      _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadWorkout(String workoutId) async {
    try {
      final response = await _service.getWorkout(workoutId);
      _resetWearHeartRateBufferIfWorkoutChanged(response.workout.id);
      _activeWorkout = response.workout;
      _activeExerciseGroups = List.from(response.exerciseGroups);
      _activeProposedSets = List.from(response.proposedSets);
      _activeCompletedSets = List.from(response.completedSets);
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );
      _sortState();
      await _hydrateWearHeartRateFromApi();
      if (hasActiveWorkout) {
        _startTimer();
      } else {
        _stopTimer();
      }
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
    _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
    _applyStateSnapshot(
      response.hasStateSnapshot() ? response.stateSnapshot : null,
    );
    _sortState();
    if (hasActiveWorkout) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  Future<String?> startWorkout(String name, List<ExerciseGroup> groups) async {
    try {
      await NotificationService.cancelAll();
      _wasResting = false;
      final response = await _service.startWorkout(name, groups);
      _applyStartWorkoutResponse(response);
      notifyListeners();
      if (response.id.isNotEmpty) return response.id;
      return response.hasWorkout() ? response.workout.id : null;
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  Future<void> reorderExerciseGroups(List<String> groupIds) async {
    if (_activeWorkout == null) return;

    // Optimistically update local state
    final orderedGroups = <ExerciseGroup>[];
    for (final id in groupIds) {
      final group = _activeExerciseGroups.firstWhere((g) => g.id == id);
      orderedGroups.add(group..workoutOrder = orderedGroups.length);
    }
    _activeExerciseGroups = orderedGroups;

    // Reorder sets to match groups
    final orderedSets = <ProposedSet>[];
    for (final group in orderedGroups) {
      final sets = _activeProposedSets
          .where((s) => s.exerciseGroupId == group.id)
          .toList();
      for (final set in sets) {
        orderedSets.add(set..workoutOrder = orderedSets.length);
      }
    }
    _activeProposedSets = orderedSets;

    _sortState();

    notifyListeners();

    try {
      final response = await _service.reorderExerciseGroups(
        _activeWorkout!.id,
        groupIds,
      );
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );
    } catch (e) {
      _handleError(e);
      await _loadWorkout(_activeWorkout!.id);
    }
  }

  Future<void> startSet(String proposedSetId) async {
    if (_activeWorkout == null) return;
    try {
      final response = await _service.startSet(
        _activeWorkout!.id,
        proposedSetId,
      );
      _activeCompletedSets.add(response.completedSet);
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );
      notifyListeners();
      onSessionRefreshNeeded?.call();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> completeSet(
    String proposedSetId,
    int actualReps,
    double actualWeight, {
    int? completedAt,
  }) async {
    if (_activeWorkout == null) return;
    try {
      final response = await _service.completeSet(
        _activeWorkout!.id,
        proposedSetId,
        actualReps,
        actualWeight,
        completedAt,
      );
      final completed = response.completedSet;
      _activeCompletedSets.removeWhere(
        (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
      );
      _activeCompletedSets.add(completed);
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );
      notifyListeners();
      onSessionRefreshNeeded?.call();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> deleteCompletedSet(String completedSetId) async {
    if (_activeWorkout == null) return;
    try {
      final response = await _service.deleteCompletedSet(
        _activeWorkout!.id,
        completedSetId,
      );
      _activeCompletedSets.removeWhere((c) => c.id == completedSetId);
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );
      notifyListeners();
      onSessionRefreshNeeded?.call();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> skipWarmup(String proposedSetId) async {
    if (_activeWorkout == null) return;
    final proposed = _activeProposedSets.cast<ProposedSet?>().firstWhere(
      (p) => p!.id == proposedSetId,
      orElse: () => null,
    );
    if (proposed == null) return;
    if (!proposed.warmup) return;

    try {
      final response = await _service.cancelProposedSet(
        _activeWorkout!.id,
        proposedSetId,
      );
      _activeProposedSets.removeWhere((set) => set.id == proposedSetId);
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );
      notifyListeners();
      onSessionRefreshNeeded?.call();
    } catch (e) {
      _handleError(e);
    }
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
      final plannedSets = _buildPlannedGroupSetsFromConfigs(
        sets: sets,
        interleaveWarmups: interleaveWarmups,
        exerciseConfigs: exerciseConfigs,
        restConfig: restConfig,
      );
      await _replaceExerciseGroupPlan(
        name: name,
        exerciseGroupId: null,
        interleaveWarmups: interleaveWarmups,
        sets: plannedSets,
        restConfig: restConfig,
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
      final plannedSets = _buildPlannedGroupSetsFromConfigs(
        sets: sets,
        interleaveWarmups: interleaveWarmups,
        exerciseConfigs: exerciseConfigs,
        restConfig: restConfig,
      );
      await _replaceExerciseGroupPlan(
        name: groupData.group!.name,
        exerciseGroupId: groupData.group!.id,
        interleaveWarmups: interleaveWarmups,
        sets: plannedSets,
        restConfig: restConfig,
        instruction: groupData.group!.instruction,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> updateSet(String setId, int reps, double weight) async {
    final proposed = _activeProposedSets.cast<ProposedSet?>().firstWhere(
      (p) => p!.id == setId,
      orElse: () => null,
    );
    if (proposed == null || proposed.exerciseGroupId.isEmpty) return;

    final groupIndex = exerciseGroups.indexWhere(
      (g) => g.group?.id == proposed.exerciseGroupId,
    );
    if (groupIndex == -1) return;

    final groupData = exerciseGroups[groupIndex];
    final group = groupData.group!;

    final plannedSets = _buildPlannedGroupSetsFromExistingGroup(groupData);
    final idx = plannedSets.indexWhere(
      (s) =>
          s.exercise == proposed.exercise &&
          s.warmup == proposed.warmup &&
          s.targetWeight == proposed.targetWeight &&
          s.targetReps == proposed.targetReps,
    );
    if (idx >= 0) {
      plannedSets[idx]
        ..targetReps = reps
        ..targetWeight = weight;
    } else {
      // Fallback: update first matching proposed set slot by id order.
      final existingOrdered = List<ProposedSet>.from(groupData.sets)
        ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
      final slot = existingOrdered.indexWhere((s) => s.id == setId);
      if (slot >= 0 && slot < plannedSets.length) {
        plannedSets[slot]
          ..targetReps = reps
          ..targetWeight = weight;
      }
    }

    await _replaceExerciseGroupPlan(
      name: group.name,
      exerciseGroupId: group.id,
      interleaveWarmups: group.interleaveWarmups,
      sets: plannedSets,
      restConfig: group.hasRestConfig() ? group.restConfig : null,
      instruction: group.instruction,
    );
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
  Future<void> endWorkout() async {
    if (_activeWorkout == null) return;
    try {
      await _flushPendingWearHeartRateUploads(force: true);
      await NotificationService.cancelAll();
      _wasResting = false;
      final ended = await _service.endWorkout(_activeWorkout!.id);
      _activeWorkout = ended;
      _stopTimer();
      notifyListeners();

      // Fire-and-forget: never blocks workout completion
      _writeToHealthPlatform(ended);
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
    _stopTimer();
    notifyListeners();
  }

  void ingestWearHeartRateBatch(WearSensorBatch batch) {
    if (_activeWorkout == null) return;
    if (batch.workoutId != _activeWorkout!.id) return;

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
    super.dispose();
  }
}
