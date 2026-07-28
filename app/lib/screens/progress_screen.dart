import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbenum.dart';
import '../gen/workout/v1/settings.pbenum.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../services/grpc_client.dart';
import '../services/workout_service.dart';
import '../widgets/top_level_back_scope.dart';

/// Progress: one card per exercise showing the top working-set weight actually
/// lifted over time, with the current weight, the gain since you started, and a
/// coloured trend chart.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<_ExerciseProgress>? _series;
  int _workoutCount = 0;
  double _totalVolume = 0;
  bool _isLoading = true;

  // A calm, distinct colour per exercise (cycled by index).
  static const _palette = [
    Color(0xFF60A5FA), // blue
    Color(0xFFF59E0B), // amber
    Color(0xFF34D399), // green
    Color(0xFFF472B6), // pink
    Color(0xFFA78BFA), // violet
    Color(0xFF22D3EE), // cyan
    Color(0xFFFB7185), // rose
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final grpc = context.read<GrpcClient>();
    final service = WorkoutServiceWrapper(grpc);
    try {
      final workouts = (await service.listWorkouts())
          .where((w) => w.endTime != Int64.ZERO)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      final byExercise = <Exercise, List<_Point>>{};
      var totalVolume = 0.0;
      for (final workout in workouts) {
        final response = await service.getWorkout(workout.id);
        // Map proposed set id -> proposed set so we can read exercise + warmup.
        final proposedById = {for (final p in response.proposedSets) p.id: p};
        // Heaviest actual working-set weight per exercise this workout.
        final topThisWorkout = <Exercise, double>{};
        for (final c in response.completedSets) {
          final p = proposedById[c.proposedSetId];
          if (p == null || p.warmup) continue;
          final w = c.actualWeight.toDouble();
          totalVolume += w * c.actualReps;
          final cur = topThisWorkout[p.exercise] ?? 0;
          if (w > cur) topThisWorkout[p.exercise] = w;
        }
        final date = DateTime.fromMillisecondsSinceEpoch(
          workout.startTime.toInt() * 1000,
        );
        topThisWorkout.forEach((ex, w) {
          byExercise.putIfAbsent(ex, () => []).add(_Point(date, w));
        });
      }

      final series = <_ExerciseProgress>[];
      var i = 0;
      byExercise.forEach((ex, points) {
        series.add(_ExerciseProgress(
          exercise: ex,
          points: points,
          color: _palette[i % _palette.length],
        ));
        i++;
      });
      // Most-improved first.
      series.sort((a, b) => b.gain.compareTo(a.gain));

      setState(() {
        _series = series;
        _workoutCount = workouts.length;
        _totalVolume = totalVolume;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading progress: $e');
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
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
              title: const Text('Progress',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ),
            body: body,
          ),
        );

    if (_isLoading) {
      return scaffold(const Center(child: CircularProgressIndicator()));
    }
    if (_series == null || _series!.isEmpty) {
      return scaffold(_EmptyState(cs: cs));
    }

    return scaffold(
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SummaryHeader(
            workoutCount: _workoutCount,
            totalVolume: _totalVolume,
            since: _series!
                .expand((s) => s.points)
                .map((p) => p.date)
                .reduce((a, b) => a.isBefore(b) ? a : b),
            unit: unit,
            cs: cs,
          ),
          const SizedBox(height: 16),
          for (final s in _series!) ...[
            _ExerciseCard(series: s, unit: unit, cs: cs),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int workoutCount;
  final double totalVolume;
  final DateTime since;
  final WeightUnit unit;
  final ColorScheme cs;
  const _SummaryHeader({
    required this.workoutCount,
    required this.totalVolume,
    required this.since,
    required this.unit,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _headStat('$workoutCount', 'workouts', cs),
        const SizedBox(width: 24),
        _headStat(_compactVolume(totalVolume), '${weightUnitSuffix(unit)} lifted', cs),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text('since ${_shortDate(since)}',
              style: TextStyle(color: cs.tertiary, fontSize: 12)),
        ),
      ],
    );
  }

  String _compactVolume(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return v.round().toString();
  }

  Widget _headStat(String value, String label, ColorScheme cs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
          Text(label, style: TextStyle(color: cs.tertiary, fontSize: 12)),
        ],
      );
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseProgress series;
  final WeightUnit unit;
  final ColorScheme cs;
  const _ExerciseCard(
      {required this.series, required this.unit, required this.cs});

  @override
  Widget build(BuildContext context) {
    final name = exerciseNames[series.exercise] ?? '?';
    final emoji = exerciseEmojis[series.exercise] ?? '🏋️';
    final suffix = weightUnitSuffix(unit);
    final gain = series.gain;
    final gainColor = gain > 0 ? const Color(0xFF34D399) : cs.tertiary;
    final gainText = gain == 0
        ? 'no change yet'
        : '${gain > 0 ? '+' : ''}${formatWeight(gain, unit)} $suffix';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/exercise/${series.exercise.value}'),
        child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.3)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${formatWeight(series.current, unit)} $suffix',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: series.color)),
                  Text(gainText,
                      style: TextStyle(
                          color: gainColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (series.points.length >= 2)
            SizedBox(height: 140, child: _Chart(series: series, unit: unit, cs: cs))
          else
            Text('One session so far — keep going to see a trend.',
                style: TextStyle(color: cs.tertiary, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              _footStat('Start', '${formatWeight(series.start, unit)} $suffix', cs),
              const SizedBox(width: 20),
              _footStat('Best', '${formatWeight(series.best, unit)} $suffix', cs),
              const SizedBox(width: 20),
              _footStat('Sessions', '${series.points.length}', cs),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

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
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      );
}

class _Chart extends StatelessWidget {
  final _ExerciseProgress series;
  final WeightUnit unit;
  final ColorScheme cs;
  const _Chart({required this.series, required this.unit, required this.cs});

  @override
  Widget build(BuildContext context) {
    final pts = series.points;
    final spots = [
      for (var i = 0; i < pts.length; i++)
        FlSpot(i.toDouble(), pts[i].weight),
    ];
    final minW = pts.map((p) => p.weight).reduce((a, b) => a < b ? a : b);
    final maxW = pts.map((p) => p.weight).reduce((a, b) => a > b ? a : b);
    final pad = ((maxW - minW) * 0.25).clamp(2.0, double.infinity);

    return LineChart(
      LineChartData(
        minY: minW - pad,
        maxY: maxW + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxW - minW) / 2).clamp(1, double.infinity),
          getDrawingHorizontalLine: (v) =>
              FlLine(color: cs.outline.withValues(alpha: 0.15), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: ((maxW - minW) / 2).clamp(1, double.infinity),
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
              interval: (pts.length - 1).toDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i != 0 && i != pts.length - 1) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_shortDate(pts[i].date),
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
            getTooltipItems: (spots) => spots.map((s) {
              final p = pts[s.x.round()];
              return LineTooltipItem(
                '${formatWeight(p.weight, unit)} ${weightUnitSuffix(unit)}\n${_shortDate(p.date)}',
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
            color: series.color,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, bar) => spot.x == spots.length - 1,
              getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                radius: 4,
                color: series.color,
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
                  series.color.withValues(alpha: 0.28),
                  series.color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyState({required this.cs});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📈', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('No workout history yet',
                style: TextStyle(
                    color: cs.onSurface, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Finish a workout and your progress shows up here.',
                style: TextStyle(color: cs.tertiary, fontSize: 13)),
          ],
        ),
      );
}

String _shortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

class _Point {
  final DateTime date;
  final double weight;
  _Point(this.date, this.weight);
}

class _ExerciseProgress {
  final Exercise exercise;
  final List<_Point> points;
  final Color color;
  _ExerciseProgress(
      {required this.exercise, required this.points, required this.color});

  double get start => points.first.weight;
  double get current => points.last.weight;
  double get best => points.map((p) => p.weight).reduce((a, b) => a > b ? a : b);
  double get gain => current - start;
}
