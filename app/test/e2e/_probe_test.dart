import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Probe: can a headless `flutter test` render real fonts and write a legible PNG?
void main() {
  final fontsDir =
      '${Platform.environment['HOME']}/flutter-sdk/bin/cache/artifacts/material_fonts';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Load real Roboto + MaterialIcons so screenshots aren't tofu boxes.
    Future<void> load(String family, String file) async {
      final bytes = File('$fontsDir/$file').readAsBytesSync();
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }

    await load('Roboto', 'Roboto-Regular.ttf');
    await load('MaterialIcons', 'MaterialIcons-Regular.otf');
  });

  testWidgets('captures a legible screenshot', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 48),
                  Text('Schlift harness probe',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('test_screenshots/_probe.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());

    expect(out.lengthSync(), greaterThan(1000));
    // ignore: avoid_print
    print('wrote ${out.path} (${out.lengthSync()} bytes)');
  });
}
