/// What to do when the passkey is gone. Words in app/copy.yaml.
library;

import 'package:flutter/material.dart';

import '../gen/copy.dart';

class LostPasskeyScreen extends StatelessWidget {
  const LostPasskeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = copy.lostPasskey;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.title,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            const Text('\u{1F62D}', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              t.body,
              style: TextStyle(
                fontSize: 16,
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
