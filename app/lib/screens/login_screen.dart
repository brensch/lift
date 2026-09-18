import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gen/copy.dart';
import 'lost_passkey_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/wobbly_text.dart';
import '../widgets/common/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _devUsernameController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  late TabController _tabController;

  final List<String> _usernameExamples = copy.login.usernameExamples;
  int _exampleIndex = 0;
  Timer? _exampleTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<AuthProvider>().clearError();
        setState(() {});
      }
    });

    _exampleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _usernameController.text.isEmpty) {
        setState(() {
          _exampleIndex = (_exampleIndex + 1) % _usernameExamples.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _devUsernameController.dispose();
    _usernameFocusNode.dispose();
    _tabController.dispose();
    _exampleTimer?.cancel();
    super.dispose();
  }

  void _passkeyLogin() {
    context.read<AuthProvider>().passkeyLogin();
  }

  Future<void> _createAccount() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      context.read<AuthProvider>().setError(copy.login.usernameRequired);
      return;
    }
    final auth = context.read<AuthProvider>();
    await auth.passkeyRegister(username);
  }

  void _devLogin() {
    final username = _devUsernameController.text.trim();
    if (username.isEmpty) return;
    context.read<AuthProvider>().testLogin(username);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final themeProvider = context.watch<ThemeProvider>();

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),

                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      const WobblyText(
                        text: 'SCHLIFT',
                        fontSize: 48,
                        maxOffset: 4,
                      ),

                      const SizedBox(height: 48),

                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),

                          side: BorderSide(
                            color: colorScheme.primary,
                            width: 1.0,
                          ),
                        ),

                        child: Column(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            TabBar(
                              controller: _tabController,

                              dividerColor: colorScheme.primary,

                              dividerHeight: 1.0,

                              labelColor: colorScheme.onSurface,

                              unselectedLabelColor: colorScheme.tertiary,

                              indicatorColor: colorScheme.primary,

                              indicatorWeight:
                                  4.0, // Thicker indicator for prominent selected state

                              indicatorSize: TabBarIndicatorSize.tab,

                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w900,

                                fontSize: 12,

                                letterSpacing: 1.0,
                              ),

                              tabs: [
                                Tab(text: copy.login.newUserTab),
                                Tab(text: copy.login.signInTab),
                              ],
                            ),

                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),

                              curve: Curves.easeInOut,

                              child: Padding(
                                padding: const EdgeInsets.all(24),

                                child: _tabController.index == 0
                                    ? _buildNewUserTab(auth, colorScheme)
                                    : _buildSignInTab(auth, colorScheme),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (kDebugMode) ...[
                        const SizedBox(height: 32),

                        const Divider(),

                        const SizedBox(height: 16),

                        Text(
                          copy.login.devLoginHeading,

                          style: TextStyle(
                            fontSize: 12,

                            fontWeight: FontWeight.bold,

                            letterSpacing: 1.5,

                            color: colorScheme.tertiary,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _devUsernameController,

                          decoration: InputDecoration(
                            labelText: copy.login.devUsername,
                          ),

                          textInputAction: TextInputAction.done,

                          autocorrect: false,

                          onSubmitted: (_) => _devLogin(),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,

                          height: 48,

                          child: OutlinedButton(
                            onPressed: auth.isLoading ? null : _devLogin,

                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 20,

                                    width: 20,

                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(copy.login.devLogin),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 24,

            right: 24,

            child: FloatingActionButton.small(
              onPressed: () => themeProvider.toggle(),

              backgroundColor: colorScheme.surface,

              foregroundColor: colorScheme.onSurface,

              elevation: 0,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),

                side: BorderSide(color: colorScheme.outline),
              ),

              child: Icon(
                themeProvider.isDarkMode(context)
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,

                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewUserTab(AuthProvider auth, ColorScheme colorScheme) {
    return Column(
      key: const ValueKey('new_user'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          copy.login.usernamePrompt,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          decoration: InputDecoration(
            hintText: _usernameExamples[_exampleIndex],
            hintStyle: TextStyle(
              color: colorScheme.tertiary.withValues(alpha: 0.4),
              fontWeight: FontWeight.normal,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onSubmitted: (_) => _createAccount(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        if (auth.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              auth.error!,
              style: TextStyle(color: colorScheme.error, fontSize: 13),
              textAlign: TextAlign.left,
            ),
          ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: copy.login.createAccount,
          icon: Icons.fingerprint,
          loading: auth.isLoading,
          onPressed: auth.isLoading ? null : () => _createAccount(),
        ),
      ],
    );
  }

  Widget _buildSignInTab(AuthProvider auth, ColorScheme colorScheme) {
    return Column(
      key: const ValueKey('sign_in'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          copy.login.signInBlurb,
          textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 24),
        if (auth.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              auth.error!,
              style: TextStyle(color: colorScheme.error, fontSize: 13),
              textAlign: TextAlign.left,
            ),
          ),
        PrimaryButton(
          label: copy.login.signIn,
          icon: Icons.fingerprint,
          loading: auth.isLoading,
          onPressed: auth.isLoading ? null : _passkeyLogin,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'lost-passkey'),
                builder: (_) => const LostPasskeyScreen(),
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              copy.lostPasskey.button,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
