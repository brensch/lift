import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:convert';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Map<String, dynamic>? fields;

  LogEntry({
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

class AppLogger {
  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;

  static const int maxEntries = 2000;

  final _entries = ListQueue<LogEntry>();

  AppLogger._();

  List<LogEntry> get entries => _entries.toList();

  /// Get entries filtered by level and/or tag.
  List<LogEntry> filtered({LogLevel? minLevel, String? tag}) {
    return _entries.where((e) {
      if (minLevel != null && e.level.index < minLevel.index) return false;
      if (tag != null && e.tag != tag) return false;
      return true;
    }).toList();
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
    _entries.addLast(entry);
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
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }

  void debug(String tag, String message, [Map<String, dynamic>? fields]) =>
      _add(LogLevel.debug, tag, message, fields);

  void info(String tag, String message, [Map<String, dynamic>? fields]) =>
      _add(LogLevel.info, tag, message, fields);

  void warn(String tag, String message, [Map<String, dynamic>? fields]) =>
      _add(LogLevel.warn, tag, message, fields);

  void error(String tag, String message, [Map<String, dynamic>? fields]) =>
      _add(LogLevel.error, tag, message, fields);

  void clear() => _entries.clear();

  /// Export all logs as a single string, one entry per line.
  String export({LogLevel? minLevel}) {
    final list = minLevel != null ? filtered(minLevel: minLevel) : entries;
    return list.map((e) => e.toStructuredString()).join('\n');
  }
}
