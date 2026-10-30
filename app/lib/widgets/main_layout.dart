import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import 'join_request_banner.dart';
import '../services/wearable_bridge_service.dart';
import 'menu_profile.dart';
import 'multiplayer_modal.dart';
import 'workout_bar/workout_bottom_bar.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';
import 'wordmark.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const MainLayout({super.key, required this.child, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    void goToTopLevel(String path) {
      Navigator.pop(context);
      if (currentPath != path) {
        context.go(path);
      }
    }

    bool isSettingsSection(String path) =>
        path == '/settings' ||
        path == '/settings/profile-marker' ||
        path == '/passkeys' ||
        path == '/passkeys/add' ||
        path == '/sound-settings' ||
        path == '/debug-notifications' ||
        path == '/settings/plate-colors';

    final isTopLevelMenuPage =
        currentPath == '/' ||
        currentPath == '/progress' ||
        currentPath == '/history' ||
        currentPath == '/settings';

    return PopScope(
      canPop: !isTopLevelMenuPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentPath != '/') {
          context.go('/');
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // The menu icon's lines end 16 from the edge, in line with the page
          // content below: 5 here + the button's 8 + the glyph's own 3.
          actionsPadding: const EdgeInsets.only(right: 5),
          title: GestureDetector(
            onTap: () => context.go('/'),
            child: const Wordmark(),
          ),
          actions: [
            const _WatchLaunchButton(),
            _buildMultiplayerButton(context, mp),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(AppIcons.menu, size: 32),
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
                // You, and your totals. Tap to edit your profile.
                MenuProfile(
                  onEditProfile: () {
                    Navigator.pop(context);
                    context.push('/settings/profile-marker');
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    // Dividers and the active highlight run edge to edge.
                    children: [
                      _MenuButton(
                        icon: AppIcons.workout,
                        label: 'Workout',
                        onTap: () => goToTopLevel('/'),
                        isActive: currentPath == '/',
                      ),
                      const SizedBox(height: 4),
                      _MenuButton(
                        icon: AppIcons.progress,
                        label: 'Progress',
                        onTap: () => goToTopLevel('/progress'),
                        isActive: currentPath == '/progress',
                      ),
                      const SizedBox(height: 4),
                      _MenuButton(
                        icon: AppIcons.history,
                        label: 'History',
                        onTap: () => goToTopLevel('/history'),
                        isActive: currentPath == '/history',
                      ),
                    ],
                  ),
                ),
                Divider(color: colorScheme.outline),
                // Logout, and Settings as a cog beside it.
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  child: Row(
                    children: [
                      _MenuButton(
                        icon: AppIcons.logout,
                        label: 'Logout',
                        color: colorScheme.error,
                        onTap: () {
                          Navigator.pop(context);
                          authProvider.logout();
                          context.go('/login');
                        },
                        isActive: false,
                        edgeToEdge: false,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: () => goToTopLevel('/settings'),
                        icon: Icon(
                          AppIcons.settings,
                          size: 28,
                          color: isSettingsSection(currentPath)
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: mp.incomingRequests.isEmpty
            ? child
            : Column(
                children: [
                  JoinRequestBanner(request: mp.incomingRequests.first),
                  Expanded(child: child),
                ],
              ),
        bottomNavigationBar: WorkoutBottomBar(
          key: ValueKey(wp.activeWorkout?.id ?? 'none'),
        ),
      ),
    );
  }

  /// Icon only; a count shows when others are in the session.
  Widget _buildMultiplayerButton(BuildContext context, MultiplayerProvider mp) {
    final colorScheme = Theme.of(context).colorScheme;
    final participantCount = mp.isInSession ? mp.participants.length + 1 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Badge(
        isLabelVisible: participantCount > 1,
        label: Text('$participantCount'),
        backgroundColor: colorScheme.onSurface,
        textColor: colorScheme.surface,
        child: IconButton.filled(
          tooltip: 'Multiplayer',
          onPressed: () => _showMultiplayerModal(context),
          icon: const Icon(AppIcons.multiplayer),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: context.tokens.br(8)),
          ),
        ),
      ),
    );
  }

  void _showMultiplayerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      routeSettings: const RouteSettings(name: 'sheet/multiplayer'),
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

  /// Runs to the menu's edges (the list items, whose highlight and dividers
  /// span the full width) rather than sitting inside padding (Logout).
  final bool edgeToEdge;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
    this.color,
    this.edgeToEdge = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.onSurface;

    return Material(
      color: isActive ? colorScheme.primary : Colors.transparent,
      borderRadius: edgeToEdge ? null : context.tokens.br(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: edgeToEdge ? 24 : 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: isActive ? colorScheme.onPrimary : effectiveColor,
              ),
              const SizedBox(width: 20),
              Text(
                label,
                style: TextStyle(
                  fontWeight: context.tokens.weight.heavy,
                  fontSize: context.tokens.size.title,
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

/// Opens Schlift on the watch. Shown only when a paired watch has Schlift
/// installed; checked once when the bar is built.
class _WatchLaunchButton extends StatefulWidget {
  const _WatchLaunchButton();

  @override
  State<_WatchLaunchButton> createState() => _WatchLaunchButtonState();
}

class _WatchLaunchButtonState extends State<_WatchLaunchButton> {
  bool _available = false;

  @override
  void initState() {
    super.initState();
    context.read<WearableBridgeService>().isWatchAppAvailable().then((ok) {
      if (mounted && ok) setState(() => _available = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Open watch app',
      icon: Icon(AppIcons.watch, color: colorScheme.onSurface),
      onPressed: () async {
        final bridge = context.read<WearableBridgeService>();
        final alreadyOpen = await bridge.isWatchAppOpenOnWatch();
        final queued = await bridge.openWatchApp();
        if (!context.mounted) return;
        final String message;
        if (!queued) {
          message = 'No paired watch with Schlift installed';
        } else if (alreadyOpen) {
          message = 'Schlift is already open on your watch';
        } else {
          message = 'Open Schlift on your wrist to connect';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }
}
