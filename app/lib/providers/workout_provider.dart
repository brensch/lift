import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../logic/exercise_groups.dart';
import '../services/workout_service.dart';
import '../providers/sound_provider.dart';
import '../services/notification_service.dart';
import '../services/health_service.dart' show HealthService, HealthWriteResult;
import '../services/error_modal_service.dart';
import '../logic/exercises.dart';
import '../logic/utils.dart';

class WorkoutProvider extends ChangeNotifier with WidgetsBindingObserver {
  final WorkoutServiceWrapper _service;
  SoundProvider? _soundProvider;

  /// Called after each set mutation so the multiplayer session view can
  /// refresh immediately instead of waiting for the next background tick.
  VoidCallback? onSessionRefreshNeeded;

  // Loading state
  bool _isLoading = false;

  // Active workout state
  Workout? _activeWorkout;
  List<ExerciseGroup> _activeExerciseGroups = [];
  List<ProposedSet> _activeProposedSets = [];
  List<CompletedSet> _activeCompletedSets = [];
  ProposedSet? _backendNextUpSet;
  WorkoutStateSnapshot? _stateSnapshot;
  List<ExerciseStatus> _exerciseStatuses = [];
  List<ProposedExerciseGroup> _proposedGroups = [];
  final List<HeartRateSample> _wearHeartRateSamples = [];
  final List<WorkoutHeartRatePoint> _pendingWearHeartRateUploads = [];
  DateTime? _lastWearHeartRateUploadAt;
  bool _wearHeartRateUploadInFlight = false;

  bool _wasResting = false;

  Timer? _timer;
  DateTime _now = DateTime.now();

  WorkoutProvider(this._service) {
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onStartNextSet = _onStartNextSet;
  }

  void _onStartNextSet() {
    final next = nextPendingSet;
    if (next != null) {
      startSet(next.id);
    }
  }

  void setSoundProvider(SoundProvider provider) {
    _soundProvider = provider;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _now = DateTime.now();
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
    if (e is GrpcError && e.code == StatusCode.unauthenticated) return;
    final message = cleanErrorMessage(e);
    ErrorModalService.showError(message.toUpperCase());
  }

  // Loading state
  bool get isLoading => _isLoading;

  // Active workout getters
  Workout? get workout => _activeWorkout;
  List<ProposedSet> get proposedSets => _activeProposedSets;
  List<CompletedSet> get completedSets => _activeCompletedSets;
  List<ExerciseStatus> get exerciseStatuses => _exerciseStatuses;
  List<ProposedExerciseGroup> get proposedGroups => _proposedGroups;

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
    final weightStr = w == w.roundToDouble()
        ? w.toInt().toString()
        : w.toStringAsFixed(1);
    return 'Next up: $prefix$name — ${weightStr}kg x ${next.targetReps}';
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
          unawaited(NotificationService.scheduleRest(
            restUntilUnix: restUntil,
            soundPresetId: presetId,
            body: _nextSetBody(),
          ));
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

  Future<void> loadActiveWorkout(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final active = await _service.getActiveWorkout();
      if (active != null) {
        final response = await _service.getWorkout(active.id);
        _activeWorkout = response.workout;
        _activeExerciseGroups = List.from(response.exerciseGroups);
        _activeProposedSets = List.from(response.proposedSets);
        _activeCompletedSets = List.from(response.completedSets);
        _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
        _applyStateSnapshot(
          response.hasStateSnapshot() ? response.stateSnapshot : null,
        );
        _sortState();
        _startTimer();
      } else {
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
    } catch (e) {
      _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadWorkout(String workoutId) async {
    try {
      final response = await _service.getWorkout(workoutId);
      _activeWorkout = response.workout;
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
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  void _applyStartWorkoutResponse(StartWorkoutResponse response) {
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
      final response = await _service.createExerciseGroup(
        workoutId: _activeWorkout!.id,
        name: name,
        sets: sets,
        interleaveWarmups: interleaveWarmups,
        exerciseConfigs: exerciseConfigs,
        restConfig: restConfig,
      );
      _activeExerciseGroups.add(response.group);
      _activeProposedSets.addAll(response.generatedSets);
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );
      _sortState();
      notifyListeners();
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
      final response = await _service.updateExerciseGroup(
        workoutId: _activeWorkout!.id,
        exerciseGroupId: groupData.group!.id,
        name: groupData.group!.name,
        sets: sets,
        interleaveWarmups: interleaveWarmups,
        exerciseConfigs: exerciseConfigs,
        restConfig: restConfig,
      );

      _activeExerciseGroups.removeWhere((g) => g.id == groupData.group!.id);
      _activeExerciseGroups.add(response.group);

      _activeProposedSets.removeWhere(
        (s) => s.exerciseGroupId == groupData.group!.id,
      );
      _activeProposedSets.addAll(response.generatedSets);
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );

      _sortState();

      notifyListeners();
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

    final groupIndex = exerciseGroups.indexWhere((g) => g.group?.id == proposed.exerciseGroupId);
    if (groupIndex == -1) return;

    final groupData = exerciseGroups[groupIndex];
    final group = groupData.group!;

    // Create new configs based on the update. 
    // For now, we update the config that matches the exercise of the set.
    final newConfigs = group.exerciseConfigs.map((c) {
      if (c.exercise == proposed.exercise) {
        return c.deepCopy()
          ..reps = reps
          ..startWeight = weight.toDouble()
          ..endWeight = weight.toDouble(); // Simplify to flat weight for quick edit
      }
      return c;
    }).toList();

    await updateGroup(
      groupIndex,
      sets: group.sets,
      interleaveWarmups: group.interleaveWarmups,
      exerciseConfigs: newConfigs,
      restConfig: group.hasRestConfig() ? group.restConfig : null,
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
      final response = await _service.deleteExerciseGroup(
        _activeWorkout!.id,
        groupData.group!.id,
      );
      _activeExerciseGroups.removeWhere((g) => g.id == groupData.group!.id);
      _activeProposedSets.removeWhere(
        (s) => s.exerciseGroupId == groupData.group!.id,
      );
      _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
      _applyStateSnapshot(
        response.hasStateSnapshot() ? response.stateSnapshot : null,
      );
      notifyListeners();
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
          names.add(exerciseNames[set.exercise] ?? set.exercise.name);
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
    _wearHeartRateSamples.clear();
    _pendingWearHeartRateUploads.clear();
    _lastWearHeartRateUploadAt = null;
    _wearHeartRateUploadInFlight = false;
    _stopTimer();
    notifyListeners();
  }

  void ingestWearHeartRateBatch(WearSensorBatch batch) {
    if (_activeWorkout == null) return;
    if (batch.workoutId != _activeWorkout!.id) return;
    _wearHeartRateSamples.addAll(batch.heartRateSamples);
    // Keep a rolling buffer in memory to avoid unbounded growth.
    if (_wearHeartRateSamples.length > 5000) {
      _wearHeartRateSamples.removeRange(0, _wearHeartRateSamples.length - 5000);
    }
    for (final sample in batch.heartRateSamples) {
      _pendingWearHeartRateUploads.add(
        WorkoutHeartRatePoint()
          ..sampledAt = sample.sampledAt
          ..bpm = sample.bpm
          ..availability = sample.availability.value,
      );
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
