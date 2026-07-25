// Bug hunt / coverage: onboarding with a non-default program (GZCLP). Verifies
// the program picker actually switches regimes and the resulting home reflects
// GZCLP, not the Linear 5×5 default.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/workout/v1/settings.pbgrpc.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding — selecting GZCLP sets a GZCLP program',
      (tester) async {
    final s = Scenario(binding, tester, 'onboarding_gzclp');
    final username = 'gzclp_${DateTime.now().millisecondsSinceEpoch}';

    await s.launch();
    await s.devLogin(username);

    // Marker → units → program.
    expect(await s.waitForText('Choose your colour and creature', seconds: 10),
        isTrue);
    await s.tapText('NEXT');
    expect(await s.waitForText('CHOOSE YOUR UNITS', seconds: 6), isTrue);
    await s.tapText('NEXT');
    expect(await s.waitForText('CHOOSE YOUR PROGRAM', seconds: 6), isTrue);

    // Pick GZCLP instead of the default.
    await s.tapText('GZCLP');
    await s.settle(seconds: 1);
    await s.shot('Program step — GZCLP selected');
    await s.tapText('NEXT');

    // Weights → confirm → start.
    expect(await s.waitForText('Choose starting weights', seconds: 6), isTrue);
    await s.tapText('NEXT');
    await s.settle(seconds: 2);
    await s.tapText('START');
    expect(await s.waitForText('START WORKOUT', seconds: 12), isTrue);
    await s.shot('Home — GZCLP program active');

    // Verify the backend recorded GZCLP, not the Linear default.
    final api = await s.api.login(username);
    final state = await api.programState();
    s.note('Program state',
        detail: 'regime=${state?.regimeType}', kind: 'api');
    expect(state?.regimeType, RegimeType.REGIME_TYPE_GZCLP,
        reason: 'selecting GZCLP should persist a GZCLP program');

    s.note('GZCLP onboarding verified', kind: 'assert');
    await s.report();
  });
}
