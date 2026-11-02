import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/settings.pbenum.dart';
import '../logic/exercises.dart';
import '../logic/plan_text.dart';
import '../logic/utils.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../services/workout_service.dart';
import '../widgets/common/flat.dart';
import '../theme/theme_spec.dart';

/// One lift, in depth: tap a card on Progress to see its full history — the
/// estimated max after each session with the heaviest set under it, the
/// totals, and a per-session breakdown. Progress shows the trend across lifts; this is the
/// drill-down for a single one.
class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  List<_Session>? _sessions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<WorkoutServiceWrapper>();
    try {
      // One call: the core returns the per-exercise session series (oldest
      // first) with top weight/reps, the estimated max after each session,
      // volume and set count precomputed.
      final resp = await service.getExerciseProgress();
      final ep = resp.exercises.firstWhere(
        (e) => e.exercise == widget.exercise,
        orElse: () => ExerciseProgress(),
      );
      final sessions = ep.points
          .map(
            (p) => _Session(
              date: DateTime.fromMillisecondsSinceEpoch(p.date.toInt() * 1000),
              topWeight: p.topWeight,
              topReps: p.topReps,
              estimatedMax: p.estimatedMax,
              volume: p.volume,
              sets: p.sets,
            ),
          )
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
    final name = exerciseName(widget.exercise);

    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(title: PageTitle(name)),
      body: body,
    );

    if (_isLoading) {
      return scaffold(const Center(child: CircularProgressIndicator()));
    }
    final sessions = _sessions ?? [];
    if (sessions.isEmpty) {
      return scaffold(
        Center(
          child: Text(
            'No completed sets for this lift yet.',
            style: TextStyle(color: cs.tertiary),
          ),
        ),
      );
    }

    final suffix = weightUnitSuffix(unit);
    final current = sessions.last.topWeight;
    final best = sessions
        .map((s) => s.topWeight)
        .reduce((a, b) => a > b ? a : b);
    // A bodyweight lift's max is a rep max, and its heaviest set is reps.
    final bodyweight = sessions.every((s) => s.topWeight <= 0);
    final maxNow = sessions.last.estimatedMax;
    final totalVolume = sessions.fold<double>(0, (a, s) => a + s.volume);
    final totalSets = sessions.fold<int>(0, (a, s) => a + s.sets);

    return scaffold(
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Headline: the estimated max now, and the heaviest set last time,
          // in the chart's colours.
          FlatSection(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                HeadStat(
                  maxText(maxNow, unit, bodyweight: bodyweight),
                  'estimated max',
                  size: context.tokens.size.headline,
                  color: context.tokens.series.first,
                ),
                const Spacer(),
                HeadStat(
                  bodyweight
                      ? '${sessions.last.topReps} reps'
                      : formatWeight(current, unit, includeUnit: true),
                  'heaviest set last time',
                  size: context.tokens.size.subtitle,
                  color: context.tokens.series[1],
                ),
              ],
            ),
          ),
          FlatSection(
            child: sessions.length >= 2
                ? SizedBox(
                    height: 200,
                    child: _TrendChart(
                      sessions: sessions,
                      bodyweight: bodyweight,
                      unit: unit,
                      maxColor: context.tokens.series.first,
                      liftedColor: context.tokens.series[1],
                      cs: cs,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'One session so far. The trend appears next time.',
                      style: TextStyle(color: cs.tertiary),
                    ),
                  ),
          ),
          // Bests / totals.
          FlatSection(
            child: Row(
              children: [
                _footStat(
                  'Best set',
                  formatWeight(best, unit, includeUnit: true),
                  cs,
                ),
                const SizedBox(width: 18),
                _footStat('Sessions', '${sessions.length}', cs),
                const SizedBox(width: 18),
                _footStat('Total sets', '$totalSets', cs),
                const SizedBox(width: 18),
                _footStat(
                  'Volume',
                  '${compactVolume(totalVolume, unit)} $suffix',
                  cs,
                ),
              ],
            ),
          ),
          const FlatHeading('Every session'),
          for (final s in sessions.reversed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.tokens.hairline),
                ),
              ),
              child: _SessionRow(session: s, unit: unit, cs: cs),
            ),
        ],
      ),
    );
  }

  Widget _footStat(String label, String value, ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          color: cs.tertiary,
          fontSize: context.tokens.size.caption,
          fontWeight: context.tokens.weight.bold,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontWeight: context.tokens.weight.heavy,
          fontSize: context.tokens.size.body,
        ),
      ),
    ],
  );
}

/// The estimated max after each session, and under it the heaviest set
/// lifted (reps, for a bodyweight lift).
class _TrendChart extends StatelessWidget {
  final List<_Session> sessions;
  final bool bodyweight;
  final WeightUnit unit;
  final Color maxColor;
  final Color liftedColor;
  final ColorScheme cs;
  const _TrendChart({
    required this.sessions,
    required this.bodyweight,
    required this.unit,
    required this.maxColor,
    required this.liftedColor,
    required this.cs,
  });

  double _lifted(_Session s) => bodyweight ? s.topReps.toDouble() : s.topWeight;

  String _label(double v) =>
      bodyweight ? '${v.round()}' : formatWeight(v, unit);

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
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
  );

  @override
  Widget build(BuildContext context) {
    final maxSpots = [
      for (var i = 0; i < sessions.length; i++)
        if (sessions[i].estimatedMax > 0)
          FlSpot(i.toDouble(), sessions[i].estimatedMax),
    ];
    final liftedSpots = [
      for (var i = 0; i < sessions.length; i++)
        FlSpot(i.toDouble(), _lifted(sessions[i])),
    ];
    final vals = [
      for (final spot in [...maxSpots, ...liftedSpots]) spot.y,
    ];
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
              getTitlesWidget: (v, meta) => Text(
                _label(v),
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
              interval: (sessions.length - 1).toDouble().clamp(
                1,
                double.infinity,
              ),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i != 0 && i != sessions.length - 1) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    shortDate(sessions[i].date),
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
            getTooltipItems: (items) => items.map((s) {
              final ses = sessions[s.x.round()];
              final suffix = bodyweight ? 'reps' : weightUnitSuffix(unit);
              return LineTooltipItem(
                '${_label(s.y)} $suffix\n${shortDate(ses.date)}',
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
          _line(liftedSpots, liftedColor),
          _line(maxSpots, maxColor),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final _Session session;
  final WeightUnit unit;
  final ColorScheme cs;
  const _SessionRow({
    required this.session,
    required this.unit,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = weightUnitSuffix(unit);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              shortDate(session.date),
              style: TextStyle(
                color: cs.tertiary,
                fontSize: context.tokens.size.small,
                fontWeight: context.tokens.weight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${formatWeight(session.topWeight, unit, includeUnit: true)} × ${session.topReps}',
              style: TextStyle(
                fontWeight: context.tokens.weight.heavy,
                fontSize: context.tokens.size.body,
              ),
            ),
          ),
          Text(
            '${session.sets} sets · ${compactVolume(session.volume, unit)} $suffix',
            style: TextStyle(
              color: cs.tertiary,
              fontSize: context.tokens.size.small,
            ),
          ),
        ],
      ),
    );
  }
}

class _Session {
  final DateTime date;
  final double topWeight;
  final int topReps;
  final double estimatedMax;
  final double volume;
  final int sets;
  _Session({
    required this.date,
    required this.topWeight,
    required this.topReps,
    required this.estimatedMax,
    required this.volume,
    required this.sets,
  });
}
