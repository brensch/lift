/// Drives real screens at phone size and captures PNGs under
/// test/screenshots/goldens/. Run with --update-goldens to (re)write the
/// images; they exist to be LOOKED at (layout, callout anchors, overflow),
/// not diffed in CI. Any render overflow or exception fails the test even
/// without goldens, so this doubles as a layout smoke suite.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/providers/settings_provider.dart';
import 'package:schlift/screens/maths_screen.dart';
import 'package:schlift/screens/science_screen.dart';
import 'package:schlift/screens/tutorial_screen.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/theme/app_theme.dart';
import 'package:schlift/widgets/dialogs/weight_adjust_sheet.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The repo bundles Manrope/Space Grotesk under assets/google_fonts/, so
  // google_fonts resolves offline and text renders legibly in goldens.
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpAtPhoneSize(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // Screens assume the app's provider shell sits above MaterialApp.
    final grpc = GrpcClient(host: '127.0.0.1', port: 1);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider(grpc)),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              authService: AuthService(grpcClient: grpc),
              grpcClient: grpc,
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Goldens are written (and only then compared) under --update-goldens.
  // Plain `flutter test` still exercises every pump/tap/overflow check but
  // skips pixel comparison — font rasterization varies across machines.
  Future<void> shoot(WidgetTester tester, String name) async {
    if (!autoUpdateGoldenFiles) return;
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('tutorial: all five pages', (tester) async {
    await pumpAtPhoneSize(tester, const TutorialScreen());
    for (var page = 1; page <= 5; page++) {
      await shoot(tester, 'tutorial_p$page');
      if (page < 5) {
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }
    }
    // The last page's papers link must navigate.
    await tester.tap(find.text('READ THE PAPERS'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Papers'), findsWidgets);
  });

  testWidgets('papers screen renders and scrolls to the bottom',
      (tester) async {
    await pumpAtPhoneSize(tester, const ScienceScreen());
    await shoot(tester, 'papers_top');
    await tester.fling(find.byType(ListView), const Offset(0, -8000), 12000);
    await tester.pumpAndSettle();
    await shoot(tester, 'papers_bottom');
  });

  testWidgets('maths screen renders', (tester) async {
    await pumpAtPhoneSize(tester, const MathsScreen());
    await shoot(tester, 'maths');
  });

  testWidgets('weight adjust sheet: step up and down', (tester) async {
    final h = await ProviderHarness.boot();
    await h.seedHome([tracker(Exercise.EXERCISE_SQUAT, weight: 185)]);
    await h.startWorkoutWith([
      set_('s1', Exercise.EXERCISE_SQUAT, order: 0, weight: 185, reps: 6),
      set_('s2', Exercise.EXERCISE_SQUAT, order: 1, weight: 185, reps: 6),
    ]);

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: h.provider),
          ChangeNotifierProvider.value(value: h.settings),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showWeightAdjustSheet(
                    context,
                    block: h.provider.exerciseBlocks.single,
                    provider: h.provider,
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    // The provider's 1s workout ticker keeps frames coming, so
    // pumpAndSettle would never settle — use bounded pumps instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, 'weight_sheet');

    // Tap + twice: 185 → 195, then UPDATE applies it to pending sets.
    await tester.tap(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('UPDATE'), findsOneWidget);
    await tester.tap(find.text('UPDATE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      h.provider.activeProposedSets.every((s) => s.targetWeight == 195),
      isTrue,
      reason: 'both pending working sets moved to 195',
    );

    // Tear down inside the test body: the provider's periodic ticker must
    // be cancelled before the binding's pending-timer check runs.
    await tester.pumpWidget(const SizedBox());
    h.dispose();
  });
}
