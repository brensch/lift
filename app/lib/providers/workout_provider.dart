import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../services/workout_service.dart';
import '../providers/sound_provider.dart';
import '../services/notification_service.dart';
import '../services/health_service.dart' show HealthService, HealthWriteResult;
import '../logic/exercises.dart';

class WorkoutProvider extends ChangeNotifier with WidgetsBindingObserver {
  final WorkoutServiceWrapper _service;
  SoundProvider? _soundProvider;

  // Loading state
  bool _isLoading = false;

  // Active workout state
  Workout? _activeWorkout;
  List<ExerciseGroup> _activeExerciseGroups = [];
  List<ProposedSet> _activeProposedSets = [];
  List<CompletedSet> _activeCompletedSets = [];
  List<ExerciseStatus> _exerciseStatuses = [];

  // Track whether we already played the sound for the current rest period
  bool _wasResting = false;
  int? _lastSoundedRestUntil;

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
      // App came back to foreground — check if rest expired while away
      _now = DateTime.now();
      _checkRestSound();
      notifyListeners();
    }
  }

  /// Set _wasResting to current state without triggering sound.
  /// Call after loading completed sets to avoid false-triggering on load.
  void _initRestState() {
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final resting = _activeCompletedSets
        .where((c) => c.endedAt != Int64.ZERO && c.restUntil.toInt() > 0)
        .toList();
    if (resting.isEmpty) {
      _wasResting = false;
      return;
    }
    resting.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final restUntil = resting.first.restUntil.toInt();
    _wasResting = restUntil > nowUnix;
    // Mark as already sounded if rest already expired, so we don't play on load
    if (!_wasResting) {
      _lastSoundedRestUntil = restUntil;
    }
  }

  void _sortState() {
    _activeExerciseGroups.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    _activeProposedSets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  }

  Future<void> _checkRestSound() async {
    final nowUnix = _now.millisecondsSinceEpoch ~/ 1000;
    final resting = _activeCompletedSets
        .where((c) => c.endedAt != Int64.ZERO && c.restUntil.toInt() > 0)
        .toList();
    if (resting.isEmpty) {
      _wasResting = false;
      return;
    }
    resting.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final latest = resting.first;
    final restUntil = latest.restUntil.toInt();
    final isCurrentlyResting = restUntil > nowUnix;

    if (_wasResting && !isCurrentlyResting && _lastSoundedRestUntil != restUntil) {
      // Rest just ended — cancel scheduled notification (prevent double sound),
      // play in-app sound, and show buzz notification for watches
      _lastSoundedRestUntil = restUntil;
      await NotificationService.cancelRestNotification();
      _soundProvider?.playCurrentSound();
      await NotificationService.showBuzzNotification(body: _nextSetBody());
    }
    _wasResting = isCurrentlyResting;
  }

  void _handleError(Object e) {
    if (e is GrpcError && e.code == StatusCode.unauthenticated) return;
    String message;
    if (e is GrpcError) {
      message = e.message ?? 'Server error';
    } else {
      message = e.toString().replaceFirst('Exception: ', '');
    }
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // Loading state
  bool get isLoading => _isLoading;

  // Active workout getters
  Workout? get workout => _activeWorkout;
  List<ProposedSet> get proposedSets => _activeProposedSets;
  List<CompletedSet> get completedSets => _activeCompletedSets;
  List<ExerciseStatus> get exerciseStatuses => _exerciseStatuses;

  Workout? get activeWorkout => _activeWorkout;
  List<ProposedSet> get activeProposedSets => _activeProposedSets;
  List<CompletedSet> get activeCompletedSets => _activeCompletedSets;
  bool get hasActiveWorkout => _activeWorkout != null && _activeWorkout!.endTime == Int64.ZERO;
  bool get isWorkoutEnded => _activeWorkout != null && _activeWorkout!.endTime != Int64.ZERO;
  DateTime get now => _now;

  List<ExerciseGroupData> get exerciseGroups {
    if (_activeExerciseGroups.isEmpty) {
      return groupSetsByExercise(_activeProposedSets);
    }

    return _activeExerciseGroups.map((group) {
      final sets = _activeProposedSets.where((s) => s.exerciseGroupId == group.id).toList();
      sets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
      final exercise = sets.isNotEmpty ? sets.first.exercise : Exercise.EXERCISE_UNSPECIFIED;
      return ExerciseGroupData(exercise: exercise, sets: sets, group: group);
    }).toList();
  }

  String _nextSetBody() {
    final next = nextPendingSet;
    if (next == null) return 'All sets complete!';
    final name = exerciseNames[next.exercise] ?? '?';
    final prefix = next.warmup ? 'Warmup ' : '';
    final w = next.targetWeight.toDouble();
    final weightStr = w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
    return 'Next up: $prefix$name — ${weightStr}kg x ${next.targetReps}';
  }

  // Debug getters
  bool get debugWasResting => _wasResting;
  int? get debugLastSoundedRestUntil => _lastSoundedRestUntil;

  bool isSetDone(String setId) {
    return _activeCompletedSets.any((c) => c.proposedSetId == setId && c.endedAt != Int64.ZERO);
  }

  bool isSetActive(String setId) {
    return _activeCompletedSets.any((c) => c.proposedSetId == setId && c.endedAt == Int64.ZERO);
  }

  String? get activeSetId {
    final active = _activeCompletedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.endedAt == Int64.ZERO,
      orElse: () => null,
    );
    return active?.proposedSetId;
  }

  CompletedSet? get restingSet {
    final nowUnix = _now.millisecondsSinceEpoch ~/ 1000;
    final candidates = _activeCompletedSets
        .where((c) => c.endedAt != Int64.ZERO && c.restUntil.toInt() > nowUnix)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return candidates.first;
  }

  ProposedSet? get nextPendingSet {
    for (final set in _activeProposedSets) {
      if (!isSetDone(set.id) && !isSetActive(set.id)) {
        return set;
      }
    }
    return null;
  }

  int get restSecondsRemaining {
    final resting = restingSet;
    if (resting == null) return 0;
    final remaining = resting.restUntil.toInt() - (_now.millisecondsSinceEpoch ~/ 1000);
    return remaining > 0 ? remaining : 0;
  }

  int? get lastRestEndTimestamp {
    final candidates = _activeCompletedSets
        .where((c) => c.endedAt != Int64.ZERO && c.restUntil != Int64.ZERO)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return candidates.first.restUntil.toInt();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      _checkRestSound();
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
        _sortState();
        // Initialize rest tracking state so we don't false-trigger sound on load
        _initRestState();
        _startTimer();
      } else {
        _activeWorkout = null;
        _activeExerciseGroups = [];
        _activeProposedSets = [];
        _activeCompletedSets = [];
        _stopTimer();
      }

      final proposedSchedule = await _service.getProposedWorkoutSchedule(userId);
      _exerciseStatuses = proposedSchedule.exerciseStatuses;
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
      _sortState();
      _initRestState();
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

  Future<String?> startWorkout(String name, List<ExerciseGroup> groups, List<ProposedSet> sets) async {
    try {
      final workoutId = await _service.startWorkout(name, groups, sets);
      await _loadWorkout(workoutId);
      return workoutId;
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
      final sets = _activeProposedSets.where((s) => s.exerciseGroupId == group.id).toList();
      for (final set in sets) {
        orderedSets.add(set..workoutOrder = orderedSets.length);
      }
    }
    _activeProposedSets = orderedSets;

    _sortState();

    notifyListeners();

    try {
      await _service.reorderExerciseGroups(_activeWorkout!.id, groupIds);
    } catch (e) {
      _handleError(e);
      await _loadWorkout(_activeWorkout!.id);
    }
  }

  Future<void> startSet(String proposedSetId) async {
    if (_activeWorkout == null) return;
    try {
      await NotificationService.cancelRestNotification();
      _wasResting = false;
      final completed = await _service.startSet(_activeWorkout!.id, proposedSetId);
      _activeCompletedSets.add(completed);
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> completeSet(
    String proposedSetId,
    int actualReps,
    double actualWeight,
  ) async {
    if (_activeWorkout == null) return;
    try {
      final completed = await _service.completeSet(
        _activeWorkout!.id,
        proposedSetId,
        actualReps,
        actualWeight,
      );
      _activeCompletedSets.removeWhere(
        (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
      );
      _activeCompletedSets.add(completed);
      // Mark that rest has started so _checkRestSound can detect the transition
      if (completed.restUntil.toInt() > 0) {
        _wasResting = true;
        // Schedule background notification for when rest ends
        final presetId = _soundProvider?.currentPreset ?? 'chord_strum';
        await NotificationService.scheduleRestNotification(
          restUntilUnix: completed.restUntil.toInt(),
          soundPresetId: presetId,
          body: _nextSetBody(),
        );
      }
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> deleteCompletedSet(String completedSetId) async {
    if (_activeWorkout == null) return;
    try {
      await _service.deleteCompletedSet(_activeWorkout!.id, completedSetId);
      _activeCompletedSets.removeWhere((c) => c.id == completedSetId);
      await NotificationService.cancelRestNotification();
      _wasResting = false;
      notifyListeners();
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

    try {
      await NotificationService.cancelRestNotification();
      final completed = await _service.completeSet(
        _activeWorkout!.id,
        proposedSetId,
        proposed.targetReps,
        proposed.targetWeight.toDouble(),
      );
      _activeCompletedSets.removeWhere(
        (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
      );
      _activeCompletedSets.add(completed);
      // Suppress sound for skipped warmup rest period
      if (completed.restUntil.toInt() > 0) {
        _lastSoundedRestUntil = completed.restUntil.toInt();
      }
      _wasResting = false;
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
      await NotificationService.cancelAll();
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
        final storeName = Platform.isAndroid ? 'Health Connect' : 'Apple Health';
        Fluttertoast.showToast(
          msg: 'Successfully uploaded to $storeName',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else if (result == HealthWriteResult.permissionDenied) {
        Fluttertoast.showToast(
          msg: 'Health Connect permission denied — enable in Settings > Apps > Lift',
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

  void rebuildGroup(int groupIndex, {required List<double> targetWeights, bool? warmups, int? setCount}) {
    final groups = exerciseGroups;
    if (groupIndex < 0 || groupIndex >= groups.length) return;

    final groupData = groups[groupIndex];
    if (groupData.group != null) {
      final reps = groupData.sets.where((s) => !s.warmup).firstOrNull?.targetReps ?? 5;
      updateGroup(
        groupIndex,
        targetWeights: targetWeights,
        reps: reps,
        setCount: setCount ?? groupData.sets.where((s) => !s.warmup).length,
        warmups: warmups,
      );
      return;
    }
  }

  Future<void> addExerciseGroup({
    required String name,
    required ExerciseGroupType type,
    required List<Exercise> exercises,
    required int sets,
    required int reps,
    required List<double> weights,
    required bool includeWarmup,
  }) async {
    if (_activeWorkout == null) return;
    try {
      final response = await _service.createExerciseGroup(
        workoutId: _activeWorkout!.id,
        name: name,
        type: type,
        exercises: exercises,
        sets: sets,
        reps: reps,
        weights: weights,
        includeWarmup: includeWarmup,
      );
      _activeExerciseGroups.add(response.group);
      _activeProposedSets.addAll(response.generatedSets);
      _sortState();
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> updateGroup(int groupIndex, {
    required List<double> targetWeights,
    required int reps,
    required int setCount,
    bool? warmups,
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
        sets: setCount,
        reps: reps,
        weights: targetWeights,
        includeWarmup: warmups ?? groupData.group!.includeWarmup,
      );

      _activeExerciseGroups.removeWhere((g) => g.id == groupData.group!.id);
      _activeExerciseGroups.add(response.group);

      _activeProposedSets.removeWhere((s) => s.exerciseGroupId == groupData.group!.id);
      _activeProposedSets.addAll(response.generatedSets);
      
      _sortState();

      notifyListeners();
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
      await _service.deleteExerciseGroup(_activeWorkout!.id, groupData.group!.id);
      _activeExerciseGroups.removeWhere((g) => g.id == groupData.group!.id);
      _activeProposedSets.removeWhere((s) => s.exerciseGroupId == groupData.group!.id);
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> clear() async {
    await NotificationService.cancelAll();
    _activeWorkout = null;
    _activeProposedSets = [];
    _activeCompletedSets = [];
    _stopTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }
}
