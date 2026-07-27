// Direct gRPC access to the same backend the app talks to. Two uses:
//  1. Seed and assert backend state (program state, sessions, workouts).
//  2. Drive *API peers* — additional users (Bob, Carol) who act purely through
//     the API. The real app under test sees them exactly as it would see real
//     phones, because the backend can't tell an API peer from an app.
//
// On the emulator, 127.0.0.1:50051 reaches the host backend via `adb reverse`.

import 'package:grpc/grpc.dart';
import 'package:schlift/gen/workout/v1/auth.pbgrpc.dart';
import 'package:schlift/gen/workout/v1/group.pbgrpc.dart';
import 'package:schlift/gen/workout/v1/settings.pbgrpc.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';

/// A gRPC connection to the backend, plus helpers to seed state and assert it.
class Api {
  Api._(this._channel);

  final ClientChannel _channel;
  late final AuthServiceClient auth = AuthServiceClient(_channel);
  late final WorkoutServiceClient workout = WorkoutServiceClient(_channel);
  late final MultiplayerServiceClient multiplayer =
      MultiplayerServiceClient(_channel);
  late final SettingsServiceClient settings = SettingsServiceClient(_channel);

  static Api connect({String host = '127.0.0.1', int port = 50051}) {
    final channel = ClientChannel(
      host,
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        idleTimeout: Duration(seconds: 5),
      ),
    );
    return Api._(channel);
  }

  Future<void> close() => _channel.shutdown();

  CallOptions _authed(String token) =>
      CallOptions(metadata: {'x-session-token': token});

  /// Dev-login (test-auth) as [username]; returns the peer's session.
  Future<Peer> login(String username) async {
    final resp = await auth.testLogin(TestLoginRequest(username: username));
    return Peer(this, username, resp.sessionToken, resp.userId);
  }
}

/// A user acting entirely through the API — used to populate multiplayer
/// sessions and to exercise the backend independently of the app under test.
class Peer {
  Peer(this._api, this.username, this.token, this.userId);

  final Api _api;
  final String username;
  final String token;
  final String userId;
  String? workoutId;

  CallOptions get _opts => _api._authed(token);

  Future<String> inviteToken() async {
    final r = await _api.multiplayer
        .getMyInviteToken(GetMyInviteTokenRequest(), options: _opts);
    return r.inviteToken;
  }

  /// Join the session that [inviteToken] belongs to.
  Future<void> joinViaInvite(String inviteToken) async {
    await _api.multiplayer.joinViaInvite(
      JoinViaInviteRequest(inviteToken: inviteToken),
      options: _opts,
    );
  }

  Future<GetCurrentSessionResponse> currentSession() => _api.multiplayer
      .getCurrentSession(GetCurrentSessionRequest(), options: _opts);

  /// The user's active workout as the backend sees it — used to cross-check that
  /// UI actions (starting sets, completing them) actually persist.
  Future<Workout?> activeWorkout() async {
    final r = await _api.workout
        .getActiveWorkout(GetActiveWorkoutRequest(), options: _opts);
    return r.hasWorkout() ? r.workout : null;
  }

  /// Full detail (proposed + completed sets) for the adopted workout. The bare
  /// [activeWorkout] Workout carries only ids; GetWorkout carries the sets.
  Future<GetWorkoutResponse?> workoutDetail() async {
    if (workoutId == null) return null;
    return _api.workout
        .getWorkout(GetWorkoutRequest(workoutId: workoutId), options: _opts);
  }

  /// The regime's current program state (weights, stall counts, …).
  Future<TrainingProgramState?> programState() async {
    final r = await _api.settings.getActiveTrainingProgramState(
        GetActiveTrainingProgramStateRequest(),
        options: _opts);
    return r.hasState() ? r.state : null;
  }

  /// The proposed next workout the home screen renders (groups + weights).
  Future<List<ProposedExerciseGroup>> proposedGroups() async {
    final r = await _api.workout.getProposedWorkoutSchedule(
        GetProposedWorkoutScheduleRequest(),
        options: _opts);
    return r.proposedGroups;
  }

  /// Start a simple one-exercise workout (used to give a peer visible activity).
  Future<void> startWorkout(
    String name,
    Exercise exercise,
    double weight,
    int sets,
  ) async {
    final group = ExerciseGroup()
      ..name = name
      ..sets = sets
      ..workoutOrder = 0
      ..exerciseConfigs.add(ExerciseTypeConfig()
        ..exercise = exercise
        ..startWeight = weight
        ..endWeight = weight
        ..reps = 5
        ..includeWarmup = false);
    final resp = await _api.workout.startWorkout(
      StartWorkoutRequest()
        ..name = name
        ..exerciseGroups.add(group),
      options: _opts,
    );
    workoutId = resp.workout.id;
  }

  /// Adopt the user's current active workout (e.g. one the app under test
  /// started) so this peer can drive it through the API. Shares the same
  /// user_id, so the backend returns the app's workout.
  Future<bool> adoptActiveWorkout() async {
    final w = await activeWorkout();
    workoutId = w?.id;
    return workoutId != null;
  }

  /// Complete every pending working (non-warmup) set at its target — used to log
  /// a full, successful workout so progression should advance.
  Future<int> completeAllWorkingSets() async {
    if (workoutId == null) return 0;
    var done = 0;
    for (var i = 0; i < 50; i++) {
      final w = await _api.workout
          .getWorkout(GetWorkoutRequest(workoutId: workoutId), options: _opts);
      final pending = w.proposedSets.where((set) =>
          !set.warmup &&
          !set.cancelled &&
          !w.completedSets.any((c) => c.proposedSetId == set.id));
      if (pending.isEmpty) break;
      final set = pending.first;
      await _api.workout.completeSet(
        CompleteSetRequest()
          ..workoutId = workoutId!
          ..proposedSetId = set.id
          ..actualReps = set.targetReps
          ..actualWeight = set.targetWeight,
        options: _opts,
      );
      done++;
    }
    return done;
  }

  /// Complete the next pending working set of the peer's workout.
  Future<void> completeNextSet(int reps) async {
    if (workoutId == null) return;
    final w = await _api.workout
        .getWorkout(GetWorkoutRequest(workoutId: workoutId), options: _opts);
    final pending = w.proposedSets.where((s) =>
        !s.warmup &&
        !s.cancelled &&
        !w.completedSets.any((c) => c.proposedSetId == s.id));
    if (pending.isEmpty) return;
    final set = pending.first;
    await _api.workout.completeSet(
      CompleteSetRequest()
        ..workoutId = workoutId!
        ..proposedSetId = set.id
        ..actualReps = reps
        ..actualWeight = set.targetWeight,
      options: _opts,
    );
  }

  Future<void> endWorkout() async {
    if (workoutId == null) return;
    await _api.workout.endWorkout(
      EndWorkoutRequest(workoutId: workoutId),
      options: _opts,
    );
  }

  Future<void> leaveSession() async {
    await _api.multiplayer
        .leaveCurrentSession(LeaveCurrentSessionRequest(), options: _opts);
  }

  /// People this user has trained with (durable session history).
  Future<List<TrainingPartner>> trainingPartners() async {
    final r = await _api.multiplayer
        .getTrainingPartners(GetTrainingPartnersRequest(), options: _opts);
    return r.partners;
  }

  /// One-tap re-pair: join a known partner's current session.
  Future<String> joinPartnerSession(String partnerUserId) async {
    final r = await _api.multiplayer.joinPartnerSession(
      JoinPartnerSessionRequest(partnerUserId: partnerUserId),
      options: _opts,
    );
    return r.sessionId;
  }
}
