/// What to do when the passkey is gone. Words in app/copy.yaml.
library;

import '../widgets/common/flat.dart';
import 'package:flutter/material.dart';

import '../gen/copy.dart';
import '../theme/theme_spec.dart';

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
            Text(
              t.body,
              style: TextStyle(
                fontSize: context.tokens.size.bodyLg,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
