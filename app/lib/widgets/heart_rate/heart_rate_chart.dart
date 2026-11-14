import 'dart:async';
import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/wearable.pb.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../services/health_service.dart';
import '../../theme/theme_spec.dart';
import 'legend.dart';
import 'models.dart';
import 'zone_summary.dart';

class HeartRateChart extends StatefulWidget {
  final List<HeartRateSample> heartRateSamples;
  final List<CompletedSet> completedSets;
  final Int64 workoutStartTime; // seconds
  final DateTime now;
  final WorkoutStateSnapshot? stateSnapshot;
  final bool followLiveClock;

  /// The side margins of the plot, its legend and the zones; the figures
  /// (avg, max, min) run edge to edge in a grid.
  final double inset;

  /// Whether the figures' grid draws its own bottom line when nothing
  /// follows it; off where the section's hairline already ends it there.
  final bool closeGrid;

  /// Something to do about the reading, at the right of it in the header
  /// (the live page's "open the watch app").
  final Widget? headerAction;

  const HeartRateChart({
    super.key,
    required this.heartRateSamples,
    required this.completedSets,
    required this.workoutStartTime,
    required this.now,
    this.stateSnapshot,
    this.followLiveClock = true,
    this.inset = 0,
    this.closeGrid = true,
    this.headerAction,
  });

  @override
  State<HeartRateChart> createState() => _HeartRateChartState();
}

class _HeartRateChartState extends State<HeartRateChart> {
  static const double _defaultLiveWindowSeconds = 600; // 10 min

  /// The laid-out size of one axis label, in the app's theme and the
  /// device's text scale.
  static Size _labelSize(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  static const double _liveNowAnchorFraction = 0.75; // 3/4 across

  Timer? _repaintTimer;
  HeartRateZoneProfile? _zoneProfile;
  bool _zoneProfileLoaded = false;
  late List<HeartRateSample> _uiHeartRateSamples;
  late List<CompletedSet> _uiCompletedSets;
  late DateTime _uiNow;
  WorkoutStateSnapshot? _uiStateSnapshot;
  bool _isLiveViewport = true;
  bool _hasManualViewport = false;
  double _manualWindowStartSec = 0;
  double _manualWindowSpanSec = _defaultLiveWindowSeconds;
  double _selectedLiveWindowSpanSec = _defaultLiveWindowSeconds;
  double? _gestureStartWindowStartSec;
  double? _gestureStartWindowSpanSec;
  double? _gestureStartLocalFocalX;

  @override
  void initState() {
    super.initState();
    _syncUiSnapshotFromWidget();
    _configureRepaintTimer();
    unawaited(_loadZoneProfile());
  }

  @override
  void didUpdateWidget(covariant HeartRateChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.followLiveClock != widget.followLiveClock) {
      _configureRepaintTimer();
      _syncUiSnapshotFromWidget();
      return;
    }

    if (!widget.followLiveClock) {
      // Summary/snapshot chart should reflect incoming data immediately.
      _syncUiSnapshotFromWidget();
      return;
    }

    final stateChanged =
        _stateSnapshotKey(oldWidget.stateSnapshot) !=
        _stateSnapshotKey(widget.stateSnapshot);
    final setsChanged =
        _completedSetListKey(oldWidget.completedSets) !=
        _completedSetListKey(widget.completedSets);

    if (stateChanged || setsChanged) {
      // Keep phase transitions / completed set edges immediate.
      _syncUiSnapshotFromWidget();
    }
    // Otherwise allow the 1 Hz timer to pull the latest HR samples/now.
  }

  @override
  void dispose() {
    _repaintTimer?.cancel();
    super.dispose();
  }

  void _configureRepaintTimer() {
    _repaintTimer?.cancel();
    _repaintTimer = null;
    if (!widget.followLiveClock) return;
    _repaintTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _syncUiSnapshotFromWidget();
    });
  }

  void _syncUiSnapshotFromWidget() {
    if (!mounted) {
      _uiHeartRateSamples = widget.heartRateSamples;
      _uiCompletedSets = widget.completedSets;
      _uiNow = widget.now;
      _uiStateSnapshot = widget.stateSnapshot;
      return;
    }
    setState(() {
      _uiHeartRateSamples = widget.heartRateSamples;
      _uiCompletedSets = widget.completedSets;
      _uiNow = widget.now;
      _uiStateSnapshot = widget.stateSnapshot;
    });
  }

  String _stateSnapshotKey(WorkoutStateSnapshot? snapshot) {
    if (snapshot == null) return 'null';
    return '${snapshot.state.value}:${snapshot.restUntil.toInt()}';
  }

  String _completedSetListKey(List<CompletedSet> sets) {
    if (sets.isEmpty) return '0';
    final last = sets.last;
    return '${sets.length}:${last.endedAt.toInt()}:${last.restUntil.toInt()}';
  }

  Future<void> _loadZoneProfile() async {
    final profile = await HealthService.readHeartRateZoneProfile();
    if (!mounted) return;
    setState(() {
      _zoneProfile = profile;
      _zoneProfileLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heartRateSamples = _uiHeartRateSamples;
    final startMs = widget.workoutStartTime.toInt() * 1000;
    final localNow = DateTime.now();
    final effectiveNow = widget.followLiveClock
        ? (_uiNow.isAfter(localNow) ? _uiNow : localNow)
        : _uiNow;

    if (heartRateSamples.isEmpty) return const SizedBox.shrink();

    final nowSec = (effectiveNow.millisecondsSinceEpoch - startMs) / 1000.0;
    final dataMaxX = max(
      nowSec,
      (heartRateSamples.last.sampledAt.toInt() - startMs) / 1000.0,
    );
    final predictedRestEndSec = _predictedCurrentRestEndSec(startMs);
    final domainMaxX = max(dataMaxX, predictedRestEndSec ?? 0.0);
    final liveWindow = _computeLiveViewport(nowSec, domainMaxX);
    final viewport = (widget.followLiveClock && _isLiveViewport)
        ? liveWindow
        : _hasManualViewport
        ? clampViewport(
            startSec: _manualWindowStartSec,
            spanSec: _manualWindowSpanSec,
            domainMaxX: domainMaxX,
          )
        : widget.followLiveClock
        ? liveWindow
        : clampViewport(
            startSec: 0,
            spanSec: max(domainMaxX, minWindowSeconds),
            domainMaxX: domainMaxX,
          );
    final minX = viewport.startSec;
    final maxX = viewport.endSec;
    final viewportSamples = samplesInRange(
      heartRateSamples,
      startMs: startMs,
      minX: minX,
      maxX: maxX,
      marginSec: 30,
    );
    // The floor sits a little under the lowest reading (never over 80), on a
    // round twenty: no empty band from there down to zero.
    final lowest = heartRateSamples.fold<double>(
      100,
      (low, s) => s.bpm < low ? s.bpm.toDouble() : low,
    );
    final minY = (((lowest - 10) ~/ 20) * 20).clamp(0, 80).toDouble();
    final effectiveMaxHr =
        _zoneProfile?.estimatedMaxHeartRateBpm ?? defaultMaxHr;
    final zones = zonesForConfig(
      maxHr: effectiveMaxHr,
      restingHr: _zoneProfile?.restingHeartRateBpm,
    );
    final maxY = max(defaultMaxHr.toDouble(), effectiveMaxHr.toDouble());
    final downsampled = _downsample(viewportSamples, startMs, 500, maxY);
    final spots = _extendSpotsToNow(downsampled, nowSec);

    // The latest reading, wherever the window is (the header shows only
    // live).
    final currentBpm = heartRateSamples.last.bpm;
    final currentZone = zoneFor(currentBpm, zones);
    final zoneColor = zoneColorByName(
      currentZone?.name ?? 'Z1',
      context.tokens.heartZones,
    );
    final restBands = _clipVerticalAnnotations(
      _phaseAnnotations(context, startMs, nowSec),
      minX: minX,
      maxX: maxX,
    );
    final bottomInterval = _bottomAxisInterval(viewport.spanSec);
    // Each axis is as wide (or tall) as its widest label, measured in the
    // style and text scale it is drawn in, so no label wraps or clips.
    final caption = TextStyle(fontSize: context.tokens.size.caption);
    final bottomAxisHeight =
        _labelSize(context, formatElapsedHms(maxX.round()), caption).height + 8;
    // Colour the single line by HR zone with a vertical stepped gradient
    // (one series) instead of emitting a separate series per point pair.
    final gradient = zoneGradient(zones, maxY, context.tokens.heartZones);

    final t = context.tokens;
    // The lines the plot is ruled with: the zones' edges.
    // The plot is ruled every twenty beats, floor to ceiling.
    final boundaries = <int>[
      for (var bpm = minY.round() + 20; bpm < maxY; bpm += 20) bpm,
    ];
    final resting = _zoneProfile?.restingHeartRateBpm;
    // The reading now, as two blocks edge to edge: the number as big as it
    // goes, and the zone it is in as a block of the zone's colour.
    final header = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: t.hairline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.heartRate.title, style: t.label()),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${currentBpm.round()}',
                          style: t.mono(
                            TextStyle(
                              fontSize: t.size.giant,
                              fontWeight: t.weight.bold,
                              height: 1.05,
                              color: zoneColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(copy.heartRate.bpm, style: t.label()),
                        if (widget.headerAction != null) ...[
                          const Spacer(),
                          widget.headerAction!,
                        ],
                      ],
                    ),
                    if (resting != null)
                      Text(
                        copy.heartRate.resting.replaceAll(
                          '{bpm}',
                          '${resting.round()}',
                        ),
                        style: t.label(),
                      ),
                  ],
                ),
              ),
            ),
            if (currentZone != null)
              Expanded(
                flex: 2,
                child: Container(
                  color: zoneColor,
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentZone.name,
                        style: t.mono(
                          TextStyle(
                            fontSize: t.size.displayLg,
                            fontWeight: t.weight.bold,
                            height: 1,
                            color: t.inkOn(zoneColor),
                          ),
                        ),
                      ),
                      Text(
                        [
                          currentZone.label,
                          if (_zoneProfileLoaded &&
                              _zoneProfile != null &&
                              _zoneProfile!.ageYears != null)
                            _zoneProfile!.hasRestingHeartRate
                                ? copy.heartRate.zonesByReserve
                                : copy.heartRate.zonesByMax,
                        ].join(' '),
                        style: t.mono(
                          TextStyle(
                            fontSize: t.size.body,
                            fontWeight: t.weight.bold,
                            color: t.inkOn(zoneColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final side = EdgeInsets.symmetric(horizontal: widget.inset);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A finished workout has no "now" to read a current BPM from: the
        // plot starts at the top.
        if (widget.followLiveClock) header,
        // The plot runs from one edge of the page to the other, like every
        // section's lines: its rules are the zones' edges, each numbered
        // inside the plot at the left.
        Padding(
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 320,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (details) {
                  _gestureStartWindowStartSec = minX;
                  _gestureStartWindowSpanSec = maxX - minX;
                  _gestureStartLocalFocalX = details.localFocalPoint.dx;
                },
                onScaleUpdate: (details) {
                  final width = constraints.maxWidth;
                  final startStart = _gestureStartWindowStartSec;
                  final startSpan = _gestureStartWindowSpanSec;
                  final startFocalX = _gestureStartLocalFocalX;
                  if (width <= 0 ||
                      startStart == null ||
                      startSpan == null ||
                      startFocalX == null) {
                    return;
                  }

                  final clampedScale = details.scale.clamp(0.5, 4.0);
                  var newSpan = (startSpan / clampedScale).clamp(
                    minWindowSeconds,
                    maxWindowSeconds,
                  );

                  final startFrac = (startFocalX / width).clamp(0.0, 1.0);
                  final currFrac = (details.localFocalPoint.dx / width).clamp(
                    0.0,
                    1.0,
                  );
                  final focalTimeAtStart = startStart + startSpan * startFrac;
                  var newStart = focalTimeAtStart - newSpan * currFrac;

                  final clamped = clampViewport(
                    startSec: newStart,
                    spanSec: newSpan,
                    domainMaxX: domainMaxX,
                  );
                  setState(() {
                    _hasManualViewport = true;
                    if (widget.followLiveClock) {
                      _isLiveViewport = false;
                    }
                    _manualWindowStartSec = clamped.startSec;
                    _manualWindowSpanSec = clamped.spanSec;
                  });
                },
                child: LineChart(
                  LineChartData(
                    minX: minX,
                    maxX: maxX,
                    minY: minY,
                    maxY: maxY,
                    clipData: const FlClipData.all(),
                    lineTouchData: const LineTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      // The line's colour says the zone: no names beside it.
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: bottomAxisHeight,
                          interval: bottomInterval,
                          // The window's own ends aren't on
                          // the interval; their labels would
                          // land on the neighbours'.
                          minIncluded: false,
                          maxIncluded: false,
                          getTitlesWidget: (value, meta) {
                            if (value < 0 || value > maxX + 0.5) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              space: 6,
                              fitInside: SideTitleFitInsideData.fromTitleMeta(
                                meta,
                              ),
                              child: Text(
                                formatElapsedHms(value.round()),
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: context.tokens.size.caption,
                                  color: t.muted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(
                      // The reading's block ends in the line over the plot.
                      border: Border(bottom: BorderSide(color: t.outline)),
                    ),
                    rangeAnnotations: RangeAnnotations(
                      horizontalRangeAnnotations: const [],
                      verticalRangeAnnotations: restBands,
                    ),
                    extraLinesData: ExtraLinesData(
                      extraLinesOnTop: false,
                      horizontalLines: [
                        for (final bpm in boundaries)
                          if (bpm > minY && bpm < maxY)
                            HorizontalLine(
                              y: bpm.toDouble(),
                              color: t.hairline,
                              strokeWidth: 1,
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topLeft,
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  bottom: 2,
                                ),
                                style: t.mono(
                                  TextStyle(
                                    fontSize: t.size.caption,
                                    color: t.muted,
                                  ),
                                ),
                                labelResolver: (line) => '${line.y.round()}',
                              ),
                            ),
                      ],
                      verticalLines: [
                        VerticalLine(
                          x: nowSec,
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ],
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.2,
                        gradient: gradient,
                        barWidth: 2.0,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                  duration: Duration.zero,
                  transformationConfig: const FlTransformationConfig(
                    scaleAxis: FlScaleAxis.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: side,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    HeartRateLegendItem(
                      label: copy.workout.lifting,
                      color: context.tokens.lifting,
                    ),
                    HeartRateLegendItem(
                      label: copy.workout.resting,
                      color: context.tokens.resting,
                    ),
                    HeartRateLegendItem(
                      label: copy.workout.yapping,
                      color: context.tokens.yapping,
                    ),
                  ],
                ),
              ),
              if (widget.followLiveClock) ...[
                const SizedBox(width: 8),
                _buildLatestButton(context, viewport.spanSec),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        ZoneSummary(
          samples: heartRateSamples,
          zones: zones,
          inset: widget.inset,
          closeGrid: widget.closeGrid,
        ),
      ],
    );
  }

  List<FlSpot> _downsample(
    List<HeartRateSample> samples,
    int startMs,
    int maxPoints,
    double maxBpm,
  ) {
    if (samples.length <= maxPoints) {
      return samples
          .map(
            (s) => FlSpot(
              (s.sampledAt.toInt() - startMs) / 1000.0,
              s.bpm.clamp(0, maxBpm),
            ),
          )
          .toList();
    }

    final step = samples.length / maxPoints;
    final result = <FlSpot>[];
    for (var i = 0; i < maxPoints; i++) {
      final s = samples[(i * step).floor()];
      result.add(
        FlSpot(
          (s.sampledAt.toInt() - startMs) / 1000.0,
          s.bpm.clamp(0, maxBpm),
        ),
      );
    }
    return result;
  }

  List<FlSpot> _extendSpotsToNow(List<FlSpot> spots, double nowSec) {
    if (spots.isEmpty) return spots;
    final out = List<FlSpot>.from(spots);
    final last = out.last;
    if (nowSec > last.x + 0.25) {
      out.add(FlSpot(nowSec, last.y));
    }
    return out;
  }

  /// The workout's phases as shaded bands; see [phaseBands]. Lifting is
  /// the short, important stretch: it gets the stronger tint.
  List<VerticalRangeAnnotation> _phaseAnnotations(
    BuildContext context,
    int startMs,
    double nowSec,
  ) {
    final snapshot = _uiStateSnapshot;
    final live = widget.followLiveClock && snapshot != null;
    final liftStart =
        live &&
            snapshot.state == WorkoutState.WORKOUT_STATE_LIFTING &&
            snapshot.liftingStartedAt > Int64.ZERO
        ? (snapshot.liftingStartedAt.toInt() * 1000 - startMs) / 1000.0
        : null;
    final t = context.tokens;
    return [
      for (final b in phaseBands(
        _uiCompletedSets,
        startMs: startMs,
        liveNowSec: live ? nowSec : null,
        liveLiftStartSec: liftStart,
      ))
        VerticalRangeAnnotation(
          x1: b.x1,
          x2: b.x2,
          color: switch (b.phase) {
            WorkoutPhase.lifting => t.lifting.withValues(alpha: 0.4),
            WorkoutPhase.resting => t.resting.withValues(alpha: 0.16),
            WorkoutPhase.yapping => t.yapping.withValues(alpha: 0.16),
          },
        ),
    ];
  }

  ChartViewport _computeLiveViewport(double nowSec, double domainMaxX) {
    final span = _selectedLiveWindowSpanSec;
    // Now sits three quarters across from the first second on.
    final start = nowSec - span * _liveNowAnchorFraction;
    return clampViewport(
      startSec: start,
      spanSec: span,
      domainMaxX: domainMaxX,
    );
  }

  /// "Latest": lit while the window follows now. Panning or zooming puts
  /// it out; a tap puts the window back on now, at the zoom it has.
  Widget _buildLatestButton(BuildContext context, double spanSec) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _isLiveViewport;
    return FilledButton.tonal(
      onPressed: () {
        setState(() {
          _selectedLiveWindowSpanSec = spanSec;
          _isLiveViewport = true;
          _hasManualViewport = false;
        });
      },
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: isSelected
            ? colorScheme.primary.withValues(alpha: 0.18)
            : colorScheme.surfaceContainer,
      ),
      child: Text(
        copy.heartRate.latest,
        style: TextStyle(
          fontWeight: context.tokens.weight.heavy,
          fontSize: context.tokens.size.small,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
    );
  }

  double? _predictedCurrentRestEndSec(int startMs) {
    final snapshot = _uiStateSnapshot;
    if (snapshot == null) return null;
    if (snapshot.state != WorkoutState.WORKOUT_STATE_RESTING) return null;
    final restUntil = snapshot.restUntil.toInt();
    if (restUntil <= 0) return null;
    return ((restUntil * 1000) - startMs) / 1000.0;
  }

  List<VerticalRangeAnnotation> _clipVerticalAnnotations(
    List<VerticalRangeAnnotation> annotations, {
    required double minX,
    required double maxX,
  }) {
    final out = <VerticalRangeAnnotation>[];
    for (final a in annotations) {
      final x1 = max(minX, a.x1);
      final x2 = min(maxX, a.x2);
      if (x2 <= x1) continue;
      out.add(VerticalRangeAnnotation(x1: x1, x2: x2, color: a.color));
    }
    return out;
  }

  double _bottomAxisInterval(double maxX) {
    if (maxX <= 90) return 15;
    if (maxX <= 300) return 60;
    if (maxX <= 900) return 120;
    if (maxX <= 1800) return 300;
    if (maxX <= 3600) return 600;
    return 900;
  }
}
