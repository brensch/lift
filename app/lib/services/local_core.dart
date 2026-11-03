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

  /// Fires after every call that may have recorded something, so the sync
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
    try {
      response = await native.call(
        handle: _handle,
        method: method,
        request: request.writeToBuffer(),
      );
    } catch (e) {
      throw CoreException.from(e);
    }
    if (!_isRead(method)) _writes.add(null);
    return parse(response);
  }

  static bool _isRead(String method) =>
      method.startsWith('Get') || method.startsWith('List');

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

  void close() {
    _writes.close();
    native.closeAccount(handle: _handle);
  }
}
