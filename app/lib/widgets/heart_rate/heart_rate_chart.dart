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
import 'trend_painter.dart';
import '../../theme/app_icons.dart';

class HeartRateChart extends StatefulWidget {
  final List<HeartRateSample> heartRateSamples;
  final List<CompletedSet> completedSets;
  final Int64 workoutStartTime; // seconds
  final DateTime now;
  final WorkoutStateSnapshot? stateSnapshot;
  final bool followLiveClock;
  final bool collapsible;
  final bool startCollapsed;

  /// Full-page mode: no card chrome, never collapsible, taller chart, and an
  /// extra avg/max/min + time-in-zone summary below it.
  final bool fullView;

  const HeartRateChart({
    super.key,
    required this.heartRateSamples,
    required this.completedSets,
    required this.workoutStartTime,
    required this.now,
    this.stateSnapshot,
    this.followLiveClock = true,
    this.collapsible = false,
    this.startCollapsed = false,
    this.fullView = false,
  });

  // Standard fallback when a personalized max HR isn't available.
  static const int _maxHr = 200;
  static const List<HeartRateZonePercent> _zonePercents = [
    HeartRateZonePercent('Z1', '50-60%', 0.50, 0.60),
    HeartRateZonePercent('Z2', '60-70%', 0.60, 0.70),
    HeartRateZonePercent('Z3', '70-80%', 0.70, 0.80),
    HeartRateZonePercent('Z4', '80-90%', 0.80, 0.90),
    HeartRateZonePercent('Z5', '90-100%', 0.90, 1.00),
  ];

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
  static const double _minWindowSeconds = 60;
  static const double _maxWindowSeconds = 3600;

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
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.collapsible && widget.startCollapsed;
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

    final available = heartRateSamples
        .where(
          (s) =>
              s.availability ==
              HeartRateAvailability.HEART_RATE_AVAILABILITY_AVAILABLE,
        )
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();

    final nowSec = (effectiveNow.millisecondsSinceEpoch - startMs) / 1000.0;
    final dataMaxX = max(
      nowSec,
      (available.last.sampledAt.toInt() - startMs) / 1000.0,
    );
    final predictedRestEndSec = _predictedCurrentRestEndSec(startMs);
    final domainMaxX = max(dataMaxX, predictedRestEndSec ?? 0.0);
    final liveWindow = _computeLiveViewport(nowSec, domainMaxX);
    final viewport = (widget.followLiveClock && _isLiveViewport)
        ? liveWindow
        : _hasManualViewport
        ? _clampViewport(
            startSec: _manualWindowStartSec,
            spanSec: _manualWindowSpanSec,
            domainMaxX: domainMaxX,
          )
        : widget.followLiveClock
        ? liveWindow
        : _clampViewport(
            startSec: 0,
            spanSec: max(domainMaxX, _minWindowSeconds),
            domainMaxX: domainMaxX,
          );
    final minX = viewport.startSec;
    final maxX = viewport.endSec;
    final viewportSamples = _samplesInRange(
      available,
      startMs: startMs,
      minX: minX,
      maxX: maxX,
      marginSec: 30,
    );
    final downsampled = _downsample(viewportSamples, startMs, 500);
    final spots = _extendSpotsToNow(downsampled, nowSec);

    const minY = 0.0;
    final effectiveMaxHr =
        _zoneProfile?.estimatedMaxHeartRateBpm ?? HeartRateChart._maxHr;
    final zones = _zonesForConfig(
      maxHr: effectiveMaxHr,
      restingHr: _zoneProfile?.restingHeartRateBpm,
    );
    final maxY = max(
      HeartRateChart._maxHr.toDouble(),
      effectiveMaxHr.toDouble(),
    );

    final currentBpm = spots.last.y;
    final currentZone = zoneFor(currentBpm, zones);
    final zoneColor = _zoneColorForBpm(currentBpm, zones);
    final restBands = _clipVerticalAnnotations(
      _buildPhaseBands(startMs, nowSec),
      minX: minX,
      maxX: maxX,
    );
    final bottomInterval = _bottomAxisInterval(viewport.spanSec);
    // Each axis is as wide (or tall) as its widest label, measured in the
    // style and text scale it is drawn in, so no label wraps or clips.
    final caption = TextStyle(fontSize: context.tokens.size.caption);
    final leftAxisWidth =
        _labelSize(context, '${maxY.round()}', caption).width + _axisGap + 2;
    final rightAxisWidth =
        zones
            .map(
              (z) => _labelSize(
                context,
                z.name,
                caption.copyWith(fontWeight: context.tokens.weight.bold),
              ).width,
            )
            .fold(0.0, max) +
        _axisGap +
        2;
    final bottomAxisHeight =
        _labelSize(context, formatElapsedHms(maxX.round()), caption).height + 8;
    // Colour the single line by HR zone with a vertical stepped gradient
    // (one series) instead of emitting a separate series per point pair.
    final gradient = zoneGradient(zones, maxY);

    final expandedHeader = Row(
      children: [
        Text(
          'HEART RATE',
          style: TextStyle(
            fontSize: context.tokens.size.small,
            fontWeight: context.tokens.weight.bold,
            letterSpacing: 1.5,
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
          'BPM',
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
              borderRadius: context.tokens.br(4),
            ),
            child: Text(
              '${currentZone.name} ${currentZone.label}',
              style: TextStyle(
                fontSize: context.tokens.size.caption,
                fontWeight: context.tokens.weight.bold,
                letterSpacing: 0.5,
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
            _zoneProfile!.hasRestingHeartRate ? 'HRR' : '%MAX',
            style: TextStyle(
              fontSize: context.tokens.size.caption,
              fontWeight: context.tokens.weight.bold,
              letterSpacing: 0.5,
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
              borderRadius: context.tokens.br(4),
            ),
            child: Text(
              'zzz ${_zoneProfile!.restingHeartRateBpm!.round()}',
              style: TextStyle(
                fontSize: context.tokens.size.caption,
                fontWeight: context.tokens.weight.bold,
                letterSpacing: 0.3,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
        if (widget.collapsible) ...[
          const SizedBox(width: 6),
          Icon(
            _collapsed ? AppIcons.expandDown : AppIcons.expandUp,
            color: colorScheme.tertiary,
          ),
        ],
      ],
    );

    final collapsedHeader = Row(
      children: [
        Text(
          'HEART RATE',
          style: TextStyle(
            fontSize: context.tokens.size.small,
            fontWeight: context.tokens.weight.bold,
            letterSpacing: 1.5,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 24,
            child: CustomPaint(
              painter: HeartRateTrendPainter(samples: available, zones: zones),
            ),
          ),
        ),
        const SizedBox(width: 12),
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
          'BPM',
          style: TextStyle(
            fontSize: context.tokens.size.small,
            fontWeight: context.tokens.weight.bold,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 6),
        Icon(AppIcons.expandDown, color: colorScheme.tertiary),
      ],
    );

    return Container(
      padding: widget.fullView ? EdgeInsets.zero : const EdgeInsets.all(12),
      decoration: widget.fullView
          ? null
          : BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: context.tokens.br(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.35),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: context.tokens.br(8),
            onTap: widget.collapsible
                ? () => setState(() => _collapsed = !_collapsed)
                : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _collapsed && widget.collapsible
                  ? KeyedSubtree(
                      key: const ValueKey('collapsed-hr-header'),
                      child: collapsedHeader,
                    )
                  : KeyedSubtree(
                      key: const ValueKey('expanded-hr-header'),
                      child: expandedHeader,
                    ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: ClipRect(
              child: _collapsed && widget.collapsible
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        const SizedBox(height: 8),
                        SizedBox(
                          height: widget.fullView ? 320 : 160,
                          child: LayoutBuilder(
                            builder: (context, constraints) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onScaleStart: (details) {
                                _gestureStartWindowStartSec = minX;
                                _gestureStartWindowSpanSec = maxX - minX;
                                _gestureStartLocalFocalX =
                                    details.localFocalPoint.dx;
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

                                final clampedScale = details.scale.clamp(
                                  0.5,
                                  4.0,
                                );
                                var newSpan = (startSpan / clampedScale).clamp(
                                  _minWindowSeconds,
                                  _maxWindowSeconds,
                                );

                                final startFrac = (startFocalX / width).clamp(
                                  0.0,
                                  1.0,
                                );
                                final currFrac =
                                    (details.localFocalPoint.dx / width).clamp(
                                      0.0,
                                      1.0,
                                    );
                                final focalTimeAtStart =
                                    startStart + startSpan * startFrac;
                                var newStart =
                                    focalTimeAtStart - newSpan * currFrac;

                                final clamped = _clampViewport(
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
                                  lineTouchData: const LineTouchData(
                                    enabled: false,
                                  ),
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
                                              fitInside:
                                                  SideTitleFitInsideData.fromTitleMeta(
                                                    meta,
                                                  ),
                                              child: Text(
                                                '$bpm',
                                                maxLines: 1,
                                                softWrap: false,
                                                style: TextStyle(
                                                  fontSize: context
                                                      .tokens
                                                      .size
                                                      .caption,
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    rightTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: rightAxisWidth,
                                        interval: 5,
                                        minIncluded: false,
                                        maxIncluded: false,
                                        getTitlesWidget: (value, meta) {
                                          for (final z in zones) {
                                            final mid = (z.low + z.high) / 2.0;
                                            if ((value - mid).abs() < 1) {
                                              return SideTitleWidget(
                                                meta: meta,
                                                space: _axisGap,
                                                fitInside:
                                                    SideTitleFitInsideData.fromTitleMeta(
                                                      meta,
                                                    ),
                                                child: Text(
                                                  z.name,
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  style: TextStyle(
                                                    fontSize: context
                                                        .tokens
                                                        .size
                                                        .caption,
                                                    fontWeight: context
                                                        .tokens
                                                        .weight
                                                        .bold,
                                                    color: colorScheme.onSurface
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
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
                                            fitInside:
                                                SideTitleFitInsideData.fromTitleMeta(
                                                  meta,
                                                ),
                                            child: Text(
                                              formatElapsedHms(value.round()),
                                              maxLines: 1,
                                              softWrap: false,
                                              style: TextStyle(
                                                fontSize:
                                                    context.tokens.size.caption,
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.45),
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
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.35,
                                        ),
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
                                transformationConfig:
                                    const FlTransformationConfig(
                                      scaleAxis: FlScaleAxis.none,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  HeartRateLegendItem(
                                    label: copy.workout.lifting,
                                    color: context.tokens.workoutLiftingFg,
                                  ),
                                  HeartRateLegendItem(
                                    label: copy.workout.resting,
                                    color: context.tokens.workoutRestingFg,
                                  ),
                                  HeartRateLegendItem(
                                    label: copy.workout.yapping,
                                    color: context.tokens.workoutYappingFg,
                                  ),
                                ],
                              ),
                            ),
                            if (widget.followLiveClock) ...[
                              const SizedBox(width: 8),
                              _buildLiveWindowButton(
                                context,
                                label: '5m',
                                spanSec: 300,
                              ),
                              const SizedBox(width: 6),
                              _buildLiveWindowButton(
                                context,
                                label: '10m',
                                spanSec: 600,
                              ),
                            ],
                          ],
                        ),
                        if (widget.fullView) ...[
                          const SizedBox(height: 18),
                          ZoneSummary(samples: available, zones: zones),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _downsample(
    List<HeartRateSample> samples,
    int startMs,
    int maxPoints,
  ) {
    if (samples.length <= maxPoints) {
      return samples
          .map(
            (s) => FlSpot(
              (s.sampledAt.toInt() - startMs) / 1000.0,
              s.bpm.clamp(0, HeartRateChart._maxHr.toDouble()),
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
          s.bpm.clamp(0, HeartRateChart._maxHr.toDouble()),
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

  List<HeartRateSample> _samplesInRange(
    List<HeartRateSample> samples, {
    required int startMs,
    required double minX,
    required double maxX,
    double marginSec = 0,
  }) {
    final minRange = minX - marginSec;
    final maxRange = maxX + marginSec;
    final filtered = samples.where((s) {
      final x = (s.sampledAt.toInt() - startMs) / 1000.0;
      return x >= minRange && x <= maxRange;
    }).toList();
    return filtered.isEmpty ? samples.take(2).toList() : filtered;
  }

  /// Two bands per done set: resting (blue) from its completion to its rest
  /// target, cut short by the next Done; then yapping (pink) from the rest
  /// target to the next Done, if the next set came after the rest ran out.
  /// The workout's phases as shaded bands: lifting (a set's start to its
  /// end), resting (the end to the rest's end) and yapping (rest over, next
  /// set not started). Live, the phase in progress runs to [nowSec].
  List<VerticalRangeAnnotation> _buildPhaseBands(int startMs, double nowSec) {
    final sorted = _uiCompletedSets.toList()
      ..sort((a, b) => a.endedAt.compareTo(b.endedAt));
    final deduped = <CompletedSet>[];
    final seenKeys = <String>{};
    for (final c in sorted) {
      if (seenKeys.add('${c.endedAt.toInt()}:${c.restUntil.toInt()}')) {
        deduped.add(c);
      }
    }
    double at(Int64 unixSec) => (unixSec.toInt() * 1000 - startMs) / 1000.0;

    final snapshot = _uiStateSnapshot;
    final live = widget.followLiveClock && snapshot != null;
    final liveLiftStart =
        live &&
            snapshot.state == WorkoutState.WORKOUT_STATE_LIFTING &&
            snapshot.liftingStartedAt > Int64.ZERO
        ? at(snapshot.liftingStartedAt)
        : null;

    final bands = <VerticalRangeAnnotation>[];
    // Lifting is the short, important stretch: it gets the stronger tint.
    void band(double x1, double x2, Color color, {double alpha = 0.16}) {
      if (x2 > x1) {
        bands.add(
          VerticalRangeAnnotation(
            x1: x1,
            x2: x2,
            color: color.withValues(alpha: alpha),
          ),
        );
      }
    }

    for (var i = 0; i < deduped.length; i++) {
      final c = deduped[i];
      final ended = at(c.endedAt);
      if (c.startedAt > Int64.ZERO) {
        band(
          at(c.startedAt),
          ended,
          context.tokens.workoutLiftingFg,
          alpha: 0.4,
        );
      }
      // Where this set's rest-and-chat stops: the next set's start (its end
      // when its start wasn't recorded), or, live, the set now being lifted
      // or now itself. A finished workout stops at the rest's end.
      final next = i + 1 < deduped.length ? deduped[i + 1] : null;
      final double? stop = next != null
          ? at(next.startedAt > Int64.ZERO ? next.startedAt : next.endedAt)
          : live
          ? (liveLiftStart ?? nowSec)
          : null;
      final restEnd = c.restUntil == Int64.ZERO ? ended : at(c.restUntil);
      band(
        ended,
        stop == null ? restEnd : min(restEnd, stop),
        context.tokens.workoutRestingFg,
      );
      if (stop != null) {
        band(max(restEnd, ended), stop, context.tokens.workoutYappingFg);
      }
    }
    if (liveLiftStart != null) {
      band(liveLiftStart, nowSec, context.tokens.workoutLiftingFg, alpha: 0.4);
    }
    return bands;
  }

  ChartViewport _computeLiveViewport(double nowSec, double domainMaxX) {
    final span = _selectedLiveWindowSpanSec;
    final start = max(0.0, nowSec - span * _liveNowAnchorFraction);
    return _clampViewport(
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
          letterSpacing: 0.4,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
    );
  }

  ChartViewport _clampViewport({
    required double startSec,
    required double spanSec,
    required double domainMaxX,
  }) {
    final clampedSpan = spanSec
        .clamp(_minWindowSeconds, _maxWindowSeconds)
        .toDouble();
    final maxStart = max(0.0, domainMaxX - clampedSpan * 0.05);
    final clampedStart = startSec.clamp(0.0, maxStart).toDouble();
    return ChartViewport(
      startSec: clampedStart,
      endSec: clampedStart + clampedSpan,
      spanSec: clampedSpan,
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

  Color _zoneColorForBpm(double bpm, List<HeartRateZone> zones) {
    final zone = zoneFor(bpm, zones);
    if (zone == null) return const Color(0xFF22C55E);
    switch (zone.name) {
      case 'Z1':
        return const Color(0xFF22C55E);
      case 'Z2':
        return const Color(0xFFEAB308);
      case 'Z3':
        return const Color(0xFFF59E0B);
      case 'Z4':
        return const Color(0xFFEF4444);
      case 'Z5':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF22C55E);
    }
  }

  List<HeartRateZone> _zonesForMaxHr(int maxHr) {
    return HeartRateChart._zonePercents.map((z) {
      final low = (z.lowPct * maxHr).round();
      final high = (z.highPct * maxHr).round();
      return HeartRateZone(z.name, z.label, low, high);
    }).toList();
  }

  List<HeartRateZone> _zonesForConfig({required int maxHr, double? restingHr}) {
    if (restingHr == null || !restingHr.isFinite || restingHr <= 0) {
      return _zonesForMaxHr(maxHr);
    }

    final reserve = maxHr - restingHr;
    if (reserve <= 0) return _zonesForMaxHr(maxHr);

    final out = <HeartRateZone>[];
    var lastHigh = 0;
    for (final z in HeartRateChart._zonePercents) {
      var low = (restingHr + reserve * z.lowPct).round();
      var high = (restingHr + reserve * z.highPct).round();
      low = low.clamp(0, maxHr);
      high = high.clamp(0, maxHr);
      if (low < lastHigh) low = lastHigh;
      if (high <= low) high = min(maxHr, low + 1);
      out.add(HeartRateZone(z.name, z.label, low, high));
      lastHigh = high;
    }
    return out;
  }

  /// A vertical, hard-stepped gradient that paints the line in its HR-zone
  /// colour by y-position. Maps each zone's [low, high] bpm to a fraction of
  /// the chart's y-range and repeats the colour at both ends for a sharp edge.

  // ── Full-view summary: avg/max/min + time in zone ──
}
