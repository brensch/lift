/// What to do when the passkey is gone. Words in app/copy.yaml.
library;

import '../widgets/common/flat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../gen/copy.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/primary_button.dart';

/// The server this build talks to (as main.dart reads it).
const _serverHost = String.fromEnvironment('SERVER_HOST');

/// Where a new passkey is made for an account whose passkeys are lost, to
/// wait for an admin's approval: the website of the server this build
/// signs in to, so the passkey is that server's. In the browser, so it
/// works whatever version of the app this is. A build on a local backend
/// has no website of its own; its passkeys are dev.schlift.com's.
final _recover = Uri.https(switch (_serverHost) {
  '' => kReleaseMode ? 'schlift.com' : 'dev.schlift.com',
  'localhost' || '127.0.0.1' || '10.0.2.2' => 'dev.schlift.com',
  final host => host,
}, '/recover');

class LostPasskeyScreen extends StatelessWidget {
  const LostPasskeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.lostPasskey;
    return Scaffold(
      appBar: AppBar(title: PageTitle(t.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Text(
              '\u{1F62D}',
              style: TextStyle(fontSize: context.tokens.size.giant),
            ),
            const SizedBox(height: 16),
            for (final paragraph in [t.body, t.note]) ...[
              Text(
                paragraph,
                style: TextStyle(
                  fontSize: context.tokens.size.bodyLg,
                  height: 1.5,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            PrimaryButton(
              label: t.recoverButton,
              loading: false,
              onPressed: () =>
                  launchUrl(_recover, mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      ),
    );
  }
}
