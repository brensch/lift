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
import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../logic/first_workout.dart';
import '../logic/audio.dart';
import '../logic/exercise_blocks.dart';
import '../logic/exercise_prescription.dart';
import '../logic/weight_units.dart';
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
import '../theme/schlift_spec.dart';

/// Offered after a session whose exercises diverged from its template (or
/// that started empty): "save this as/into a template?". Computed at
/// EndWorkout, consumed once by the UI.
class TemplateUpdateSuggestion {
  /// '' = the workout started empty; saving creates a new template.
  final String templateId;
  final String templateName;

  /// The exercises actually performed, in workout order.
  final List<Exercise> exercises;

  const TemplateUpdateSuggestion({
    required this.templateId,
    required this.templateName,
    required this.exercises,
  });

  bool get isNew => templateId.isEmpty;
}

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
  List<ProposedSet> _activeProposedSets = [];
  List<CompletedSet> _activeCompletedSets = [];
  ProposedSet? _backendNextUpSet;
  WorkoutStateSnapshot? _stateSnapshot;
  GetHomeResponse? _home;
  TemplateUpdateSuggestion? _pendingTemplateUpdate;
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
  final List<ExerciseBlock> _blocksCache = [];
  late final UnmodifiableListView<HeartRateSample> _wearHeartRateSamplesView =
      UnmodifiableListView(_wearHeartRateSamples);

  /// [sandbox] is the tutorial's provider: a mock backend behind it and
  /// nothing real in front. It never touches the on-device cache, never
  /// schedules or cancels OS notifications, plays no sound, writes nothing
  /// to the health platform and leaves the notification tap handler to
  /// the real provider.
  WorkoutProvider(this._service, this._settingsProvider, {bool sandbox = false})
    : _sandbox = sandbox {
    WidgetsBinding.instance.addObserver(this);
    _restoreLocalCacheFuture = sandbox
        ? Future<void>.value()
        : _restoreLocalCache();
  }

  final bool _sandbox;

  void _setNow(DateTime value) {
    _now = value;
    _clock.value = value;
  }

  // ── Plan-shaping ops: optimistic local apply + queued mutation ──
  // The local apply gives instant feedback; the server response (with the
  // authoritative plan, warmups included) replaces it a beat later.

  /// Where an added exercise's calibration ramp starts, or null when it
  /// does not calibrate. Mirrors `calibration_start_weight` fed from the
  /// tracker the server reads (`exercise_plans` in src/server/workout.rs).
  double? _calibrationStartFor(Exercise exercise) {
    final tracker = trackerFor(exercise);
    return calibrationStartWeight(
      exercise,
      seedWeightLb: tracker?.workingWeight ?? 0,
      performedBefore: (tracker?.lastPerformedAt ?? Int64.ZERO) > Int64.ZERO,
      unit: _settingsProvider.weightUnit,
    );
  }

  /// How many working sets an optimistic add plans for one exercise. The
  /// SAME formula generates the client set ids in addPrescribedExercises —
  /// if they diverge, the ids misalign with the sets. A calibrating
  /// exercise is one rung, and the server hands that rung the first id.
  int _prescribedSetCount(Exercise exercise) =>
      _calibrationStartFor(exercise) != null
      ? 1
      : (trackerFor(exercise)?.sets ?? 3).clamp(1, 10);

  void _applyLocalAddExercises(
    List<Exercise> exercises,
    List<String> workingSetIds,
  ) {
    final workout = _activeWorkout;
    if (workout == null) return;
    var order = _activeProposedSets.isEmpty
        ? 0
        : _activeProposedSets.last.workoutOrder + 1;
    final existingIds = _activeProposedSets.map((s) => s.id).toSet();
    var idIndex = 0;
    for (final exercise in exercises) {
      final tracker = trackerFor(exercise);
      final count = _prescribedSetCount(exercise);
      final rampStart = _calibrationStartFor(exercise);
      for (var i = 0; i < count; i++) {
        final id = idIndex < workingSetIds.length
            ? workingSetIds[idIndex++]
            : _uuid.v4();
        // Replaying a mutation the server already applied must not
        // duplicate the sets.
        if (existingIds.contains(id)) continue;
        if (rampStart != null) {
          _activeProposedSets.add(
            calibrationSet(
              id: id,
              workoutId: workout.id,
              exercise: exercise,
              weightLb: rampStart,
            )..workoutOrder = order++,
          );
          continue;
        }
        _activeProposedSets.add(
          ProposedSet()
            ..id = id
            ..workoutId = workout.id
            ..workoutOrder = order++
            ..exercise = exercise
            // Fallbacks mirror DEFAULT_*_REST_SECONDS and the 8-12 range
            // bottom in src/workout/planning.rs / exercise_catalog.rs.
            ..targetReps = tracker?.targetReps ?? 8
            ..targetWeight = tracker?.workingWeight ?? 0
            ..restAfterSuccess = (tracker != null && tracker.restSeconds > 0)
                ? tracker.restSeconds
                : 180
            ..restAfterFailure =
                (tracker != null && tracker.restSecondsFailure > 0)
                ? tracker.restSecondsFailure
                : 300,
        );
      }
    }
    _refreshDerivedState();
  }

  void _applyLocalAdjustExerciseWeight(Exercise exercise, double weightLb) {
    if (_applyLocalTypedCalibrationWeight(exercise, weightLb)) {
      _refreshDerivedState();
      return;
    }
    final completedIds = _activeCompletedSets
        .map((c) => c.proposedSetId)
        .toSet();
    for (final set in _activeProposedSets) {
      if (set.exercise != exercise || set.warmup || set.cancelled) continue;
      if (completedIds.contains(set.id)) continue;
      set.targetWeight = weightLb;
    }
    // Pending warmups keep their old rungs for ~one round trip; the server
    // response swaps in the recalculated ladder without a blink.
    _refreshDerivedState();
  }

  /// "I know my weight": a typed weight while the exercise is mid-ramp — a
  /// pending calibration rung, or a done rung whose question is still
  /// unanswered — ends the ramp. Unanswered done rungs are recorded right
  /// (nothing appended), the pending rungs go, and the prescription's full
  /// working sets take their place at the snapped weight. Their ids derive
  /// from the first pending rung, else the unanswered done rung, so both
  /// reducers agree. No warmup ladder: the ramp was the warmup. Returns
  /// false when the exercise is not mid-ramp, leaving the ordinary adjust
  /// to run. Mirrors the calibration branch of `apply_adjust_exercise_weight`.
  bool _applyLocalTypedCalibrationWeight(Exercise exercise, double weightLb) {
    final workout = _activeWorkout;
    if (workout == null) return false;
    _sortState();
    final pendingRungs = _activeProposedSets
        .where(
          (s) =>
              s.exercise == exercise &&
              s.calibration &&
              !s.cancelled &&
              !_isDoneSet(s.id),
        )
        .toList();
    bool isRungOf(CompletedSet c, {required bool liveOnly}) {
      final p = _proposedById(c.proposedSetId);
      return p != null &&
          p.exercise == exercise &&
          p.calibration &&
          (!liveOnly || !p.cancelled);
    }

    bool isOpen(CompletedSet c) =>
        c.endedAt != Int64.ZERO && c.effort == Effort.EFFORT_UNSPECIFIED;
    // The latest unanswered done rung of this exercise.
    CompletedSet? open;
    for (final c in _activeCompletedSets) {
      if (!isOpen(c) || !isRungOf(c, liveOnly: true)) continue;
      if (open == null || c.endedAt >= open.endedAt) open = c;
    }
    final String baseId;
    int at;
    if (pendingRungs.isNotEmpty) {
      baseId = pendingRungs.first.id;
      at = _activeProposedSets.indexWhere((s) => s.id == baseId);
    } else if (open != null) {
      final rungId = open.proposedSetId;
      final idx = _activeProposedSets.indexWhere((s) => s.id == rungId);
      if (idx < 0) return false;
      baseId = open.id;
      at = idx + 1;
    } else {
      return false;
    }
    // close_open_rungs: every unanswered done rung of the exercise.
    for (final c in _activeCompletedSets) {
      if (isOpen(c) && isRungOf(c, liveOnly: false)) {
        c.effort = Effort.EFFORT_RIGHT;
      }
    }

    final pendingIds = pendingRungs.map((s) => s.id).toSet();
    _activeProposedSets.removeWhere((s) => pendingIds.contains(s.id));
    final p = prescriptionFor(exercise);
    final weight = snapWeightLb(
      exercise,
      weightLb,
      _settingsProvider.weightUnit,
    );
    final working = [
      for (var n = 0; n < (p.sets < 1 ? 1 : p.sets); n++)
        ProposedSet()
          ..id = appendedSetId(baseId, n)
          ..workoutId = workout.id
          ..exercise = exercise
          ..targetReps = p.repLow
          ..targetWeight = weight
          ..warmup = false
          ..restAfterSuccess = p.restSeconds
          ..restAfterFailure = p.restSecondsFailure
          ..cancelled = false
          ..calibration = false,
    ];
    // Pending rungs only ever sit after the done ones, so `at` is unmoved.
    if (at > _activeProposedSets.length) at = _activeProposedSets.length;
    _activeProposedSets.insertAll(at, working);
    for (var i = 0; i < _activeProposedSets.length; i++) {
      _activeProposedSets[i].workoutOrder = i;
    }
    return true;
  }

  void _applyLocalRemoveExercise(Exercise exercise) {
    final completedIds = _activeCompletedSets
        .map((c) => c.proposedSetId)
        .toSet();
    for (final set in _activeProposedSets) {
      if (set.exercise != exercise || completedIds.contains(set.id)) continue;
      set.cancelled = true;
    }
    _refreshDerivedState();
  }

  void _applyLocalReorderExercises(List<Exercise> exercises) {
    final rank = <Exercise, int>{
      for (var i = 0; i < exercises.length; i++) exercises[i]: i,
    };
    _activeProposedSets.sort((a, b) {
      final rankA = rank[a.exercise] ?? rank.length;
      final rankB = rank[b.exercise] ?? rank.length;
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.workoutOrder.compareTo(b.workoutOrder);
    });
    for (var i = 0; i < _activeProposedSets.length; i++) {
      _activeProposedSets[i].workoutOrder = i;
    }
    _refreshDerivedState();
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
    final nowUnix = _now.millisecondsSinceEpoch ~/ 1000;
    final isCurrentlyResting =
        snapshot.state == WorkoutState.WORKOUT_STATE_RESTING &&
        snapshot.restUntil.toInt() > nowUnix;

    if (_wasResting && !isCurrentlyResting && !_sandbox) {
      await NotificationService.cancelRest();
      _soundProvider?.playCurrentSound();
      unawaited(NotificationService.playRestCompletionHaptic());
    }
    _wasResting = isCurrentlyResting;
  }

  void _sortState() {
    _activeProposedSets.sort(
      (a, b) => a.workoutOrder.compareTo(b.workoutOrder),
    );
  }

  List<ProposedSet> _visibleProposedSetsSorted() {
    final sets = _activeProposedSets.where((s) => !s.cancelled).toList();
    sets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    return sets;
  }

  /// An exercise's undone warmup once it was skipped or one of the
  /// exercise's working sets is done: behind you, never removed, still
  /// doable. Mirrors `is_passed_warmup`.
  bool isPassedWarmup(ProposedSet set) =>
      set.warmup &&
      !_isDoneSet(set.id) &&
      (set.skipped ||
          _activeProposedSets.any(
            (p) =>
                p.exercise == set.exercise &&
                !p.cancelled &&
                !p.warmup &&
                _isDoneSet(p.id),
          ));

  /// The set up next: carry on with the exercise of the latest done set
  /// while it has sets left, else the first open set in plan order. Passed
  /// warmups are not open. Mirrors `compute_next_up_set` (the rung case is
  /// [_awaitingRampSet]).
  ProposedSet? _firstUncompletedSet() {
    final open = _visibleProposedSetsSorted()
        .where((s) => !_isDoneSet(s.id) && !isPassedWarmup(s))
        .toList();
    final last = _lastDoneSet();
    final exercise = last == null
        ? null
        : _proposedById(last.proposedSetId)?.exercise;
    if (exercise != null) {
      for (final s in open) {
        if (s.exercise == exercise) return s;
      }
    }
    return open.isEmpty ? null : open.first;
  }

  /// The tiny optimistic layer: after a local set change, advance the
  /// highlight to the next set and derive the state the same way
  /// `workout_state_snapshot_from_state` in `src/workout/reducer.rs` does.
  /// The authoritative snapshot comes from the server response a beat later.
  void _refreshDerivedState() {
    _sortState();
    final nextUp = _firstUncompletedSet();
    _backendNextUpSet = nextUp;
    final now = _nowSecs;
    // The question outlives the state: a calibration rung can be the last
    // set in the plan (ALL_DONE) and its answer is what appends the rest.
    final prompt = _effortPromptFromState();

    // A started set that is still pending is being lifted, whatever the
    // rest: the timer counts up from its start. Mirrors the LIFTING branch
    // of `workout_state_snapshot`.
    final workout = _activeWorkout;
    final liftingId = workout?.liftingSetId ?? '';
    if (liftingId.isNotEmpty) {
      final lifting = _proposedById(liftingId);
      final done = _activeCompletedSets.any(
        (c) => c.proposedSetId == liftingId && c.endedAt != Int64.ZERO,
      );
      if (lifting != null && !lifting.cancelled && !done) {
        _applyStateSnapshot(
          WorkoutStateSnapshot(
            state: WorkoutState.WORKOUT_STATE_LIFTING,
            displaySet: lifting,
            effortPrompt: prompt,
            liftingStartedAt: workout!.liftingStartedAt,
          ),
        );
        _rebuildBlocksCache();
        return;
      }
    }

    // A rung still asking decides what is next, whatever else is pending:
    // its "right" appends the working sets straight after it, and the
    // first of them is what Done will log — never past the user's own
    // working sets. The next-up set follows it. Mirrors
    // `awaiting_ramp_set`.
    final awaiting = _awaitingRampSet();
    if (awaiting != null) {
      _backendNextUpSet = awaiting.$1;
      // A rung was just done, so this is resting or, once its rest has
      // run out, yapping.
      final resting = awaiting.$2 > Int64(now);
      _applyStateSnapshot(
        WorkoutStateSnapshot(
          state: resting
              ? WorkoutState.WORKOUT_STATE_RESTING
              : WorkoutState.WORKOUT_STATE_YAPPING,
          displaySet: awaiting.$1,
          restUntil: awaiting.$2,
          effortPrompt: prompt,
        ),
      );
      _rebuildBlocksCache();
      return;
    }

    // Nothing pending: the workout is finished.
    if (nextUp == null) {
      _applyStateSnapshot(
        WorkoutStateSnapshot(
          state: WorkoutState.WORKOUT_STATE_ALL_DONE,
          effortPrompt: prompt,
        ),
      );
      _rebuildBlocksCache();
      return;
    }

    // After a done set: resting while its rest runs, yapping once it has run
    // out, both timed from that rest's end (down to it, up from it). The
    // target was stored locally on completion, so the timers keep running
    // off the device clock even with no connection. Mirrors
    // `workout_state_snapshot_from_state`.
    final lastDone = _lastDoneSet();
    if (lastDone != null) {
      final restEnd = lastDone.restUntil > lastDone.endedAt
          ? lastDone.restUntil
          : lastDone.endedAt;
      _applyStateSnapshot(
        WorkoutStateSnapshot(
          state: restEnd > Int64(now)
              ? WorkoutState.WORKOUT_STATE_RESTING
              : WorkoutState.WORKOUT_STATE_YAPPING,
          displaySet: nextUp,
          restUntil: restEnd,
          effortPrompt: prompt,
        ),
      );
      _rebuildBlocksCache();
      return;
    }

    // Nothing done yet: the first set is ready.

    _applyStateSnapshot(
      WorkoutStateSnapshot(
        state: WorkoutState.WORKOUT_STATE_READY,
        displaySet: nextUp,
        effortPrompt: prompt,
      ),
    );
    _rebuildBlocksCache();
  }

  /// A server snapshot is a photo of one instant. Once the rest it
  /// describes has run out the server would say YAPPING, so re-derive from
  /// the sets at the current clock. Nothing is resolved by rest ending.
  void _rederiveWhenRestEnds() {
    final snapshot = _stateSnapshot;
    if (snapshot == null || !hasActiveWorkout) return;
    if (snapshot.state != WorkoutState.WORKOUT_STATE_RESTING ||
        snapshot.restUntil > Int64(_nowSecs)) {
      return;
    }
    _refreshDerivedState();
    notifyListeners();
  }

  // ── Effort and calibration: the Dart half of src/workout/reducer.rs ──

  /// The most recently finished set, by `ended_at`. Ties go to the later
  /// row, as Rust's `max_by_key` does.
  CompletedSet? _lastDoneSet() {
    CompletedSet? last;
    for (final s in _activeCompletedSets) {
      if (s.endedAt == Int64.ZERO) continue;
      if (last == null || s.endedAt >= last.endedAt) last = s;
    }
    return last;
  }

  bool _isDoneSet(String proposedId) => _activeCompletedSets.any(
    (c) => c.proposedSetId == proposedId && c.endedAt != Int64.ZERO,
  );

  ProposedSet? _proposedById(String id) {
    for (final set in _activeProposedSets) {
      if (set.id == id) return set;
    }
    return null;
  }

  /// Whether "how was that" is asked after this done set: every working
  /// set and every calibration rung, never a warmup. Mirrors
  /// `is_prompt_worthy`.
  bool _isPromptWorthy(CompletedSet done) {
    if (done.endedAt == Int64.ZERO) return false;
    final proposed = _proposedById(done.proposedSetId);
    if (proposed == null || proposed.cancelled) return false;
    return proposed.calibration || !proposed.warmup;
  }

  /// The question on screen: the latest done set while it is prompt-worthy,
  /// whatever the rest state, with its current answer. Mirrors
  /// `effort_prompt_from_state`.
  EffortPrompt? _effortPromptFromState() {
    final last = _lastDoneSet();
    if (last == null || !_isPromptWorthy(last)) return null;
    final proposed = _proposedById(last.proposedSetId);
    if (proposed == null) return null;
    return EffortPrompt(
      exercise: proposed.exercise,
      completedSetId: last.id,
      calibration: proposed.calibration,
      effort: last.effort,
    );
  }

  /// Every prompt-worthy done set still unanswered is recorded "right",
  /// oldest first. CompleteSet runs this with [extendRamp] (an unanswered
  /// rung appends the next sets before the Done lands); EndWorkout runs it
  /// without — pending rows on a finished workout are wrong. Nothing else
  /// resolves. Mirrors `resolve_unanswered`.
  void _resolveUnanswered({required bool extendRamp}) {
    while (true) {
      CompletedSet? open;
      for (final set in _activeCompletedSets) {
        if (set.effort != Effort.EFFORT_UNSPECIFIED || !_isPromptWorthy(set)) {
          continue;
        }
        // Rust's min_by_key keeps the first of equal keys.
        if (open == null || set.endedAt < open.endedAt) open = set;
      }
      if (open == null) return;
      _applyEffort(open, Effort.EFFORT_RIGHT, extendRamp: extendRamp);
    }
  }

  /// Answer "how was that" for the latest done set — or change the
  /// answer, until the next Done. Any other set is a no-op. On a rung a
  /// changed answer takes back what the old one appended, but only when the
  /// exercise's pending sets are exactly that append (otherwise — weight
  /// typed, exercise removed — only the answer changes), then appends for
  /// the new one. Mirrors `apply_rate_exercise_to_active`.
  void _recordEffort(String completedSetId, Effort effort) {
    final workout = _activeWorkout;
    if (workout == null || effort == Effort.EFFORT_UNSPECIFIED) return;
    if (workout.endTime > Int64.ZERO) return;
    final done = _lastDoneSet();
    if (done == null || done.id != completedSetId) return;
    if (!_isPromptWorthy(done)) return;
    final old = done.effort;
    if (old == effort) return;
    final rung = _proposedById(done.proposedSetId);
    if (rung == null || !rung.calibration) {
      done.effort = effort;
      return;
    }
    if (old == Effort.EFFORT_UNSPECIFIED) {
      _applyEffort(done, effort, extendRamp: true);
      return;
    }
    final previous = _rampAppend(
      workout.id,
      done,
      rung,
      old,
    ).map((s) => s.id).toSet();
    final pending = _activeProposedSets
        .where(
          (s) =>
              s.exercise == rung.exercise && !s.cancelled && !_isDoneSet(s.id),
        )
        .map((s) => s.id)
        .toSet();
    if (previous.length != pending.length || !previous.containsAll(pending)) {
      done.effort = effort;
      return;
    }
    _activeProposedSets.removeWhere((s) => previous.contains(s.id));
    for (var i = 0; i < _activeProposedSets.length; i++) {
      _activeProposedSets[i].workoutOrder = i;
    }
    _applyEffort(done, effort, extendRamp: true);
  }

  /// Store [effort] on [done]; with [extendRamp], on a calibration rung
  /// apply the ramp rule: easy climbs a rung, right settles here, hard
  /// settles one rung down (the opener if this was the first). The sixth
  /// rung settles whatever the answer.
  void _applyEffort(
    CompletedSet done,
    Effort effort, {
    required bool extendRamp,
  }) {
    done.effort = effort;
    final workout = _activeWorkout;
    final rung = _proposedById(done.proposedSetId);
    if (workout == null || rung == null || !rung.calibration || !extendRamp) {
      return;
    }
    final appended = _rampAppend(workout.id, done, rung, effort);
    _insertSetsAfter(rung.id, appended);
  }

  /// What an answer on a rung appends, with ids derived from the done set
  /// so both reducers (and the phone's would-be Done target) agree.
  List<ProposedSet> _rampAppend(
    String workoutId,
    CompletedSet done,
    ProposedSet rung,
    Effort effort,
  ) {
    _sortState();
    final rungs = _activeProposedSets
        .where(
          (s) => s.exercise == rung.exercise && s.calibration && !s.cancelled,
        )
        .toList();
    var position = rungs.indexWhere((s) => s.id == rung.id);
    if (position < 0) position = 0;
    final effective = position + 1 >= maxCalibrationRungs
        ? Effort.EFFORT_RIGHT
        : effort;
    final unit = _settingsProvider.weightUnit;
    var n = 0;
    String nextId() => appendedSetId(done.id, n++);
    switch (effective) {
      case Effort.EFFORT_EASY:
        return [
          calibrationSet(
            id: nextId(),
            workoutId: workoutId,
            exercise: rung.exercise,
            weightLb: nextCalibrationWeight(
              rung.exercise,
              rung.targetWeight.toDouble(),
              unit,
            ),
          ),
        ];
      case Effort.EFFORT_HARD:
        final previous = position == 0
            ? rung.targetWeight
            : rungs[position - 1].targetWeight;
        return workingSetsAfterCalibration(
          workoutId: workoutId,
          exercise: rung.exercise,
          weightLb: previous.toDouble(),
          newId: nextId,
        );
      default:
        return workingSetsAfterCalibration(
          workoutId: workoutId,
          exercise: rung.exercise,
          weightLb: rung.targetWeight.toDouble(),
          newId: nextId,
        );
    }
  }

  /// The set an unanswered calibration rung is waiting on — the first set
  /// "right" would append — and that rung's rest end. Mirrors
  /// `awaiting_ramp_set`.
  (ProposedSet, Int64)? _awaitingRampSet() {
    final last = _lastDoneSet();
    final workout = _activeWorkout;
    if (last == null || workout == null) return null;
    if (last.effort != Effort.EFFORT_UNSPECIFIED) return null;
    final rung = _proposedById(last.proposedSetId);
    if (rung == null || !rung.calibration || rung.cancelled) return null;
    final next = _rampAppend(workout.id, last, rung, Effort.EFFORT_RIGHT);
    if (next.isEmpty) return null;
    return (next.first, last.restUntil);
  }

  /// Splice [sets] in straight after the set [afterId], ahead of whatever
  /// follows it (another exercise's block included), and renumber. Falls
  /// back to the end when the anchor is missing. Mirrors `insert_sets_after`.
  void _insertSetsAfter(String afterId, List<ProposedSet> sets) {
    final anchor = _activeProposedSets.indexWhere((s) => s.id == afterId);
    final at = anchor < 0 ? _activeProposedSets.length : anchor + 1;
    _activeProposedSets.insertAll(at, sets);
    for (var i = 0; i < _activeProposedSets.length; i++) {
      _activeProposedSets[i].workoutOrder = i;
    }
  }

  /// Correct a done set after the fact: reps and weight change, and the
  /// rest is recomputed from `endedAt` by the same rule Done used. An
  /// unknown set is a no-op. Mirrors `apply_edit_completed_set_to_active`.
  void _applyLocalEditCompletedSet(
    String completedSetId,
    int actualReps,
    double actualWeight,
  ) {
    final idx = _activeCompletedSets.indexWhere(
      (c) => c.id == completedSetId && c.endedAt != Int64.ZERO,
    );
    if (idx == -1) return;
    final set = _activeCompletedSets[idx];
    final proposed = _proposedById(set.proposedSetId);
    if (proposed == null) return;
    final isFinal = _isFinalSetOfExerciseAfterCompletion(proposed.id);
    final rest = _restSecondsAfter(proposed, actualReps, isFinal);
    set
      ..actualReps = actualReps
      ..actualWeight = actualWeight
      ..restUntil = set.endedAt + Int64(rest);
    // Tapped down below a rung's target: the miss answers it, hard.
    if (_missedRung(proposed, actualReps)) {
      _recordEffort(completedSetId, Effort.EFFORT_HARD);
    }
    _refreshDerivedState();
  }

  void _rebuildBlocksCache() {
    _blocksCache
      ..clear()
      ..addAll(blocksFromSets(_activeProposedSets));
  }

  void _applyWorkoutResponse(GetWorkoutResponse response) {
    _resetWearHeartRateBufferIfWorkoutChanged(response.workout.id);
    _activeWorkout = response.workout;
    _activeProposedSets = List.from(response.proposedSets);
    _activeCompletedSets = List.from(response.completedSets);
    // Authoritative state comes from the server — never recomputed locally.
    _sortState();
    _backendNextUpSet = response.hasNextUpSet() ? response.nextUpSet : null;
    if (response.hasStateSnapshot()) {
      _applyStateSnapshot(response.stateSnapshot);
    }
    _rebuildBlocksCache();
  }

  String? _workoutIdForMutation(WorkoutMutation mutation) {
    final payload = mutation.whichMutation();
    switch (payload) {
      case WorkoutMutation_Mutation.completeSet:
        return mutation.completeSet.workoutId;
      case WorkoutMutation_Mutation.deleteCompletedSet:
        return mutation.deleteCompletedSet.workoutId;
      case WorkoutMutation_Mutation.endWorkout:
        return mutation.endWorkout.workoutId;
      case WorkoutMutation_Mutation.addExercises:
        return mutation.addExercises.workoutId;
      case WorkoutMutation_Mutation.adjustExerciseWeight:
        return mutation.adjustExerciseWeight.workoutId;
      case WorkoutMutation_Mutation.removeExercise:
        return mutation.removeExercise.workoutId;
      case WorkoutMutation_Mutation.reorderExercises:
        return mutation.reorderExercises.workoutId;
      case WorkoutMutation_Mutation.rateExercise:
        return mutation.rateExercise.workoutId;
      case WorkoutMutation_Mutation.editCompletedSet:
        return mutation.editCompletedSet.workoutId;
      case WorkoutMutation_Mutation.startSet:
        return mutation.startSet.workoutId;
      case WorkoutMutation_Mutation.skipWarmups:
        return mutation.skipWarmups.workoutId;
      case WorkoutMutation_Mutation.notSet:
        return null;
    }
  }

  void _overlayPendingMutationsOnActiveWorkout() {
    final workout = _activeWorkout;
    if (workout == null) return;

    for (final mutation in _pendingMutations) {
      if (_workoutIdForMutation(mutation) != workout.id) continue;
      switch (mutation.whichMutation()) {
        case WorkoutMutation_Mutation.completeSet:
          _applyLocalCompleteSet(
            mutation.completeSet.proposedSetId,
            mutation.completeSet.actualReps,
            mutation.completeSet.actualWeight,
            completedAt: mutation.completeSet.completedAt.toInt(),
            effort: mutation.completeSet.effort,
          );
        case WorkoutMutation_Mutation.startSet:
          _applyLocalStartSet(
            mutation.startSet.proposedSetId,
            mutation.startSet.startedAt.toInt(),
          );
        case WorkoutMutation_Mutation.skipWarmups:
          _applyLocalSkipWarmups(mutation.skipWarmups.exercise);
        case WorkoutMutation_Mutation.deleteCompletedSet:
          _applyLocalDeleteCompletedSet(
            mutation.deleteCompletedSet.completedSetId,
          );
        case WorkoutMutation_Mutation.addExercises:
          _applyLocalAddExercises(
            mutation.addExercises.exercises,
            mutation.addExercises.clientWorkingSetIds,
          );
        case WorkoutMutation_Mutation.adjustExerciseWeight:
          _applyLocalAdjustExerciseWeight(
            mutation.adjustExerciseWeight.exercise,
            mutation.adjustExerciseWeight.workingWeight,
          );
        case WorkoutMutation_Mutation.removeExercise:
          _applyLocalRemoveExercise(mutation.removeExercise.exercise);
        case WorkoutMutation_Mutation.reorderExercises:
          _applyLocalReorderExercises(mutation.reorderExercises.exercises);
        case WorkoutMutation_Mutation.rateExercise:
          _recordEffort(
            mutation.rateExercise.completedSetId,
            mutation.rateExercise.effort,
          );
          _refreshDerivedState();
        case WorkoutMutation_Mutation.editCompletedSet:
          _applyLocalEditCompletedSet(
            mutation.editCompletedSet.completedSetId,
            mutation.editCompletedSet.actualReps,
            mutation.editCompletedSet.actualWeight,
          );
        case WorkoutMutation_Mutation.endWorkout:
        case WorkoutMutation_Mutation.notSet:
          continue;
      }
    }
  }

  Future<void> _persistLocalCache() async {
    if (_sandbox) return;
    final prefs = await SharedPreferences.getInstance();
    if (_activeWorkout == null) {
      await prefs.remove(_localWorkoutCacheKey);
    } else {
      final snapshot = GetWorkoutResponse(
        workout: _activeWorkout,
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
        'THIS VERSION OF SCHLIFT IS TOO OLD. PLEASE UPDATE FROM THE STORE.',
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

  /// The resolved tracker for one exercise. GetHome returns one for every
  /// exercise, so this only misses before the first home load.
  ExerciseTracker? trackerFor(Exercise exercise) {
    for (final tracker in trackers) {
      if (tracker.exercise == exercise) return tracker;
    }
    return null;
  }

  /// Refresh templates/trackers/volume without touching the active session.
  /// The one-shot "update your template?" offer from the last EndWorkout.
  TemplateUpdateSuggestion? takePendingTemplateUpdate() {
    final suggestion = _pendingTemplateUpdate;
    _pendingTemplateUpdate = null;
    return suggestion;
  }

  /// The backend this provider talks to; the Add sheet reads the template
  /// library through it so a sandboxed provider (the tutorial) stays
  /// sandboxed.
  WorkoutServiceWrapper get service => _service;

  Future<void> refreshHome() async {
    try {
      _home = await _service.getHome();
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

  /// Copies library entries into the user's templates (see
  /// templates/library.yaml). The response carries the refreshed home.
  Future<void> addLibraryTemplates(List<String> libraryIds) async {
    _home = await _service.addLibraryTemplates(libraryIds);
    notifyListeners();
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

  List<ExerciseBlock> get exerciseBlocks => _blocksCache;

  String _nextSetBody() {
    final next = nextPendingSet;
    if (next == null) return 'All sets complete!';
    final name = exerciseNames[next.exercise] ?? '?';
    final prefix = next.warmup ? 'Warmup ' : '';
    final w = next.targetWeight.toDouble();
    final weightStr = formatWeight(w, _settingsProvider.weightUnit);
    return 'Next up: $prefix$name, $weightStr ${weightUnitSuffix(_settingsProvider.weightUnit)} × ${next.targetReps}';
  }

  bool isSetDone(String setId) {
    return _activeCompletedSets.any((c) => c.proposedSetId == setId);
  }

  ProposedSet? get nextPendingSet {
    return _backendNextUpSet;
  }

  /// The open "how was that", or null. Live only while the rest it belongs
  /// to is running — exactly when the server would carry it.
  /// The question on screen, with its current answer, or null.
  EffortPrompt? get effortPrompt {
    final snapshot = _stateSnapshot;
    if (snapshot == null || !snapshot.hasEffortPrompt()) return null;
    return snapshot.effortPrompt;
  }

  /// The latest done set: the one whose rest is running or just ran.
  CompletedSet? get lastDoneSet => _lastDoneSet();

  /// The set up next: the state's display set — the next pending set, or
  /// while a rung is still asking, the set its "right" would append
  /// (`{done}:0`), so the circle and the banner show it before anything is
  /// sent. Derived by the same rule as the server's; the way to do another
  /// set is to start it.
  ProposedSet? get doneTargetSet {
    final snapshot = _stateSnapshot;
    if (snapshot != null && snapshot.hasDisplaySet()) {
      return snapshot.displaySet;
    }
    return _backendNextUpSet;
  }

  /// When the last done set's rest ends (or ended): the yapping count-up
  /// runs from here. Zero before the first set.
  Int64 get lastRestEnd => _lastDoneSet()?.restUntil ?? Int64.ZERO;

  ProposedSet? proposedSetById(String id) => _proposedById(id);

  /// The user's display unit; the watch snapshot formats weights with it.
  WeightUnit get weightUnit => _settingsProvider.weightUnit;

  int get restSecondsRemaining {
    final snapshot = _stateSnapshot;
    if (snapshot == null) return 0;
    if (snapshot.state != WorkoutState.WORKOUT_STATE_RESTING) return 0;
    final remaining =
        snapshot.restUntil.toInt() - (_now.millisecondsSinceEpoch ~/ 1000);
    return remaining > 0 ? remaining : 0;
  }

  void _applyStateSnapshot(WorkoutStateSnapshot? snapshot) {
    final oldRestUntil = _stateSnapshot?.restUntil.toInt();
    final oldState = _stateSnapshot?.state;

    _stateSnapshot = snapshot;

    if (_sandbox) {
      _wasResting =
          snapshot?.state == WorkoutState.WORKOUT_STATE_RESTING &&
          (snapshot?.restUntil.toInt() ?? 0) > _nowSecs;
      return;
    }

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
          final presetId = knownSoundPreset(_soundProvider?.currentPreset);
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
      // _checkRestSound reads the snapshot synchronously before its first
      // await, so it still sees the rest end if the re-derivation below
      // moves the state on.
      unawaited(_checkRestSound());
      _rederiveWhenRestEnds();
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

  /// True until this account has finished a workout: the banner explains
  /// each step during the first one only. Someone who has lifted before
  /// (any exercise performed) is never new, whatever this device recorded.
  bool get isFirstWorkout =>
      !_firstWorkoutDone &&
      !trackers.any((t) => t.lastPerformedAt > Int64.ZERO);
  // Until the device flag is read, assume done: no hint flashes up.
  bool _firstWorkoutDone = true;

  Future<void> _loadFirstWorkout(String userId) async {
    final done = await FirstWorkout.isDone(userId);
    if (done == _firstWorkoutDone) return;
    _firstWorkoutDone = done;
    notifyListeners();
  }

  Future<void> loadActiveWorkout(String userId) async {
    _lastLoadUserId = userId;
    if (!_sandbox) unawaited(_loadFirstWorkout(userId));
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
        _activeProposedSets = [];
        _activeCompletedSets = [];
        _backendNextUpSet = null;
        _applyStateSnapshot(null);
        _stopTimer();
      }

      _home = await _service.getHome();
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
    String name, {
    String templateId = '',
    List<Exercise> exercises = const [],
  }) async {
    try {
      if (!_sandbox) await NotificationService.cancelAll();
      _wasResting = false;
      final response = await _service.startWorkout(
        name,
        templateId: templateId,
        exercises: exercises,
      );
      _applyStartWorkoutResponse(response);
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
    CompleteSetRequest? completeSet,
    DeleteCompletedSetRequest? deleteCompletedSet,
    AddExercisesRequest? addExercises,
    AdjustExerciseWeightRequest? adjustExerciseWeight,
    RemoveExerciseRequest? removeExercise,
    ReorderExercisesRequest? reorderExercises,
    RateExerciseRequest? rateExercise,
    EditCompletedSetRequest? editCompletedSet,
    StartSetRequest? startSet,
    SkipWarmupsRequest? skipWarmups,
  }) {
    final mutation = WorkoutMutation()
      ..eventId = _uuid.v4()
      ..clientCreatedAt = Int64(createdAt);
    if (completeSet != null) {
      mutation.completeSet = completeSet;
    } else if (deleteCompletedSet != null) {
      mutation.deleteCompletedSet = deleteCompletedSet;
    } else if (addExercises != null) {
      mutation.addExercises = addExercises;
    } else if (adjustExerciseWeight != null) {
      mutation.adjustExerciseWeight = adjustExerciseWeight;
    } else if (removeExercise != null) {
      mutation.removeExercise = removeExercise;
    } else if (reorderExercises != null) {
      mutation.reorderExercises = reorderExercises;
    } else if (rateExercise != null) {
      mutation.rateExercise = rateExercise;
    } else if (editCompletedSet != null) {
      mutation.editCompletedSet = editCompletedSet;
    } else if (startSet != null) {
      mutation.startSet = startSet;
    } else if (skipWarmups != null) {
      mutation.skipWarmups = skipWarmups;
    }
    return mutation;
  }

  int get _nowSecs => _now.millisecondsSinceEpoch ~/ 1000;

  /// Mirrors `apply_start_set_to_active`: open questions resolve first;
  /// re-starting the set being lifted keeps its first start; a done,
  /// cancelled or unknown set is a no-op.
  void _applyLocalStartSet(String proposedSetId, int startedAt) {
    final workout = _activeWorkout;
    if (workout == null) return;
    _resolveUnanswered(extendRamp: true);
    final proposed = _proposedById(proposedSetId);
    final pending =
        proposed != null &&
        !proposed.cancelled &&
        !_activeCompletedSets.any((c) => c.proposedSetId == proposedSetId);
    if (pending && workout.liftingSetId != proposedSetId) {
      workout
        ..liftingSetId = proposedSetId
        ..liftingStartedAt = Int64(startedAt);
    }
    _refreshDerivedState();
  }

  // Tiny optimistic set edit: mutate the local list so the tap registers
  // instantly, then _refreshDerivedState advances the highlight. Mirrors
  // `apply_complete_set_to_active` in `src/workout/reducer.rs`: one done
  // row per set with the rest target and its start stored on it; any Done
  // ends the lifting; a rating given with it is recorded there and then.
  void _applyLocalCompleteSet(
    String proposedSetId,
    int actualReps,
    double actualWeight, {
    int? completedAt,
    Effort effort = Effort.EFFORT_UNSPECIFIED,
  }) {
    if (_activeWorkout == null) return;
    // Done is idempotent: a set already logged is never logged twice.
    final alreadyDone = _activeCompletedSets.any(
      (c) => c.proposedSetId == proposedSetId,
    );
    if (alreadyDone) return;
    // Every open question is answered "right" first, extending a ramp — so
    // a Done on the `{done}:0` an unanswered rung shows finds its set.
    _resolveUnanswered(extendRamp: true);
    // Set gone (skipped/cancelled, or a stale/duplicate at-least-once
    // intent): a no-op, as on the server.
    final proposed = _proposedById(proposedSetId);
    if (proposed == null || proposed.cancelled) {
      _refreshDerivedState();
      return;
    }
    final endedAt = Int64(completedAt ?? _nowSecs);
    final restUntil = _localRestUntil(proposedSetId, actualReps, endedAt);
    final workout = _activeWorkout!;
    final startedAt = workout.liftingSetId == proposedSetId
        ? workout.liftingStartedAt
        : Int64.ZERO;
    workout
      ..liftingSetId = ''
      ..liftingStartedAt = Int64.ZERO;
    final id = _uuid.v4();
    _activeCompletedSets.add(
      CompletedSet()
        ..id = id
        ..workoutId = workout.id
        ..proposedSetId = proposedSetId
        ..actualReps = actualReps
        ..actualWeight = actualWeight
        ..endedAt = endedAt
        ..restUntil = restUntil
        ..startedAt = startedAt,
    );
    // A rung short of its target has answered for itself: too heavy.
    final answer = _missedRung(proposed, actualReps)
        ? Effort.EFFORT_HARD
        : effort;
    if (answer != Effort.EFFORT_UNSPECIFIED) _recordEffort(id, answer);
    _refreshDerivedState();
  }

  /// A finding-weight rung done short of its target: the miss answers "how
  /// many more could you have done" — none, hard. Mirrors `missed_rung`.
  bool _missedRung(ProposedSet proposed, int actualReps) =>
      proposed.calibration && actualReps < proposed.targetReps;

  /// The rest-timer target for a just-completed set, computed locally so the
  /// countdown starts on the transition and survives signal loss — it's a
  /// stored target time (endedAt + rest), not a per-request server value. Mirrors
  /// `complete_set` in `src/workout/reducer.rs`: the rest *durations* are
  /// server-provided on the proposed set (`restAfterSuccess`/`restAfterFailure`);
  /// an exercise's final set uses the short end-of-exercise rest. The server reconciles
  /// with an identical target when the mutation lands.
  static const int _endOfExerciseRestSeconds =
      60; // END_OF_EXERCISE_REST_SECONDS

  Int64 _localRestUntil(String proposedSetId, int actualReps, Int64 endedAt) {
    final proposed = _proposedById(proposedSetId);
    if (proposed == null || proposed.cancelled) return Int64.ZERO;
    final isFinal = _isFinalSetOfExerciseAfterCompletion(proposedSetId);
    return endedAt + Int64(_restSecondsAfter(proposed, actualReps, isFinal));
  }

  /// How long to rest after a set: the success rest when the target was
  /// hit, the failure rest otherwise, and the short between-exercise rest
  /// after an exercise's final set. A calibration rung always rests its
  /// own 90 s — the ramp continues after the answer, so it is never final.
  /// Mirrors `rest_seconds_after`.
  int _restSecondsAfter(ProposedSet proposed, int actualReps, bool isFinal) {
    if (proposed.calibration) return proposed.restAfterSuccess;
    if (isFinal) return _endOfExerciseRestSeconds;
    return actualReps >= proposed.targetReps
        ? proposed.restAfterSuccess
        : proposed.restAfterFailure;
  }

  /// True when every other live set of this exercise is already completed —
  /// so finishing this one ends the exercise. Mirrors
  /// `is_final_set_of_exercise_after_completion` in the Rust reducer.
  bool _isFinalSetOfExerciseAfterCompletion(String proposedSetId) {
    final current = _proposedById(proposedSetId);
    if (current == null || current.cancelled) return false;
    for (final set in _activeProposedSets) {
      // Finishing a working set puts the exercise's undone warmups behind
      // you: they don't keep it open.
      if (set.exercise != current.exercise ||
          set.cancelled ||
          set.id == current.id ||
          (set.warmup && !current.warmup)) {
        continue;
      }
      if (!_isDoneSet(set.id)) return false;
    }
    return true;
  }

  void _applyLocalDeleteCompletedSet(String completedSetId) {
    _activeCompletedSets.removeWhere((c) => c.id == completedSetId);
    _refreshDerivedState();
  }

  Future<void> reorderExercises(List<Exercise> exercises) async {
    if (_activeWorkout == null) return;
    final createdAt = _now.millisecondsSinceEpoch ~/ 1000;

    // Optimistically update local state
    _applyLocalReorderExercises(exercises);
    notifyListeners();

    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        reorderExercises: ReorderExercisesRequest()
          ..workoutId = _activeWorkout!.id
          ..exercises.addAll(exercises),
      ),
    );
    unawaited(_persistLocalCache());
    onSessionRefreshNeeded?.call();
  }

  /// Skip [exercise]'s warmups (the warmup row's "Skip"): its undone warmups are marked
  /// skipped — kept, out of the way, still doable. Mirrors
  /// `apply_skip_warmups_to_active`.
  Future<void> skipWarmups(Exercise exercise) async {
    if (_activeWorkout == null) return;
    _applyLocalSkipWarmups(exercise);
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: _nowSecs,
        skipWarmups: SkipWarmupsRequest()
          ..workoutId = _activeWorkout!.id
          ..exercise = exercise,
      ),
      immediate: true,
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  void _applyLocalSkipWarmups(Exercise exercise) {
    for (final s in _activeProposedSets) {
      if (s.exercise == exercise &&
          s.warmup &&
          !s.cancelled &&
          !_isDoneSet(s.id)) {
        s.skipped = true;
      }
    }
    _refreshDerivedState();
  }

  /// Begin a set: the workout is LIFTING it until its Done, the timer
  /// counting up from now. Mirrors `apply_start_set_to_active`.
  Future<void> startSet(String proposedSetId, {int? startedAt}) async {
    if (_activeWorkout == null) return;
    startedAt ??= _nowSecs;
    _applyLocalStartSet(proposedSetId, startedAt);
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

  /// Log a set as done. [effort] (Easy / Good / Hard) answers "how was
  /// that" for it in the same mutation; leave it unspecified for a warmup.
  Future<void> completeSet(
    String proposedSetId,
    int actualReps,
    double actualWeight, {
    int? completedAt,
    Effort effort = Effort.EFFORT_UNSPECIFIED,
  }) async {
    if (_activeWorkout == null) return;
    final endedAt = completedAt ?? (_now.millisecondsSinceEpoch ~/ 1000);
    _applyLocalCompleteSet(
      proposedSetId,
      actualReps,
      actualWeight,
      completedAt: endedAt,
      effort: effort,
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
          ..completedAt = Int64(endedAt)
          ..effort = effort,
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

  /// Correct a done set: fewer reps than planned, a different weight. The
  /// rest is recomputed from when the set ended. The range checks are the
  /// server's (`apply_edit_completed_set_to_active`), which would reject
  /// anything outside them.
  Future<void> editCompletedSet(
    String completedSetId,
    int actualReps,
    double actualWeight,
  ) async {
    if (_activeWorkout == null) return;
    if (actualReps < 0 || actualWeight < 0 || actualWeight > 2000) return;
    final createdAt = _nowSecs;
    _applyLocalEditCompletedSet(completedSetId, actualReps, actualWeight);
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        editCompletedSet: EditCompletedSetRequest()
          ..workoutId = _activeWorkout!.id
          ..completedSetId = completedSetId
          ..actualReps = actualReps
          ..actualWeight = actualWeight,
      ),
      immediate: true,
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  /// A tap on a done set's circle, StrongLifts style: each tap takes one
  /// rep off (one per rep missed), and the tap after zero undoes the set.
  /// A finding-weight rung stops at zero instead: the plan it settled hangs
  /// off it.
  Future<void> tapDoneSet(String completedSetId) async {
    final done = _activeCompletedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.id == completedSetId && c.endedAt != Int64.ZERO,
      orElse: () => null,
    );
    if (done == null) return;
    if (done.actualReps > 0) {
      await editCompletedSet(
        completedSetId,
        done.actualReps - 1,
        done.actualWeight,
      );
      return;
    }
    if (_proposedById(done.proposedSetId)?.calibration ?? true) return;
    await deleteCompletedSet(completedSetId);
  }

  /// Answer "how was that" for a done set. On a calibration rung the
  /// answer also shapes the plan (another rung, or the working sets).
  Future<void> rateExercise(String completedSetId, Effort effort) async {
    if (_activeWorkout == null) return;
    if (effort == Effort.EFFORT_UNSPECIFIED) return;
    final createdAt = _nowSecs;
    _recordEffort(completedSetId, effort);
    _refreshDerivedState();
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        rateExercise: RateExerciseRequest()
          ..workoutId = _activeWorkout!.id
          ..completedSetId = completedSetId
          ..effort = effort,
      ),
      immediate: true,
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  /// Add exercises to the active workout with the app in charge of the
  /// numbers: weight/sets/reps/rest/warmups from each exercise's tracker —
  /// exactly what a template start would prescribe. The user picks
  /// movements; adjusting a weight is its own flow.
  Future<void> addPrescribedExercises(List<Exercise> exercises) async {
    if (_activeWorkout == null || exercises.isEmpty) return;
    final createdAt = _now.millisecondsSinceEpoch ~/ 1000;
    // Client-chosen working-set ids so an offline add's completions
    // reconcile when the queued mutation lands. Warmups are server-only.
    final workingSetIds = <String>[
      for (final exercise in exercises)
        for (var i = 0; i < _prescribedSetCount(exercise); i++) _uuid.v4(),
    ];
    _applyLocalAddExercises(exercises, workingSetIds);
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        addExercises: AddExercisesRequest()
          ..workoutId = _activeWorkout!.id
          ..exercises.addAll(exercises)
          ..clientWorkingSetIds.addAll(workingSetIds),
      ),
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  /// Move an exercise's remaining working sets to a new weight (lb). The
  /// server regenerates its pending warmups for it.
  Future<void> adjustExerciseWeight(Exercise exercise, double weightLb) async {
    if (_activeWorkout == null) return;
    final createdAt = _now.millisecondsSinceEpoch ~/ 1000;
    _applyLocalAdjustExerciseWeight(exercise, weightLb);
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        adjustExerciseWeight: AdjustExerciseWeightRequest()
          ..workoutId = _activeWorkout!.id
          ..exercise = exercise
          ..workingWeight = weightLb,
      ),
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  /// Cancel an exercise's remaining sets. Sets already done stay.
  Future<void> removeExercise(Exercise exercise) async {
    if (_activeWorkout == null) return;
    final createdAt = _now.millisecondsSinceEpoch ~/ 1000;
    _applyLocalRemoveExercise(exercise);
    _queueMutation(
      _buildMutation(
        workoutId: _activeWorkout!.id,
        createdAt: createdAt,
        removeExercise: RemoveExerciseRequest()
          ..workoutId = _activeWorkout!.id
          ..exercise = exercise,
      ),
    );
    await _persistLocalCache();
    notifyListeners();
    onSessionRefreshNeeded?.call();
  }

  /// What the session actually contained, compared against the template it
  /// started from. Returns the offer to make, or null when nothing
  /// changed (or nothing was done).
  TemplateUpdateSuggestion? _computeTemplateUpdateSuggestion(Workout ended) {
    // Exercises with at least one completed working set, in workout order.
    final doneSetIds = _activeCompletedSets.map((c) => c.proposedSetId).toSet();
    final ordered = List<ProposedSet>.from(
      _activeProposedSets.where(
        (p) => !p.warmup && !p.cancelled && doneSetIds.contains(p.id),
      ),
    )..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    final performed = <Exercise>[];
    for (final set in ordered) {
      if (!performed.contains(set.exercise)) performed.add(set.exercise);
    }
    if (performed.isEmpty) return null;

    if (ended.templateId.isEmpty) {
      return TemplateUpdateSuggestion(
        templateId: '',
        templateName: '',
        exercises: performed,
      );
    }
    final template = templates.cast<WorkoutTemplate?>().firstWhere(
      (t) => t!.id == ended.templateId,
      orElse: () => null,
    );
    if (template == null) return null;
    final planned = template.exercises.toSet();
    final same =
        planned.length == performed.length && planned.containsAll(performed);
    if (same) return null;
    return TemplateUpdateSuggestion(
      templateId: template.id,
      templateName: template.name,
      exercises: performed,
    );
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
      if (!_sandbox) await NotificationService.cancelAll();
      _wasResting = false;
      // The server closes every open question as "right" at EndWorkout
      // without extending a ramp; keep the local rows in step.
      _resolveUnanswered(extendRamp: false);
      final response = await _service.endWorkout(_activeWorkout!.id);
      final ended = response.workout;
      _pendingTemplateUpdate = _computeTemplateUpdateSuggestion(ended);
      _activeWorkout = ended;
      _pendingMutations.clear();
      _stopTimer();
      final userId = _lastLoadUserId;
      if (!_sandbox && userId != null) {
        _firstWorkoutDone = true;
        unawaited(FirstWorkout.markDone(userId));
      }
      await _persistLocalCache();
      notifyListeners();

      // Fire-and-forget: never blocks workout completion
      if (!_sandbox) _writeToHealthPlatform(ended);
      // The trackers just advanced server-side; pull the new numbers so
      // home shows them the moment the user lands back on it.
      unawaited(refreshHome());

      if (fireEndedCallback) {
        onWorkoutEnded?.call(ended.id);
      }
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
        final proposed = _activeProposedSets.cast<ProposedSet?>().firstWhere(
          (p) => p!.id == cs.proposedSetId,
          orElse: () => null,
        );
        if (proposed != null && isWorkingSet(proposed)) {
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
          backgroundColor: schliftSpec.success,
          textColor: schliftSpec.onPrimary,
        );
      } else if (result == HealthWriteResult.permissionDenied) {
        Fluttertoast.showToast(
          msg: 'Health Connect permission denied. Enable in settings',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: schliftSpec.warning,
          textColor: schliftSpec.onPrimary,
        );
      }
    } catch (e, st) {
      debugPrint('Health: write failed: $e\n$st');
      Fluttertoast.showToast(
        msg: 'Failed to sync workout to Health Connect',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: schliftSpec.error,
        textColor: schliftSpec.onPrimary,
      );
    }
  }

  Future<void> clear() async {
    if (!_sandbox) await NotificationService.cancelAll();
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
      if (!_sandbox) {
        unawaited(
          HealthService.writeHeartRateSamples(
            workoutId: workout.id,
            samples: batch,
          ),
        );
      }
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
