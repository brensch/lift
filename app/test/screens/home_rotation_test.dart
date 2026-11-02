import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/rotation_text.dart';
import 'package:schlift/providers/auth_provider.dart';
import 'package:schlift/screens/home/home_screen.dart';
import 'package:schlift/widgets/template_row.dart';
import 'package:schlift/services/auth_service.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/services/wearable_bridge_service.dart';
import 'package:schlift/theme/app_icons.dart';
import 'package:schlift/theme/app_theme.dart';

import '../support/provider_harness.dart';

/// Home with StrongLifts A and B in rotation (onboarding's) and Arms as a
/// favourite (added later), at phone size.
Future<ProviderHarness> boot(WidgetTester tester) async {
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
  return h;
}

/// Let the core answer until [done], then pump through any sheet's
/// entrance (the library's loading spinner never settles).
Future<void> settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _sheet = find.byType(DraggableScrollableSheet);
Finder _inSheet(Finder f) => find.descendant(of: _sheet, matching: f);

/// Drag the sheet's list until [target] is built, letting the core answer
/// (the library loads from it) between drags.
Future<void> scrollSheetTo(
  WidgetTester tester,
  Finder target,
  double by,
) async {
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.drag(_inSheet(find.byType(Scrollable)).first, Offset(0, -by));
    await tester.pump();
  }
  await tester.ensureVisible(target);
  await tester.pump();
}

/// Open the Manage sheet and wait for the library.
Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text(copy.library.editButton));
  await settle(
    tester,
    () =>
        _sheet.evaluate().isNotEmpty &&
        _inSheet(find.byType(CircularProgressIndicator)).evaluate().isEmpty,
  );
}

/// The chips in their groups, the suggestion's reason, and the Manage
/// sheet: the rotation check (its line and bars), the sections, what a
/// workout would add, adding into the rotation, moving to the favourites.
void main() {
  testWidgets('Home: rotation, favourites, actions, the reason', (
    tester,
  ) async {
    final h = await boot(tester);
    addTearDown(h.dispose);

    final home = h.provider.home!;
    final suggested = home.templates.firstWhere(
      (t) => t.id == home.suggestedTemplateId,
    );
    expect(suggested.inRotation, isTrue);

    // Chips in three groups: the rotation under its title, the favourites
    // (and the Empty workout) under theirs, then New and Manage on a line
    // of their own.
    final l = copy.library;
    double y(Finder f) => tester.getTopLeft(f).dy;
    double chipY(String name) => y(find.widgetWithText(TemplateChip, name));
    final rotationTitle = y(find.text(l.rotationHeading.toUpperCase()));
    final favouritesTitle = y(find.text(l.favouritesHeading.toUpperCase()));
    expect(rotationTitle, lessThan(chipY('StrongLifts A')));
    expect(chipY('StrongLifts A'), lessThan(favouritesTitle));
    expect(chipY('StrongLifts B'), lessThan(favouritesTitle));
    expect(chipY('Arms'), greaterThan(favouritesTitle));
    final empty = y(find.text('Empty'));
    expect(empty, greaterThan(favouritesTitle));
    expect(y(find.text(l.newButton)), greaterThan(empty));
    expect(y(find.text(l.editButton)), y(find.text(l.newButton)));
    expect(find.byType(Divider), findsNothing);

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
      tester,
      () => h.provider.templates.firstWhere((t) => t.name == 'Arms').inRotation,
    );
    expect(
      chipY('Arms'),
      lessThan(y(find.text(l.favouritesHeading.toUpperCase()))),
    );
  });

  testWidgets('the Manage sheet: the check, sections, add, drag, delete', (
    tester,
  ) async {
    final h = await boot(tester);
    addTearDown(h.dispose);
    final l = copy.library;
    final inSheet = _inSheet;
    Finder row(String name) => find.widgetWithText(TemplateRow, name);
    Finder rowIcon(String name, String tooltip) =>
        find.descendant(of: row(name), matching: find.byTooltip(tooltip));
    Future<void> scrollTo(Finder target, double by) =>
        scrollSheetTo(tester, target, by);

    WorkoutTemplate named(String name) =>
        h.provider.templates.firstWhere((t) => t.name == name);

    await openSheet(tester);

    // The check: the owner's line above the bars of one lap's shares per
    // muscle, and only the warnings that apply; no gap line.
    final r = copy.rotation;
    final check = h.provider.rotationCheck!;
    final names = {for (final t in h.provider.templates) t.id: t.name};
    final body = inSheet(find.text(r.checkBody));
    expect(body, findsOneWidget);
    final bars = inSheet(find.byType(VolumeCard));
    expect(bars, findsOneWidget);
    expect(tester.getTopLeft(body).dy, lessThan(tester.getTopLeft(bars).dy));
    expect(tester.widget<VolumeCard>(bars).volume, check.volume);
    for (final w in rotationWarningLines(check, names)) {
      expect(inSheet(find.text(w)), findsOneWidget);
    }
    expect(inSheet(find.textContaining('Trains everything')), findsNothing);

    // The sections, and no library row for what the user has.
    for (final title in [l.rotationHeading, l.favouritesHeading]) {
      await scrollTo(inSheet(find.text(title.toUpperCase())), 100);
      expect(inSheet(find.text(title.toUpperCase())), findsOneWidget);
    }
    // A backup that adds nothing the main plan misses says nothing.
    await scrollTo(row('Arms'), 100);
    expect(tester.widget<TemplateRow>(row('Arms')).note, isEmpty);
    expect(
      inSheet(find.widgetWithText(TemplateRow, 'StrongLifts B')),
      findsOneWidget,
    );
    // Each of the user's rows: a drag handle and delete, nothing else.
    expect(
      find.descendant(
        of: row('StrongLifts B'),
        matching: find.byIcon(AppIcons.drag),
      ),
      findsOneWidget,
    );
    expect(rowIcon('StrongLifts B', l.delete), findsOneWidget);
    expect(
      find.descendant(
        of: row('StrongLifts B'),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );
    expect(inSheet(find.byType(Checkbox)), findsNothing);
    expect(inSheet(find.text(l.clone.toUpperCase())), findsNothing);

    // + adds a library workout to the main plan, and its library row is
    // gone.
    await scrollTo(rowIcon('Big Three', l.addToPlan), 200);
    await tester.tap(rowIcon('Big Three', l.addToPlan));
    await settle(
      tester,
      () => h.provider.templates.any((t) => t.name == 'Big Three'),
    );
    expect(named('Big Three').inRotation, isTrue);
    expect(rowIcon('Big Three', l.addToPlan), findsNothing);

    // The list is [Main plan, A, B, Big Three, Backup, Arms]. A drag
    // (through the list's own callback) of B past the Backup heading makes
    // it the first backup.
    List<String> names_(bool main) => [
      for (final t in h.provider.templates)
        if (t.inRotation == main) t.name,
    ];
    expect(names_(true), ['StrongLifts A', 'StrongLifts B', 'Big Three']);
    void drag(int from, int to) => tester
        .widget<ReorderableListView>(inSheet(find.byType(ReorderableListView)))
        .onReorderItem!(from, to);
    drag(2, 4);
    await settle(tester, () => !named('StrongLifts B').inRotation);
    expect(names_(true), ['StrongLifts A', 'Big Three']);
    expect(names_(false), ['StrongLifts B', 'Arms']);

    // Arms up to the top of the main plan: [Main plan, Arms, A, Big Three,
    // Backup, B].
    drag(5, 1);
    await settle(tester, () => named('Arms').inRotation);
    expect(names_(true), ['Arms', 'StrongLifts A', 'Big Three']);
    expect(names_(false), ['StrongLifts B']);
    // Home's chips follow the same order.
    expect(
      tester.getTopLeft(find.widgetWithText(TemplateChip, 'Arms')).dx,
      lessThan(
        tester
            .getTopLeft(find.widgetWithText(TemplateChip, 'StrongLifts A'))
            .dx,
      ),
    );

    // Emptying the backups leaves a line to drop on.
    drag(5, 1);
    await settle(tester, () => named('StrongLifts B').inRotation);
    expect(names_(false), isEmpty);
    await scrollTo(inSheet(find.text(l.dropHere)), -200);
    expect(inSheet(find.text(l.dropHere)), findsOneWidget);

    // Delete removes one; a library workout goes without asking.
    await scrollTo(rowIcon('Arms', l.delete), -200);
    await tester.tap(rowIcon('Arms', l.delete));
    await settle(
      tester,
      () => h.provider.templates.every((t) => t.name != 'Arms'),
    );
    expect(h.provider.templates.any((t) => t.name == 'Arms'), isFalse);

    // A backup that adds a missing muscle says so. The main plan is B, A
    // and Big Three now, none of which trains core; Core goes in as a
    // backup.
    await tester.runAsync(() => h.provider.addLibraryTemplates(['core']));
    await tester.pump();
    String note(String name) => tester.widget<TemplateRow>(row(name)).note;
    expect(note('StrongLifts A'), isEmpty, reason: 'in the main plan');
    await scrollTo(row('Core'), 200);
    final core = additionLine([MuscleGroup.MUSCLE_GROUP_CORE]);
    expect(note('Core'), core);
    expect(
      find.descendant(of: row('Core'), matching: find.text(core)),
      findsOneWidget,
    );

    // So does a library row: Lower adds calves and core, Arms (back on
    // offer) nothing.
    await scrollTo(row('Lower'), 200);
    expect(
      note('Lower'),
      additionLine([
        MuscleGroup.MUSCLE_GROUP_CALVES,
        MuscleGroup.MUSCLE_GROUP_CORE,
      ]),
    );
    await scrollTo(rowIcon('Arms', l.addToPlan), 200);
    expect(note('Arms'), isEmpty);

    // Core goes (a library workout, without asking) and is back on offer.
    await scrollTo(rowIcon('Core', l.delete), -200);
    await tester.tap(rowIcon('Core', l.delete));
    await settle(
      tester,
      () => h.provider.templates.every((t) => t.name != 'Core'),
    );
    await scrollTo(rowIcon('Core', l.addToPlan), 200);
    expect(note('Core'), core);
  });

  testWidgets('the Manage sheet: shares, no target, no numbers', (
    tester,
  ) async {
    final h = await boot(tester);
    addTearDown(h.dispose);
    await openSheet(tester);

    final bars = _inSheet(find.byType(VolumeCard));
    final card = tester.widget<VolumeCard>(bars);
    expect(card.proportional, isTrue);
    expect(card.volume, h.provider.rotationCheck!.volume);
    // A row per muscle and nothing that reads as a number: no set counts,
    // no target, no recovery hours.
    expect(
      find.descendant(of: bars, matching: find.textContaining(RegExp(r'\d'))),
      findsNothing,
    );
    expect(find.descendant(of: bars, matching: find.text('▲')), findsNothing);
    // The biggest share fills its track; Home's card is the weekly one.
    final most = card.volume
        .map((v) => v.completedSets7d)
        .reduce((a, b) => a > b ? a : b);
    expect(most, greaterThan(0));
    final shares = tester
        .widgetList<FractionallySizedBox>(
          find.descendant(
            of: bars,
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .map((b) => b.widthFactor)
        .toList();
    expect(shares.length, card.volume.length);
    expect(shares.reduce((a, b) => a! > b! ? a : b), 1.0);
    final home = find.descendant(
      of: find.byType(HomeScreen),
      matching: find.byType(VolumeCard),
    );
    expect(tester.widget<VolumeCard>(home.first).proportional, isFalse);
  });

  testWidgets('the Manage sheet: a muscle picks out what trains it', (
    tester,
  ) async {
    final h = await boot(tester);
    addTearDown(h.dispose);
    await openSheet(tester);
    Finder row(String name) => _inSheet(find.widgetWithText(TemplateRow, name));
    bool? emphasis(String name) =>
        tester.widget<TemplateRow>(row(name)).emphasis;
    const biceps = MuscleGroup.MUSCLE_GROUP_BICEPS;
    final muscle = find.byKey(ValueKey('muscle-${biceps.name}'));

    // Each row's emphasis, top to bottom: the main plan, the backups and
    // the library.
    Future<List<bool?>> pass() async {
      final out = <bool?>[];
      for (final name in ['StrongLifts A', 'Arms', 'Pull', 'Push']) {
        await scrollSheetTo(tester, row(name), 100);
        out.add(emphasis(name));
      }
      await scrollSheetTo(tester, muscle, -400);
      return out;
    }

    // Nothing picked: every row plain.
    expect(await pass(), [null, null, null, null]);

    // Biceps, first or as a helper (as the bars count it): StrongLifts A
    // (barbell row), Arms and Pull are picked out, Push dimmed.
    await tester.tap(muscle);
    await tester.pump();
    final bars = tester.widget<VolumeCard>(_inSheet(find.byType(VolumeCard)));
    expect(bars.highlight, {biceps});
    expect(await pass(), [true, true, true, false]);
    await scrollSheetTo(tester, row('Arms'), 100);
    expect(
      find.descendant(
        of: row('Arms'),
        matching: find.byKey(const ValueKey('template-row-picked')),
      ),
      findsOneWidget,
    );
    await scrollSheetTo(tester, muscle, -400);

    // Another muscle moves the pick; tapping it again clears it.
    const chest = MuscleGroup.MUSCLE_GROUP_CHEST;
    final chestBar = find.byKey(ValueKey('muscle-${chest.name}'));
    await scrollSheetTo(tester, chestBar, -400);
    await tester.tap(chestBar);
    await tester.pump();
    expect(await pass(), [true, false, false, true]);
    await scrollSheetTo(tester, chestBar, -400);
    await tester.tap(chestBar);
    await tester.pump();
    expect(await pass(), [null, null, null, null]);
  });

  testWidgets('the Manage sheet: a ready-made plan becomes the main plan', (
    tester,
  ) async {
    final h = await boot(tester);
    addTearDown(h.dispose);
    await openSheet(tester);
    final l = copy.library;
    Finder plan(String id) => find.byKey(ValueKey('plan-$id'));
    Finder inPlan(String id, Finder f) =>
        find.descendant(of: plan(id), matching: f);

    // StrongLifts is what the main plan is; the others can be applied.
    await scrollSheetTo(tester, plan('push_pull_legs'), 200);
    expect(inPlan('stronglifts', find.text(l.planCurrent)), findsOneWidget);
    expect(inPlan('stronglifts', find.byTooltip(l.applyPlan)), findsNothing);
    expect(
      inPlan('push_pull_legs', find.text('Push · Pull · Legs')),
      findsOneWidget,
    );

    await tester.tap(inPlan('push_pull_legs', find.byTooltip(l.applyPlan)));
    List<String> names(bool main) => [
      for (final t in h.provider.templates)
        if (t.inRotation == main) t.name,
    ];
    await settle(tester, () => names(true).join() == 'PushPullLegs');
    expect(names(true), ['Push', 'Pull', 'Legs']);
    expect(names(false), ['StrongLifts A', 'StrongLifts B', 'Arms']);
    await scrollSheetTo(tester, plan('push_pull_legs'), 200);
    expect(inPlan('push_pull_legs', find.text(l.planCurrent)), findsOneWidget);
    expect(inPlan('stronglifts', find.byTooltip(l.applyPlan)), findsOneWidget);

    // Home's chips: the plan's three under the main plan's heading, the
    // old main plan under the backups'.
    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    double y(Finder f) => tester.getTopLeft(f).dy;
    double chipY(String name) => y(find.widgetWithText(TemplateChip, name));
    final backups = y(find.text(l.favouritesHeading.toUpperCase()));
    for (final name in ['Push', 'Pull', 'Legs']) {
      expect(chipY(name), lessThan(backups), reason: name);
    }
    for (final name in ['StrongLifts A', 'StrongLifts B', 'Arms']) {
      expect(chipY(name), greaterThan(backups), reason: name);
    }
  });
}
