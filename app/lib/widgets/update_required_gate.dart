/// Over the whole app once the server has turned this version away
/// (`MIN_APP_VERSION`, [AccountSync.updateRequired]): nothing syncs until
/// the app is updated, so the only way on is the store.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen/copy.dart';
import '../services/account_sync.dart';
import '../theme/theme_spec.dart';

class UpdateRequiredGate extends StatelessWidget {
  final Widget child;

  const UpdateRequiredGate({super.key, required this.child});

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
    return Stack(
      children: [
        child,
        if (required)
          Positioned.fill(
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          copy.updateRequired.title,
                          style: TextStyle(
                            fontSize: context.tokens.size.title,
                            fontWeight: context.tokens.weight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          copy.updateRequired.body,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
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
            ),
          ),
      ],
    );
  }
}
