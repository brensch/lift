/// First-party page-view tracking: which screens were opened and for how
/// long. Rows go to our own backend (AnalyticsService.RecordPageViews) and
/// nowhere else.
///
/// Three ways a page gets tracked, in order of preference:
///  * go_router routes — nothing to do. [PageTrackObserver] names each view
///    after the route's path template ("/settings", "/exercise/:ex").
///  * imperative routes and sheets — pass
///    `settings: RouteSettings(name: 'tutorial')` (or `routeSettings:` for a
///    sheet). Unnamed routes, i.e. dialogs, are ignored.
///  * steps inside one screen — wrap the step in [TrackedPage], or call
///    [PageTracker.enter] when the step changes.
///
/// A page name is a stable slug, never a concrete id and never user text.
library;

import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart' hide PageView;
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';

import '../gen/workout/v1/analytics.pb.dart';
import 'app_logger.dart';
import 'grpc_client.dart';

class PageTracker with WidgetsBindingObserver {
  PageTracker._();
  static final PageTracker instance = PageTracker._();

  static const _tag = 'PageTracker';
  static const _flushAfter = Duration(seconds: 30);
  static const _flushAtCount = 20;
  static const _maxQueued = 500;
  static const _maxPerUpload = 200;

  /// A page passed through in less than this was never looked at — a
  /// redirect, or a screen that immediately hands over to its first step.
  @visibleForTesting
  Duration minView = const Duration(milliseconds: 250);

  final String _appSessionId = const Uuid().v4();
  final List<PageView> _queue = [];
  int _seq = 0;

  // Named routes currently on the navigators, bottom to top. The top one is
  // what comes back when a sub-page or a popped route goes away.
  final List<String> _routes = [];
  String? _page;
  DateTime? _enteredAt;
  final Stopwatch _onPage = Stopwatch();

  GrpcClient? _client;
  bool Function() _isLoggedIn = () => false;
  Timer? _flushTimer;
  bool _uploading = false;
  // The backend predates the RPC. Stop asking until the next launch.
  bool _unsupported = false;
  String? _pausedPage;

  @visibleForTesting
  List<PageView> get queued => List.unmodifiable(_queue);

  @visibleForTesting
  String? get currentPage => _page;

  @visibleForTesting
  void resetForTest() {
    detach();
    _queue.clear();
    _routes.clear();
    _page = null;
    _enteredAt = null;
    _pausedPage = null;
    _unsupported = false;
    minView = const Duration(milliseconds: 250);
    _onPage
      ..stop()
      ..reset();
  }

  /// Until this is called the tracker follows pages but never schedules a
  /// timer or touches the network, which is what widget tests want.
  void attach(GrpcClient client, {required bool Function() isLoggedIn}) {
    _client = client;
    _isLoggedIn = isLoggedIn;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    _flushTimer = null;
    _client = null;
  }

  /// The views seen before login were held for this moment.
  void onLogin() => unawaited(flush());

  /// Whatever is still queued belongs to the account that just left; it must
  /// not be uploaded under the next one.
  void onLogout() => _queue.clear();

  /// Start timing [page], closing whatever was showing. Null means nothing
  /// trackable is showing.
  void enter(String? page) {
    if (page == _page) return;
    _close();
    if (page == null || page.isEmpty) return;
    _page = page;
    _enteredAt = DateTime.now();
    _onPage
      ..reset()
      ..start();
  }

  /// A sub-page (a step, a panel) went away: fall back to the route under it.
  void leave(String page) {
    if (_page == page) enter(_routes.lastOrNull);
  }

  void routePushed(String name) {
    _routes.add(name);
    enter(name);
  }

  void routeGone(String name) {
    final index = _routes.lastIndexOf(name);
    if (index < 0) return;
    final wasTop = index == _routes.length - 1;
    _routes.removeAt(index);
    // Only the top route going away changes what is on screen; a route
    // removed from underneath (go_router replacing the stack) does not.
    if (wasTop) enter(_routes.lastOrNull);
  }

  void _close() {
    final page = _page;
    final enteredAt = _enteredAt;
    _page = null;
    _enteredAt = null;
    _onPage.stop();
    if (page == null || enteredAt == null) return;
    if (_onPage.elapsed < minView) return;

    _queue.add(
      PageView(
        appSessionId: _appSessionId,
        seq: _seq++,
        page: page,
        enteredAtMs: Int64(enteredAt.millisecondsSinceEpoch),
        durationMs: Int64(_onPage.elapsedMilliseconds),
      ),
    );
    if (_queue.length > _maxQueued) {
      _queue.removeRange(0, _queue.length - _maxQueued);
    }
    if (_queue.length >= _flushAtCount) {
      unawaited(flush());
    } else {
      _scheduleFlush();
    }
  }

  void _scheduleFlush() {
    if (_client == null || _unsupported || _flushTimer != null) return;
    if (_queue.isEmpty || !_isLoggedIn()) return;
    _flushTimer = Timer(_flushAfter, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    final client = _client;
    if (client == null || _unsupported || _uploading) return;
    if (_queue.isEmpty || !_isLoggedIn()) return;
    _uploading = true;
    final batch = _queue.take(_maxPerUpload).toList();
    try {
      await client.analyticsService.recordPageViews(
        RecordPageViewsRequest(views: batch),
        options: CallOptions(timeout: const Duration(seconds: 10)),
      );
      // Identity, not position: onLogout may have emptied the queue meanwhile.
      _queue.removeWhere(batch.contains);
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unimplemented) {
        _unsupported = true;
        _queue.clear();
      }
      // Anything else: keep the batch. The server ignores a (session, seq)
      // it already has, so a retry can never double count.
      AppLogger.instance.debug(_tag, 'upload failed', {'code': e.codeName});
    } catch (e) {
      AppLogger.instance.debug(_tag, 'upload failed', {'error': '$e'});
    } finally {
      _uploading = false;
    }
    _scheduleFlush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Time with the phone in a pocket is not time on the page.
    if (state == AppLifecycleState.paused) {
      _pausedPage = _page;
      _close();
      unawaited(flush());
    } else if (state == AppLifecycleState.resumed && _pausedPage != null) {
      final page = _pausedPage;
      _pausedPage = null;
      if (_page == null) enter(page);
    }
  }
}

/// Attach to every Navigator that shows pages: `GoRouter(observers:)` and
/// each `ShellRoute(observers:)`. One instance per navigator.
class PageTrackObserver extends NavigatorObserver {
  static String? _name(Route<dynamic>? route) {
    final name = route?.settings.name;
    return (name == null || name.isEmpty) ? null : name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _name(route);
    if (name != null) PageTracker.instance.routePushed(name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _name(route);
    if (name != null) PageTracker.instance.routeGone(name);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _name(route);
    if (name != null) PageTracker.instance.routeGone(name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final oldName = _name(oldRoute);
    final newName = _name(newRoute);
    // Push first so the old route is never momentarily "the top going away".
    if (newName != null) PageTracker.instance.routePushed(newName);
    if (oldName != null) PageTracker.instance.routeGone(oldName);
  }
}

/// Tracks a step that lives inside a screen rather than on a route:
///
///     TrackedPage(name: 'onboarding/2-unit', child: UnitStep(...))
///
/// Give it a key that changes with the step when steps swap in place.
class TrackedPage extends StatefulWidget {
  const TrackedPage({super.key, required this.name, required this.child});

  final String name;
  final Widget child;

  @override
  State<TrackedPage> createState() => _TrackedPageState();
}

class _TrackedPageState extends State<TrackedPage> {
  @override
  void initState() {
    super.initState();
    PageTracker.instance.enter(widget.name);
  }

  @override
  void didUpdateWidget(TrackedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) PageTracker.instance.enter(widget.name);
  }

  @override
  void dispose() {
    PageTracker.instance.leave(widget.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
