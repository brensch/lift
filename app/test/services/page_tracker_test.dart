import 'package:flutter/material.dart' hide PageView;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schlift/services/page_tracker.dart';

/// The router shape main.dart uses: a root navigator holding a ShellRoute,
/// each with its own observer.
GoRouter _router(GlobalKey<NavigatorState> rootKey) => GoRouter(
  navigatorKey: rootKey,
  observers: [PageTrackObserver()],
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const Text('login')),
    ShellRoute(
      observers: [PageTrackObserver()],
      builder: (_, __, child) => Scaffold(body: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('home')),
        GoRoute(path: '/settings', builder: (_, __) => const Text('settings')),
        GoRoute(
          path: '/exercise/:ex',
          builder: (_, state) => Text('exercise ${state.pathParameters['ex']}'),
        ),
      ],
    ),
  ],
);

void main() {
  final tracker = PageTracker.instance;
  late GlobalKey<NavigatorState> rootKey;
  late GoRouter router;

  List<String> recorded() => tracker.queued.map((v) => v.page).toList();

  Future<void> pumpApp(WidgetTester tester) async {
    rootKey = GlobalKey<NavigatorState>();
    router = _router(rootKey);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  setUp(() {
    tracker.resetForTest();
    tracker.minView = Duration.zero;
  });
  tearDown(tracker.resetForTest);

  testWidgets('a go_router route is tracked with no per-page code', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(tracker.currentPage, '/');

    router.push('/settings');
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/settings');

    router.pop();
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/');
    expect(recorded(), ['/', '/settings']);
  });

  testWidgets('go() between sibling routes swaps the page', (tester) async {
    await pumpApp(tester);
    router.go('/settings');
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/settings');
    router.go('/');
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/');
    expect(recorded(), ['/', '/settings']);
  });

  testWidgets('a parameterised route records its template, not the id', (
    tester,
  ) async {
    await pumpApp(tester);
    router.push('/exercise/42');
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/exercise/:ex');
  });

  testWidgets('unnamed routes (dialogs) are ignored', (tester) async {
    await pumpApp(tester);
    showDialog<void>(
      context: rootKey.currentContext!,
      builder: (_) => const AlertDialog(title: Text('sure?')),
    );
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/');

    rootKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/');
    expect(recorded(), isEmpty);
  });

  testWidgets('a named root route with in-screen steps falls back to the shell '
      'page underneath when it pops', (tester) async {
    await pumpApp(tester);
    rootKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'tutorial'),
        builder: (_) => const Text('tutorial'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tracker.currentPage, 'tutorial');

    tracker.enter('tutorial/01-home_volume');
    tracker.enter('tutorial/02-home_templates');

    rootKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/');
    expect(recorded(), [
      '/',
      'tutorial',
      'tutorial/01-home_volume',
      'tutorial/02-home_templates',
    ]);
  });

  testWidgets('a named sheet is a page; closing it returns to the route', (
    tester,
  ) async {
    await pumpApp(tester);
    showModalBottomSheet<void>(
      context: rootKey.currentContext!,
      useRootNavigator: true,
      routeSettings: const RouteSettings(name: 'sheet/template-library'),
      builder: (_) => const SizedBox(height: 100),
    );
    await tester.pumpAndSettle();
    expect(tracker.currentPage, 'sheet/template-library');

    rootKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tracker.currentPage, '/');
  });

  testWidgets('TrackedPage follows steps swapped in place', (tester) async {
    tracker.routePushed('/onboarding');
    final step = ValueNotifier(0);
    const slugs = ['onboarding/1-marker', 'onboarding/2-unit'];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: step,
          builder: (_, i, __) =>
              TrackedPage(name: slugs[i], child: Text('step $i')),
        ),
      ),
    );
    expect(tracker.currentPage, 'onboarding/1-marker');

    step.value = 1;
    await tester.pump();
    expect(tracker.currentPage, 'onboarding/2-unit');

    // The screen goes away: back to whatever route is underneath.
    await tester.pumpWidget(const SizedBox());
    expect(tracker.currentPage, '/onboarding');
    expect(recorded(), [
      '/onboarding',
      'onboarding/1-marker',
      'onboarding/2-unit',
    ]);
  });

  test('a pass-through page is not recorded', () {
    tracker.minView = const Duration(minutes: 1);
    tracker.enter('/onboarding');
    tracker.enter('onboarding/1-marker');
    expect(recorded(), isEmpty);
  });

  test('logout drops views that belonged to the account that left', () {
    tracker.enter('/');
    tracker.enter('/settings');
    expect(recorded(), ['/']);
    tracker.onLogout();
    expect(recorded(), isEmpty);
  });

  test('seq is unique per view so a retried upload cannot double count', () {
    for (final page in ['/', '/settings', '/', '/history']) {
      tracker.enter(page);
    }
    final seqs = tracker.queued.map((v) => v.seq).toSet();
    expect(seqs.length, tracker.queued.length);
    expect(tracker.queued.map((v) => v.appSessionId).toSet().length, 1);
  });
}
