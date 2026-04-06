import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../services/wearable_bridge_service.dart';
import 'multiplayer_modal.dart';
import 'wobbly_text.dart';
import 'workout_bottom_bar.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const MainLayout({super.key, required this.child, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final userName = authProvider.username ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    void goToTopLevel(String path) {
      Navigator.pop(context);
      if (currentPath != path) {
        context.go(path);
      }
    }

    bool isSettingsSection(String path) =>
        path == '/settings' ||
        path == '/passkeys' ||
        path == '/passkeys/add' ||
        path == '/sound-settings' ||
        path == '/debug-notifications' ||
        path == '/settings/plate-colors';

    final isTopLevelMenuPage =
        currentPath == '/' ||
        currentPath == '/progress' ||
        currentPath == '/history' ||
        currentPath == '/training-program' ||
        currentPath == '/settings';

    return PopScope(
      canPop: !isTopLevelMenuPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentPath != '/') {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: GestureDetector(
            onTap: () => context.go('/'),
            child: const WobblyText(
              text: 'SCHLIFT',
              fontSize: 24,
              maxOffset: 2,
            ),
          ),
          actions: [
            _buildWatchLaunchButton(context),
            _buildMultiplayerButton(context, mp),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        endDrawerEnableOpenDragGesture: false,
        endDrawer: Drawer(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _MenuButton(
                        icon: Icons.fitness_center_outlined,
                        label: 'Workout',
                        onTap: () => goToTopLevel('/'),
                        isActive: currentPath == '/',
                      ),
                      const SizedBox(height: 4),
                      _MenuButton(
                        icon: Icons.bar_chart_outlined,
                        label: 'Progress',
                        onTap: () => goToTopLevel('/progress'),
                        isActive: currentPath == '/progress',
                      ),
                      const SizedBox(height: 4),
                      _MenuButton(
                        icon: Icons.history_outlined,
                        label: 'History',
                        onTap: () => goToTopLevel('/history'),
                        isActive: currentPath == '/history',
                      ),
                      Divider(height: 32, color: colorScheme.outline),
                      _MenuButton(
                        icon: Icons.fitness_center_outlined,
                        label: 'Training Program',
                        onTap: () => goToTopLevel('/training-program'),
                        isActive: currentPath == '/training-program',
                      ),
                      const SizedBox(height: 4),
                      _MenuButton(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () => goToTopLevel('/settings'),
                        isActive: isSettingsSection(currentPath),
                      ),
                      Divider(height: 32, color: colorScheme.outline),
                    ],
                  ),
                ),
                Divider(color: colorScheme.outline),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (userName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 20,
                                color: colorScheme.tertiary,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: -0.5,
                                  color: colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            _MenuButton(
                              icon: Icons.logout,
                              label: 'Logout',
                              color: colorScheme.error,
                              onTap: () {
                                Navigator.pop(context);
                                authProvider.logout();
                                context.go('/login');
                              },
                              isActive: false,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                themeProvider.isDarkMode(context)
                                    ? Icons.wb_sunny
                                    : Icons.dark_mode_outlined,
                                color: colorScheme.onSurface,
                              ),
                              tooltip: themeProvider.isDarkMode(context)
                                  ? 'Switch to light mode'
                                  : 'Switch to dark mode',
                              onPressed: () => themeProvider.toggle(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(child: child),
            WorkoutBottomBar(key: ValueKey(wp.activeWorkout?.id ?? 'none')),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplayerButton(BuildContext context, MultiplayerProvider mp) {
    final wp = context.watch<WorkoutProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    // Check workout duration if active
    bool shouldShake = !mp.isInSession;
    if (wp.hasActiveWorkout && wp.activeWorkout!.startTime != Int64.ZERO) {
      final startTime = DateTime.fromMillisecondsSinceEpoch(
        wp.activeWorkout!.startTime.toInt() * 1000,
      );
      final duration = DateTime.now().difference(startTime);
      if (duration.inMinutes >= 5) {
        shouldShake = false;
      }
    }

    final participantCount = mp.participants.length;
    final buttonLabel = participantCount > 1
        ? 'Multiplayer ($participantCount)'
        : 'Multiplayer';

    Widget button = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: FilledButton.icon(
        onPressed: () => _showMultiplayerModal(context),
        icon: const Icon(Icons.group_add, size: 16),
        label: Text(
          buttonLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 36),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    if (!shouldShake) {
      return button;
    }

    return _ShakingWidget(child: button);
  }

  Widget _buildWatchLaunchButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Open watch app',
      icon: Icon(Icons.watch, color: colorScheme.onSurface),
      onPressed: () async {
        final bridge = context.read<WearableBridgeService>();
        final opened = await bridge.openWatchApp();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              opened
                  ? 'Sent open request to watch'
                  : 'No connected watch found',
            ),
          ),
        );
      },
    );
  }

  void _showMultiplayerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => const MultiplayerModal(),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? color;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.onSurface;

    return Material(
      color: isActive ? colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? colorScheme.onPrimary : effectiveColor,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: -0.5,
                  color: isActive ? colorScheme.onPrimary : effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShakingWidget extends StatefulWidget {
  final Widget child;
  const _ShakingWidget({required this.child});

  @override
  State<_ShakingWidget> createState() => _ShakingWidgetState();
}

class _ShakingWidgetState extends State<_ShakingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _startCycle();
  }

  Future<void> _startCycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        await _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(angle: _animation.value, child: child);
      },
      child: widget.child,
    );
  }
}
