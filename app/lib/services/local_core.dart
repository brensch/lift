/// The account, on this phone: the Rust core (`core/` in the repo, linked in
/// through flutter_rust_bridge) answering the app's RPCs from a SQLite file.
/// Every rule — planning, progression, summaries — runs there; this is only
/// the doorway. See docs/architecture/local-first.md.
library;

import 'dart:async';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:protobuf/protobuf.dart';

import '../gen/native/api.dart' as native;
import '../gen/native/frb_generated.dart';
import '../gen/workout/v1/group.pb.dart';

/// A write or read the core refused: `code` is invalid_argument, not_found,
/// failed_precondition or storage.
class CoreException implements Exception {
  final String code;
  final String message;

  const CoreException(this.code, this.message);

  factory CoreException.from(Object error) {
    final text = error.toString();
    final colon = text.indexOf(': ');
    if (colon < 0) return CoreException('storage', text);
    return CoreException(text.substring(0, colon), text.substring(colon + 2));
  }

  @override
  String toString() => message;
}

class LocalCore {
  final int _handle;

  /// Fires after every call that stored events for the server, so the sync
  /// can push it.
  final _writes = StreamController<void>.broadcast();

  LocalCore._(this._handle);

  static Future<void>? _loading;

  /// Load the native library once. [library] points tests at a host build.
  static Future<void> init({ExternalLibrary? library}) =>
      _loading ??= RustLib.init(externalLibrary: library);

  /// The account file at [path], for [userId], known as [name].
  static Future<LocalCore> open(
    String path,
    String userId, {
    String name = '',
  }) async {
    await init();
    try {
      return LocalCore._(
        await native.openAccount(path: path, userId: userId, name: name),
      );
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// An account that lives only while open: the tutorial, tests.
  static Future<LocalCore> memory(String userId) => open(':memory:', userId);

  Stream<void> get writes => _writes.stream;

  /// Answer [method] (the gRPC method name) for [request].
  Future<T> call<T extends GeneratedMessage>(
    String method,
    GeneratedMessage request,
    T Function(List<int>) parse,
  ) async {
    final List<int> response;
    final bool recorded;
    try {
      (response, recorded) = await native.call(
        handle: _handle,
        method: method,
        request: request.writeToBuffer(),
      );
    } catch (e) {
      throw CoreException.from(e);
    }
    // Something for the server: a write, or a read that recorded an ended
    // workout's heart rate. One that finished as the file was closed has no
    // one to tell.
    if (recorded && !_writes.isClosed) _writes.add(null);
    return parse(response);
  }

  /// The last seq this file holds: where the server picks up.
  Future<int> confirmed() => native.confirmed(handle: _handle);

  /// What this phone recorded that the server hasn't placed, after the
  /// pending event numbered [after] (the last one this stream sent): packed
  /// (empty when there's nothing), and the number of the last.
  Future<(List<int>, int)> outbox(int after) async {
    final (packed, last) = await native.outbox(handle: _handle, after: after);
    return (packed, last);
  }

  /// How many events wait for the server.
  Future<int> pendingCount() => native.pendingCount(handle: _handle);

  /// Events from the server (packed), in its order, and the last seq it
  /// holds. Returns whether the account changed under the app.
  Future<bool> receive(List<int> packed, int head) async {
    try {
      return await native.receive(handle: _handle, packed: packed, head: head);
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// A session partner's workout events (packed) from the server: their
  /// workout so far when [whole], else more of it. Held only while the app
  /// runs.
  Future<void> receivePartner(
    String partner,
    List<int> packed, {
    required bool whole,
  }) async {
    try {
      await native.receivePartner(
        handle: _handle,
        partner: partner,
        packed: packed,
        whole: whole,
      );
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// Where a session partner is up to, folded by this phone's core from
  /// their events; null once they're off show. Who they are is not in it.
  Future<ParticipantStatus?> partnerStatus(SessionMember member) async {
    try {
      final status = await native.partnerStatus(
        handle: _handle,
        partner: member.user.id,
        joinedAt: member.joinedAt.toInt(),
        endedAt: member.endedAt.toInt(),
      );
      return status == null ? null : ParticipantStatus.fromBuffer(status);
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// Forget the partners not in [partners]: the session's members now.
  Future<void> keepPartners(List<String> partners) async {
    try {
      await native.keepPartners(handle: _handle, partners: partners);
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// Keep the template library the server sent (a packed
  /// ListTemplateLibraryResponse). Returns whether it changed.
  Future<bool> setLibrary(List<int> packed) async {
    try {
      return await native.setLibrary(handle: _handle, packed: packed);
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// The whole account as one SQLite file at [dest].
  Future<void> export(String dest) async {
    try {
      await native.exportAccount(handle: _handle, dest: dest);
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// Whose account the file at [path] holds: the user's id and name.
  static Future<(String, String)> fileOwner(String path) async {
    await init();
    try {
      return await native.accountFileOwner(path: path);
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// Done once the file is closed: after any call still running on it.
  Future<void> close() async {
    await native.closeAccount(handle: _handle);
    await _writes.close();
  }
}
