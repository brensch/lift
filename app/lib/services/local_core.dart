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

  /// The account file at [path], for [userId].
  static Future<LocalCore> open(String path, String userId) async {
    await init();
    try {
      return LocalCore._(
        await native.openAccount(path: path, userId: userId),
      );
    } catch (e) {
      throw CoreException.from(e);
    }
  }

  /// An account that lives only while open: the tutorial, tests.
  static Future<LocalCore> memory(String userId) => open(':memory:', userId);

  Stream<void> get writes => _writes.stream;

  /// Answer [method] (the gRPC method name) for [request]. [at] sets the
  /// clock the call runs at — for seeding a believable past.
  Future<T> call<T extends GeneratedMessage>(
    String method,
    GeneratedMessage request,
    T Function(List<int>) parse, {
    DateTime? at,
  }) async {
    final bytes = request.writeToBuffer();
    final List<int> response;
    try {
      response = at == null
          ? await native.call(handle: _handle, method: method, request: bytes)
          : await native.callAt(
              handle: _handle,
              method: method,
              request: bytes,
              now: at.millisecondsSinceEpoch ~/ 1000,
            );
    } catch (e) {
      throw CoreException.from(e);
    }
    if (!_isRead(method)) _writes.add(null);
    return parse(response);
  }

  static bool _isRead(String method) =>
      method.startsWith('Get') || method.startsWith('List');

  /// What the server hasn't acknowledged, packed; and its last seq.
  Future<(List<int>, int)> outbox() async {
    final (packed, last) = await native.outbox(handle: _handle);
    return (packed, last);
  }

  Future<void> acked(int head) => native.acked(handle: _handle, head: head);

  /// The account's seq and the last one the server acknowledged.
  Future<(int, int)> syncState() async {
    final (seq, acked) = await native.syncState(handle: _handle);
    return (seq, acked);
  }

  /// Events pulled from the server, appended after this file's own.
  Future<int> restore(List<int> packed) async {
    try {
      return await native.restore(handle: _handle, packed: packed);
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

  /// Whose account the file at [path] holds.
  static Future<String> fileOwner(String path) async {
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
