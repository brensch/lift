import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/wobbly_text.dart';

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

  final List<String> _usernameExamples = [
    'squat_master_9000',
    'bench_press_king',
    'iron_addict',
    'gains_goblin',
    'reps_for_jesus',
    'dorito_pump',
    'senior_minister_of_gains',
    'chicken_and_rice',
    'gluteus_maximus_prime',
    'anabolic_pigeon',
    'whey_too_much',
    'bicep_charles',
    'chuck_norris',
    'preworkout_heartbeat',
    'creatine_gremlin',
    'quadzilla_jr',
    'quadzilla_sr',
    'deltoid_dan',
    'shrugged_off',
    'gym_shark_bait',
    'tuna_shake',
    'failed_pr',
    'broccoli_boy',
  ];
  int _exampleIndex = 0;
  Timer? _exampleTimer;
  bool _isUsernameFocused = false;

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

    _usernameFocusNode.addListener(() {
      setState(() {
        _isUsernameFocused = _usernameFocusNode.hasFocus;
      });
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

  void _createAccount() {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      context.read<AuthProvider>().setError('you gotta pick a username');
      return;
    }
    context.read<AuthProvider>().passkeyRegister(username);
  }

  void _devLogin() {
    final username = _devUsernameController.text.trim();
    if (username.isEmpty) return;
    context.read<AuthProvider>().testLogin('__test__$username');
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
                        text: 'LIFT',
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

                              tabs: const [
                                Tab(text: 'NEW USER'),

                                Tab(text: 'SIGN IN'),
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

                      if (Platform.isLinux) ...[
                        const SizedBox(height: 32),

                        const Divider(),

                        const SizedBox(height: 16),

                        Text(
                          'DEV LOGIN',

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

                          decoration: const InputDecoration(
                            labelText: 'Username',

                            prefixText: '__test__',
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
                                : const Text('Dev Login'),
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
        const Text(
          'What should we call you',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
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
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: auth.isLoading ? null : _createAccount,
            icon: const Icon(Icons.fingerprint, size: 24),
            label: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('CREATE ACCOUNT'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              side: BorderSide(color: colorScheme.primary, width: 1.0),
            ),
          ),
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
        const Text(
          'Use a passkey on your device to sign in securely.',
          textAlign: TextAlign.left,
          style: TextStyle(fontSize: 14),
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
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: auth.isLoading ? null : _passkeyLogin,
            icon: const Icon(Icons.fingerprint, size: 24),
            label: auth.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('SIGN IN'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              side: BorderSide(color: colorScheme.primary, width: 1.0),
            ),
          ),
        ),
      ],
    );
  }
}
