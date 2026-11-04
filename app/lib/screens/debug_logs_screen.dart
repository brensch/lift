import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/utils.dart';
import '../services/app_logger.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';

/// The app's log, newest first, by day: what happened and when, to the
/// second. Pick a level, search, or tap a tag to see only it; tap an entry
/// for its exact time and fields. Older entries load as they scroll in.
class DebugLogsScreen extends StatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

/// The level tabs: each shows that level and above.
const _levels = <({String label, LogLevel min})>[
  (label: 'All', min: LogLevel.debug),
  (label: 'Info', min: LogLevel.info),
  (label: 'Warn', min: LogLevel.warn),
  (label: 'Error', min: LogLevel.error),
];

const _page = 200;

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  int _levelIdx = 0;
  String? _tag;
  String _text = '';
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<LogEntry> _entries = [];
  bool _loading = true;
  bool _more = true;
  bool _loadingMore = false;
  final _expanded = <LogEntry>{};
  Timer? _poll;
  Timer? _typing;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
    // New entries appear while the newest are in view.
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_scroll.hasClients && _scroll.offset > 40) return;
      _reload(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _typing?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  LogLevel get _min => _levels[_levelIdx].min;

  Future<void> _reload({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final page = await AppLogger.instance.read(
      minLevel: _min,
      tag: _tag,
      text: _text,
      limit: _page,
    );
    if (!mounted) return;
    setState(() {
      // Quiet: keep what was scrolled to, add what's new on top.
      if (quiet && _entries.isNotEmpty && AppLogger.instance.persisted) {
        final top = _entries.first.id;
        _entries = [...page.where((e) => e.id > top), ..._entries];
      } else {
        _entries = page;
        _more = page.length == _page && AppLogger.instance.persisted;
      }
      _loading = false;
    });
  }

  void _onScroll() {
    if (!_more || _loadingMore) return;
    if (_scroll.position.extentAfter > 600) return;
    _loadOlder();
  }

  Future<void> _loadOlder() async {
    if (_entries.isEmpty) return;
    _loadingMore = true;
    final page = await AppLogger.instance.read(
      minLevel: _min,
      tag: _tag,
      text: _text,
      before: _entries.last.id,
      limit: _page,
    );
    if (!mounted) return;
    setState(() {
      _entries = [..._entries, ...page];
      _more = page.length == _page;
      _loadingMore = false;
    });
  }

  void _filter({int? level, String? tag, bool clearTag = false}) {
    setState(() {
      if (level != null) _levelIdx = level;
      if (clearTag) _tag = null;
      if (tag != null) _tag = tag;
    });
    _reload();
  }

  void _onSearch(String text) {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 250), () {
      _text = text.trim();
      _reload();
    });
  }

  Future<void> _share() async {
    final text = await AppLogger.instance.export(minLevel: _min);
    if (!mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No logs to share')));
      return;
    }
    // As a gzipped file: kept for good, the warnings and errors can run
    // long, and log text shrinks several times over.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/schlift-logs.txt.gz');
    await file.writeAsBytes(gzip.encode(utf8.encode(text)));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _copy() async {
    final text = await AppLogger.instance.export(minLevel: _min);
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied $lines entries')));
  }

  Future<void> _clear() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the log?'),
        content: const Text(
          'Every entry on this phone goes, warnings and errors too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await AppLogger.instance.clear();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    // Rows: a day's heading (a String), then its entries.
    final rows = <Object>[];
    String? day;
    for (final e in _entries) {
      final d = _dayLabel(e.timestamp);
      if (d != day) {
        day = d;
        rows.add(d);
      }
      rows.add(e);
    }

    return Scaffold(
      appBar: AppBar(
        title: PageTitle('Logs'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.copy),
            tooltip: 'Copy',
            onPressed: _copy,
          ),
          IconButton(
            icon: const Icon(AppIcons.share),
            tooltip: 'Share',
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(AppIcons.delete),
            tooltip: 'Clear',
            onPressed: _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          FlatTabs(
            labels: [for (final l in _levels) l.label],
            selected: _levelIdx,
            onSelect: (i) => _filter(level: i),
          ),
          _SearchBar(
            controller: _search,
            tag: _tag,
            onChanged: _onSearch,
            onClearTag: () => _filter(clearTag: true),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                ? Center(
                    child: Text(
                      'Nothing logged here',
                      style: TextStyle(color: context.tokens.muted),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.builder(
                      controller: _scroll,
                      // A pixel on top: room for the first band's top line.
                      padding: const EdgeInsets.only(top: 1, bottom: 24),
                      itemCount: rows.length + (_more ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == rows.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final row = rows[i];
                        if (row is String) return FlatHeading(row);
                        final entry = row as LogEntry;
                        return _LogRow(
                          entry: entry,
                          expanded: _expanded.contains(entry),
                          onTap: () => setState(() {
                            if (!_expanded.remove(entry)) _expanded.add(entry);
                          }),
                          onTag: () => _filter(tag: entry.tag),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Today", "Yesterday", or "Nov 3" ("Nov 3, 2025" in another year).
String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  return switch (days) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => dayDate(d),
  };
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Search across the entries, and the tag being shown alone, if one is.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String? tag;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearTag;

  const _SearchBar({
    required this.controller,
    required this.tag,
    required this.onChanged,
    required this.onClearTag,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          Icon(AppIcons.search, size: t.size.bodyLg, color: t.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: t.size.body, color: t.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'Search',
                hintStyle: TextStyle(color: t.muted),
              ),
            ),
          ),
          if (tag != null)
            InputChip(
              label: Text(
                tag!,
                style: t.mono(
                  TextStyle(fontSize: t.size.small, fontWeight: t.weight.bold),
                ),
              ),
              onDeleted: onClearTag,
              deleteIcon: Icon(AppIcons.close, size: t.size.body),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// One entry as a full-width row: the time to the second on the left with
/// the level and the tag under it (warnings and errors in their colour);
/// the message and its fields beside them. Tapped open, the exact time and every field in
/// full.
class _LogRow extends StatelessWidget {
  final LogEntry entry;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onTag;

  const _LogRow({
    required this.entry,
    required this.expanded,
    required this.onTap,
    required this.onTag,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ts = entry.timestamp;
    final tone = switch (entry.level) {
      LogLevel.error => t.error,
      LogLevel.warn => t.overdue,
      _ => null,
    };
    final fields = entry.fields ?? const {};
    final mono = t.mono(TextStyle(fontSize: t.size.small, color: t.muted));
    final timeStyle = t.mono(
      TextStyle(fontSize: t.size.small, fontWeight: t.weight.bold),
    );
    final tagStyle = t.mono(
      TextStyle(fontSize: t.size.caption, fontWeight: t.weight.bold),
    );
    final timeWidth =
        (TextPainter(
          text: TextSpan(text: '00:00:00', style: timeStyle),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout()).width +
        1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.hairline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // When, and what logged it under: one column as wide as the
              // time.
              SizedBox(
                width: timeWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_two(ts.hour)}:${_two(ts.minute)}:${_two(ts.second)}',
                      maxLines: 1,
                      softWrap: false,
                      style: timeStyle.copyWith(
                        color: entry.level == LogLevel.debug ? t.muted : t.text,
                      ),
                    ),
                    Text(
                      entry.levelName,
                      maxLines: 1,
                      style: tagStyle.copyWith(color: tone ?? t.muted),
                    ),
                    GestureDetector(
                      onTap: onTag,
                      child: Text(
                        entry.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tagStyle.copyWith(color: tone ?? t.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.message,
                      maxLines: expanded ? null : 3,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.size.body,
                        color: entry.level == LogLevel.debug ? t.muted : t.text,
                      ),
                    ),
                    if (fields.isNotEmpty && !expanded) ...[
                      const SizedBox(height: 2),
                      Text(
                        fields.entries
                            .map((f) => '${f.key} ${f.value}')
                            .join('  ·  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: mono,
                      ),
                    ],
                    if (expanded) ...[
                      const SizedBox(height: 6),
                      Text(ts.toIso8601String(), style: mono),
                      if (fields.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SelectableText(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(fields.map((k, v) => MapEntry(k, '$v'))),
                          style: mono,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
