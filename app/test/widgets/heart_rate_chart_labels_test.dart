/// The heart-rate chart's axis labels: each one a single line, whole, and
/// inside the chart. Run with --update-goldens to also write the image to
/// test/widgets/goldens/ for looking at.
library;

import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schlift/gen/workout/v1/wearable.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/theme/schlift_spec.dart';
import 'package:schlift/widgets/heart_rate/heart_rate_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // A 45-minute session: sets push the heart rate up, rests let it fall.
  const startSec = 1761900000;
  const lengthSec = 45 * 60;
  final samples = [
    for (var t = 0; t <= lengthSec; t += 5)
      HeartRateSample(
        sampledAt: Int64((startSec + t) * 1000),
        bpm: 95 + 45 * (0.5 + 0.5 * sin(t / 90.0)),
        availability: HeartRateAvailability.HEART_RATE_AVAILABILITY_AVAILABLE,
      ),
  ];
  final sets = [
    for (var t = 120; t < lengthSec; t += 240)
      // 40 s lifting, 150 s rest, then 50 s over rest before the next set.
      CompletedSet(
        startedAt: Int64(startSec + t),
        endedAt: Int64(startSec + t + 40),
        restUntil: Int64(startSec + t + 190),
      ),
  ];

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('every axis label fits, ${width.round()}dp wide', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: Padding(
              // The workout screen's own gutter.
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: HeartRateChart(
                  heartRateSamples: samples,
                  completedSets: sets,
                  workoutStartTime: Int64(startSec),
                  now: DateTime.fromMillisecondsSinceEpoch(
                    (startSec + lengthSec) * 1000,
                  ),
                  followLiveClock: false,
                  fullView: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (autoUpdateGoldenFiles) {
        await expectLater(
          find.byType(HeartRateChart),
          matchesGoldenFile('goldens/heart_rate_chart_${width.round()}.png'),
        );
      }

      final chart = find.byType(LineChart);
      expect(chart, findsOneWidget);
      // Every period is on the chart: each set's lifting, its rest, and
      // the chat after the rest until the next set starts.
      const tokens = schliftSpec;
      final bands = tester
          .widget<LineChart>(chart)
          .data
          .rangeAnnotations
          .verticalRangeAnnotations;
      int count(Color c) => bands
          .where((b) => b.color?.withValues(alpha: 1) == c.withValues(alpha: 1))
          .length;
      expect(count(tokens.lifting), sets.length, reason: 'lifting bands');
      expect(count(tokens.resting), sets.length, reason: 'resting bands');
      expect(
        count(tokens.yapping),
        sets.length - 1,
        reason: 'yapping bands, between one set and the next',
      );

      final chartRect = tester.getRect(chart);
      final labels = find.descendant(of: chart, matching: find.byType(Text));
      expect(labels, findsWidgets);
      final rects = <Rect>[];
      for (final element in labels.evaluate()) {
        final text = (element.widget as Text).data ?? '';
        final paragraph = element.renderObject! as RenderParagraph;
        final lines = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        );
        final rows = lines.map((b) => b.top).toSet();
        expect(
          rows.length,
          1,
          reason: '"$text" wraps onto ${rows.length} lines',
        );
        expect(
          paragraph.size.width + 0.5 >= paragraph.getMaxIntrinsicWidth(0),
          isTrue,
          reason: '"$text" is squeezed narrower than it needs',
        );
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(
          chartRect.inflate(0.5).contains(rect.topLeft) &&
              chartRect.inflate(0.5).contains(rect.bottomRight),
          isTrue,
          reason: '"$text" at $rect pokes out of the chart $chartRect',
        );
        rects.add(rect);
      }
      // No two labels on top of each other.
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          final overlap = rects[i].intersect(rects[j]);
          expect(
            overlap.width > 0.5 && overlap.height > 0.5,
            isFalse,
            reason: 'labels overlap at ${rects[i]} and ${rects[j]}',
          );
        }
      }
    });
  }
}
