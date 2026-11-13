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
  });

  @override
  State<HeartRateChart> createState() => _HeartRateChartState();
}

class _HeartRateChartState extends State<HeartRateChart> {
  static const double _defaultLiveWindowSeconds = 600; // 10 min
  // Between an axis label and the plot.
  static const double _axisGap = 4;

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
    const minY = 0.0;
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
    final leftAxisWidth =
        _labelSize(context, '${maxY.round()}', caption).width + _axisGap + 2;
    final bottomAxisHeight =
        _labelSize(context, formatElapsedHms(maxX.round()), caption).height + 8;
    // Colour the single line by HR zone with a vertical stepped gradient
    // (one series) instead of emitting a separate series per point pair.
    final gradient = zoneGradient(zones, maxY, context.tokens.heartZones);

    final header = Row(
      children: [
        Text(
          copy.heartRate.title,
          style: TextStyle(
            fontSize: context.tokens.size.small,
            fontWeight: context.tokens.weight.bold,
            color: colorScheme.tertiary,
          ),
        ),
        const Spacer(),
        Text(
          '${currentBpm.round()}',
          style: TextStyle(
            fontSize: context.tokens.size.titleLg,
            fontWeight: context.tokens.weight.heavy,
            height: 1.0,
            color: zoneColor,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          copy.heartRate.bpm,
          style: TextStyle(
            fontSize: context.tokens.size.small,
            fontWeight: context.tokens.weight.bold,
            color: colorScheme.tertiary,
          ),
        ),
        if (currentZone != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: zoneColor.withValues(alpha: 0.12),
              borderRadius: context.tokens.brXs,
            ),
            child: Text(
              '${currentZone.name} ${currentZone.label}',
              style: TextStyle(
                fontSize: context.tokens.size.caption,
                fontWeight: context.tokens.weight.bold,
                color: zoneColor,
              ),
            ),
          ),
        ],
        if (_zoneProfileLoaded &&
            _zoneProfile != null &&
            _zoneProfile!.ageYears != null) ...[
          const SizedBox(width: 8),
          Text(
            _zoneProfile!.hasRestingHeartRate
                ? copy.heartRate.zonesByReserve
                : copy.heartRate.zonesByMax,
            style: TextStyle(
              fontSize: context.tokens.size.caption,
              fontWeight: context.tokens.weight.bold,
              color: colorScheme.tertiary,
            ),
          ),
        ],
        if (_zoneProfile?.restingHeartRateBpm != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: context.tokens.brXs,
            ),
            child: Text(
              copy.heartRate.resting.replaceAll(
                '{bpm}',
                '${_zoneProfile!.restingHeartRateBpm!.round()}',
              ),
              style: TextStyle(
                fontSize: context.tokens.size.caption,
                fontWeight: context.tokens.weight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ],
    );

    final side = EdgeInsets.symmetric(horizontal: widget.inset);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A finished workout has no "now" to read a current BPM from: the
        // plot starts at the top.
        if (widget.followLiveClock) ...[
          Padding(padding: side, child: header),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: side,
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
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: leftAxisWidth,
                          interval: 10,
                          minIncluded: false,
                          maxIncluded: false,
                          getTitlesWidget: (value, meta) {
                            final bpm = value.round();
                            final boundaryValues = <int>{
                              0,
                              ...zones.map((z) => z.low),
                              ...zones.map((z) => z.high),
                            };
                            if (boundaryValues.contains(bpm)) {
                              return SideTitleWidget(
                                meta: meta,
                                space: _axisGap,
                                fitInside: SideTitleFitInsideData.fromTitleMeta(
                                  meta,
                                ),
                                child: Text(
                                  '$bpm',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: context.tokens.size.caption,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
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
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    rangeAnnotations: RangeAnnotations(
                      horizontalRangeAnnotations: const [],
                      verticalRangeAnnotations: restBands,
                    ),
                    extraLinesData: ExtraLinesData(
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
                _buildLiveWindowButton(
                  context,
                  label: copy.heartRate.window5m,
                  spanSec: 300,
                ),
                const SizedBox(width: 6),
                _buildLiveWindowButton(
                  context,
                  label: copy.heartRate.window10m,
                  spanSec: 600,
                ),
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
    final start = max(0.0, nowSec - span * _liveNowAnchorFraction);
    return clampViewport(
      startSec: start,
      spanSec: span,
      domainMaxX: domainMaxX,
    );
  }

  Widget _buildLiveWindowButton(
    BuildContext context, {
    required String label,
    required double spanSec,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _isLiveViewport && _selectedLiveWindowSpanSec == spanSec;
    return FilledButton.tonal(
      onPressed: () {
        setState(() {
          _selectedLiveWindowSpanSec = spanSec;
          _isLiveViewport = true;
          _hasManualViewport = false;
          _manualWindowStartSec = 0;
          _manualWindowSpanSec = spanSec;
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
        label,
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
