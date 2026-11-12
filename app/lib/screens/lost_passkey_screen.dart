/// What to do when the passkey is gone. Words in app/copy.yaml.
library;

import '../widgets/common/flat.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../gen/copy.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/primary_button.dart';

/// Where a new passkey is made for an account whose passkeys are lost, to
/// wait for an admin's approval. In the browser, so it works whatever
/// version of the app this is.
final _recover = Uri.parse('https://schlift.com/recover');

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
            for (final paragraph in [
              t.body,
              t.signedInElsewhere,
              t.recoverBody,
            ]) ...[
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
