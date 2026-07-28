import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbenum.dart';
import '../gen/workout/v1/settings.pbenum.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../services/grpc_client.dart';
import '../services/workout_service.dart';
import '../widgets/top_level_back_scope.dart';

/// One lift, in depth: tap a card on Progress to see its full history — a
/// weight / estimated-1RM trend you can toggle between, personal bests, and a
/// per-session breakdown. Progress shows the trend across lifts; this is the
/// drill-down for a single one.
class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

enum _Metric { weight, oneRm }

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  List<_Session>? _sessions;
  bool _isLoading = true;
  _Metric _metric = _Metric.weight;

  static const _accent = Color(0xFF60A5FA);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final grpc = context.read<GrpcClient>();
    final service = WorkoutServiceWrapper(grpc);
    try {
      // One call: the server returns the per-exercise session series (oldest
      // first) with top weight/reps, est-1RM, volume and set count precomputed.
      final resp = await service.getExerciseProgress();
      final ep = resp.exercises.firstWhere(
        (e) => e.exercise == widget.exercise,
        orElse: () => ExerciseProgress(),
      );
      final sessions = ep.points
          .map((p) => _Session(
                date: DateTime.fromMillisecondsSinceEpoch(
                    p.date.toInt() * 1000),
                topWeight: p.topWeight,
                topReps: p.topReps,
                bestOneRm: p.bestOneRepMax,
                volume: p.volume,
                sets: p.sets,
              ))
          .toList();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading exercise detail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final name = exerciseNames[widget.exercise] ?? '?';
    final emoji = exerciseEmojis[widget.exercise] ?? '🏋️';

    Widget scaffold(Widget body) => TopLevelBackScope(
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ],
              ),
            ),
            body: body,
          ),
        );

    if (_isLoading) {
      return scaffold(const Center(child: CircularProgressIndicator()));
    }
    final sessions = _sessions ?? [];
    if (sessions.isEmpty) {
      return scaffold(Center(
        child: Text('No completed sets for this lift yet.',
            style: TextStyle(color: cs.tertiary)),
      ));
    }

    final suffix = weightUnitSuffix(unit);
    final current = sessions.last.topWeight;
    final best = sessions.map((s) => s.topWeight).reduce((a, b) => a > b ? a : b);
    final bestOneRm =
        sessions.map((s) => s.bestOneRm).reduce((a, b) => a > b ? a : b);
    final totalVolume = sessions.fold<double>(0, (a, s) => a + s.volume);
    final totalSets = sessions.fold<int>(0, (a, s) => a + s.sets);

    return scaffold(
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Headline: current top weight + best est. 1RM.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _headStat('${formatWeight(current, unit)} $suffix', 'current top set',
                  cs, big: true, color: _accent),
              const Spacer(),
              _headStat('${formatWeight(bestOneRm, unit)} $suffix', 'best est. 1RM', cs),
            ],
          ),
          const SizedBox(height: 20),
          _MetricToggle(
            metric: _metric,
            onChanged: (m) => setState(() => _metric = m),
            cs: cs,
          ),
          const SizedBox(height: 12),
          if (sessions.length >= 2)
            SizedBox(
              height: 200,
              child: _TrendChart(
                sessions: sessions,
                metric: _metric,
                unit: unit,
                color: _accent,
                cs: cs,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('One session so far — the trend appears next time.',
                  style: TextStyle(color: cs.tertiary)),
            ),
          const SizedBox(height: 20),
          // Bests / totals.
          Row(
            children: [
              _footStat('Best set', '${formatWeight(best, unit)} $suffix', cs),
              const SizedBox(width: 18),
              _footStat('Sessions', '${sessions.length}', cs),
              const SizedBox(width: 18),
              _footStat('Total sets', '$totalSets', cs),
              const SizedBox(width: 18),
              _footStat('Volume', '${_compact(totalVolume)} $suffix', cs),
            ],
          ),
          const SizedBox(height: 24),
          Text('EVERY SESSION',
              style: TextStyle(
                  color: cs.tertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          for (final s in sessions.reversed) _SessionRow(session: s, unit: unit, cs: cs),
        ],
      ),
    );
  }

  static String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return v.round().toString();
  }

  Widget _headStat(String value, String label, ColorScheme cs,
          {bool big = false, Color? color}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: big ? 30 : 18,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: color)),
          Text(label, style: TextStyle(color: cs.tertiary, fontSize: 12)),
        ],
      );

  Widget _footStat(String label, String value, ColorScheme cs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: cs.tertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      );
}

class _MetricToggle extends StatelessWidget {
  final _Metric metric;
  final ValueChanged<_Metric> onChanged;
  final ColorScheme cs;
  const _MetricToggle(
      {required this.metric, required this.onChanged, required this.cs});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, _Metric m) {
      final active = metric == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? cs.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: active ? cs.primary : cs.tertiary)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        seg('Top weight', _Metric.weight),
        seg('Est. 1RM', _Metric.oneRm),
      ]),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<_Session> sessions;
  final _Metric metric;
  final WeightUnit unit;
  final Color color;
  final ColorScheme cs;
  const _TrendChart({
    required this.sessions,
    required this.metric,
    required this.unit,
    required this.color,
    required this.cs,
  });

  double _value(_Session s) =>
      metric == _Metric.weight ? s.topWeight : s.bestOneRm;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < sessions.length; i++)
        FlSpot(i.toDouble(), _value(sessions[i])),
    ];
    final vals = sessions.map(_value).toList();
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final pad = ((maxV - minV) * 0.25).clamp(2.0, double.infinity);
    final interval = ((maxV - minV) / 2).clamp(1.0, double.infinity);

    return LineChart(
      LineChartData(
        minY: minV - pad,
        maxY: maxV + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: cs.outline.withValues(alpha: 0.15), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: interval,
              getTitlesWidget: (v, meta) => Text(formatWeight(v, unit),
                  style: TextStyle(fontSize: 10, color: cs.tertiary)),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: (sessions.length - 1).toDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i != 0 && i != sessions.length - 1) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_shortDate(sessions[i].date),
                      style: TextStyle(fontSize: 10, color: cs.tertiary)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItems: (items) => items.map((s) {
              final ses = sessions[s.x.round()];
              return LineTooltipItem(
                '${formatWeight(_value(ses), unit)} ${weightUnitSuffix(unit)}\n${_shortDate(ses.date)}',
                TextStyle(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 11),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, bar) => spot.x == spots.length - 1,
              getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                radius: 4,
                color: color,
                strokeWidth: 2,
                strokeColor: cs.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final _Session session;
  final WeightUnit unit;
  final ColorScheme cs;
  const _SessionRow(
      {required this.session, required this.unit, required this.cs});

  @override
  Widget build(BuildContext context) {
    final suffix = weightUnitSuffix(unit);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(_shortDate(session.date),
                style: TextStyle(
                    color: cs.tertiary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                '${formatWeight(session.topWeight, unit)} $suffix × ${session.topReps}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          Text('${session.sets} sets · ${_compactVol(session.volume)} $suffix',
              style: TextStyle(color: cs.tertiary, fontSize: 12)),
        ],
      ),
    );
  }

  static String _compactVol(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.round().toString();
  }
}

String _shortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

class _Session {
  final DateTime date;
  final double topWeight;
  final int topReps;
  final double bestOneRm;
  final double volume;
  final int sets;
  _Session({
    required this.date,
    required this.topWeight,
    required this.topReps,
    required this.bestOneRm,
    required this.volume,
    required this.sets,
  });
}
