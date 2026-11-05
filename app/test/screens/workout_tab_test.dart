import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/screens/workout_tab.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Retry on the startup error opens the account again', (
    tester,
  ) async {
    final h = (await tester.runAsync(ProviderHarness.boot))!;
    addTearDown(h.dispose);
    var retried = 0;
    h.provider.onRetryStartup = () async => retried++;
    h.provider.reportLoadError(Exception('the file would not open'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: h.provider,
        child: MaterialApp(theme: AppTheme.theme, home: const WorkoutTab()),
      ),
    );
    expect(find.text(copy.startup.failed), findsOneWidget);

    await tester.tap(find.text(copy.startup.retry));
    await tester.pump();
    expect(retried, 1);
    // Still the error, not a spinner that would never end.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
