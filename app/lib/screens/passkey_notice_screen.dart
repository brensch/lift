import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';

class PasskeyNoticeScreen extends StatefulWidget {
  const PasskeyNoticeScreen({super.key});

  @override
  State<PasskeyNoticeScreen> createState() => _PasskeyNoticeScreenState();
}

class _PasskeyNoticeScreenState extends State<PasskeyNoticeScreen> {
  static final Uri _appleLearnMoreUri = Uri.parse(
    'https://developer.apple.com/passkeys/',
  );
  static final Uri _googleLearnMoreUri = Uri.parse(
    'https://safety.google/authentication/passkey/',
  );

  bool _isSubmitting = false;

  Future<void> _continue() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await context.read<AuthProvider>().acknowledgePasskeyNotice();
      if (!mounted) return;
      context.go('/');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openLearnMore() async {
    final uri = switch (defaultTargetPlatform) {
      TargetPlatform.android => _googleLearnMoreUri,
      TargetPlatform.iOS || TargetPlatform.macOS => _appleLearnMoreUri,
      _ => _googleLearnMoreUri,
    };
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Important',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You need access to at least one passkey to log in again with this account.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Your account cannot be recovered if you lose access to all passkeys for this account.",
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: cs.tertiary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You can add more passkeys for different devices in settings. Make sure to use a trusted cloud service like iCloud keychain or 1Password to avoid losing access to your account.',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: cs.tertiary),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _openLearnMore,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Learn more about passkeys'),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                          textStyle: const TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _continue,
                        child: Text(
                          _isSubmitting ? 'Saving...' : 'I understand',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
