import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/tutorial/tutorial_seen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each account gets the tutorial once on a device', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await TutorialSeen.checkAndMark('alice'), isFalse);
    expect(await TutorialSeen.checkAndMark('alice'), isTrue);

    // A second account on the same phone sees it too.
    expect(await TutorialSeen.checkAndMark('bob'), isFalse);
    expect(await TutorialSeen.checkAndMark('bob'), isTrue);
  });
}
