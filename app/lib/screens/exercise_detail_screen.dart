import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../gen/copy.dart';
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
import 'reload_on_account_change.dart';

/// One lift, in depth: tap a card on Progress to see its history over the
/// span picked — the estimated max after each session with the heaviest set
/// under it, the totals, the records and when they happened, and every
/// session by month. Progress shows the trend across lifts; this is the
/// drill-down for a single one.
class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

/// The least the chart zooms in to.
const _shortestSpan = Duration(days: 7);

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen>
    with ReloadOnAccountChange {
  List<_Session>? _sessions;
  bool _isLoading = true;
  int _windowIdx = 0; // default: All, the first

  /// The span the user panned or pinched the chart to; null while a tab's
  /// span shows.
  ({DateTime from, DateTime to})? _custom;

  /// Where a pan or pinch began: the span then, and the finger's place on
  /// the chart (0 left, 1 right).
  ({DateTime from, DateTime to})? _gestureSpan;
  double _gestureAt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reload() => _load();

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
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
            copy.exercise.empty,
            style: TextStyle(color: cs.tertiary),
          ),
        ),
      );
    }

    final suffix = weightUnitSuffix(unit);
    final current = sessions.last.topWeight;
    // A bodyweight lift's max is a rep max, and its heaviest set is reps.
    final bodyweight = sessions.every((s) => s.topWeight <= 0);
    final maxNow = sessions.last.estimatedMax;
    final (:from, :to) = _custom ?? chartSpan(_windowIdx, sessions.first.date);
    final inSpan = sessions
        .where((s) => !s.date.isBefore(from) && !s.date.isAfter(to))
        .toList();
    final totalVolume = inSpan.fold<double>(0, (a, s) => a + s.volume);
    final totalSets = inSpan.fold<int>(0, (a, s) => a + s.sets);

    final header = <Widget>[
      // Headline: the estimated max now, and the heaviest set last time,
      // in the chart's colours.
      FlatSection(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            HeadStat(
              maxText(maxNow, unit, bodyweight: bodyweight),
              copy.exercise.estimatedMax,
              size: context.tokens.size.headline,
              color: context.tokens.series.first,
            ),
            const Spacer(),
            HeadStat(
              bodyweight
                  ? copy.exercise.reps.replaceAll(
                      '{n}',
                      '${sessions.last.topReps}',
                    )
                  : formatWeight(current, unit, includeUnit: true),
              copy.exercise.heaviestLastTime,
              size: context.tokens.size.subtitle,
              color: context.tokens.series[1],
            ),
          ],
        ),
      ),
      // No tab while the chart shows a span of the user's own.
      FlatTabs(
        labels: [for (final w in chartWindows) w.label],
        selected: _custom == null ? _windowIdx : -1,
        onSelect: (i) => setState(() {
          _windowIdx = i;
          _custom = null;
        }),
      ),
      FlatSection(
        child: SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onScaleStart: (d) => _gestureBegan(
                d.localFocalPoint.dx,
                constraints.maxWidth,
                (from: from, to: to),
              ),
              onScaleUpdate: (d) => _gestureMoved(
                d.localFocalPoint.dx,
                d.horizontalScale,
                constraints.maxWidth,
                sessions.first.date,
              ),
              onScaleEnd: (_) => setState(() => _gestureSpan = null),
              child: _TrendChart(
                sessions: sessions,
                inSpan: inSpan,
                from: from,
                to: to,
                animate: _gestureSpan == null,
                bodyweight: bodyweight,
                unit: unit,
                maxColor: context.tokens.series.first,
                liftedColor: context.tokens.series[1],
                cs: cs,
              ),
            ),
          ),
        ),
      ),
      if (inSpan.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Center(
            child: Text(
              _custom == null
                  ? copy.exercise.noneInSpan.replaceAll(
                      '{span}',
                      chartWindows[_windowIdx].label,
                    )
                  : copy.exercise.noneHere,
              style: TextStyle(
                color: cs.tertiary,
                fontSize: context.tokens.size.body,
              ),
            ),
          ),
        )
      else ...[
        // Totals over the span.
        FlatSection(
          child: Row(
            children: [
              _footStat(copy.exercise.sessions, '${inSpan.length}', cs),
              const SizedBox(width: 18),
              _footStat(copy.exercise.totalSets, '$totalSets', cs),
              const SizedBox(width: 18),
              _footStat(
                copy.exercise.volume,
                '${compactVolume(totalVolume, unit)} $suffix',
                cs,
              ),
            ],
          ),
        ),
        FlatHeading(copy.exercise.records),
        _Records(
          sessions: inSpan,
          last: sessions.last,
          from: from,
          to: to,
          bodyweight: bodyweight,
          unit: unit,
        ),
      ],
    ];

    // Every session in the span, newest first under its month's heading
    // (a String), as History lists workouts; built as they scroll in.
    final rows = <Object>[];
    (int, int)? month;
    for (final s in inSpan.reversed) {
      final key = (s.date.year, s.date.month);
      if (key != month) {
        month = key;
        rows.add(monthYear(s.date));
      }
      rows.add(s);
    }

    return scaffold(
      ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: header.length + rows.length,
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          final row = rows[index - header.length];
          if (row is String) return FlatHeading(row);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.tokens.hairline),
              ),
            ),
            child: _SessionRow(session: row as _Session, unit: unit, cs: cs),
          );
        },
      ),
    );
  }

  /// A pan or pinch on the chart begins: from the span showing, with the
  /// finger at `x` across a chart `width` wide.
  void _gestureBegan(
    double x,
    double width,
    ({DateTime from, DateTime to}) span,
  ) {
    _gestureSpan = span;
    _gestureAt = _TrendChart.across(x, width);
  }

  /// The finger moved to `x` and the pinch is at `scale`: the date that was
  /// under the finger stays under it, the span narrowing as the fingers
  /// spread. Kept from a week up to the whole history, within it.
  void _gestureMoved(double x, double scale, double width, DateTime first) {
    final start = _gestureSpan;
    if (start == null) return;
    final now = DateTime.now();
    final longest = now.difference(first) + const Duration(days: 7);
    final startMs = start.to.difference(start.from).inMilliseconds;
    final spanMs = (startMs / scale).clamp(
      _shortestSpan.inMilliseconds.toDouble(),
      longest.inMilliseconds.toDouble(),
    );
    final anchor = start.from.millisecondsSinceEpoch + _gestureAt * startMs;
    var fromMs = anchor - _TrendChart.across(x, width) * spanMs;
    final earliest = first.subtract(const Duration(days: 7));
    fromMs = fromMs.clamp(
      earliest.millisecondsSinceEpoch.toDouble(),
      now.millisecondsSinceEpoch - spanMs,
    );
    final from = DateTime.fromMillisecondsSinceEpoch(fromMs.round());
    setState(
      () => _custom = (
        from: from,
        to: from.add(Duration(milliseconds: spanMs.round())),
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

/// The span's records, each with when it happened: the peak estimated max,
/// the heaviest set (most reps, bodyweight), the biggest session, the
/// longest break between sessions, how often, the last session, and how
/// far the max moved.
class _Records extends StatelessWidget {
  final List<_Session> sessions;

  /// The lift's last session of all, whatever the span.
  final _Session last;
  final DateTime from;
  final DateTime to;
  final bool bodyweight;
  final WeightUnit unit;
  const _Records({
    required this.sessions,
    required this.last,
    required this.from,
    required this.to,
    required this.bodyweight,
    required this.unit,
  });

  /// The first session to reach the most of `of`.
  _Session _first(double Function(_Session) of) =>
      sessions.reduce((a, b) => of(b) > of(a) ? b : a);

  @override
  Widget build(BuildContext context) {
    final c = copy.exercise;
    final peak = _first((s) => s.estimatedMax);
    final heaviest = _first(
      (s) => bodyweight ? s.topReps.toDouble() : s.topWeight * 1000 + s.topReps,
    );
    final biggest = _first((s) => s.volume);

    // The longest stretch between two sessions in the span.
    ({int days, DateTime from, DateTime to})? gap;
    for (var i = 1; i < sessions.length; i++) {
      final days = calendarDaysBetween(sessions[i - 1].date, sessions[i].date);
      if (gap == null || days > gap.days) {
        gap = (days: days, from: sessions[i - 1].date, to: sessions[i].date);
      }
    }

    final spanStart = sessions.first.date.isAfter(from)
        ? sessions.first.date
        : from;
    final weeks = to.difference(spanStart).inHours / (24 * 7);
    final pace = sessions.length / (weeks < 1 ? 1 : weeks);

    final ago = calendarDaysBetween(last.date, DateTime.now());
    final lastText = switch (ago) {
      0 => c.today,
      1 => c.yesterday,
      _ => c.daysAgo.replaceAll('{days}', '$ago'),
    };

    final gain = sessions.last.estimatedMax - sessions.first.estimatedMax;
    final gainText = bodyweight
        ? '${gain >= 0 ? '+' : '−'}${gain.abs().round()}'
        : '${gain >= 0 ? '+' : '−'}${formatWeight(gain.abs(), unit, includeUnit: true)}';

    final records = <(String, String, Color?, String?)>[
      (
        c.peakMax,
        maxText(peak.estimatedMax, unit, bodyweight: bodyweight),
        null,
        dayDate(peak.date),
      ),
      (
        bodyweight ? c.mostReps : c.heaviestSet,
        bodyweight
            ? c.reps.replaceAll('{n}', '${heaviest.topReps}')
            : '${formatWeight(heaviest.topWeight, unit, includeUnit: true)} × ${heaviest.topReps}',
        null,
        dayDate(heaviest.date),
      ),
      if (!bodyweight)
        (
          c.biggestSession,
          '${compactVolume(biggest.volume, unit)} ${weightUnitSuffix(unit)}',
          null,
          dayDate(biggest.date),
        ),
      if (gap != null && gap.days > 1)
        (
          c.longestBreak,
          c.breakDays.replaceAll('{days}', '${gap.days}'),
          null,
          '${dayDate(gap.from)} → ${dayDate(gap.to)}',
        ),
      (
        c.pace,
        c.perWeek.replaceAll('{n}', pace.toStringAsFixed(1)),
        null,
        null,
      ),
      (c.lastTrained, lastText, null, dayDate(last.date)),
      if (sessions.length >= 2)
        (
          c.gain,
          gainText,
          gain > 0 ? context.tokens.ready : null,
          c.gainSince.replaceAll('{date}', dayDate(sessions.first.date)),
        ),
    ];

    // Two to a row, so each has room for its date.
    return FlatMetricGrid(
      columns: 2,
      bottomLine: true,
      metrics: [for (final r in records) (r.$1, r.$2, r.$3)],
      notes: [for (final r in records) r.$4],
    );
  }
}

/// A break this long between sessions breaks the chart's lines: time off
/// shows as a gap.
const _breakDays = 14;

/// The estimated max after each session, and under it the heaviest set
/// lifted (reps, for a bodyweight lift), placed by date and shown from
/// [from] to [to]. Every session is plotted whatever the span, so a new
/// span pans and zooms the same lines rather than morphing them.
class _TrendChart extends StatelessWidget {
  final List<_Session> sessions;

  /// The sessions from [from] on: what the y axis fits.
  final List<_Session> inSpan;
  final DateTime from;
  final DateTime to;

  /// Ease to a new span (a tab); false follows a finger as it moves.
  final bool animate;
  final bool bodyweight;
  final WeightUnit unit;
  final Color maxColor;
  final Color liftedColor;
  final ColorScheme cs;
  const _TrendChart({
    required this.sessions,
    required this.inSpan,
    required this.from,
    required this.to,
    required this.animate,
    required this.bodyweight,
    required this.unit,
    required this.maxColor,
    required this.liftedColor,
    required this.cs,
  });

  /// The left axis's labels' width: the plot starts after it.
  static const _axisWidth = 36.0;

  /// How far across the plot `x` is, on a chart `width` wide: 0 at its
  /// left edge, 1 at its right.
  static double across(double x, double width) =>
      ((x - _axisWidth) / (width - _axisWidth)).clamp(0.0, 1.0);

  /// Days since the first session: the x axis, the same for every span.
  double _x(DateTime d) =>
      d.difference(sessions.first.date).inMinutes / Duration.minutesPerDay;

  double _lifted(_Session s) => bodyweight ? s.topReps.toDouble() : s.topWeight;

  String _label(double v) =>
      bodyweight ? '${v.round()}' : formatWeight(v, unit);

  /// A line's points, with a gap at each break.
  List<FlSpot> _series(Iterable<_Session> of, double Function(_Session) y) {
    final spots = <FlSpot>[];
    _Session? previous;
    for (final s in of) {
      if (previous != null &&
          s.date.difference(previous.date).inDays > _breakDays) {
        spots.add(FlSpot.nullSpot);
      }
      spots.add(FlSpot(_x(s.date), y(s)));
      previous = s;
    }
    return spots;
  }

  /// A round step that cuts `range` into about four.
  static double _step(double range) {
    final rough = range / 4;
    if (rough <= 0) return 1;
    final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
    for (final m in const [1.0, 2.0, 2.5, 5.0]) {
      if (m * magnitude >= rough) return m * magnitude;
    }
    return 10 * magnitude;
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.2,
    preventCurveOverShooting: true,
    color: color,
    barWidth: 2.5,
    dotData: FlDotData(
      show: true,
      checkToShowDot: (spot, bar) => spot == spots.last,
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
    final liftedSpots = _series(sessions, _lifted);
    final maxSpots = _series(
      sessions.where((s) => s.estimatedMax > 0),
      (s) => s.estimatedMax,
    );
    final vals = [
      for (final s in inSpan.isEmpty ? sessions : inSpan) ...[
        _lifted(s),
        if (s.estimatedMax > 0) s.estimatedMax,
      ],
    ];
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final step = _step(maxV - minV);
    final minY = (minV / step).floor() * step;
    var maxY = (maxV / step).ceil() * step;
    if (maxY <= minY) maxY = minY + step;
    final minX = _x(from);
    final maxX = _x(to);
    final span = maxX - minX;
    final withYear = span > 330;

    return LineChart(
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeInOutCubic,
      LineChartData(
        minX: minX,
        maxX: maxX,
        // The dates count from the left edge: one there, mid-span, the right.
        baselineX: minX,
        clipData: const FlClipData.all(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: cs.outline.withValues(alpha: 0.15), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _axisWidth,
              interval: step,
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
              interval: span / 2,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                space: 4,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(
                  axisDate(
                    sessions.first.date.add(
                      Duration(minutes: (v * Duration.minutesPerDay).round()),
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
        // No tooltips: a touch on the chart pans and pinches it.
        lineTouchData: const LineTouchData(enabled: false),
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
            copy.exercise.sessionLine
                .replaceAll('{sets}', '${session.sets}')
                .replaceAll(
                  '{volume}',
                  '${compactVolume(session.volume, unit)} $suffix',
                ),
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
