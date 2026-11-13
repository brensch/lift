import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/settings.pbenum.dart';
import '../logic/exercise_blocks.dart';
import '../logic/exercises.dart';
import '../logic/utils.dart';
import '../gen/copy.dart';
import 'reload_on_account_change.dart';
import '../logic/session_state.dart';
import '../logic/weight_units.dart';
import '../gen/workout/v1/group.pb.dart';
import '../providers/settings_provider.dart';
import '../services/grpc_client.dart';
import '../services/multiplayer_service.dart';
import '../services/workout_service.dart';
import '../widgets/common/flat.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

/// History: past workouts as rich cards — date, the lifts you did, and totals
/// (volume, sets, duration) — instead of a bare list.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with ReloadOnAccountChange {
  List<_HistoryItem>? _items;
  Map<String, List<String>> _partners = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reload() => _load();

  Future<void> _load() async {
    final grpc = context.read<GrpcClient>();
    final service = context.read<WorkoutServiceWrapper>();
    final List<_HistoryItem> items;
    try {
      // Each finished workout with its summary (volume, working sets,
      // exercises), from the core. Newest first already.
      final summaries = await service.listWorkoutSummaries();
      items = [
        for (final ws in summaries)
          _HistoryItem(
            workout: ws.workout,
            volume: ws.summary.totalVolume,
            workingSets: ws.summary.workingSets,
            exercises: ws.summary.exercises.map((e) => e.exercise).toList(),
          ),
      ];
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });

    // Who you trained with, for group sessions (durable roster, minus you),
    // asked of the server in one call once the list is up.
    final sessionIds = {
      for (final item in items)
        if (item.workout.sessionId.isNotEmpty) item.workout.sessionId,
    };
    if (sessionIds.isEmpty) return;
    final List<SessionRoster> rosters;
    try {
      rosters = await MultiplayerServiceWrapper(
        grpc,
      ).getSessionRosters(sessionIds);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(
      () => _partners = {
        for (final r in rosters)
          r.sessionId: [for (final u in r.partners) u.name],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;

    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(title: PageTitle(copy.history.title)),
      body: body,
    );

    if (_isLoading) {
      return scaffold(const Center(child: CircularProgressIndicator()));
    }
    if (_items == null || _items!.isEmpty) {
      return scaffold(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🗒️',
                style: TextStyle(fontSize: context.tokens.size.display),
              ),
              const SizedBox(height: 12),
              Text(
                copy.history.empty,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: context.tokens.weight.heavy,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final thisWeek = _items!.where((i) {
      final d = i.date;
      return now.difference(d).inDays < 7;
    }).length;

    final rows = _rows();
    return scaffold(
      ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: rows.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return FlatSection(
              child: Row(
                children: [
                  HeadStat('${_items!.length}', copy.history.workouts),
                  const SizedBox(width: 24),
                  HeadStat('$thisWeek', copy.history.thisWeek),
                ],
              ),
            );
          }
          final row = rows[index - 1];
          if (row is String) return FlatHeading(row);
          final item = row as _HistoryItem;
          return _HistoryCard(
            item: item,
            partners: _partners[item.workout.sessionId] ?? const [],
            unit: unit,
            cs: cs,
            onDiscarded: _load,
          );
        },
      ),
    );
  }

  /// Full-width rows grouped under a month heading, so a long history stays
  /// scannable: each heading (a String) followed by its workouts.
  List<Object> _rows() {
    final out = <Object>[];
    String? currentMonth;
    for (final item in _items!) {
      final label = monthYear(item.date);
      if (label != currentMonth) {
        out.add(label);
        currentMonth = label;
      }
      out.add(item);
    }
    return out;
  }
}

class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  final List<String> partners;
  final WeightUnit unit;
  final ColorScheme cs;

  /// The workout was thrown away from its summary: the list reloads.
  final VoidCallback onDiscarded;
  const _HistoryCard({
    required this.item,
    required this.partners,
    required this.unit,
    required this.cs,
    required this.onDiscarded,
  });

  @override
  Widget build(BuildContext context) {
    final date = item.date;
    final title = item.exercises.isNotEmpty
        ? item.exercises.take(3).map(exerciseName).join(' · ')
        : (item.workout.name.isNotEmpty
              ? item.workout.name
              : copy.history.untitled);
    final more = item.exercises.length > 3
        ? ' +${item.exercises.length - 3}'
        : '';

    final details = [
      if (item.volume > 0)
        '${_thousands(displayWeightFromPounds(item.volume, unit))} ${weightUnitSuffix(unit)}',
      if (item.workingSets > 0)
        copy.history.sets.replaceAll('{n}', '${item.workingSets}'),
      if (partners.isNotEmpty)
        copy.history.withPartners.replaceAll('{names}', _names(partners)),
    ].join(' · ');

    // A full-width row, split from the next by a hairline.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // A workout thrown away from its summary leaves the list.
          final discarded = await context.push<bool>(
            '/workout/${item.workout.id}/completed?isHistory=true',
          );
          if (discarded == true) onDiscarded();
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.tokens.hairline)),
          ),
          // The date fills the row's height, split from the rest by one
          // vertical hairline.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DateBadge(date: date, cs: cs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$title$more',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: context.tokens.weight.heavy,
                                  fontSize: context.tokens.size.bodyLg,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_relativeDay(date)} · ${_formatDuration(item.duration)}',
                                style: TextStyle(
                                  color: cs.tertiary,
                                  fontSize: context.tokens.size.small,
                                ),
                              ),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  details,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: context.tokens.size.small,
                                    fontWeight: context.tokens.weight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(AppIcons.forward, color: cs.tertiary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _thousands(double v) {
    final n = v.round();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatDuration(Duration d) =>
      d.inMinutes < 1 ? '<1m' : formatDurationShort(d.inSeconds);
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  final ColorScheme cs;
  const _DateBadge({required this.date, required this.cs});

  @override
  Widget build(BuildContext context) {
    // As wide as the row is tall: a square cell, the vertical hairline on
    // its right the only line around it.
    return Container(
      width: 84,
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: context.tokens.hairline)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            shortMonth(date),
            style: TextStyle(
              color: cs.primary,
              fontSize: context.tokens.size.small,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: context.tokens.size.headline,
              fontWeight: context.tokens.weight.heavy,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

String _names(List<String> names) {
  final clean = names.where((n) => n.isNotEmpty).toList();
  if (clean.isEmpty) return copy.history.friends;
  if (clean.length == 1) return clean[0];
  if (clean.length == 2) {
    return copy.history.twoNames
        .replaceAll('{a}', clean[0])
        .replaceAll('{b}', clean[1]);
  }
  return '${clean[0]}, ${clean[1]} +${clean.length - 2}';
}

String _relativeDay(DateTime d) {
  final days = calendarDaysBetween(d, DateTime.now());
  final h = copy.history;
  if (days == 0) return h.today;
  if (days == 1) return h.yesterday;
  if (days < 7) return h.daysAgo.replaceAll('{days}', '$days');
  if (days < 14) return h.lastWeek;
  return '${d.month}/${d.day}/${d.year}';
}

class _HistoryItem {
  final Workout workout;
  final double volume;
  final int workingSets;
  final List<Exercise> exercises;
  _HistoryItem({
    required this.workout,
    required this.volume,
    required this.workingSets,
    required this.exercises,
  });

  DateTime get date =>
      DateTime.fromMillisecondsSinceEpoch(workout.startTime.toInt() * 1000);
  Duration get duration =>
      Duration(seconds: (workout.endTime - workout.startTime).toInt());
}
