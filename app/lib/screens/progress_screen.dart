import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbenum.dart';
import '../gen/workout/v1/settings.pbenum.dart';
import '../logic/exercises.dart';
import '../logic/utils.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../gen/copy.dart';
import '../services/workout_service.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';
import 'reload_on_account_change.dart';
import '../theme/app_icons.dart';

/// Progress: one card per exercise showing the top working-set weight actually
/// lifted over time, with the current weight, the gain since you started, and a
/// coloured trend chart.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with ReloadOnAccountChange {
  List<_ExerciseProgress>? _series;
  int _workoutCount = 0;
  double _totalVolume = 0;
  DateTime _since = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isLoading = true;

  int _windowIdx = 0; // default: All, the first

  /// Filter each series to the selected window, dropping exercises with nothing
  /// in range. Getters (current/best/max/gain) then read the windowed points.
  List<_ExerciseProgress> _windowed(List<_ExerciseProgress> all) {
    final days = chartWindows[_windowIdx].days;
    if (days == null) return all;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final out = <_ExerciseProgress>[];
    for (final s in all) {
      final pts = s.points.where((p) => p.date.isAfter(cutoff)).toList();
      if (pts.isEmpty) continue;
      out.add(
        _ExerciseProgress(
          exercise: s.exercise,
          bodyweight: s.bodyweight,
          points: pts,
          history: s.points,
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

  @override
  void reload() => _loadData();

  Future<void> _loadData() async {
    final service = context.read<WorkoutServiceWrapper>();
    try {
      // One call: the core returns the per-exercise series (most-improved
      // first) plus the header totals, all precomputed.
      final resp = await service.getExerciseProgress();
      final series = <_ExerciseProgress>[];
      for (var i = 0; i < resp.exercises.length; i++) {
        final ep = resp.exercises[i];
        series.add(
          _ExerciseProgress(
            exercise: ep.exercise,
            bodyweight: ep.bodyweight,
            points: ep.points
                .map(
                  (p) => _Point(
                    DateTime.fromMillisecondsSinceEpoch(p.date.toInt() * 1000),
                    p.topWeight,
                    p.estimatedMax,
                  ),
                )
                .toList(),
            colorIndex: i,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _series = series;
        _workoutCount = resp.workoutCount;
        _totalVolume = resp.totalVolume;
        _since = DateTime.fromMillisecondsSinceEpoch(resp.since.toInt() * 1000);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading progress: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;

    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.go('/'),
        ),
        title: PageTitle(copy.progress.title),
      ),
      body: body,
    );

    if (_isLoading) {
      return scaffold(const Center(child: CircularProgressIndicator()));
    }
    if (_series == null || _series!.isEmpty) {
      return scaffold(_EmptyState(cs: cs));
    }

    final shown = _windowed(_series!);
    // One span for every chart: the window, or for all time from the
    // first lift shown.
    final (:from, :to) = chartSpan(
      _windowIdx,
      shown.isEmpty
          ? null
          : shown
                .map((s) => s.points.first.date)
                .reduce((a, b) => a.isBefore(b) ? a : b),
    );

    return scaffold(
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          FlatSection(
            child: _SummaryHeader(
              workoutCount: _workoutCount,
              totalVolume: _totalVolume,
              since: _since,
              unit: unit,
              cs: cs,
            ),
          ),
          FlatTabs(
            labels: [for (final w in chartWindows) w.label],
            selected: _windowIdx,
            onSelect: (i) => setState(() => _windowIdx = i),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  copy.progress.noneInSpan.replaceAll(
                    '{span}',
                    chartWindows[_windowIdx].label,
                  ),
                  style: TextStyle(
                    color: cs.tertiary,
                    fontSize: context.tokens.size.body,
                  ),
                ),
              ),
            )
          else
            for (final s in shown)
              // Keyed: a span that drops a lift doesn't hand its chart to
              // the next one.
              _ExerciseCard(
                key: ValueKey(s.exercise),
                series: s,
                unit: unit,
                cs: cs,
                from: from,
                to: to,
              ),
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
        HeadStat('$workoutCount', copy.progress.workouts),
        const SizedBox(width: 24),
        HeadStat(
          compactVolume(totalVolume, unit),
          copy.progress.lifted.replaceAll('{unit}', weightUnitSuffix(unit)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            copy.progress.since.replaceAll('{date}', shortDate(since)),
            style: TextStyle(
              color: cs.tertiary,
              fontSize: context.tokens.size.small,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseProgress series;
  final WeightUnit unit;
  final ColorScheme cs;

  /// The span every card's chart covers, so their dates line up.
  final DateTime from;
  final DateTime to;
  const _ExerciseCard({
    super.key,
    required this.series,
    required this.unit,
    required this.cs,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final name = exerciseName(series.exercise);
    final gain = series.gain;
    final gainColor = gain > 0 ? context.tokens.ready : cs.tertiary;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The name across the full width, the current weight and the
              // gain on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: context.tokens.weight.bold,
                        fontSize: context.tokens.size.bodyLg,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (gainText.isNotEmpty) ...[
                    Text(
                      gainText,
                      style: context.tokens.mono(
                        TextStyle(
                          color: gainColor,
                          fontSize: context.tokens.size.small,
                          fontWeight: context.tokens.weight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    formatWeight(series.current, unit),
                    style: context.tokens.mono(
                      TextStyle(
                        fontWeight: context.tokens.weight.bold,
                        fontSize: context.tokens.size.title,
                        color: series.colorIn(context.tokens),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // The trend, then the bests.
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: _Chart(series: series, from: from, to: to),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _rightStat(
                        context,
                        copy.progress.max,
                        series.bodyweight
                            ? '${series.maxNow.round()}'
                            : formatWeight(series.maxNow, unit),
                        cs,
                      ),
                      const SizedBox(height: 4),
                      _rightStat(
                        context,
                        copy.progress.best,
                        formatWeight(series.best, unit),
                        cs,
                      ),
                    ],
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

/// One exercise's top weights, a dot each, placed by date between [from] and [to], the
/// same span for every card, with dates along the bottom. The card's InkWell
/// owns the tap.
class _Chart extends StatelessWidget {
  final _ExerciseProgress series;
  final DateTime from;
  final DateTime to;
  const _Chart({required this.series, required this.from, required this.to});

  /// Days since the epoch: the x axis, the same for every span and card.
  static double _x(DateTime d) =>
      d.millisecondsSinceEpoch / Duration.millisecondsPerDay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = series.colorIn(context.tokens);
    // The span's points fit the y axis; every session is plotted, so a new
    // span pans and zooms the same dots rather than morphing them.
    final pts = series.points;
    final all = series.history;
    // A dot a session: the gaps between them are the time off.
    final spots = [
      for (var i = 0; i < all.length; i++)
        ScatterSpot(
          _x(all[i].date),
          all[i].weight,
          dotPainter: FlDotCirclePainter(
            radius: i == all.length - 1 ? 3.5 : 2,
            color: color,
            strokeWidth: 0,
          ),
        ),
    ];
    final minX = _x(from);
    final maxX = _x(to);
    final span = maxX - minX;
    final minW = pts.map((p) => p.weight).reduce((a, b) => a < b ? a : b);
    final maxW = pts.map((p) => p.weight).reduce((a, b) => a > b ? a : b);
    final pad = ((maxW - minW) * 0.25).clamp(2.0, double.infinity);
    final withYear = span > 330;

    return ScatterChart(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      ScatterChartData(
        scatterSpots: spots,
        minX: minX,
        maxX: maxX,
        // The dates count from the left edge: one there, mid-span, the right.
        baselineX: minX,
        clipData: const FlClipData.all(),
        minY: minW - pad,
        maxY: maxW + pad,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
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
              reservedSize: 16,
              interval: span / 2,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                space: 2,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(
                  axisDate(
                    DateTime.fromMillisecondsSinceEpoch(
                      (v * Duration.millisecondsPerDay).round(),
                    ),
                    withYear: withYear,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: context.tokens.size.caption,
                    color: cs.tertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        scatterTouchData: ScatterTouchData(enabled: false),
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
          copy.progress.empty,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: context.tokens.weight.heavy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          copy.progress.emptyBody,
          style: TextStyle(
            color: cs.tertiary,
            fontSize: context.tokens.size.body,
          ),
        ),
      ],
    ),
  );
}

class _Point {
  final DateTime date;
  final double weight;

  /// The estimated max after the session (a rep max for bodyweight).
  final double estimatedMax;
  _Point(this.date, this.weight, this.estimatedMax);
}

class _ExerciseProgress {
  final Exercise exercise;

  /// A bodyweight lift, by its load style: its maxes are rep maxes, even
  /// with added weight.
  final bool bodyweight;
  final List<_Point> points;

  /// Every session of the lift, whatever the span: what the chart plots.
  final List<_Point> history;

  /// Index into the theme's series palette, so the colour follows the theme.
  final int colorIndex;
  _ExerciseProgress({
    required this.exercise,
    required this.bodyweight,
    required this.points,
    List<_Point>? history,
    required this.colorIndex,
  }) : history = history ?? points;

  Color colorIn(ThemeSpec tokens) =>
      tokens.series[colorIndex % tokens.series.length];

  double get start => points.first.weight;
  double get current => points.last.weight;
  double get best =>
      points.map((p) => p.weight).reduce((a, b) => a > b ? a : b);
  double get maxNow => points.last.estimatedMax;
  double get gain => current - start;
}
