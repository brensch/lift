// Host-side driver: writes each on-device screenshot to app/test_screenshots/.
// The step log is written by the scenario to the device and pulled by the host
// after the run (integration_test can't deliver screenshots AND reportData in
// the same run), then turned into report.html by scripts/build_e2e_report.py.
//
//   flutter drive --driver test_driver/integration_test.dart \
//     --target integration_test/<scenario>_test.dart -d emulator-5554

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  Directory('test_screenshots').createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final f = File('test_screenshots/$name.png')..parent.createSync(recursive: true);
      await f.writeAsBytes(bytes);
      return true;
    },
  );
}
