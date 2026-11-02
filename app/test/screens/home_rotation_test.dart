import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/logic/rotation_text.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/screens/home/home_screen.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/services/wearable_bridge_service.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

/// Home with StrongLifts A and B in rotation (onboarding's) and Arms as a
/// favourite (added later): rotation chips above the divider, favourites
/// below, the suggestion's reason under its name, and the rotation check
/// at the top of the Edit sheet.
void main() {
  testWidgets('rotation, favourites, the reason and the check', (tester) async {
    final h = (await tester.runAsync(() async {
      final h = await ProviderHarness.boot(sandbox: true);
      await h.service.completeOnboarding(
        unit: WeightUnit.WEIGHT_UNIT_LB,
        libraryIds: ['stronglifts_a', 'stronglifts_b'],
      );
      await h.service.addLibraryTemplates(['arms']);
      await h.provider.loadActiveWorkout('test');
      return h;
    }))!;
    addTearDown(h.dispose);
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final grpc = GrpcClient(host: '127.0.0.1', port: 1);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: h.provider),
          ChangeNotifierProvider.value(value: h.settings),
          Provider<WearableBridgeService>.value(
            value: NoopWearableBridgeService(),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              authService: AuthService(grpcClient: grpc),
              grpcClient: grpc,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> settle(bool Function() done) async {
      for (var i = 0; i < 40 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      // The sheet's loading spinner never settles: pump through the
      // sheet's entrance instead.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final home = h.provider.home!;
    final suggested = home.templates.firstWhere(
      (t) => t.id == home.suggestedTemplateId,
    );
    expect(suggested.inRotation, isTrue);

    // Chips: rotation above the divider, favourites below.
    final divider = tester.getTopLeft(find.byType(Divider).first).dy;
    double chipY(String name) =>
        tester.getTopLeft(find.widgetWithText(TemplateChip, name)).dy;
    expect(chipY('StrongLifts A'), lessThan(divider));
    expect(chipY('StrongLifts B'), lessThan(divider));
    expect(chipY('Arms'), greaterThan(divider));

    // The reason under the suggested template's name, from the core's
    // structured reason; the old orange line is gone.
    final line = suggestionLine(home.suggestionReason);
    expect(line, isNotEmpty);
    expect(find.text(line), findsOneWidget);
    expect(find.textContaining('Recommended'), findsNothing);

    // Arms into the rotation from the card's menu.
    await tester.tap(find.widgetWithText(TemplateChip, 'Arms'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.more));
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.rotation.add));
    await settle(
      () => h.provider.templates.firstWhere((t) => t.name == 'Arms').inRotation,
    );
    expect(
      chipY('Arms'),
      lessThan(tester.getTopLeft(find.byType(Divider).first).dy),
    );

    // The Edit sheet opens on the rotation check: one lap's bars and what
    // is wrong with it.
    await tester.tap(find.text(copy.library.editButton));
    await settle(
      () => find
          .text(copy.rotation.checkTitle.toUpperCase())
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text(copy.rotation.checkTitle.toUpperCase()), findsOneWidget);
    final names = {for (final t in h.provider.templates) t.id: t.name};
    final warnings = rotationWarningLines(h.provider.rotationCheck!, names);
    expect(warnings, isNotEmpty, reason: 'nothing in it trains calves');
    for (final w in warnings) {
      expect(find.text(w), findsOneWidget);
    }
    expect(find.byType(VolumeCard), findsWidgets);
  });
}
