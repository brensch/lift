import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:convert';

import 'package:path_provider/path_provider.dart';

import '../gen/native/api/logs.dart' as native;
import 'local_core.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  /// Its place in the log file; 0 for one only in memory.
  final int id;
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Map<String, dynamic>? fields;

  LogEntry({
    this.id = 0,
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.fields,
  });

  String get levelName => level.name.toUpperCase();

  String toStructuredString() {
    final buf = StringBuffer();
    final ts = timestamp.toIso8601String();
    buf.write('$ts [$levelName] $tag: $message');
    if (fields != null && fields!.isNotEmpty) {
      buf.write(' ');
      buf.write(json.encode(fields));
    }
    return buf.toString();
  }

  @override
  String toString() => toStructuredString();
}

/// The app's log. Each entry goes to the debugger at once and, once
/// [attach] has opened the log file (logs.sqlite beside the accounts), into
/// it within a second: a warning or error straight away. The file keeps
/// warnings and errors for good and the latest megabyte of debug and info
/// (see app/native/src/logs.rs). Until it's open (and in tests, where it
/// never is) the latest [maxEntries] are kept in memory.
class AppLogger {
  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;

  static const int maxEntries = 2000;

  /// How long an info or debug entry waits to be written with others.
  static const _flushAfter = Duration(seconds: 1);

  final _entries = ListQueue<LogEntry>();

  /// Logged and not yet in the file.
  final _pending = <LogEntry>[];
  bool _attached = false;
  Timer? _flushTimer;
  Future<void>? _flushing;

  AppLogger._();

  bool get persisted => _attached;

  /// Open the log file and write what was logged before it was open.
  Future<void> attach() async {
    if (_attached) return;
    try {
      await LocalCore.init();
      final dir = await getApplicationSupportDirectory();
      await native.openLogs(path: '${dir.path}/logs.sqlite');
      _attached = true;
      await flush();
    } catch (e) {
      developer.log('log file not opened: $e', name: 'Schlift/Logs');
    }
  }

  void _add(
    LogLevel level,
    String tag,
    String message, [
    Map<String, dynamic>? fields,
  ]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      fields: fields,
    );
    developer.log(
      entry.toStructuredString(),
      name: 'Schlift/$tag',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      },
    );
    _entries.addLast(entry);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
    _pending.add(entry);
    // Before the file is open, what waits for it is bounded like memory.
    if (!_attached && _pending.length > maxEntries) _pending.removeAt(0);
    if (!_attached) return;
    if (level.index >= LogLevel.warn.index) {
      unawaited(flush());
    } else {
      _flushTimer ??= Timer(_flushAfter, () => unawaited(flush()));
    }
  }

  /// Write what's waiting to the file now (as the app goes to the
  /// background, say).
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (!_attached) return;
    await _flushing;
    if (_pending.isEmpty) return;
    final batch = List<LogEntry>.of(_pending);
    _pending.clear();
    final done = native
        .appendLogs(
          lines: [
            for (final e in batch)
              native.LogLine(
                atMs: e.timestamp.millisecondsSinceEpoch,
                level: e.level.index,
                tag: e.tag,
                message: e.message,
                fields: e.fields == null || e.fields!.isEmpty
                    ? ''
                    : _encode(e.fields!),
              ),
          ],
        )
        .catchError((Object e) {
          developer.log('log write failed: $e', name: 'Schlift/Logs');
        });
    _flushing = done;
    await done;
  }

  static String _encode(Map<String, dynamic> fields) =>
      json.encode(fields, toEncodable: (v) => v.toString());

  /// Up to [limit] entries at [minLevel] or above, newest first, older than
  /// the one numbered [before] (0 for the newest), with [tag] and containing
  /// [text] when given.
  Future<List<LogEntry>> read({
    LogLevel minLevel = LogLevel.debug,
    String? tag,
    String text = '',
    int before = 0,
    int limit = 200,
  }) async {
    if (!_attached) {
      final needle = text.toLowerCase();
      return _entries
          .toList()
          .reversed
          .where(
            (e) =>
                e.level.index >= minLevel.index &&
                (tag == null || e.tag == tag) &&
                (needle.isEmpty ||
                    e.toStructuredString().toLowerCase().contains(needle)),
          )
          .take(limit)
          .toList();
    }
    await flush();
    final rows = await native.readLogs(
      minLevel: minLevel.index,
      tag: tag ?? '',
      text: text,
      before: before,
      limit: limit,
    );
    return [
      for (final r in rows)
        LogEntry(
          id: r.id,
          timestamp: DateTime.fromMillisecondsSinceEpoch(r.atMs),
          level: LogLevel.values[r.level.clamp(0, LogLevel.values.length - 1)],
          tag: r.tag,
          message: r.message,
          fields: r.fields.isEmpty
              ? null
              : json.decode(r.fields) as Map<String, dynamic>,
        ),
    ];
  }

  Future<void> clear() async {
    _entries.clear();
    _pending.clear();
    if (_attached) await native.clearLogs();
  }

  /// Every entry at [minLevel] or above, oldest first, one per line.
  Future<String> export({LogLevel minLevel = LogLevel.debug}) async {
    final all = <LogEntry>[];
    var before = 0;
    while (true) {
      final page = await read(minLevel: minLevel, before: before, limit: 1000);
      all.addAll(page);
      if (page.length < 1000 || !_attached) break;
      before = page.last.id;
    }
    return all.reversed.map((e) => e.toStructuredString()).join('\n');
  }

  void debug(String tag, String message, [Map<String, dynamic>? fields]) =>
      _add(LogLevel.debug, tag, message, fields);

  void info(String tag, String message, [Map<String, dynamic>? fields]) =>
      _add(LogLevel.info, tag, message, fields);

  void warn(String tag, String message, [Map<String, dynamic>? fields]) =>
      _add(LogLevel.warn, tag, message, fields);

  void error(String tag, String message, [Map<String, dynamic>? fields]) =>
      _add(LogLevel.error, tag, message, fields);
}
