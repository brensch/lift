import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../logic/first_workout.dart';
import '../logic/audio.dart';
import '../logic/exercise_blocks.dart';
import '../logic/session_state.dart';
import '../logic/set_labels.dart';
import '../providers/settings_provider.dart';
import '../services/workout_service.dart';
import '../providers/sound_provider.dart';
import '../services/notification_service.dart';
import '../services/health_service.dart' show HealthService;
import '../services/error_modal_service.dart';
import '../logic/exercises.dart';
import '../logic/utils.dart';
import '../services/app_logger.dart';
import '../theme/schlift_spec.dart';

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

  /// Called once for each ramp set whose "how many more could you have
  /// done?" opens: done with every rep, on the phone or the watch. The app
  /// shell shows the question; dismissed, it stays unanswered.
  void Function(String proposedSetId)? onRungQuestion;

  void setBodyWeightKg(double kg) => _bodyWeightKg = kg;

  bool _isLoading = false;
  String? _lastLoadError;

  // The workout on screen: the active one, or the one just ended.
  Workout? _workout;
  List<ProposedSet> _proposed = [];
  List<CompletedSet> _completed = [];
  Set<String> _passedWarmups = {};
  Set<String> _firstTimeSets = {};
  List<ExerciseLog> _logs = [];
  WorkoutSummary? _summary;
  String _rungQuestion = '';
  List<RungOutcome> _rungOutcomes = const [];
  final Set<String> _askedRungs = {};
  ProposedSet? _nextUp;
  WorkoutStateSnapshot? _snapshot;
  GetHomeResponse? _home;
  TemplateOffer? _pendingTemplateOffer;

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
  WorkoutProvider(
    this._service,
    this._settingsProvider, {
    bool sandbox = false,
    int budgetMinutes = defaultBudgetMinutes,
  }) : _sandbox = sandbox,
       _budgetMinutes = budgetMinutes {
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
    _firstTimeSets = response.firstTimeSetIds.toSet();
    _logs = List.of(response.exerciseLogs);
    _summary = response.hasSummary() ? response.summary : null;
    _rungQuestion = response.rungQuestionSetId;
    _rungOutcomes = List.of(response.rungOutcomes);
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
      // A change just opened a ramp set's question: ask it, once.
      final asking = _rungQuestion;
      if (asking.isNotEmpty && _askedRungs.add(asking)) {
        onRungQuestion?.call(asking);
      }
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

  /// The home: templates, plans, volume, recovery, the suggestion.
  /// Null until the first load.
  GetHomeResponse? get home => _home;

  /// Whether the account is onboarded, null until the first home. The
  /// router listens to this alone, not to every change of the workout.
  ValueListenable<bool?> get onboarded => _onboarded;
  final ValueNotifier<bool?> _onboarded = ValueNotifier(null);

  void _setHome(GetHomeResponse? home) {
    _home = home;
    _onboarded.value = home?.onboarded;
  }

  List<WorkoutTemplate> get templates => _home?.templates ?? const [];

  /// One lap of the rotation: sets per muscle and what is wrong with it.
  RotationCheck? get rotationCheck => _home?.rotationCheck;

  /// Every exercise in the catalog, planned at the home's now on its own.
  List<ExercisePlan> get plans => _home?.plans ?? const [];

  /// One exercise's plan. The home has one for every exercise, so this only
  /// misses before the first load.
  ExercisePlan? planFor(Exercise exercise) {
    for (final plan in plans) {
      if (plan.decision.exercise == exercise) return plan;
    }
    return null;
  }

  /// How [exercise] is loaded (barbell, dumbbell, bodyweight, …).
  EquipmentKind equipmentOf(Exercise exercise) =>
      planFor(exercise)?.equipment ?? EquipmentKind.EQUIPMENT_KIND_UNSPECIFIED;

  /// One step of [exercise]'s weight (lb); 0 for bodyweight.
  double weightStepOf(Exercise exercise) => planFor(exercise)?.step ?? 0;

  /// A template's lifts planned in the budget: what starting it records.
  TemplatePlan? templatePlanFor(String templateId) {
    for (final plan in _home?.templatePlans ?? const <TemplatePlan>[]) {
      if (plan.templateId == templateId) return plan;
    }
    return null;
  }

  /// The time the user has for a workout, in minutes. Home plans every lift
  /// in it, and a start records it.
  int get budgetMinutes => _budgetMinutes;
  int _budgetMinutes;
  static const defaultBudgetMinutes = 60;
  static const budgetStepMinutes = 5;
  static const minBudgetMinutes = 10;
  static const maxBudgetMinutes = 180;

  /// Move the budget by [steps] of [budgetStepMinutes] and plan again,
  /// once the taps settle: the future completes when home is planned in it.
  Future<void> stepBudget(int steps) {
    final next = (_budgetMinutes + steps * budgetStepMinutes).clamp(
      minBudgetMinutes,
      maxBudgetMinutes,
    );
    if (next == _budgetMinutes) return Future.value();
    _budgetMinutes = next;
    notifyListeners();
    _budgetReplan?.cancel();
    final replanned = _budgetReplanned ??= Completer<void>();
    _budgetReplan = Timer(_budgetSettle, () async {
      _budgetReplanned = null;
      await refreshHome();
      replanned.complete();
    });
    return replanned.future;
  }

  static const _budgetSettle = Duration(milliseconds: 250);
  Timer? _budgetReplan;
  Completer<void>? _budgetReplanned;

  /// Each lift of the workout on screen: the decision it started from and
  /// the weight changes since, in workout order.
  List<ExerciseLog> get exerciseLogs => _logs;

  /// The core's totals for the workout on screen: working-set volume and
  /// sets per exercise, and its time.
  WorkoutSummary? get summary => _summary;

  /// The ramp set whose "how many more could you have done?" is open, or
  /// '' when none: the core decides (done in full, unanswered, the latest
  /// set, nothing lifted since).
  String get rungQuestionSetId => _rungQuestion;

  /// What each range answer to the open question leads to (the core
  /// answers a copy): the next ramp set's weight, or the working sets'.
  RungOutcome? rungOutcome(RepsLeft repsLeft) {
    for (final o in _rungOutcomes) {
      if (o.repsLeft == repsLeft) return o;
    }
    return null;
  }

  ExerciseLog? logFor(Exercise exercise) {
    for (final log in _logs) {
      if (log.decision.exercise == exercise) return log;
    }
    return null;
  }

  /// The one-shot "update your template?" offer from the last EndWorkout.
  TemplateOffer? takePendingTemplateOffer() {
    final offer = _pendingTemplateOffer;
    _pendingTemplateOffer = null;
    return offer;
  }

  /// The account this provider works on; the Add sheet reads the template
  /// library through it so the tutorial's provider stays in its sandbox.
  WorkoutServiceWrapper get service => _service;

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

  /// The set ids the core says are first-time calibration sets
  /// (`GetWorkoutResponse.first_time_set_ids`).
  Set<String> get firstTimeSetIds => _firstTimeSets;

  bool isSetDone(String setId) => _completed.any(
    (c) => c.proposedSetId == setId && c.endedAt != Int64.ZERO,
  );

  ProposedSet? get nextPendingSet => _nextUp;

  /// The set up next: the state's display set — the next pending set, or
  /// while a rung is still asking, the set its "right" would append — so
  /// the circle and the banner show it before anything is done.
  ProposedSet? get doneTargetSet => shownSet(_snapshot, _nextUp);

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

  /// The user's colour for a plate of [weight] (in their unit).
  Color plateColor(double weight) => _settingsProvider.plateColor(weight);

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
    final set = setTextFor(next, _settingsProvider.weightUnit);
    return 'Next up: $prefix$name, $set';
  }

  /// True until this account has finished a workout: the banner explains
  /// each step during the first one only. Someone who has lifted before
  /// (any exercise performed) is never new, whatever this device recorded.
  bool get isFirstWorkout =>
      !_firstWorkoutDone && !plans.any((p) => p.lastPerformedAt > Int64.ZERO);
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
        // A question open before this load was asked then.
        if (_rungQuestion.isNotEmpty) _askedRungs.add(_rungQuestion);
        _mergeHeartRate(await _service.getWorkoutHeartRate(active.id));
        _startTimer();
      } else {
        _clearWorkout();
      }
      _setHome(await _service.getHome(budgetMinutes: _budgetMinutes));
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
    _firstTimeSets = {};
    _logs = [];
    _summary = null;
    _rungQuestion = '';
    _rungOutcomes = const [];
    _askedRungs.clear();
    _nextUp = null;
    _blocksCache.clear();
    _applyStateSnapshot(null);
    _stopTimer();
  }

  /// Refresh templates, plans and volume without touching the session.
  Future<void> refreshHome() async {
    try {
      final budget = _budgetMinutes;
      final home = await _service.getHome(budgetMinutes: budget);
      // The budget moved while planning: its own replan follows.
      if (budget != _budgetMinutes) return;
      _setHome(home);
      notifyListeners();
    } catch (e) {
      AppLogger.instance.warn('Workout', 'refreshHome failed', {
        'error': e.toString(),
      });
    }
  }

  // ── Templates and plans ──

  /// Create or update [template]. [unlink] makes a library template the
  /// user's own, changed or not: Clone, saved.
  Future<void> saveTemplate(
    WorkoutTemplate template, {
    bool unlink = false,
  }) async {
    await _service.saveTemplate(template, unlink: unlink);
    await refreshHome();
  }

  /// [exercises] planned as one workout in the budget, exactly as Home plans
  /// a template of them: the template editor's rows, saved or not.
  Future<TemplatePlan> planTemplate(List<Exercise> exercises) =>
      _service.getTemplatePlan(exercises, budgetMinutes: _budgetMinutes);

  /// Put [template] in the rotation the suggestion picks from, or make it
  /// a reserve. A library template keeps following the library.
  Future<void> setInRotation(WorkoutTemplate template, bool inRotation) =>
      saveTemplate(template.deepCopy()..inRotation = inRotation);

  Future<void> deleteTemplate(String templateId) async {
    await _service.deleteTemplate(templateId);
    await refreshHome();
  }

  /// Put the templates in [templateIds]' order; with [rotationCount], the
  /// first that many are the rotation and the rest reserves (the Manage
  /// sheet's drag across its two sections).
  Future<void> reorderTemplates(
    List<String> templateIds, {
    int? rotationCount,
  }) async {
    await _service.reorderTemplates(templateIds, rotationCount: rotationCount);
    await refreshHome();
  }

  /// Adds library entries to the user's templates, following the library
  /// (templates/library.yaml, built into the core).
  Future<void> addLibraryTemplates(
    List<String> libraryIds, {
    bool inRotation = false,
  }) async {
    await _service.addLibraryTemplates(libraryIds, inRotation: inRotation);
    await refreshHome();
  }

  /// Makes the ready-made plan [planId] the rotation (the core adds what
  /// the user lacks and moves the rest to the reserves).
  Future<void> applyLibraryPlan(String planId) async {
    await _service.applyLibraryPlan(planId);
    await refreshHome();
  }

  /// The user's own weight and reps (and optionally sets) for [exercise]:
  /// the plan carries on from it.
  Future<void> setOverride({
    required Exercise exercise,
    required double weightLb,
    required int reps,
    int? sets,
  }) async {
    await _service.setOverride(
      exercise: exercise,
      weight: weightLb,
      reps: reps,
      sets: sets,
    );
    await refreshHome();
  }

  /// Drop the user's own weight for [exercise]; the plan goes back to
  /// what the history says.
  Future<void> removeOverride(Exercise exercise) async {
    await _service.setOverride(exercise: exercise, weight: 0, reps: 0);
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
        budgetMinutes: _budgetMinutes,
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

  /// Begin a set: the workout is LIFTING it until its Done, the timer
  /// counting up from now.
  Future<void> startSet(String proposedSetId, {int? startedAt}) async {
    if (_workout == null) return;
    await _mutate(
      WorkoutMutation()
        ..startSet = (StartSetRequest()
          ..workoutId = _workoutId
          ..proposedSetId = proposedSetId
          ..startedAt = Int64(startedAt ?? 0)),
    );
  }

  /// Log a set as done.
  Future<void> completeSet(
    String proposedSetId,
    int actualReps,
    double actualWeight, {
    int? completedAt,
  }) async {
    if (_workout == null) return;
    await _mutate(
      WorkoutMutation()
        ..completeSet = (CompleteSetRequest()
          ..workoutId = _workoutId
          ..proposedSetId = proposedSetId
          ..actualReps = actualReps
          ..actualWeight = actualWeight
          ..completedAt = Int64(completedAt ?? 0)),
    );
  }

  Future<void> deleteCompletedSet(String completedSetId) async {
    if (_workout == null) return;
    await _mutate(
      WorkoutMutation()
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
      WorkoutMutation()
        ..editCompletedSet = (EditCompletedSetRequest()
          ..workoutId = _workoutId
          ..completedSetId = completedSetId
          ..actualReps = actualReps
          ..actualWeight = actualWeight),
    );
  }

  /// A tap on a done set's circle, StrongLifts style: each tap takes one
  /// rep off (one per rep missed), and the tap after zero undoes the set.
  /// A calibration rung stops at zero instead: the plan it settled hangs
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

  /// Answer a ramp set's "how many more could you have done?": 0–1 ends
  /// the ramp there, more climbs the next rung for it. The core ignores an
  /// answer to a question no longer open.
  Future<void> answerRung(String proposedSetId, RepsLeft repsLeft) async {
    if (_workout == null) return;
    await _mutate(
      WorkoutMutation()
        ..answerRung = (AnswerRungRequest()
          ..workoutId = _workoutId
          ..proposedSetId = proposedSetId
          ..repsLeft = repsLeft),
    );
  }

  /// Answer a ramp set's question with a specific jump instead: the next
  /// ramp set is that set's weight plus [jumpLb] (pounds), snapped to what
  /// loads, and the ramp goes on. The core ignores a jump out of range or
  /// to a question no longer open.
  Future<void> answerRungJump(String proposedSetId, double jumpLb) async {
    if (_workout == null) return;
    await _mutate(
      WorkoutMutation()
        ..answerRung = (AnswerRungRequest()
          ..workoutId = _workoutId
          ..proposedSetId = proposedSetId
          ..jumpLb = jumpLb),
    );
  }

  /// Skip [exercise]'s warmups (the warmup row's "Skip"): they're marked
  /// skipped — kept, out of the way, still doable.
  Future<void> skipWarmups(Exercise exercise) async {
    if (_workout == null) return;
    await _mutate(
      WorkoutMutation()
        ..skipWarmups = (SkipWarmupsRequest()
          ..workoutId = _workoutId
          ..exercise = exercise),
    );
  }

  /// Add exercises to the workout, each planned by the core in the
  /// workout's budget, exactly as a start would plan it.
  Future<void> addPrescribedExercises(List<Exercise> exercises) async {
    if (_workout == null || exercises.isEmpty) return;
    await _mutate(
      WorkoutMutation()
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
      WorkoutMutation()
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
      WorkoutMutation()
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
      WorkoutMutation()
        ..setSession = (SetWorkoutSessionRequest()
          ..workoutId = _workoutId
          ..sessionId = sessionId),
    );
  }

  Future<void> reorderExercises(List<Exercise> exercises) async {
    if (_workout == null) return;
    // Show the new order now. The core answers a beat later, and until then
    // the list would draw the old order again, so names would flash back.
    final moved = [
      for (final exercise in exercises)
        ..._blocksCache.where((b) => b.exercise == exercise),
      ..._blocksCache.where((b) => !exercises.contains(b.exercise)),
    ];
    _blocksCache
      ..clear()
      ..addAll(moved);
    notifyListeners();
    await _mutate(
      WorkoutMutation()
        ..reorderExercises = (ReorderExercisesRequest()
          ..workoutId = _workoutId
          ..exercises.addAll(exercises)),
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
      _pendingTemplateOffer = response.hasTemplateOffer()
          ? response.templateOffer
          : null;
      _stopTimer();
      final userId = _userId;
      if (!_sandbox && userId != null) {
        _firstWorkoutDone = true;
        unawaited(FirstWorkout.markDone(userId));
      }
      // The plans just moved on; home shows them straight away.
      _setHome(await _service.getHome(budgetMinutes: _budgetMinutes));
      notifyListeners();

      if (!_sandbox) _writeToHealthPlatform(ended);
      if (fireEndedCallback) onWorkoutEnded?.call(ended.id);
    } catch (e) {
      _handleError(e);
    }
  }

  void _writeToHealthPlatform(Workout workout) async {
    final heartRate = List<HeartRateSample>.of(_wearHeartRateSamples);
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

      final stored = await HealthService.writeCompletedWorkout(
        startTime: startTime,
        endTime: endTime,
        title: title,
        bodyWeightKg: _bodyWeightKg,
      );
      if (stored) {
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
    // The workout's heart rate, written after it; a failure here is only
    // logged and never changes what the workout write reported.
    try {
      await HealthService.writeHeartRateSamples(
        workoutId: workout.id,
        samples: heartRate,
      );
    } catch (e) {
      AppLogger.instance.warn('Health', 'heart rate write failed', {
        'error': e.toString(),
      });
    }
  }

  /// Leave a finished workout behind (its summary was closed): home is
  /// what's on screen now. The home itself stays.
  Future<void> dismissEndedWorkout() async {
    if (hasActiveWorkout) return;
    if (!_sandbox) await NotificationService.cancelAll();
    _wasResting = false;
    _clearWorkout();
    _resetWearHeartRateBuffer();
    notifyListeners();
  }

  /// Forget everything: the account was closed (signed out).
  Future<void> clear() async {
    if (!_sandbox) await NotificationService.cancelAll();
    _wasResting = false;
    _clearWorkout();
    _resetWearHeartRateBuffer();
    _setHome(null);
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

    final wasEmpty = _wearHeartRateSamples.isEmpty;
    var insertedAny = false;
    for (final sample in batch.heartRateSamples) {
      if (!_wearHeartRateSampleTimestamps.add(sample.sampledAt.toInt())) {
        continue;
      }
      _insertHeartRateSample(sample);
      _unsavedHeartRate.add(
        WorkoutHeartRatePoint()
          ..sampledAt = sample.sampledAt
          ..bpm = sample.bpm
          ..availability = sample.availability.value,
      );
      insertedAny = true;
    }
    if (!insertedAny) return;
    _trimHeartRate();
    // The session strip and the live chart read new samples on the 1 Hz
    // clock; only the first one changes what is built (the chart appears).
    if (wasEmpty) notifyListeners();
    unawaited(_saveHeartRate());
  }

  /// Insert [sample] in time order: appended when it is the newest, as a
  /// live sample is.
  void _insertHeartRateSample(HeartRateSample sample) {
    final samples = _wearHeartRateSamples;
    if (samples.isEmpty || samples.last.sampledAt <= sample.sampledAt) {
      samples.add(sample);
      return;
    }
    var lo = 0;
    var hi = samples.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (samples[mid].sampledAt <= sample.sampledAt) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    samples.insert(lo, sample);
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
    _budgetReplan?.cancel();
    _clock.dispose();
    _onboarded.dispose();
    super.dispose();
  }
}
