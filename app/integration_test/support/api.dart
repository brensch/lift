// Direct access to the same backend the app talks to. Two uses:
//  1. Read backend state: an account as the server holds it (pulled and
//     folded by the core, exactly as a reinstalled phone would).
//  2. Drive *API peers* — additional users (Bob, Carol) who act like phones:
//     their own in-memory core, their events pushed over Sync. The app under
//     test sees them exactly as it would see real phones.
//
// One phone records an account: a peer logged in as the app's own user only
// reads (writing too would be a second phone, which the server refuses).
//
// On the emulator, 127.0.0.1:50051 reaches the host backend via `adb reverse`.

import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:protobuf/protobuf.dart' show GeneratedMessage;
import 'package:schlift/gen/workout/v1/account.pbgrpc.dart';
import 'package:schlift/gen/workout/v1/auth.pbgrpc.dart';
import 'package:schlift/gen/workout/v1/group.pbgrpc.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/services/local_core.dart';

/// A gRPC connection to the backend, plus helpers to seed state and assert it.
class Api {
  Api._(this._channel);

  final ClientChannel _channel;
  late final AuthServiceClient auth = AuthServiceClient(_channel);
  late final SyncServiceClient sync = SyncServiceClient(_channel);
  late final MultiplayerServiceClient multiplayer = MultiplayerServiceClient(
    _channel,
  );

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

/// A user acting like a phone of their own, entirely through the API.
class Peer {
  Peer(this._api, this.username, this.token, this.userId);

  final Api _api;
  final String username;
  final String token;
  final String userId;
  String? workoutId;

  /// Set once this peer has adopted the app's own workout: from then on it
  /// only reads.
  bool _readOnly = false;

  LocalCore? _core;

  CallOptions get _opts => _api._authed(token);

  /// This peer's copy of the account, level with the server's.
  Future<LocalCore> _pulled() async {
    final core = _core ??= await LocalCore.memory(userId);
    final (seq, _) = await core.syncState();
    final pulled = await _api.sync.pullEvents(
      PullEventsRequest(afterSeq: Int64(seq)),
      options: _opts,
    );
    await core.restore(pulled.events);
    return core;
  }

  Future<T> _read<T extends GeneratedMessage>(
    String method,
    GeneratedMessage request,
    T Function(List<int>) parse,
  ) async => (await _pulled()).call(method, request, parse);

  /// A write, as this peer's phone would make it: recorded on its core,
  /// then pushed and acknowledged.
  Future<T> _write<T extends GeneratedMessage>(
    String method,
    GeneratedMessage request,
    T Function(List<int>) parse,
  ) async {
    if (_readOnly) {
      throw StateError(
        'one phone records an account: $username is the app under test',
      );
    }
    final core = await _pulled();
    final response = await core.call(method, request, parse);
    await _push(core);
    return response;
  }

  Future<void> _push(LocalCore core) async {
    final (packed, last) = await core.outbox();
    if (last == 0) return;
    final up = StreamController<SyncRequest>();
    final down = _api.sync.sync(up.stream, options: _opts);
    up.add(SyncRequest(events: packed));
    await for (final message in down) {
      if (message.hasHead() && message.head.toInt() >= last) break;
    }
    await core.acked(last);
    await up.close();
  }

  Future<String> inviteToken() async {
    final r = await _api.multiplayer.getMyInviteToken(
      GetMyInviteTokenRequest(),
      options: _opts,
    );
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

  /// The user's active workout as the backend holds it — used to cross-check
  /// that UI actions (starting sets, completing them) reached the server.
  Future<Workout?> activeWorkout() async {
    final r = await _read(
      'GetActiveWorkout',
      GetActiveWorkoutRequest(),
      GetActiveWorkoutResponse.fromBuffer,
    );
    return r.hasWorkout() ? r.workout : null;
  }

  /// Full detail (proposed + completed sets) for the adopted workout.
  Future<GetWorkoutResponse?> workoutDetail() async {
    if (workoutId == null) return null;
    return _read(
      'GetWorkout',
      GetWorkoutRequest(workoutId: workoutId),
      GetWorkoutResponse.fromBuffer,
    );
  }

  /// The home payload: templates, resolved trackers, volume, suggestion.
  Future<GetHomeResponse> home() =>
      _read('GetHome', GetHomeRequest(), GetHomeResponse.fromBuffer);

  /// The resolved tracker for one exercise (weight the next workout uses).
  Future<ExerciseTracker?> trackerFor(Exercise exercise) async {
    final response = await home();
    for (final tracker in response.trackers) {
      if (tracker.exercise == exercise) return tracker;
    }
    return null;
  }

  Future<void> _setTracker(SetExerciseTrackerRequest request) => _write(
    'SetExerciseTracker',
    request,
    SetExerciseTrackerResponse.fromBuffer,
  );

  /// Start a simple one-exercise workout (used to give a peer visible
  /// activity). The core prescribes everything from the tracker, so the
  /// weight is planted there first.
  Future<void> startWorkout(
    String name,
    Exercise exercise,
    double weight,
    int sets,
  ) async {
    await _setTracker(
      SetExerciseTrackerRequest()
        ..exercise = exercise
        ..workingWeight = weight
        ..overrideSets = sets,
    );
    final resp = await _write(
      'StartWorkout',
      StartWorkoutRequest()
        ..name = name
        ..exercises.add(exercise),
      StartWorkoutResponse.fromBuffer,
    );
    workoutId = resp.workout.id;
  }

  /// Follow the app's own active workout (the same user), to read what
  /// the server holds of it. Read-only from here on.
  Future<bool> adoptActiveWorkout() async {
    _readOnly = true;
    final w = await activeWorkout();
    workoutId = w?.id;
    return workoutId != null;
  }

  /// Run a whole workout end to end: start it with the given lifts (each
  /// `exercise` at `weight`), complete every working set, and end it. Used
  /// to seed a peer's workout history.
  Future<void> doWorkout(
    String name,
    List<MapEntry<Exercise, double>> lifts, {
    int sets = 5,
    int reps = 5,
  }) async {
    final req = StartWorkoutRequest()..name = name;
    for (final lift in lifts) {
      await _setTracker(
        SetExerciseTrackerRequest()
          ..exercise = lift.key
          ..workingWeight = lift.value
          ..overrideSets = sets
          ..overrideRepLow = reps
          ..overrideRepHigh = reps,
      );
      req.exercises.add(lift.key);
    }
    final resp = await _write(
      'StartWorkout',
      req,
      StartWorkoutResponse.fromBuffer,
    );
    workoutId = resp.workout.id;
    await completeAllWorkingSets();
    await endWorkout();
  }

  /// Complete every pending working (non-warmup) set at its target, a
  /// calibration rung answered "right" so the working sets follow.
  Future<int> completeAllWorkingSets() async {
    if (workoutId == null) return 0;
    var done = 0;
    for (var i = 0; i < 50; i++) {
      final w = (await workoutDetail())!;
      final pending = w.proposedSets.where(
        (set) =>
            !set.warmup &&
            !set.cancelled &&
            !w.completedSets.any((c) => c.proposedSetId == set.id),
      );
      if (pending.isEmpty) break;
      final set = pending.first;
      await _complete(set, set.targetReps, effort: Effort.EFFORT_RIGHT);
      done++;
    }
    return done;
  }

  Future<void> _complete(
    ProposedSet set,
    int reps, {
    Effort effort = Effort.EFFORT_UNSPECIFIED,
  }) => _write(
    'CompleteSet',
    CompleteSetRequest()
      ..workoutId = workoutId!
      ..proposedSetId = set.id
      ..actualReps = reps
      ..actualWeight = set.targetWeight
      ..effort = effort,
    CompleteSetResponse.fromBuffer,
  );

  /// Complete the next pending working set of the peer's workout.
  Future<void> completeNextSet(int reps) async {
    if (workoutId == null) return;
    final w = (await workoutDetail())!;
    final pending = w.proposedSets.where(
      (s) =>
          !s.warmup &&
          !s.cancelled &&
          !w.completedSets.any((c) => c.proposedSetId == s.id),
    );
    if (pending.isEmpty) return;
    await _complete(pending.first, reps);
  }

  /// Copy library templates (templates/library.yaml ids) onto the user's home.
  Future<void> addLibraryTemplates(List<String> libraryIds) => _write(
    'AddLibraryTemplates',
    AddLibraryTemplatesRequest()..libraryIds.addAll(libraryIds),
    AddLibraryTemplatesResponse.fromBuffer,
  );

  /// Whether [exercise] has ever been performed (a tracker with a session
  /// behind it). Before that, a loaded exercise opens with a calibration rung
  /// instead of warmups + working sets.
  Future<bool> hasPerformed(Exercise exercise) async {
    final tracker = await trackerFor(exercise);
    return tracker != null && tracker.lastPerformedAt > Int64.ZERO;
  }

  Future<void> endWorkout() async {
    if (workoutId == null) return;
    await _write(
      'EndWorkout',
      EndWorkoutRequest(workoutId: workoutId),
      EndWorkoutResponse.fromBuffer,
    );
  }

  Future<void> leaveSession() async {
    await _api.multiplayer.leaveCurrentSession(
      LeaveCurrentSessionRequest(),
      options: _opts,
    );
  }

  /// People this user has trained with (durable session history).
  Future<List<TrainingPartner>> trainingPartners() async {
    final r = await _api.multiplayer.getTrainingPartners(
      GetTrainingPartnersRequest(),
      options: _opts,
    );
    return r.partners;
  }

  /// Ask a known partner to train together (they must approve).
  Future<String> requestJoinPartner(String partnerUserId) async {
    final r = await _api.multiplayer.requestJoinPartner(
      RequestJoinPartnerRequest(partnerUserId: partnerUserId),
      options: _opts,
    );
    return r.requestId;
  }

  /// Incoming pending join requests for this user.
  Future<List<JoinRequest>> joinRequests() async {
    final r = await _api.multiplayer.getJoinRequests(
      GetJoinRequestsRequest(),
      options: _opts,
    );
    return r.requests;
  }

  /// Approve or decline a join request; returns the session id when accepted.
  Future<String> respondJoinRequest(String requestId, bool accept) async {
    final r = await _api.multiplayer.respondJoinRequest(
      RespondJoinRequestRequest(requestId: requestId, accept: accept),
      options: _opts,
    );
    return r.sessionId;
  }
}
