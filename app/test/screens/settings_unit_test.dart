import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/weight_units.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/screens/settings_screen.dart';
import 'package:schlift/services/account_sync.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

/// A unit picked in Settings replans home in it: the plans (and the weight
/// steps the workout's selectors use) are on the new unit's grid at once.
void main() {
  const squat = Exercise.EXERCISE_SQUAT;

  testWidgets('picking kilograms replans home in kilograms', (tester) async {
    final h = (await tester.runAsync(() async {
      final h = await ProviderHarness.boot();
      await h.seedHistory({squat: (185, 5)});
      await h.settings.load();
      return h;
    }))!;
    addTearDown(h.dispose);
    expect(h.provider.weightStepOf(squat), 5, reason: 'lb plans first');

    final grpc = GrpcClient(host: '127.0.0.1', port: 1);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: h.provider),
          ChangeNotifierProvider.value(value: h.settings),
          ChangeNotifierProvider(create: (_) => AccountSync(grpc)),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(
              authService: AuthService(grpcClient: grpc),
              grpcClient: grpc,
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.theme, home: const SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(copy.settings.weightUnit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(copy.settings.kilograms));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(h.settings.weightUnit, WeightUnit.WEIGHT_UNIT_KG);
    expect(
      h.provider.weightStepOf(squat) / poundsPerKilogram,
      closeTo(2.5, 0.01),
    );
  });
}
