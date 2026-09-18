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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/providers/settings_provider.dart';
import 'package:schlift/providers/theme_provider.dart';
import 'package:schlift/screens/maths_screen.dart';
import 'package:schlift/screens/science_screen.dart';
import 'package:schlift/screens/onboarding/steps/marker_step.dart';
import 'package:schlift/screens/onboarding/steps/strength_step.dart';
import 'package:schlift/screens/onboarding/steps/templates_step.dart';
import 'package:schlift/screens/onboarding/steps/weight_step.dart';
import 'package:schlift/screens/lost_passkey_screen.dart';
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

  Future<void> pumpAtPhoneSize(
    WidgetTester tester,
    Widget home, {
    bool settle = true, // false for screens with a repeating animation
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // Screens assume the app's provider shell sits above MaterialApp.
    final grpc = GrpcClient(host: '127.0.0.1', port: 1);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider(grpc)),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 400));
    }
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

  testWidgets('tutorial: every step from copy.yaml', (tester) async {
    await pumpAtPhoneSize(tester, const TutorialScreen(), settle: false);
    final steps = copy.tutorial.steps.length;
    // The outline throbs forever, so never pumpAndSettle on this screen.
    for (var step = 1; step <= steps; step++) {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await shoot(tester, 'tutorial_s$step');
      // Every step points at something the screen actually has.
      expect(find.text(copy.tutorial.steps[step - 1].title), findsOneWidget);
      if (step < steps) {
        await tester.tap(find.text(copy.tutorial.next));
      }
    }
    // Back works too.
    await tester.tap(find.text(copy.tutorial.previous));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text(copy.tutorial.steps[steps - 2].title), findsOneWidget);
    await tester.tap(find.text(copy.tutorial.next));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // The last step's papers link must navigate.
    await tester.tap(find.text(copy.tutorial.papersButton));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('Workout science'), findsWidgets);
    // The header's shaking multiplayer button sleeps in a loop; tear the
    // tree down and let its last sleep elapse so no timer is left pending.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('onboarding templates step: tick, untick, finish gating', (
    tester,
  ) async {
    final library = [
      LibraryTemplate(
        id: 'stronglifts_a',
        name: 'StrongLifts 5×5 A',
        blurb: 'Squat, bench, row.',
        groupKey: 'programs',
        groupLabel: 'Programs',
        exercises: [Exercise.EXERCISE_SQUAT, Exercise.EXERCISE_BENCH_PRESS],
      ),
      LibraryTemplate(
        id: 'butt_stuff',
        name: 'Butt Stuff',
        blurb: 'Hip thrusts and friends.',
        groupKey: 'parts',
        groupLabel: 'Body parts',
        exercises: [Exercise.EXERCISE_HIP_THRUST],
        isDefault: true,
      ),
    ];
    final selected = <String>{'butt_stuff'};
    var finished = 0;
    late StateSetter rebuild;
    await pumpAtPhoneSize(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return Scaffold(
            body: TemplatesStep(
              library: library,
              error: null,
              selected: selected,
              onToggle: (id) => setState(() {
                if (!selected.remove(id)) selected.add(id);
              }),
              isSaving: false,
              onBack: () {},
              onFinish: () => finished++,
            ),
          );
        },
      ),
    );
    await shoot(tester, 'onboarding_templates');
    expect(find.text('PROGRAMS'), findsOneWidget);
    expect(find.text('BODY PARTS'), findsOneWidget);
    final finish = find.text(copy.onboarding.templates.finish);

    // Untick the only pick: finish disables and the nudge appears.
    await tester.tap(find.text('Butt Stuff'));
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(find.text(copy.onboarding.templates.noneSelected), findsOneWidget);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(finished, 0);

    // Tick one back: finish works.
    await tester.tap(find.text('StrongLifts 5×5 A'));
    await tester.pumpAndSettle();
    expect(selected, {'stronglifts_a'});
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(finished, 1);
    rebuild(() {});
  });

  testWidgets('lost passkey page renders', (tester) async {
    await pumpAtPhoneSize(tester, const LostPasskeyScreen());
    await shoot(tester, 'lost_passkey');
    expect(find.text(copy.lostPasskey.body), findsOneWidget);
  });

  testWidgets('onboarding marker step renders the chosen marker', (
    tester,
  ) async {
    await pumpAtPhoneSize(
      tester,
      Scaffold(
        body: MarkerStep(
          selectedEmoji: '🦍',
          selectedColorHex: '#FF6B6B',
          emojiChoices: const ['🦍', '🐣', '🐔', '🐇', '🐕', '🐒'],
          onSelectEmoji: (_) {},
          onSelectColor: (_) {},
          onRefreshEmojis: () {},
          onNext: () {},
        ),
      ),
    );
    await shoot(tester, 'onboarding_marker');
    expect(find.text(copy.onboarding.marker.title), findsOneWidget);
  });

  testWidgets('onboarding strength slider: weights follow the slider', (
    tester,
  ) async {
    var strength = 0.5;
    await pumpAtPhoneSize(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: StrengthStep(
            unit: WeightUnit.WEIGHT_UNIT_LB,
            strength: strength,
            onChanged: (v) => setState(() => strength = v),
            onBack: () {},
            onNext: () {},
          ),
        ),
      ),
    );
    await shoot(tester, 'onboarding_strength');
    // The parity numbers from test/logic/starting_weights_test.dart.
    expect(find.text('180 lb'), findsOneWidget);
    expect(find.text('130 lb'), findsOneWidget);
    // Drag up to the gorilla end: the bar maxes out at 315 / 225.
    await tester.drag(find.byType(Slider), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(strength, 1.0);
    expect(find.text('315 lb'), findsOneWidget);
    expect(find.text('225 lb'), findsOneWidget);
    expect(find.text(StrengthStep.creatureFor(1)), findsNWidgets(2));
  });

  testWidgets('onboarding weight step renders', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpAtPhoneSize(
      tester,
      Scaffold(
        body: WeightStep(
          unit: WeightUnit.WEIGHT_UNIT_KG,
          controller: controller,
          onBack: () {},
          onNext: () {},
        ),
      ),
    );
    await shoot(tester, 'onboarding_weight');
    expect(find.text(copy.onboarding.weight.body), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
  });

  testWidgets('papers screen renders and scrolls to the bottom', (
    tester,
  ) async {
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
