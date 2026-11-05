/// A banner over the app's pages (the shell route, so not over /login,
/// onboarding or the tutorial) while an account is open with no server
/// session ([AuthProvider.hasServerSession]): the server stopped accepting
/// this phone's sign-in, or the account came from a file. Everything works
/// on the phone; sync waits for a sign-in, which the button leads to.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../providers/auth_provider.dart';
import '../services/account_sync.dart';
import '../theme/theme_spec.dart';

class SessionExpiredBanner extends StatelessWidget {
  final Widget child;

  const SessionExpiredBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final signedOut = context.select<AuthProvider, bool>(
      (auth) => auth.isLoggedIn && !auth.hasServerSession,
    );
    // The update banner already says sync is off; one at a time.
    final updateRequired = context.select<AccountSync, bool>(
      (sync) => sync.updateRequired,
    );
    final show = signedOut && !updateRequired;
    final t = context.tokens;
    // The same tree either way, so the page under it keeps its state.
    return Column(
      children: [
        // Like the update banner: a panel with a rule under it.
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
                        copy.sessionExpired,
                        style: TextStyle(color: t.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => context.go('/login'),
                      child: Text(copy.login.signIn),
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
            child: child,
          ),
        ),
      ],
    );
  }
}
