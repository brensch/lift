import 'package:flutter/material.dart';

class PasskeysScreen extends StatelessWidget {
  const PasskeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passkeys')),
      body: const Center(
        child: Text('Passkey management is only available in the web app.'),
      ),
    );
  }
}
