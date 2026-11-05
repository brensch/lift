import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/screens/exercise_detail_screen.dart';
import 'package:schlift/services/account_sync.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/services/workout_service.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

/// A pull-up is bodyweight by its load style, as the core says: with added
/// weight on the belt its heaviest set still reads as reps, not pounds.
void main() {
  const pullUp = Exercise.EXERCISE_PULL_UP;

  testWidgets('a weighted pull-up reads as reps', (tester) async {
    final h = (await tester.runAsync(() async {
      final h = await ProviderHarness.boot();
      await h.seedHistory({pullUp: (25, 8)});
      await h.settings.load();
      return h;
    }))!;
    addTearDown(h.dispose);

    final grpc = GrpcClient(host: '127.0.0.1', port: 1);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<WorkoutServiceWrapper>.value(value: h.service),
          ChangeNotifierProvider.value(value: h.settings),
          ChangeNotifierProvider(create: (_) => AccountSync(grpc)),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: const ExerciseDetailScreen(exercise: pullUp),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(
      find.text(copy.exercise.reps.replaceAll('{n}', '8')),
      findsWidgets,
    );
  });
}
