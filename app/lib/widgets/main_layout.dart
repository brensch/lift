import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import 'multiplayer_modal.dart';
import 'workout_bottom_bar.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final userName = authProvider.username ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    final hasWorkout = wp.hasActiveWorkout;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: () => context.go('/'),
          child: const Text(
            'LIFT',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
        ),
        actions: [
          if (hasWorkout)
            IconButton(
              icon: Icon(
                mp.isInSession ? Icons.group : Icons.group_add_outlined,
                size: 22,
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const MultiplayerModal(),
                );
              },
            ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'MENU',
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
                      label: 'WORKOUT',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/',
                    ),
                    const SizedBox(height: 4),
                    _MenuButton(
                      icon: Icons.bar_chart_outlined,
                      label: 'PROGRESS',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/progress');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/progress',
                    ),
                    const SizedBox(height: 4),
                    _MenuButton(
                      icon: Icons.history_outlined,
                      label: 'HISTORY',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/history');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/history',
                    ),
                    Divider(height: 32, color: colorScheme.outline),
                    _MenuButton(
                      icon: Icons.notifications_outlined,
                      label: 'PICK SOUND',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/sound-settings');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/sound-settings',
                    ),
                    const SizedBox(height: 4),
                    _MenuButton(
                      icon: Icons.key_outlined,
                      label: 'PASSKEYS',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/passkeys');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/passkeys',
                    ),
                    Divider(height: 32, color: colorScheme.outline),
                    // Dark mode toggle
                    InkWell(
                      onTap: () => themeProvider.toggle(),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(
                              themeProvider.isDarkMode(context)
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 20,
                              color: colorScheme.onSurface,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                themeProvider.isDarkMode(context) ? 'LIGHT MODE' : 'DARK MODE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: -0.5,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 24,
                              child: Switch(
                                value: themeProvider.isDarkMode(context),
                                onChanged: (_) => themeProvider.toggle(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: colorScheme.outline),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (userName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 20, color: colorScheme.tertiary),
                            const SizedBox(width: 12),
                            Text(
                              userName.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _MenuButton(
                      icon: Icons.logout,
                      label: 'LOGOUT',
                      color: colorScheme.error,
                      onTap: () {
                        Navigator.pop(context);
                        authProvider.logout();
                        context.go('/login');
                      },
                      isActive: false,
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
          const WorkoutBottomBar(),
        ],
      ),
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
