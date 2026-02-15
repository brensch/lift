import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'session_header.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.username ?? '';

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
                      icon: Icons.home,
                      label: 'HOME',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/',
                    ),
                    const SizedBox(height: 8),
                    _MenuButton(
                      icon: Icons.bar_chart,
                      label: 'PROGRESS',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/progress');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/progress',
                    ),
                    const SizedBox(height: 8),
                    _MenuButton(
                      icon: Icons.history,
                      label: 'HISTORY',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/history');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/history',
                    ),
                    const Divider(height: 32),
                    _MenuButton(
                      icon: Icons.notifications, // Or music_note
                      label: 'PICK SOUND',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/sound-settings');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/sound-settings',
                    ),
                    const SizedBox(height: 8),
                    _MenuButton(
                      icon: Icons.key,
                      label: 'PASSKEYS',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/passkeys');
                      },
                      isActive: GoRouterState.of(context).uri.toString() == '/passkeys',
                    ),
                    // Dark Mode toggle would go here if implemented in provider
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (userName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 20, color: Colors.grey),
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
                      color: Colors.red,
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
          const SessionHeader(),
          Expanded(child: child),
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
    final theme = Theme.of(context);
    final effectiveColor = color ?? (isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface);
    
    return Material(
      color: isActive ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isActive ? theme.colorScheme.onPrimary : effectiveColor),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.5,
                  color: isActive ? theme.colorScheme.onPrimary : effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
