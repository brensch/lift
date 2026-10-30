import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';
import '../widgets/top_level_back_scope.dart';
import '../theme/app_icons.dart';

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

  // Time-scale filter for the charts. null = all time.
  static const _windows = <({String label, int? days})>[
    (label: '1M', days: 31),
    (label: '3M', days: 92),
    (label: '6M', days: 183),
    (label: '1Y', days: 365),
    (label: 'All', days: null),
  ];
  int _windowIdx = _windows.length - 1; // default: All

  /// Filter each series to the selected window, dropping exercises with nothing
  /// in range. Getters (current/best/1RM/gain) then read the windowed points.
  List<_ExerciseProgress> _windowed(List<_ExerciseProgress> all) {
    final days = _windows[_windowIdx].days;
    if (days == null) return all;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final out = <_ExerciseProgress>[];
    for (final s in all) {
      final pts = s.points.where((p) => p.date.isAfter(cutoff)).toList();
      if (pts.isEmpty) continue;
      out.add(
        _ExerciseProgress(
          exercise: s.exercise,
          points: pts,
          colorIndex: s.colorIndex,
        ),
      );
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final grpc = context.read<GrpcClient>();
    final service = WorkoutServiceWrapper(grpc);
    try {
      // One call: the server returns the per-exercise series (most-improved
      // first) plus the header totals, all precomputed.
      final resp = await service.getExerciseProgress();
      final series = <_ExerciseProgress>[];
      for (var i = 0; i < resp.exercises.length; i++) {
        final ep = resp.exercises[i];
        series.add(
          _ExerciseProgress(
            exercise: ep.exercise,
            points: ep.points
                .map(
                  (p) => _Point(
                    DateTime.fromMillisecondsSinceEpoch(p.date.toInt() * 1000),
                    p.topWeight,
                    p.bestOneRepMax,
                  ),
                )
                .toList(),
            colorIndex: i,
          ),
        );
      }
      setState(() {
        _series = series;
        _workoutCount = resp.workoutCount;
        _totalVolume = resp.totalVolume;
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
            icon: const Icon(AppIcons.back),
            onPressed: () => context.go('/'),
          ),
          title: PageTitle('Progress'),
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

    final shown = _windowed(_series!);

    return scaffold(
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          FlatSection(
            child: _SummaryHeader(
              workoutCount: _workoutCount,
              totalVolume: _totalVolume,
              since: _series!
                  .expand((s) => s.points)
                  .map((p) => p.date)
                  .reduce((a, b) => a.isBefore(b) ? a : b),
              unit: unit,
              cs: cs,
            ),
          ),
          FlatTabs(
            labels: [for (final w in _windows) w.label],
            selected: _windowIdx,
            onSelect: (i) => setState(() => _windowIdx = i),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No lifts in the last ${_windows[_windowIdx].label}.',
                  style: TextStyle(
                    color: cs.tertiary,
                    fontSize: context.tokens.size.body,
                  ),
                ),
              ),
            )
          else
            for (final s in shown) _ExerciseCard(series: s, unit: unit, cs: cs),
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
        _headStat(context, '$workoutCount', 'workouts', cs),
        const SizedBox(width: 24),
        _headStat(
          context,
          _compactVolume(totalVolume),
          '${weightUnitSuffix(unit)} lifted',
          cs,
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            'since ${_shortDate(since)}',
            style: TextStyle(
              color: cs.tertiary,
              fontSize: context.tokens.size.small,
            ),
          ),
        ),
      ],
    );
  }

  String _compactVolume(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return v.round().toString();
  }

  Widget _headStat(
    BuildContext context,
    String value,
    String label,
    ColorScheme cs,
  ) => Column(
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

class _ExerciseCard extends StatelessWidget {
  final _ExerciseProgress series;
  final WeightUnit unit;
  final ColorScheme cs;
  const _ExerciseCard({
    required this.series,
    required this.unit,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final name = exerciseNames[series.exercise] ?? '?';
    final gain = series.gain;
    final gainColor = gain > 0 ? context.tokens.accentGreen : cs.tertiary;
    final gainText = gain == 0
        ? ''
        : '${gain > 0 ? '+' : '−'}${formatWeight(gain.abs(), unit)}';

    // A full-width row, split from the next by a hairline.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/exercise/${series.exercise.value}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.tokens.hairline)),
          ),
          child: Row(
            children: [
              // LEFT — name + current (with gain)
              SizedBox(
                width: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: context.tokens.weight.bold,
                        fontSize: context.tokens.size.body,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            formatWeight(series.current, unit),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: context.tokens.weight.heavy,
                              fontSize: context.tokens.size.bodyLg,
                              letterSpacing: -0.3,
                              color: series.colorIn(context.tokens),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        if (gainText.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            gainText,
                            style: TextStyle(
                              color: gainColor,
                              fontSize: context.tokens.size.small,
                              fontWeight: context.tokens.weight.heavy,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // MIDDLE — bounded trend graph (not full width)
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: series.points.length >= 2
                      ? _Chart(
                          series: series,
                          unit: unit,
                          cs: cs,
                          compact: true,
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '1 session',
                            style: TextStyle(
                              color: cs.tertiary,
                              fontSize: context.tokens.size.small,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // RIGHT — 1RM + best, stacked tight
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rightStat(
                    context,
                    '1RM',
                    formatWeight(series.bestOneRm, unit),
                    cs,
                  ),
                  const SizedBox(height: 4),
                  _rightStat(
                    context,
                    'BEST',
                    formatWeight(series.best, unit),
                    cs,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rightStat(
    BuildContext context,
    String label,
    String value,
    ColorScheme cs,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: context.tokens.size.caption,
          fontWeight: context.tokens.weight.heavy,
          letterSpacing: 0.6,
          color: cs.tertiary,
        ),
      ),
      SizedBox(width: 6),
      Text(
        value,
        style: TextStyle(
          fontSize: context.tokens.size.body,
          fontWeight: context.tokens.weight.heavy,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _Chart extends StatelessWidget {
  final _ExerciseProgress series;
  final WeightUnit unit;
  final ColorScheme cs;

  /// Compact strips axes, grid, labels and touch — a bare inline sparkline for
  /// the slim card row. The card's InkWell owns the tap.
  final bool compact;
  const _Chart({
    required this.series,
    required this.unit,
    required this.cs,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pts = series.points;
    final spots = [
      for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].weight),
    ];
    final minW = pts.map((p) => p.weight).reduce((a, b) => a < b ? a : b);
    final maxW = pts.map((p) => p.weight).reduce((a, b) => a > b ? a : b);
    final pad = ((maxW - minW) * 0.25).clamp(2.0, double.infinity);

    if (compact) {
      return LineChart(
        LineChartData(
          minY: minW - pad,
          maxY: maxW + pad,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: series.colorIn(context.tokens),
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, bar) => spot.x == spots.length - 1,
                getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                  radius: 3,
                  color: series.colorIn(context.tokens),
                  strokeWidth: 0,
                  strokeColor: series.colorIn(context.tokens),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
              getTitlesWidget: (v, meta) => Text(
                formatWeight(v, unit),
                style: TextStyle(
                  fontSize: context.tokens.size.caption,
                  color: cs.tertiary,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
                  child: Text(
                    _shortDate(pts[i].date),
                    style: TextStyle(
                      fontSize: context.tokens.size.caption,
                      color: cs.tertiary,
                    ),
                  ),
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
                  fontWeight: context.tokens.weight.bold,
                  fontSize: context.tokens.size.small,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: series.colorIn(context.tokens),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, bar) => spot.x == spots.length - 1,
              getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
                radius: 4,
                color: series.colorIn(context.tokens),
                strokeWidth: 2,
                strokeColor: cs.surface,
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
        Text('📈', style: TextStyle(fontSize: context.tokens.size.display)),
        const SizedBox(height: 12),
        Text(
          'No workout history yet',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: context.tokens.weight.heavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Finish a workout and your progress shows up here.',
          style: TextStyle(
            color: cs.tertiary,
            fontSize: context.tokens.size.body,
          ),
        ),
      ],
    ),
  );
}

String _shortDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

class _Point {
  final DateTime date;
  final double weight;
  final double oneRm;
  _Point(this.date, this.weight, this.oneRm);
}

class _ExerciseProgress {
  final Exercise exercise;
  final List<_Point> points;

  /// Index into the theme's series palette, so the colour follows the theme.
  final int colorIndex;
  _ExerciseProgress({
    required this.exercise,
    required this.points,
    required this.colorIndex,
  });

  Color colorIn(ThemeSpec tokens) =>
      tokens.series[colorIndex % tokens.series.length];

  double get start => points.first.weight;
  double get current => points.last.weight;
  double get best =>
      points.map((p) => p.weight).reduce((a, b) => a > b ? a : b);
  double get bestOneRm =>
      points.map((p) => p.oneRm).reduce((a, b) => a > b ? a : b);
  double get gain => current - start;
}
