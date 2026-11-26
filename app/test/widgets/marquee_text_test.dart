import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schlift/widgets/common/marquee_text.dart';

/// A name too long for its row: active, it waits at its start then scrolls
/// through; inactive, it's cut off and stays put.
void main() {
  Future<void> pump(WidgetTester tester, {required bool active}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: MarqueeText(
                  'Overhead Tricep Extension With A Very Long Name',
                  style: const TextStyle(fontSize: 20),
                  active: active,
                ),
              ),
            ),
          ),
        ),
      );

  double offset(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

  testWidgets('active: waits at the start, then scrolls through', (
    tester,
  ) async {
    await pump(tester, active: true);
    await tester.pump();
    expect(offset(tester), 0);
    await tester.pump(MarqueeText.pauseAtStart + const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(offset(tester), greaterThan(0));
    // Gone: the loop stops with it.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('inactive: cut off, nothing scrolls', (tester) async {
    await pump(tester, active: false);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(Scrollable), findsNothing);
  });
}
