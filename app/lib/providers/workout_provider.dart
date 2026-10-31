import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../logic/first_workout.dart';
import '../logic/audio.dart';
import '../logic/exercise_blocks.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../services/workout_service.dart';
import '../providers/sound_provider.dart';
import '../services/notification_service.dart';
import '../services/health_service.dart' show HealthService, HealthWriteResult;
import '../services/error_modal_service.dart';
import '../logic/exercises.dart';
import '../logic/utils.dart';
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

/// The workout under way and the home around it, as the core on this phone
/// says they are. Every action is one call into the core (see
/// [WorkoutServiceWrapper]) and the answer is the new state — there is no
/// copy of the rules here, and nothing waits on the network.
class WorkoutProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const int _maxWearHeartRateSamplesInMemory = 50000;

  /// Heart rate is written to the account in batches this far apart.
  static const _heartRateBatchEvery = Duration(seconds: 5);

  final WorkoutServiceWrapper _service;
  final SettingsProvider _settingsProvider;
  SoundProvider? _soundProvider;
  double _bodyWeightKg = 0;

  /// Called after endWorkout() completes successfully, with the finished
  /// workout's id. Used by the app shell to navigate to the summary screen
  /// when the workout is ended from a source that can't navigate itself
  /// (e.g. the watch).
  void Function(String workoutId)? onWorkoutEnded;

  void setBodyWeightKg(double kg) => _bodyWeightKg = kg;

  bool _isLoading = false;
  String? _lastLoadError;

  // The workout on screen: the active one, or the one just ended.
  Workout? _workout;
  List<ProposedSet> _proposed = [];
  List<CompletedSet> _completed = [];
  Set<String> _passedWarmups = {};
  ProposedSet? _nextUp;
  WorkoutStateSnapshot? _snapshot;
  GetHomeResponse? _home;
  TemplateUpdateSuggestion? _pendingTemplateUpdate;

  final List<HeartRateSample> _wearHeartRateSamples = [];
  final Set<String> _wearHeartRateBatchIds = <String>{};
  final Set<int> _wearHeartRateSampleTimestamps = <int>{};
  final List<WorkoutHeartRatePoint> _unsavedHeartRate = [];
  DateTime? _lastHeartRateSave;
  bool _heartRateSaveInFlight = false;

  bool _wasResting = false;
  Timer? _timer;
  DateTime _now = DateTime.now();
  late final ValueNotifier<DateTime> _clock = ValueNotifier<DateTime>(_now);
  final List<ExerciseBlock> _blocksCache = [];
  late final UnmodifiableListView<HeartRateSample> _wearHeartRateSamplesView =
      UnmodifiableListView(_wearHeartRateSamples);

  /// [sandbox] is the tutorial's provider: an in-memory account behind it
  /// and nothing real in front. It never schedules or cancels OS
  /// notifications, plays no sound, writes nothing to the health platform
  /// and leaves the notification tap handler to the real provider.
  WorkoutProvider(this._service, this._settingsProvider, {bool sandbox = false})
    : _sandbox = sandbox {
    WidgetsBinding.instance.addObserver(this);
  }

  final bool _sandbox;

  void _setNow(DateTime value) {
    _now = value;
    _clock.value = value;
  }

  int get _nowSecs => _now.millisecondsSinceEpoch ~/ 1000;

  void setSoundProvider(SoundProvider provider) {
    _soundProvider = provider;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setNow(DateTime.now());
      notifyListeners();
    }
  }

  // ── State from the core ──

  void _applyWorkoutResponse(GetWorkoutResponse response) {
    _resetWearHeartRateBufferIfWorkoutChanged(response.workout.id);
    _workout = response.workout;
    _proposed = List.of(response.proposedSets)
      ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    _completed = List.of(response.completedSets);
    _passedWarmups = response.passedWarmupIds.toSet();
    _nextUp = response.hasNextUpSet() ? response.nextUpSet : null;
    _applyStateSnapshot(
      response.hasStateSnapshot() ? response.stateSnapshot : null,
    );
    _blocksCache
      ..clear()
      ..addAll(blocksFromSets(_proposed));
  }

  /// Read the workout on screen again from the core: after a change, or
  /// when time alone moves its state on (a rest running out).
  Future<void> _reload() async {
    final workout = _workout;
    if (workout == null) return;
    _applyWorkoutResponse(await _service.getWorkout(workout.id));
    notifyListeners();
  }

  /// Apply one change to the workout on screen.
  Future<void> _mutate(WorkoutMutation mutation) async {
    if (_workout == null) return;
    try {
      final response = await _service.appendWorkoutMutations([mutation]);
      if (response.hasWorkoutState()) {
        _applyWorkoutResponse(response.workoutState);
      }
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  String get _workoutId => _workout!.id;

  void _handleError(Object e) {
    AppLogger.instance.error('Workout', 'core call failed', {
      'error': e.toString(),
    });
    ErrorModalService.showError(cleanErrorMessage(e).toUpperCase());
  }

  // ── Rest end: sound and state ──

  /// Called every second. The in-app sound at rest end is the primary
  /// path; the OS notification is the fallback for when the app is killed.
  Future<void> _checkRestSound() async {
    final snapshot = _snapshot;
    if (snapshot == null) {
      _wasResting = false;
      return;
    }
    final isCurrentlyResting =
        snapshot.state == WorkoutState.WORKOUT_STATE_RESTING &&
        snapshot.restUntil.toInt() > _nowSecs;
    if (_wasResting && !isCurrentlyResting && !_sandbox) {
      await NotificationService.cancelRest();
      _soundProvider?.playCurrentSound();
      unawaited(NotificationService.playRestCompletionHaptic());
    }
    _wasResting = isCurrentlyResting;
  }

  /// A snapshot is a photo of one instant: once the rest it shows has run
  /// out the workout is yapping, so ask the core again.
  void _reloadWhenRestEnds() {
    final snapshot = _snapshot;
    if (snapshot == null || !hasActiveWorkout) return;
    if (snapshot.state != WorkoutState.WORKOUT_STATE_RESTING ||
        snapshot.restUntil > Int64(_nowSecs)) {
      return;
    }
    unawaited(_reload());
  }

  void _applyStateSnapshot(WorkoutStateSnapshot? snapshot) {
    final oldRestUntil = _snapshot?.restUntil.toInt();
    final oldState = _snapshot?.state;
    _snapshot = snapshot;

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
    } else if (oldState == WorkoutState.WORKOUT_STATE_RESTING) {
      unawaited(NotificationService.cancelRest());
      _wasResting = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _setNow(DateTime.now());
      // _checkRestSound reads the snapshot before its first await, so it
      // still sees the rest end if the reload below moves the state on.
      unawaited(_checkRestSound());
      _reloadWhenRestEnds();
      unawaited(_saveHeartRate());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Reads ──

  bool get isLoading => _isLoading;
  String? get lastLoadError => _lastLoadError;

  Workout? get workout => _workout;
  List<ProposedSet> get proposedSets => _proposed;
  List<CompletedSet> get completedSets => _completed;

  /// The home: templates, trackers, volume, recovery, the suggestion.
  /// Null until the first load.
  GetHomeResponse? get home => _home;
  List<WorkoutTemplate> get templates => _home?.templates ?? const [];
  List<ExerciseTracker> get trackers => _home?.trackers ?? const [];

  /// The resolved tracker for one exercise. The home has one for every
  /// exercise, so this only misses before the first load.
  ExerciseTracker? trackerFor(Exercise exercise) {
    for (final tracker in trackers) {
      if (tracker.exercise == exercise) return tracker;
    }
    return null;
  }

  /// The one-shot "update your template?" offer from the last EndWorkout.
  TemplateUpdateSuggestion? takePendingTemplateUpdate() {
    final suggestion = _pendingTemplateUpdate;
    _pendingTemplateUpdate = null;
    return suggestion;
  }

  /// The account this provider works on; the Add sheet reads the template
  /// library through it so the tutorial's provider stays in its sandbox.
  WorkoutServiceWrapper get service => _service;

  Workout? get activeWorkout => _workout;
  List<ProposedSet> get activeProposedSets => _proposed;
  List<CompletedSet> get activeCompletedSets => _completed;
  WorkoutStateSnapshot? get stateSnapshot => _snapshot;
  bool get hasActiveWorkout =>
      _workout != null && _workout!.endTime == Int64.ZERO;
  bool get isWorkoutEnded =>
      _workout != null && _workout!.endTime != Int64.ZERO;
  DateTime get now => _now;
  ValueNotifier<DateTime> get clock => _clock;
  List<HeartRateSample> get wearHeartRateSamples => _wearHeartRateSamplesView;
  List<ExerciseBlock> get exerciseBlocks => _blocksCache;

  /// An undone warmup that's behind you: skipped, or one of its exercise's
  /// working sets is done. The core decides; this reads its answer.
  bool isPassedWarmup(ProposedSet set) => _passedWarmups.contains(set.id);

  bool isSetDone(String setId) =>
      _completed.any((c) => c.proposedSetId == setId);

  ProposedSet? get nextPendingSet => _nextUp;

  /// The question on screen, with its current answer, or null.
  EffortPrompt? get effortPrompt {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.hasEffortPrompt()) return null;
    return snapshot.effortPrompt;
  }

  /// The set up next: the state's display set — the next pending set, or
  /// while a rung is still asking, the set its "right" would append — so
  /// the circle and the banner show it before anything is done.
  ProposedSet? get doneTargetSet {
    final snapshot = _snapshot;
    if (snapshot != null && snapshot.hasDisplaySet()) {
      return snapshot.displaySet;
    }
    return _nextUp;
  }

  ProposedSet? proposedSetById(String id) {
    for (final set in _proposed) {
      if (set.id == id) return set;
    }
    return null;
  }

  CompletedSet? _doneById(String completedSetId) {
    for (final c in _completed) {
      if (c.id == completedSetId && c.endedAt != Int64.ZERO) return c;
    }
    return null;
  }

  /// The user's display unit; the watch snapshot formats weights with it.
  WeightUnit get weightUnit => _settingsProvider.weightUnit;

  int get restSecondsRemaining {
    final snapshot = _snapshot;
    if (snapshot == null) return 0;
    if (snapshot.state != WorkoutState.WORKOUT_STATE_RESTING) return 0;
    final remaining = snapshot.restUntil.toInt() - _nowSecs;
    return remaining > 0 ? remaining : 0;
  }

  String _nextSetBody() {
    final next = nextPendingSet;
    if (next == null) return 'All sets complete!';
    final name = exerciseNames[next.exercise] ?? '?';
    final prefix = next.warmup ? 'Warmup ' : '';
    final w = next.targetWeight.toDouble();
    final weightStr = formatWeight(w, _settingsProvider.weightUnit);
    return 'Next up: $prefix$name, $weightStr ${weightUnitSuffix(_settingsProvider.weightUnit)} × ${next.targetReps}';
  }

  /// True until this account has finished a workout: the banner explains
  /// each step during the first one only. Someone who has lifted before
  /// (any exercise performed) is never new, whatever this device recorded.
  bool get isFirstWorkout =>
      !_firstWorkoutDone &&
      !trackers.any((t) => t.lastPerformedAt > Int64.ZERO);
  // Until the device flag is read, assume done: no hint flashes up.
  bool _firstWorkoutDone = true;
  String? _userId;

  Future<void> _loadFirstWorkout(String userId) async {
    final done = await FirstWorkout.isDone(userId);
    if (done == _firstWorkoutDone) return;
    _firstWorkoutDone = done;
    notifyListeners();
  }

  // ── Loading ──

  /// The workout under way (if any) and the home, for [userId].
  Future<void> loadActiveWorkout(String userId) async {
    _userId = userId;
    if (!_sandbox) unawaited(_loadFirstWorkout(userId));
    _isLoading = true;
    _lastLoadError = null;
    notifyListeners();
    try {
      final active = await _service.getActiveWorkout();
      if (active != null) {
        _applyWorkoutResponse(await _service.getWorkout(active.id));
        _mergeHeartRate(await _service.getWorkoutHeartRate(active.id));
        _startTimer();
      } else {
        _clearWorkout();
      }
      _home = await _service.getHome();
    } catch (e) {
      _lastLoadError = cleanErrorMessage(e);
      _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearWorkout() {
    _resetWearHeartRateBufferIfWorkoutChanged(null);
    _workout = null;
    _proposed = [];
    _completed = [];
    _passedWarmups = {};
    _nextUp = null;
    _blocksCache.clear();
    _applyStateSnapshot(null);
    _stopTimer();
  }

  /// Refresh templates/trackers/volume without touching the session.
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

  // ── Templates and trackers ──

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
  /// templates/library.yaml). The answer carries the refreshed home.
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
    int targetReps = 0,
  }) async {
    await _service.setExerciseTracker(
      exercise: exercise,
      workingWeight: workingWeightLb,
      overrideSets: overrideSets,
      overrideRepLow: overrideRepLow,
      overrideRepHigh: overrideRepHigh,
      targetReps: targetReps,
    );
    await refreshHome();
  }

  // ── The workout ──

  Future<String?> startWorkout(
    String name, {
    String templateId = '',
    List<Exercise> exercises = const [],
  }) async {
    try {
      if (!_sandbox) await NotificationService.cancelAll();
      _wasResting = false;
      final started = await _service.startWorkout(
        name,
        templateId: templateId,
        exercises: exercises,
      );
      _applyWorkoutResponse(await _service.getWorkout(started.id));
      _startTimer();
      notifyListeners();
      return started.id;
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  WorkoutMutation _mutation() => WorkoutMutation()
    ..clientCreatedAt = Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000);

  /// Begin a set: the workout is LIFTING it until its Done, the timer
  /// counting up from now.
  Future<void> startSet(String proposedSetId, {int? startedAt}) async {
    if (_workout == null) return;
    await _mutate(
      _mutation()
        ..startSet = (StartSetRequest()
          ..workoutId = _workoutId
          ..proposedSetId = proposedSetId
          ..startedAt = Int64(startedAt ?? 0)),
    );
  }

  /// Log a set as done. [effort] (Easy / Good / Hard) answers "how was
  /// that" for it at the same time; leave it unspecified for a warmup.
  Future<void> completeSet(
    String proposedSetId,
    int actualReps,
    double actualWeight, {
    int? completedAt,
    Effort effort = Effort.EFFORT_UNSPECIFIED,
  }) async {
    if (_workout == null) return;
    await _mutate(
      _mutation()
        ..completeSet = (CompleteSetRequest()
          ..workoutId = _workoutId
          ..proposedSetId = proposedSetId
          ..actualReps = actualReps
          ..actualWeight = actualWeight
          ..completedAt = Int64(completedAt ?? 0)
          ..effort = effort),
    );
  }

  Future<void> deleteCompletedSet(String completedSetId) async {
    if (_workout == null) return;
    await _mutate(
      _mutation()
        ..deleteCompletedSet = (DeleteCompletedSetRequest()
          ..workoutId = _workoutId
          ..completedSetId = completedSetId),
    );
  }

  /// Correct a done set: fewer reps than planned, a different weight.
  Future<void> editCompletedSet(
    String completedSetId,
    int actualReps,
    double actualWeight,
  ) async {
    if (_workout == null) return;
    await _mutate(
      _mutation()
        ..editCompletedSet = (EditCompletedSetRequest()
          ..workoutId = _workoutId
          ..completedSetId = completedSetId
          ..actualReps = actualReps
          ..actualWeight = actualWeight),
    );
  }

  /// A tap on a done set's circle, StrongLifts style: each tap takes one
  /// rep off (one per rep missed), and the tap after zero undoes the set.
  /// A finding-weight rung stops at zero instead: the plan it settled hangs
  /// off it.
  Future<void> tapDoneSet(String completedSetId) async {
    final done = _doneById(completedSetId);
    if (done == null) return;
    if (done.actualReps > 0) {
      await editCompletedSet(
        completedSetId,
        done.actualReps - 1,
        done.actualWeight,
      );
      return;
    }
    if (proposedSetById(done.proposedSetId)?.calibration ?? true) return;
    await deleteCompletedSet(completedSetId);
  }

  /// Answer "how was that" for a done set. On a calibration rung the
  /// answer also shapes the plan (another rung, or the working sets).
  Future<void> rateExercise(String completedSetId, Effort effort) async {
    if (_workout == null || effort == Effort.EFFORT_UNSPECIFIED) return;
    await _mutate(
      _mutation()
        ..rateExercise = (RateExerciseRequest()
          ..workoutId = _workoutId
          ..completedSetId = completedSetId
          ..effort = effort),
    );
  }

  /// Skip [exercise]'s warmups (the warmup row's "Skip"): they're marked
  /// skipped — kept, out of the way, still doable.
  Future<void> skipWarmups(Exercise exercise) async {
    if (_workout == null) return;
    await _mutate(
      _mutation()
        ..skipWarmups = (SkipWarmupsRequest()
          ..workoutId = _workoutId
          ..exercise = exercise),
    );
  }

  /// Add exercises to the workout with the app in charge of the numbers:
  /// weight/sets/reps/rest/warmups from each exercise's tracker — exactly
  /// what a template start would prescribe.
  Future<void> addPrescribedExercises(List<Exercise> exercises) async {
    if (_workout == null || exercises.isEmpty) return;
    await _mutate(
      _mutation()
        ..addExercises = (AddExercisesRequest()
          ..workoutId = _workoutId
          ..exercises.addAll(exercises)),
    );
  }

  /// Move an exercise's remaining working sets to a new weight (lb); its
  /// pending warmups are worked out again for it.
  Future<void> adjustExerciseWeight(
    Exercise exercise,
    double weightLb, {
    int targetReps = 0,
  }) async {
    if (_workout == null) return;
    await _mutate(
      _mutation()
        ..adjustExerciseWeight = (AdjustExerciseWeightRequest()
          ..workoutId = _workoutId
          ..exercise = exercise
          ..workingWeight = weightLb
          ..targetReps = targetReps),
    );
  }

  /// Cancel an exercise's remaining sets. Sets already done stay.
  Future<void> removeExercise(Exercise exercise) async {
    if (_workout == null) return;
    await _mutate(
      _mutation()
        ..removeExercise = (RemoveExerciseRequest()
          ..workoutId = _workoutId
          ..exercise = exercise),
    );
  }

  /// The multiplayer session this workout is in, once the server says so.
  Future<void> recordSession(String sessionId) async {
    final workout = _workout;
    if (workout == null || !hasActiveWorkout) return;
    if (workout.sessionId == sessionId) return;
    await _mutate(
      _mutation()
        ..setSession = (SetWorkoutSessionRequest()
          ..workoutId = _workoutId
          ..sessionId = sessionId),
    );
  }

  Future<void> reorderExercises(List<Exercise> exercises) async {
    if (_workout == null) return;
    await _mutate(
      _mutation()
        ..reorderExercises = (ReorderExercisesRequest()
          ..workoutId = _workoutId
          ..exercises.addAll(exercises)),
    );
  }

  /// What the session actually contained, compared against the template it
  /// started from. Returns the offer to make, or null when nothing
  /// changed (or nothing was done).
  TemplateUpdateSuggestion? _computeTemplateUpdateSuggestion(Workout ended) {
    final doneSetIds = _completed.map((c) => c.proposedSetId).toSet();
    final ordered = _proposed.where(
      (p) => !p.warmup && !p.cancelled && doneSetIds.contains(p.id),
    );
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

  /// End the workout. The health write happens in the background.
  ///
  /// [fireEndedCallback] controls whether [onWorkoutEnded] is called after
  /// completion. Pass false when the caller (e.g. the phone UI) will handle
  /// navigation itself.
  Future<void> endWorkout({bool fireEndedCallback = true}) async {
    if (_workout == null) return;
    try {
      await _saveHeartRate(force: true);
      if (!_sandbox) await NotificationService.cancelAll();
      _wasResting = false;
      final response = await _service.endWorkout(_workoutId);
      final ended = response.workout;
      _applyWorkoutResponse(await _service.getWorkout(ended.id));
      _pendingTemplateUpdate = _computeTemplateUpdateSuggestion(ended);
      _stopTimer();
      final userId = _userId;
      if (!_sandbox && userId != null) {
        _firstWorkoutDone = true;
        unawaited(FirstWorkout.markDone(userId));
      }
      // The trackers just moved on; home shows them straight away.
      _home = await _service.getHome();
      notifyListeners();

      if (!_sandbox) _writeToHealthPlatform(ended);
      if (fireEndedCallback) onWorkoutEnded?.call(ended.id);
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

      // Title from the exercise names, in order.
      final seen = <int>{};
      final names = <String>[];
      for (final set in _proposed) {
        if (!set.warmup && seen.add(set.exercise.value)) {
          names.add(shortNames[set.exercise] ?? set.exercise.name);
        }
      }
      final title = names.join(', ');

      var totalVolumeKg = 0.0;
      var workingSets = 0;
      for (final cs in _completed) {
        final proposed = proposedSetById(cs.proposedSetId);
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
    _clearWorkout();
    _resetWearHeartRateBuffer();
    _home = null;
    _userId = null;
    notifyListeners();
  }

  // ── Heart rate from the watch ──

  void _resetWearHeartRateBuffer() {
    _wearHeartRateSamples.clear();
    _wearHeartRateBatchIds.clear();
    _wearHeartRateSampleTimestamps.clear();
    _unsavedHeartRate.clear();
    _lastHeartRateSave = null;
    _heartRateSaveInFlight = false;
  }

  void _resetWearHeartRateBufferIfWorkoutChanged(String? nextWorkoutId) {
    if (_workout?.id != nextWorkoutId) _resetWearHeartRateBuffer();
  }

  /// Samples already in the account, for the chart after a restart.
  void _mergeHeartRate(List<WorkoutHeartRatePoint> stored) {
    for (final point in stored) {
      if (!_wearHeartRateSampleTimestamps.add(point.sampledAt.toInt())) {
        continue;
      }
      _wearHeartRateSamples.add(
        HeartRateSample()
          ..sampledAt = point.sampledAt
          ..bpm = point.bpm
          ..availability =
              HeartRateAvailability.valueOf(point.availability) ??
              HeartRateAvailability.HEART_RATE_AVAILABILITY_UNSPECIFIED,
      );
    }
    _wearHeartRateSamples.sort((a, b) => a.sampledAt.compareTo(b.sampledAt));
    _trimHeartRate();
  }

  void _trimHeartRate() {
    if (_wearHeartRateSamples.length <= _maxWearHeartRateSamplesInMemory) {
      return;
    }
    final removeCount =
        _wearHeartRateSamples.length - _maxWearHeartRateSamplesInMemory;
    for (final s in _wearHeartRateSamples.take(removeCount)) {
      _wearHeartRateSampleTimestamps.remove(s.sampledAt.toInt());
    }
    _wearHeartRateSamples.removeRange(0, removeCount);
  }

  void ingestWearHeartRateBatch(WearSensorBatch batch) {
    if (_workout == null) return;
    if (batch.workoutId != _workout!.id) return;
    if (batch.batchId.isEmpty) return;
    if (!_wearHeartRateBatchIds.add(batch.batchId)) return;

    var insertedAny = false;
    for (final sample in batch.heartRateSamples) {
      if (!_wearHeartRateSampleTimestamps.add(sample.sampledAt.toInt())) {
        continue;
      }
      _wearHeartRateSamples.add(sample);
      _unsavedHeartRate.add(
        WorkoutHeartRatePoint()
          ..sampledAt = sample.sampledAt
          ..bpm = sample.bpm
          ..availability = sample.availability.value,
      );
      insertedAny = true;
    }
    if (!insertedAny) return;
    _wearHeartRateSamples.sort((a, b) => a.sampledAt.compareTo(b.sampledAt));
    _trimHeartRate();
    notifyListeners();
    unawaited(_saveHeartRate());
  }

  /// Write the heart rate heard since the last save into the account, in
  /// batches rather than an event per sample.
  Future<void> _saveHeartRate({bool force = false}) async {
    if (_heartRateSaveInFlight || _unsavedHeartRate.isEmpty) return;
    final workout = _workout;
    if (workout == null || workout.endTime != Int64.ZERO) return;
    final now = DateTime.now();
    final last = _lastHeartRateSave;
    if (!force && last != null && now.difference(last) < _heartRateBatchEvery) {
      return;
    }
    _heartRateSaveInFlight = true;
    _lastHeartRateSave = now;
    final batch = List<WorkoutHeartRatePoint>.of(_unsavedHeartRate);
    _unsavedHeartRate.clear();
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
      _unsavedHeartRate.insertAll(0, batch);
      debugPrint('Heart rate save failed: $e');
    } finally {
      _heartRateSaveInFlight = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _clock.dispose();
    super.dispose();
  }
}
