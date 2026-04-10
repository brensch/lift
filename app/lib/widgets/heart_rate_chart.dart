import 'dart:async';
import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../gen/workout/v1/wearable.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../services/health_service.dart';

class HeartRateChart extends StatefulWidget {
  final List<HeartRateSample> heartRateSamples;
  final List<CompletedSet> completedSets;
  final Int64 workoutStartTime; // seconds
  final DateTime now;
  final WorkoutStateSnapshot? stateSnapshot;
  final bool followLiveClock;
  final bool collapsible;
  final bool startCollapsed;

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
  });

  // Standard fallback when a personalized max HR isn't available.
  static const int _maxHr = 200;
  static const List<_ZonePercent> _zonePercents = [
    _ZonePercent('Z1', '50-60%', 0.50, 0.60),
    _ZonePercent('Z2', '60-70%', 0.60, 0.70),
    _ZonePercent('Z3', '70-80%', 0.70, 0.80),
    _ZonePercent('Z4', '80-90%', 0.80, 0.90),
    _ZonePercent('Z5', '90-100%', 0.90, 1.00),
  ];

  @override
  State<HeartRateChart> createState() => _HeartRateChartState();
}

class _HeartRateChartState extends State<HeartRateChart> {
  static const double _defaultLiveWindowSeconds = 600; // 10 min
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
    return [
      snapshot.state.value,
      snapshot.activeStartedAt.toInt(),
      snapshot.restUntil.toInt(),
      snapshot.lastRestEnd.toInt(),
    ].join(':');
  }

  String _completedSetListKey(List<CompletedSet> sets) {
    if (sets.isEmpty) return '0';
    final last = sets.last;
    return '${sets.length}:${last.startedAt.toInt()}:${last.endedAt.toInt()}:${last.restUntil.toInt()}';
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
    final completedSets = _uiCompletedSets;
    final stateSnapshot = _uiStateSnapshot;
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
    final currentZone = _zoneFor(currentBpm, zones);
    final zoneColor = _zoneColorForBpm(currentBpm, zones);
    final activityBands = _clipVerticalAnnotations(
      _buildActivityBands(startMs),
      minX: minX,
      maxX: maxX,
    );
    final liveBands = _clipVerticalAnnotations(
      _buildLiveActivityBands(
        startMs,
        effectiveNow,
        viewEndSec: maxX,
        completedSets: completedSets,
        stateSnapshot: stateSnapshot,
      ),
      minX: minX,
      maxX: maxX,
    );
    final bottomInterval = _bottomAxisInterval(viewport.spanSec);
    final zoneLineSegments = _buildZoneLineSegments(spots, zones);

    final expandedHeader = Row(
      children: [
        Text(
          'HEART RATE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: colorScheme.tertiary,
          ),
        ),
        const Spacer(),
        Text(
          '${currentBpm.round()}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.0,
            color: zoneColor,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'BPM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.tertiary,
          ),
        ),
        if (currentZone != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: zoneColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${currentZone.name} ${currentZone.label}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
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
              fontSize: 10,
              fontWeight: FontWeight.w700,
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
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'zzz ${_zoneProfile!.restingHeartRateBpm!.round()}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
        if (widget.collapsible) ...[
          const SizedBox(width: 6),
          Icon(
            _collapsed
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
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
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 24,
            child: CustomPaint(
              painter: _HeartRateTrendPainter(
                samples: available,
                lineColor: zoneColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${currentBpm.round()}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.0,
            color: zoneColor,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'BPM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.tertiary),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
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
                          height: 160,
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
                                        reservedSize: 28,
                                        interval: 10,
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
                                              child: Text(
                                                '$bpm',
                                                style: TextStyle(
                                                  fontSize: 9,
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
                                        reservedSize: 20,
                                        interval: 5,
                                        getTitlesWidget: (value, meta) {
                                          for (final z in zones) {
                                            final mid = (z.low + z.high) / 2.0;
                                            if ((value - mid).abs() < 1) {
                                              return SideTitleWidget(
                                                meta: meta,
                                                child: Text(
                                                  z.name,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
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
                                        reservedSize: 22,
                                        interval: bottomInterval,
                                        getTitlesWidget: (value, meta) {
                                          if (value < 0 || value > maxX + 0.5) {
                                            return const SizedBox.shrink();
                                          }
                                          return SideTitleWidget(
                                            meta: meta,
                                            space: 6,
                                            child: Text(
                                              _formatElapsed(value.round()),
                                              style: TextStyle(
                                                fontSize: 9,
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
                                    verticalRangeAnnotations: [
                                      ...activityBands,
                                      ...liveBands,
                                    ],
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
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.10,
                                      ),
                                      barWidth: 1.0,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(show: false),
                                    ),
                                    ...zoneLineSegments,
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
                            const Expanded(
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  _HeartRateLegendItem(
                                    label: 'Lift',
                                    color: Color(0xFFEC4899),
                                  ),
                                  _HeartRateLegendItem(
                                    label: 'Rest',
                                    color: Color(0xFF3B82F6),
                                  ),
                                  _HeartRateLegendItem(
                                    label: 'Yap',
                                    color: Color(0xFFF97316),
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

  List<VerticalRangeAnnotation> _buildActivityBands(int startMs) {
    final bands = <VerticalRangeAnnotation>[];
    final sorted =
        _uiCompletedSets
            .where((c) => c.startedAt != Int64.ZERO && c.endedAt != Int64.ZERO)
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final deduped = <CompletedSet>[];
    final seenPhaseKeys = <String>{};
    for (final c in sorted) {
      final key =
          '${c.startedAt.toInt()}:${c.endedAt.toInt()}:${c.restUntil.toInt()}';
      if (seenPhaseKeys.add(key)) {
        deduped.add(c);
      }
    }

    const liftColor = Color(0xFFEC4899);
    const restColor = Color(0xFF3B82F6);
    const yapColor = Color(0xFFF97316);
    final activeLiftStartSec = _activeLiftStartSec(startMs);

    for (var i = 0; i < deduped.length; i++) {
      final c = deduped[i];
      final liftStart = (c.startedAt.toInt() * 1000 - startMs) / 1000.0;
      final liftEnd = (c.endedAt.toInt() * 1000 - startMs) / 1000.0;

      if (liftEnd > liftStart) {
        bands.add(
          VerticalRangeAnnotation(
            x1: liftStart,
            x2: liftEnd,
            color: liftColor.withValues(alpha: 0.12),
          ),
        );
      }

      if (c.restUntil != Int64.ZERO) {
        final rawRestEnd = (c.restUntil.toInt() * 1000 - startMs) / 1000.0;
        var nextLiftStart = i + 1 < deduped.length
            ? (deduped[i + 1].startedAt.toInt() * 1000 - startMs) / 1000.0
            : double.infinity;
        if (i == deduped.length - 1 && activeLiftStartSec != null) {
          nextLiftStart = min(nextLiftStart, activeLiftStartSec);
        }
        final restEnd = min(rawRestEnd, nextLiftStart);
        if (restEnd > liftEnd) {
          bands.add(
            VerticalRangeAnnotation(
              x1: liftEnd,
              x2: restEnd,
              color: restColor.withValues(alpha: 0.12),
            ),
          );
        }
      }

      if (i > 0) {
        final prev = deduped[i - 1];
        final prevLiftEnd = (prev.endedAt.toInt() * 1000 - startMs) / 1000.0;
        final prevRawRestEnd = prev.restUntil != Int64.ZERO
            ? (prev.restUntil.toInt() * 1000 - startMs) / 1000.0
            : prevLiftEnd;
        final prevEnd = min(prevRawRestEnd, liftStart);
        if (liftStart > prevEnd + 1) {
          bands.add(
            VerticalRangeAnnotation(
              x1: prevEnd,
              x2: liftStart,
              color: yapColor.withValues(alpha: 0.12),
            ),
          );
        }
      }
    }
    return bands;
  }

  List<VerticalRangeAnnotation> _buildLiveActivityBands(
    int startMs,
    DateTime now, {
    required double viewEndSec,
    required List<CompletedSet> completedSets,
    required WorkoutStateSnapshot? stateSnapshot,
  }) {
    final snapshot = stateSnapshot;
    if (snapshot == null) return const [];

    final nowSec = (now.millisecondsSinceEpoch - startMs) / 1000.0;
    if (nowSec <= 0) return const [];

    double toSecFromUnix(int unixSeconds) =>
        ((unixSeconds * 1000) - startMs) / 1000.0;

    const liftColor = Color(0xFFEC4899);
    const yapColor = Color(0xFFF97316);

    final completedWithEnd = completedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .toList();
    final lastEndedAt = completedWithEnd.fold<int>(
      0,
      (acc, c) => max(acc, c.endedAt.toInt()),
    );
    CompletedSet? latestCompleted;
    for (final c in completedWithEnd) {
      if (latestCompleted == null || c.endedAt > latestCompleted.endedAt) {
        latestCompleted = c;
      }
    }

    final bands = <VerticalRangeAnnotation>[];

    if (snapshot.state == WorkoutState.WORKOUT_STATE_LIFTING) {
      final startedAt = snapshot.activeStartedAt.toInt();
      if (startedAt > 0) {
        final x1 = max(0.0, toSecFromUnix(startedAt));
        final lastRestEnd = snapshot.lastRestEnd.toInt();
        final latestEndedAtUnix =
            latestCompleted?.endedAt.toInt() ?? lastEndedAt;
        final prescribedRestEndUnix =
            (latestCompleted != null &&
                latestCompleted.restUntil.toInt() > latestEndedAtUnix)
            ? latestCompleted.restUntil.toInt()
            : latestEndedAtUnix;
        final effectiveRestEndUnix = max(
          latestEndedAtUnix,
          lastRestEnd > 0 ? lastRestEnd : prescribedRestEndUnix,
        );

        final gapStartUnix = effectiveRestEndUnix > 0
            ? effectiveRestEndUnix
            : (lastRestEnd > 0 ? lastRestEnd : lastEndedAt);
        if (gapStartUnix > 0) {
          final yapStart = max(0.0, toSecFromUnix(gapStartUnix));
          if (x1 > yapStart) {
            bands.add(
              VerticalRangeAnnotation(
                x1: yapStart,
                x2: x1,
                color: yapColor.withValues(alpha: 0.12),
              ),
            );
          }
        }
        if (nowSec > x1) {
          bands.add(
            VerticalRangeAnnotation(
              x1: x1,
              x2: nowSec,
              color: liftColor.withValues(alpha: 0.12),
            ),
          );
        }
      }
      return bands;
    }

    if (snapshot.state == WorkoutState.WORKOUT_STATE_RESTING) {
      final restUntilUnix = snapshot.restUntil.toInt();
      if (restUntilUnix > 0) {
        final restUntilSec = max(0.0, toSecFromUnix(restUntilUnix));
        // Avoid double-painting rest over the persisted rest band from the most
        // recent completed set. That historical band already extends to restUntil
        // (and is truncated if the next phase started early).
        if (nowSec > restUntilSec) {
          bands.add(
            VerticalRangeAnnotation(
              x1: restUntilSec,
              x2: min(nowSec, viewEndSec),
              color: yapColor.withValues(alpha: 0.12),
            ),
          );
        }
      }

      return bands;
    }

    if (snapshot.state == WorkoutState.WORKOUT_STATE_READY) {
      final lastRestEnd = snapshot.lastRestEnd.toInt();
      final gapStartUnix = lastRestEnd > 0 ? lastRestEnd : lastEndedAt;
      if (gapStartUnix > 0) {
        final x1 = max(0.0, toSecFromUnix(gapStartUnix));
        if (nowSec > x1) {
          bands.add(
            VerticalRangeAnnotation(
              x1: x1,
              x2: nowSec,
              color: yapColor.withValues(alpha: 0.12),
            ),
          );
        }
      }
    }

    return bands;
  }

  _Viewport _computeLiveViewport(double nowSec, double domainMaxX) {
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
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.4,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
    );
  }

  _Viewport _clampViewport({
    required double startSec,
    required double spanSec,
    required double domainMaxX,
  }) {
    final clampedSpan = spanSec
        .clamp(_minWindowSeconds, _maxWindowSeconds)
        .toDouble();
    final maxStart = max(0.0, domainMaxX - clampedSpan * 0.05);
    final clampedStart = startSec.clamp(0.0, maxStart).toDouble();
    return _Viewport(
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

  double? _activeLiftStartSec(int startMs) {
    final snapshot = _uiStateSnapshot;
    if (snapshot == null) return null;
    if (snapshot.state != WorkoutState.WORKOUT_STATE_LIFTING) return null;
    final startedAt = snapshot.activeStartedAt.toInt();
    if (startedAt <= 0) return null;
    return ((startedAt * 1000) - startMs) / 1000.0;
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

  String _formatElapsed(int seconds) {
    final s = max(0, seconds);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  _Zone? _zoneFor(double bpm, List<_Zone> zones) {
    for (final z in zones) {
      if (bpm >= z.low && bpm < z.high) return z;
    }
    if (zones.isNotEmpty && bpm >= zones.last.high) return zones.last;
    return null;
  }

  Color _zoneColorForBpm(double bpm, List<_Zone> zones) {
    final zone = _zoneFor(bpm, zones);
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

  List<_Zone> _zonesForMaxHr(int maxHr) {
    return HeartRateChart._zonePercents.map((z) {
      final low = (z.lowPct * maxHr).round();
      final high = (z.highPct * maxHr).round();
      return _Zone(z.name, z.label, low, high);
    }).toList();
  }

  List<_Zone> _zonesForConfig({required int maxHr, double? restingHr}) {
    if (restingHr == null || !restingHr.isFinite || restingHr <= 0) {
      return _zonesForMaxHr(maxHr);
    }

    final reserve = maxHr - restingHr;
    if (reserve <= 0) return _zonesForMaxHr(maxHr);

    final out = <_Zone>[];
    var lastHigh = 0;
    for (final z in HeartRateChart._zonePercents) {
      var low = (restingHr + reserve * z.lowPct).round();
      var high = (restingHr + reserve * z.highPct).round();
      low = low.clamp(0, maxHr);
      high = high.clamp(0, maxHr);
      if (low < lastHigh) low = lastHigh;
      if (high <= low) high = min(maxHr, low + 1);
      out.add(_Zone(z.name, z.label, low, high));
      lastHigh = high;
    }
    return out;
  }

  List<LineChartBarData> _buildZoneLineSegments(
    List<FlSpot> spots,
    List<_Zone> zones,
  ) {
    if (spots.length < 2) return const [];
    final segments = <LineChartBarData>[];
    for (var i = 1; i < spots.length; i++) {
      final a = spots[i - 1];
      final b = spots[i];
      final color = _zoneColorForBpm((a.y + b.y) / 2, zones);
      segments.add(
        LineChartBarData(
          spots: [a, b],
          isCurved: false,
          color: color,
          barWidth: 2.0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }
    return segments;
  }
}

class _HeartRateTrendPainter extends CustomPainter {
  final List<HeartRateSample> samples;
  final Color lineColor;

  const _HeartRateTrendPainter({
    required this.samples,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;

    final values = samples.map((sample) => sample.bpm).toList(growable: false);
    final minBpm = values.reduce(min);
    final maxBpm = values.reduce(max);
    final span = max(1.0, maxBpm - minBpm);
    final path = Path();

    for (int i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? 0.0
          : (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minBpm) / span;
      final dy = size.height - (normalized * (size.height - 2)) - 1;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartRateTrendPainter oldDelegate) {
    if (oldDelegate.lineColor != lineColor) return true;
    if (oldDelegate.samples.length != samples.length) return true;
    if (samples.isEmpty) return false;
    return oldDelegate.samples.last.bpm != samples.last.bpm ||
        oldDelegate.samples.last.sampledAt != samples.last.sampledAt;
  }
}

class _Viewport {
  final double startSec;
  final double endSec;
  final double spanSec;

  const _Viewport({
    required this.startSec,
    required this.endSec,
    required this.spanSec,
  });
}

class _Zone {
  final String name;
  final String label;
  final int low;
  final int high;

  const _Zone(this.name, this.label, this.low, this.high);
}

class _ZonePercent {
  final String name;
  final String label;
  final double lowPct;
  final double highPct;

  const _ZonePercent(this.name, this.label, this.lowPct, this.highPct);
}

class _HeartRateLegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _HeartRateLegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
