/// An earlier program, opened from Settings → Program, reads its document
/// and goes back to its rules with today's workouts kept.
library;

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pbenum.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/providers/workout_provider.dart';
import 'package:schlift/screens/program_document_screen.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

/// Set a program as an assistant would: the current one with [change].
Future<void> _set(
  ProviderHarness h,
  String name,
  void Function(Map<String, dynamic>) change,
) async {
  final doc =
      jsonDecode((await h.provider.getProgram()).programJson)
          as Map<String, dynamic>;
  doc['name'] = name;
  change(doc);
  final set = await h.core.call(
    'SetProgram',
    SetProgramRequest(
      programJson: jsonEncode(doc),
      note: 'Testing $name',
      author: 'mcp:Test',
    ),
    SetProgramResponse.fromBuffer,
  );
  expect(set.problems.where((p) => p.error), isEmpty);
}

Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('an earlier program opens, and Go back uses its rules', (
    tester,
  ) async {
    final h = (await tester.runAsync(() async {
      final h = await ProviderHarness.boot();
      await h.service.completeOnboarding(
        unit: WeightUnit.WEIGHT_UNIT_LB,
        libraryIds: ['stronglifts_a'],
      );
      await _set(h, 'Short rests', (d) => d['warmups']['rest_seconds'] = 20);
      await _set(h, 'Long rests', (d) => d['warmups']['rest_seconds'] = 90);
      await h.provider.refreshHome();
      return h;
    }))!;
    addTearDown(h.dispose);
    final program = (await tester.runAsync(h.provider.getProgram))!;
    final earlier = program.history.firstWhere((s) => s.name == 'Short rests');
    var changed = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<WorkoutProvider>.value(
        value: h.provider,
        child: MaterialApp(
          theme: AppTheme.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => changed = await showProgramDocument(
                  context,
                  summary: earlier,
                  byline: 'by Test',
                  current: false,
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await _pump(tester);
    for (
      var i = 0;
      i < 40 && find.textContaining('"rest_seconds"').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text('Testing Short rests'), findsOneWidget);
    expect(find.textContaining('"rest_seconds": 20'), findsOneWidget);

    await tester.tap(find.text(copy.program.use));
    await _pump(tester);
    await tester.tap(find.text(copy.program.useConfirm));
    for (var i = 0; i < 40 && !changed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(changed, isTrue);
    final now = (await tester.runAsync(h.provider.getProgram))!;
    expect(now.summary.note, 'Back to Short rests');
    expect(now.programJson, contains('"rest_seconds": 20'));
    expect(h.provider.templates, hasLength(1));
  });
}
