import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/warmup.dart';
import '../services/workout_service.dart';

class WorkoutProvider extends ChangeNotifier {
  final WorkoutServiceWrapper _service;

  Workout? _workout;
  List<ProposedSet> _proposedSets = [];
  List<CompletedSet> _completedSets = [];
  Timer? _timer;
  DateTime _now = DateTime.now();

  WorkoutProvider(this._service);

  Workout? get workout => _workout;
  List<ProposedSet> get proposedSets => _proposedSets;
  List<CompletedSet> get completedSets => _completedSets;
  bool get hasActiveWorkout => _workout != null && _workout!.endTime == Int64.ZERO;
  bool get isWorkoutEnded => _workout != null && _workout!.endTime != Int64.ZERO;
  DateTime get now => _now;

  List<ExerciseGroupData> get exerciseGroups => groupSetsByExercise(_proposedSets);

  bool isSetDone(String setId) {
    return _completedSets.any((c) => c.proposedSetId == setId && c.endedAt != Int64.ZERO);
  }

  bool isSetActive(String setId) {
    return _completedSets.any((c) => c.proposedSetId == setId && c.endedAt == Int64.ZERO);
  }

  String? get activeSetId {
    final active = _completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.endedAt == Int64.ZERO,
      orElse: () => null,
    );
    return active?.proposedSetId;
  }

  CompletedSet? get restingSet {
    final nowUnix = _now.millisecondsSinceEpoch ~/ 1000;
    return _completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.endedAt != Int64.ZERO && c.restUntil.toInt() > nowUnix,
      orElse: () => null,
    );
  }

  ProposedSet? get nextPendingSet {
    for (final set in _proposedSets) {
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

  /// Returns the unix timestamp when the last rest period ended, or null.
  /// Used to detect "chat time" (rest ended but user hasn't started next set).
  int? get lastRestEndTimestamp {
    final candidates = _completedSets
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

  Future<void> loadActiveWorkout() async {
    try {
      final active = await _service.getActiveWorkout();
      if (active != null) {
        await loadWorkout(active.id);
      } else {
        _workout = null;
        _proposedSets = [];
        _completedSets = [];
        _stopTimer();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading active workout: $e');
    }
  }

  Future<void> loadWorkout(String workoutId) async {
    try {
      final response = await _service.getWorkout(workoutId);
      _workout = response.workout;
      _proposedSets = List.from(response.proposedSets);
      _completedSets = List.from(response.completedSets);
      if (hasActiveWorkout) {
        _startTimer();
      } else {
        _stopTimer();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading workout: $e');
    }
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
    if (_workout == null) return;

    // Flatten groups and renumber
    final allSets = <ProposedSet>[];
    for (final group in groups) {
      for (final set in group.sets) {
        allSets.add(ProposedSet()
          ..mergeFromMessage(set)
          ..workoutOrder = allSets.length);
      }
    }

    // Optimistic update
    _proposedSets = allSets;
    notifyListeners();

    try {
      final updated = await _service.modifyProposedSets(_workout!.id, allSets);
      _proposedSets = List.from(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving groups: $e');
      await loadWorkout(_workout!.id);
    }
  }

  Future<void> startSet(String proposedSetId) async {
    if (_workout == null) return;
    try {
      final completed = await _service.startSet(_workout!.id, proposedSetId);
      _completedSets.add(completed);
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
    if (_workout == null) return;
    try {
      final completed = await _service.completeSet(
        _workout!.id,
        proposedSetId,
        actualReps,
        actualWeight,
      );
      _completedSets.removeWhere(
        (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
      );
      _completedSets.add(completed);
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing set: $e');
    }
  }

  Future<void> deleteCompletedSet(String completedSetId) async {
    if (_workout == null) return;
    try {
      await _service.deleteCompletedSet(_workout!.id, completedSetId);
      _completedSets.removeWhere((c) => c.id == completedSetId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting completed set: $e');
    }
  }

  /// Skip a warmup set by completing it immediately with target reps/weight.
  Future<void> skipWarmup(String proposedSetId) async {
    if (_workout == null) return;
    final proposed = _proposedSets.cast<ProposedSet?>().firstWhere(
      (p) => p!.id == proposedSetId,
      orElse: () => null,
    );
    if (proposed == null) return;

    try {
      final completed = await _service.completeSet(
        _workout!.id,
        proposedSetId,
        proposed.targetReps,
        proposed.targetWeight.toDouble(),
      );
      _completedSets.removeWhere(
        (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
      );
      _completedSets.add(completed);
      notifyListeners();
    } catch (e) {
      debugPrint('Error skipping warmup: $e');
    }
  }

  Future<void> endWorkout() async {
    if (_workout == null) return;
    try {
      final ended = await _service.endWorkout(_workout!.id);
      _workout = ended;
      _stopTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('Error ending workout: $e');
    }
  }

  /// Rebuild a specific exercise group by index with new options
  void rebuildGroup(int groupIndex, {required double targetWeight, bool? warmups, int? setCount}) {
    final groups = exerciseGroups;
    if (groupIndex < 0 || groupIndex >= groups.length) return;

    final newSets = rebuildExerciseSets(
      groups[groupIndex].sets,
      targetWeight: targetWeight,
      warmups: warmups,
      setCount: setCount,
      isSetDone: isSetDone,
    );

    final updatedGroups = List<ExerciseGroupData>.from(groups);
    updatedGroups[groupIndex] = ExerciseGroupData(
      exercise: groups[groupIndex].exercise,
      sets: newSets,
    );

    saveGroups(updatedGroups);
  }

  void clear() {
    _workout = null;
    _proposedSets = [];
    _completedSets = [];
    _stopTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
