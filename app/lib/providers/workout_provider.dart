import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/warmup.dart';
import '../services/workout_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final WorkoutServiceWrapper _service;

  // Active workout state
  Workout? _activeWorkout;
  List<ProposedSet> _activeProposedSets = [];
  List<CompletedSet> _activeCompletedSets = [];
  List<ExerciseStatus> _exerciseStatuses = [];

  // Historical / viewing state
  Workout? _viewingWorkout;
  List<ProposedSet> _viewingProposedSets = [];
  List<CompletedSet> _viewingCompletedSets = [];
  bool _isViewingHistory = false;

  Timer? _timer;
  DateTime _now = DateTime.now();

  WorkoutProvider(this._service);

  // Proxy getters for screens to show "current" context (active or historical)
  Workout? get workout => _isViewingHistory ? _viewingWorkout : _activeWorkout;
  List<ProposedSet> get proposedSets => _isViewingHistory ? _viewingProposedSets : _activeProposedSets;
  List<CompletedSet> get completedSets => _isViewingHistory ? _viewingCompletedSets : _activeCompletedSets;
  List<ExerciseStatus> get exerciseStatuses => _exerciseStatuses;
  
  // Explicit active state for the bottom bar
  Workout? get activeWorkout => _activeWorkout;
  List<ProposedSet> get activeProposedSets => _activeProposedSets;
  List<CompletedSet> get activeCompletedSets => _activeCompletedSets;
  bool get hasActiveWorkout => _activeWorkout != null && _activeWorkout!.endTime == Int64.ZERO;
  bool get isWorkoutEnded => _activeWorkout != null && _activeWorkout!.endTime != Int64.ZERO;
  bool get isViewingHistory => _isViewingHistory;
  DateTime get now => _now;

  List<ExerciseGroupData> get exerciseGroups => groupSetsByExercise(proposedSets);

  bool isSetDone(String setId, {bool useActive = false}) {
    final sets = (useActive || !_isViewingHistory) ? _activeCompletedSets : _viewingCompletedSets;
    return sets.any((c) => c.proposedSetId == setId && c.endedAt != Int64.ZERO);
  }

  bool isSetActive(String setId, {bool useActive = false}) {
    final sets = (useActive || !_isViewingHistory) ? _activeCompletedSets : _viewingCompletedSets;
    return sets.any((c) => c.proposedSetId == setId && c.endedAt == Int64.ZERO);
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
      if (!isSetDone(set.id, useActive: true) && !isSetActive(set.id, useActive: true)) {
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
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> loadActiveWorkout(String userId) async {
    try {
      final active = await _service.getActiveWorkout();
      if (active != null) {
        final response = await _service.getWorkout(active.id);
        _activeWorkout = response.workout;
        _activeProposedSets = List.from(response.proposedSets);
        _activeCompletedSets = List.from(response.completedSets);
        _startTimer();
      } else {
        _activeWorkout = null;
        _activeProposedSets = [];
        _activeCompletedSets = [];
        _stopTimer();
      }

      final proposedSchedule = await _service.getProposedWorkoutSchedule(userId);
      _exerciseStatuses = proposedSchedule.exerciseStatuses;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading active workout: $e');
    }
  }

  Future<void> loadWorkout(String workoutId, {bool asHistory = false}) async {
    try {
      final response = await _service.getWorkout(workoutId);
      if (asHistory) {
        _viewingWorkout = response.workout;
        _viewingProposedSets = List.from(response.proposedSets);
        _viewingCompletedSets = List.from(response.completedSets);
        _isViewingHistory = true;
      } else {
        _activeWorkout = response.workout;
        _activeProposedSets = List.from(response.proposedSets);
        _activeCompletedSets = List.from(response.completedSets);
        _isViewingHistory = false;
        if (hasActiveWorkout) {
          _startTimer();
        } else {
          _stopTimer();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading workout: $e');
    }
  }

  void stopViewingHistory() {
    _isViewingHistory = false;
    _viewingWorkout = null;
    _viewingProposedSets = [];
    _viewingCompletedSets = [];
    notifyListeners();
  }

  Future<String?> startWorkout(String name, List<ProposedSet> sets) async {
    try {
      final workoutId = await _service.startWorkout(name, sets);
      await loadWorkout(workoutId);
      return workoutId;
    } catch (e) {
      debugPrint('Error starting workout: $e');
      return null;
    }
  }

  Future<void> saveGroups(List<ExerciseGroupData> groups) async {
    if (_activeWorkout == null || _isViewingHistory) return;

    final allSets = <ProposedSet>[];
    for (final group in groups) {
      for (final set in group.sets) {
        allSets.add(ProposedSet()
          ..mergeFromMessage(set)
          ..workoutOrder = allSets.length);
      }
    }

    _activeProposedSets = allSets;
    notifyListeners();

    try {
      final updated = await _service.modifyProposedSets(_activeWorkout!.id, allSets);
      _activeProposedSets = List.from(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving groups: $e');
      await loadWorkout(_activeWorkout!.id);
    }
  }

  Future<void> startSet(String proposedSetId) async {
    if (_activeWorkout == null) return;
    try {
      final completed = await _service.startSet(_activeWorkout!.id, proposedSetId);
      _activeCompletedSets.add(completed);
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting set: $e');
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing set: $e');
    }
  }

  Future<void> deleteCompletedSet(String completedSetId) async {
    if (_activeWorkout == null) return;
    try {
      await _service.deleteCompletedSet(_activeWorkout!.id, completedSetId);
      _activeCompletedSets.removeWhere((c) => c.id == completedSetId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting completed set: $e');
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error skipping warmup: $e');
    }
  }

  Future<void> endWorkout() async {
    if (_activeWorkout == null) return;
    try {
      final ended = await _service.endWorkout(_activeWorkout!.id);
      _activeWorkout = ended;
      _stopTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('Error ending workout: $e');
    }
  }

  void rebuildGroup(int groupIndex, {required double targetWeight, bool? warmups, int? setCount}) {
    if (_isViewingHistory) return;
    final groups = exerciseGroups;
    if (groupIndex < 0 || groupIndex >= groups.length) return;

    final newSets = rebuildExerciseSets(
      groups[groupIndex].sets,
      targetWeight: targetWeight,
      warmups: warmups,
      setCount: setCount,
      isSetDone: (id) => isSetDone(id, useActive: true),
    );

    final updatedGroups = List<ExerciseGroupData>.from(groups);
    updatedGroups[groupIndex] = ExerciseGroupData(
      exercise: groups[groupIndex].exercise,
      sets: newSets,
    );

    saveGroups(updatedGroups);
  }

  void clear() {
    _activeWorkout = null;
    _activeProposedSets = [];
    _activeCompletedSets = [];
    _isViewingHistory = false;
    _viewingWorkout = null;
    _viewingProposedSets = [];
    _viewingCompletedSets = [];
    _stopTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
