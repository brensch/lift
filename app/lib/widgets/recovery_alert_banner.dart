/// Someone asked, at schlift.com/recover, to get into this account with a
/// new passkey. Its owner, still signed in here, is told and can refuse:
/// the one check on a request that doesn't run through the admin. Words
/// in app/copy.yaml.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/auth.pb.dart';
import '../providers/auth_provider.dart';
import '../services/app_logger.dart';
import '../services/auth_service.dart';
import '../theme/theme_spec.dart';

class RecoveryAlertBanner extends StatefulWidget {
  final Widget child;

  const RecoveryAlertBanner({super.key, required this.child});

  @override
  State<RecoveryAlertBanner> createState() => _RecoveryAlertBannerState();
}

class _RecoveryAlertBannerState extends State<RecoveryAlertBanner>
    with WidgetsBindingObserver {
  /// Asked again on coming back to the app, but not more often than this.
  static const _askEvery = Duration(minutes: 10);

  List<PendingRecovery> _waiting = const [];
  DateTime? _askedAt;
  bool _signedIn = false;
  bool _denying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Signing in (or the session lapsing) is when the answer changes hands.
    final signedIn = Provider.of<AuthProvider>(context).hasServerSession;
    if (signedIn == _signedIn) return;
    _signedIn = signedIn;
    _askedAt = null;
    if (signedIn) {
      unawaited(_ask());
    } else if (_waiting.isNotEmpty) {
      _waiting = const [];
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_ask());
  }

  Future<void> _ask() async {
    if (!_signedIn) return;
    final asked = _askedAt;
    final now = DateTime.now();
    if (asked != null && now.difference(asked) < _askEvery) return;
    _askedAt = now;
    try {
      final waiting = await context.read<AuthService>().listMyRecoveries();
      if (mounted && _signedIn) setState(() => _waiting = waiting);
    } catch (error) {
      // Offline, or a server from before recoveries: nothing to show, and
      // the next resume asks again.
      _askedAt = null;
      AppLogger.instance.info('Auth', 'listMyRecoveries', {
        'error': error.toString(),
      });
    }
  }

  Future<void> _deny() async {
    if (_denying) return;
    final auth = context.read<AuthService>();
    final waiting = _waiting;
    setState(() => _denying = true);
    try {
      for (final recovery in waiting) {
        await auth.denyMyRecovery(recovery.requestId);
      }
      if (mounted) setState(() => _waiting = const []);
    } catch (error) {
      // Still there to refuse: the banner stays.
      AppLogger.instance.warn('Auth', 'denyMyRecovery', {
        'error': error.toString(),
      });
    } finally {
      if (mounted) setState(() => _denying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = _waiting.isNotEmpty;
    final t = context.tokens;
    // The same tree either way, so the page under it keeps its state.
    return Column(
      children: [
        // Like the session banner: a panel with a rule under it.
        if (show)
          Material(
            color: t.panel,
            shape: Border(bottom: BorderSide(color: t.primary, width: 2)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        copy.recoveryAlert.body,
                        style: TextStyle(color: t.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _denying ? null : _deny,
                      child: Text(copy.recoveryAlert.deny),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            // The banner took the status bar's inset.
            removeTop: show,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
