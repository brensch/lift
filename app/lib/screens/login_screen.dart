import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/wobbly_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  bool _showCreateAccount = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _passkeyLogin() {
    context.read<AuthProvider>().passkeyLogin();
  }

  void _createAccount() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;
    context.read<AuthProvider>().passkeyRegister(username);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WobblyText(text: 'LIFT', fontSize: 48),
                  const SizedBox(height: 48),
                  // Primary: Sign in with passkey
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: auth.isLoading ? null : _passkeyLogin,
                      icon: const Icon(Icons.fingerprint, size: 24),
                      label: auth.isLoading && !_showCreateAccount
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Text(
                              'Sign in with Passkey',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (auth.error != null && !_showCreateAccount)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        auth.error!,
                        style: TextStyle(color: colorScheme.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Create account section
                  if (_showCreateAccount) ...[
                    const Divider(height: 32),
                    Text(
                      'CREATE ACCOUNT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      onSubmitted: (_) => _createAccount(),
                    ),
                    const SizedBox(height: 16),
                    if (auth.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          auth.error!,
                          style: TextStyle(color: colorScheme.error, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: auth.isLoading ? null : _createAccount,
                        child: auth.isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                            : const Text(
                                'Create Account with Passkey',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showCreateAccount = !_showCreateAccount;
                        auth.clearError();
                      });
                    },
                    child: Text(
                      _showCreateAccount
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
