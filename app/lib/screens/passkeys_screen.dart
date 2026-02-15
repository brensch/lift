import 'package:flutter/material.dart';

class PasskeysScreen extends StatelessWidget {
  const PasskeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PASSKEYS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: Center(
        child: Text(
          'Passkey management is only available in the web app.',
          style: TextStyle(color: colorScheme.tertiary),
        ),
      ),
    );
  }
}
