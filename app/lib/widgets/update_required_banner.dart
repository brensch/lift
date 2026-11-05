/// A banner over the top of the app once the server has turned this
/// version away (`MIN_APP_VERSION`, [AccountSync.updateRequired]): sync is
/// off until the app is updated, and everything else works as it does with
/// no connection.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen/copy.dart';
import '../services/account_sync.dart';
import '../theme/theme_spec.dart';

class UpdateRequiredBanner extends StatelessWidget {
  final Widget child;

  const UpdateRequiredBanner({super.key, required this.child});

  static final _appStore = Uri.parse(
    'https://apps.apple.com/us/app/schlift/id6761754276',
  );
  static final _playStore = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.brensch.schlift',
  );

  @override
  Widget build(BuildContext context) {
    final required = context.select<AccountSync, bool>(
      (sync) => sync.updateRequired,
    );
    final t = context.tokens;
    // The same tree either way, so the app under it keeps its state.
    return Column(
      children: [
        // Like the join-request banner: a panel with a rule under it.
        if (required)
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.updateRequired.title,
                            style: TextStyle(
                              color: t.text,
                              fontWeight: t.weight.bold,
                              fontSize: t.size.body,
                            ),
                          ),
                          Text(
                            copy.updateRequired.body,
                            style: TextStyle(color: t.text),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => launchUrl(
                        defaultTargetPlatform == TargetPlatform.iOS
                            ? _appStore
                            : _playStore,
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(copy.updateRequired.button),
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
            removeTop: required,
            child: child,
          ),
        ),
      ],
    );
  }
}
