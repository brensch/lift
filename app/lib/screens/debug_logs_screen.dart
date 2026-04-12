import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/app_logger.dart';

class DebugLogsScreen extends StatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  State<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends State<DebugLogsScreen> {
  LogLevel _minLevel = LogLevel.debug;
  String? _tagFilter;
  Timer? _refreshTimer;
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filtered =>
      AppLogger.instance.filtered(minLevel: _minLevel, tag: _tagFilter);

  void _shareLogs() {
    final text = AppLogger.instance.export(minLevel: _minLevel);
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to share')),
      );
      return;
    }
    Share.share(text);
  }

  void _copyLogs() {
    final text = AppLogger.instance.export(minLevel: _minLevel);
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to copy')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${_filtered.length} log entries')),
    );
  }

  void _clearLogs() {
    AppLogger.instance.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    final colorScheme = Theme.of(context).colorScheme;

    // Collect unique tags for the filter.
    final allTags = AppLogger.instance.entries.map((e) => e.tag).toSet().toList()
      ..sort();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScroll &&
          _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController
            .jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Logs (${entries.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: _copyLogs,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                // Level filter
                SegmentedButton<LogLevel>(
                  segments: const [
                    ButtonSegment(value: LogLevel.debug, label: Text('DBG')),
                    ButtonSegment(value: LogLevel.info, label: Text('INF')),
                    ButtonSegment(value: LogLevel.warn, label: Text('WRN')),
                    ButtonSegment(value: LogLevel.error, label: Text('ERR')),
                  ],
                  selected: {_minLevel},
                  onSelectionChanged: (s) =>
                      setState(() => _minLevel = s.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Tag filter
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _tagFilter,
                      isExpanded: true,
                      isDense: true,
                      hint: const Text('All tags'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All tags'),
                        ),
                        for (final tag in allTags)
                          DropdownMenuItem(value: tag, child: Text(tag)),
                      ],
                      onChanged: (v) => setState(() => _tagFilter = v),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _autoScroll
                        ? Icons.vertical_align_bottom
                        : Icons.vertical_align_top,
                    size: 20,
                  ),
                  tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
                  onPressed: () => setState(() => _autoScroll = !_autoScroll),
                ),
              ],
            ),
          ),
          // Log entries
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No log entries'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _LogEntryTile(entry: entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  const _LogEntryTile({required this.entry});

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warn:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = entry.timestamp;
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}.'
        '${ts.millisecond.toString().padLeft(3, '0')}';

    final fieldsStr = entry.fields != null && entry.fields!.isNotEmpty
        ? ' ${entry.fields!.entries.map((e) => '${e.key}=${e.value}').join(' ')}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          children: [
            TextSpan(
              text: timeStr,
              style: TextStyle(color: Colors.grey.shade500),
            ),
            TextSpan(
              text: ' ${entry.levelName.padRight(5)}',
              style: TextStyle(
                color: _levelColor(entry.level),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: ' ${entry.tag}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' ${entry.message}'),
            if (fieldsStr.isNotEmpty)
              TextSpan(
                text: fieldsStr,
                style: TextStyle(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}
