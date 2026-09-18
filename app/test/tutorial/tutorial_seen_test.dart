import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/tutorial/tutorial_seen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(TutorialSeen.resetForTest);

  test('each account gets the tutorial once on a device', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await TutorialSeen.checkAndMark('alice'), isFalse);
    expect(await TutorialSeen.checkAndMark('alice'), isTrue);

    // The bug: a second account on the same phone never saw it.
    expect(await TutorialSeen.checkAndMark('bob'), isFalse);
    expect(await TutorialSeen.checkAndMark('bob'), isTrue);
  });

  test(
    'upgrade: the old install-wide flag goes to whoever is signed in',
    () async {
      SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true});

      await TutorialSeen.migrateLegacy('alice');

      // Alice saw it under the old scheme and is not shown it again...
      expect(await TutorialSeen.checkAndMark('alice'), isTrue);
      // ...and someone signing up afterwards is.
      expect(await TutorialSeen.checkAndMark('bob'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('tutorial_seen_v1'), isFalse);
    },
  );

  test(
    'upgrade while signed out: the old flag is dropped, not inherited',
    () async {
      SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true});

      await TutorialSeen.migrateLegacy(null);

      expect(await TutorialSeen.checkAndMark('bob'), isFalse);
    },
  );

  test('a check waits for the migration instead of racing it', () async {
    SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true});

    // Deliberately not awaited: the home screen asks while it is in flight.
    final migration = TutorialSeen.migrateLegacy('alice');
    expect(await TutorialSeen.checkAndMark('alice'), isTrue);
    await migration;
  });

  test('only the first migration counts', () async {
    SharedPreferences.setMockInitialValues({'tutorial_seen_v1': true});

    await TutorialSeen.migrateLegacy('alice');
    // A later login notification must not hand the (now gone) flag to bob.
    await TutorialSeen.migrateLegacy('bob');

    expect(await TutorialSeen.checkAndMark('bob'), isFalse);
  });
}
