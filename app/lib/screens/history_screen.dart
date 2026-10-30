import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/settings.pbenum.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/grpc_client.dart';
import '../services/multiplayer_service.dart';
import '../services/workout_service.dart';
import '../widgets/common/flat.dart';
import '../widgets/top_level_back_scope.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

/// History: past workouts as rich cards — date, the lifts you did, and totals
/// (volume, sets, duration) — instead of a bare list.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<_HistoryItem>? _items;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final grpc = context.read<GrpcClient>();
    final service = WorkoutServiceWrapper(grpc);
    final multiplayer = MultiplayerServiceWrapper(grpc);
    final selfId = context.read<AuthProvider>().userId ?? '';
    try {
      // One call: the server returns each finished workout with its computed
      // summary (volume, working sets, exercises). Newest first already.
      final summaries = await service.listWorkoutSummaries();

      final items = <_HistoryItem>[];
      for (final ws in summaries) {
        final w = ws.workout;
        final s = ws.summary;
        // Who you trained with, for group sessions (durable roster, minus you).
        final partners = <String>[];
        if (w.sessionId.isNotEmpty) {
          try {
            final resp = await multiplayer.getSessionParticipants(w.sessionId);
            for (final p in resp.participants) {
              if (p.user.id.isNotEmpty && p.user.id != selfId) {
                partners.add(p.user.name);
              }
            }
          } catch (_) {}
        }
        items.add(
          _HistoryItem(
            workout: w,
            volume: s.totalVolume,
            workingSets: s.exercises.fold(0, (a, e) => a + e.totalSets),
            exercises: s.exercises.map((e) => e.exercise).toList(),
            partners: partners,
          ),
        );
      }
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;

    Widget scaffold(Widget body) => TopLevelBackScope(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            onPressed: () => context.go('/'),
          ),
          title: Text('History'),
        ),
        body: body,
      ),
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
                'No completed workouts yet',
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

    return scaffold(
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          FlatSection(
            child: Row(
              children: [
                _headStat('${_items!.length}', 'workouts', cs),
                const SizedBox(width: 24),
                _headStat('$thisWeek', 'this week', cs),
              ],
            ),
          ),
          ..._grouped(cs, unit),
        ],
      ),
    );
  }

  /// Full-width rows grouped under a month heading, so a long history stays
  /// scannable.
  List<Widget> _grouped(ColorScheme cs, WeightUnit unit) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final out = <Widget>[];
    String? currentMonth;
    for (final item in _items!) {
      final label = '${months[item.date.month - 1]} ${item.date.year}';
      if (label != currentMonth) {
        out.add(
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.tokens.hairline),
              ),
            ),
            child: SectionLabel(label),
          ),
        );
        currentMonth = label;
      }
      out.add(_HistoryCard(item: item, unit: unit, cs: cs));
    }
    return out;
  }

  Widget _headStat(String value, String label, ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: context.tokens.size.titleLg,
          fontWeight: context.tokens.weight.heavy,
          height: 1,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: cs.tertiary,
          fontSize: context.tokens.size.small,
        ),
      ),
    ],
  );
}

class _HistoryCard extends StatelessWidget {
  final _HistoryItem item;
  final WeightUnit unit;
  final ColorScheme cs;
  const _HistoryCard({
    required this.item,
    required this.unit,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final date = item.date;
    final title = item.exercises.isNotEmpty
        ? item.exercises.take(3).map((e) => exerciseNames[e] ?? '?').join(' · ')
        : (item.workout.name.isNotEmpty ? item.workout.name : 'Workout');
    final more = item.exercises.length > 3
        ? ' +${item.exercises.length - 3}'
        : '';

    final details = [
      if (item.volume > 0)
        '${_thousands(item.volume)} ${weightUnitSuffix(unit)}',
      if (item.workingSets > 0) '${item.workingSets} sets',
      if (item.partners.isNotEmpty) 'with ${_names(item.partners)}',
    ].join(' · ');

    // A full-width row, split from the next by a hairline.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          '/workout/${item.workout.id}/completed?isHistory=true',
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.tokens.hairline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _DateBadge(date: date, cs: cs),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: context.tokens.mono(
                          TextStyle(
                            fontSize: context.tokens.size.small,
                            fontWeight: context.tokens.weight.bold,
                            color: cs.onSurface,
                          ),
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (d.inMinutes < 1) return '<1m';
    return '${m}m';
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  final ColorScheme cs;
  const _DateBadge({required this.date, required this.cs});

  @override
  Widget build(BuildContext context) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(border: Border.all(color: cs.outline)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            months[date.month - 1],
            style: TextStyle(
              color: cs.primary,
              fontSize: context.tokens.size.caption,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: context.tokens.size.title,
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
  if (clean.isEmpty) return 'friends';
  if (clean.length == 1) return clean[0];
  if (clean.length == 2) return '${clean[0]} & ${clean[1]}';
  return '${clean[0]}, ${clean[1]} +${clean.length - 2}';
}

String _relativeDay(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'Last week';
  return '${d.month}/${d.day}/${d.year}';
}

class _HistoryItem {
  final Workout workout;
  final double volume;
  final int workingSets;
  final List<Exercise> exercises;
  final List<String> partners;
  _HistoryItem({
    required this.workout,
    required this.volume,
    required this.workingSets,
    required this.exercises,
    required this.partners,
  });

  DateTime get date =>
      DateTime.fromMillisecondsSinceEpoch(workout.startTime.toInt() * 1000);
  Duration get duration =>
      Duration(seconds: (workout.endTime - workout.startTime).toInt());
}
