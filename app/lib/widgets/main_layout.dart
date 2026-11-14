import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../gen/copy.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import 'join_request_banner.dart';
import 'menu_profile.dart';
import 'menu_button.dart';
import 'workout_bar/workout_bottom_bar.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';
import 'wordmark.dart';

/// The shell every signed-in page sits in: the menu (a drawer from the
/// right), the banner for a join request, and the workout's status box along
/// the bottom. It has no bar of its own. Home (or the live workout) is the
/// one page at the bottom of the stack, with the menu button; the menu
/// pushes its pages over it, and each has a title bar with a back arrow.
class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final inSession = mp.isInSession ? mp.participants.length + 1 : 0;

    // The menu opens only from home, so its pages go over home: back
    // from any of them is home again.
    void open(String path) {
      Navigator.pop(context);
      context.push(path);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      endDrawerEnableOpenDragGesture: false,
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The app's name lives here now that no page has a banner.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Wordmark(),
                  ),
                ),
              ),
              // You, and your totals. Tap to edit your profile.
              MenuProfile(
                onEditProfile: () => open('/settings/profile-marker'),
              ),
              // The items sit straight under your totals, fixed in place:
              // a plain column, nothing to scroll or stretch.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MenuButton(
                    icon: AppIcons.progress,
                    label: copy.menu.progress,
                    onTap: () => open('/progress'),
                  ),
                  const SizedBox(height: 4),
                  _MenuButton(
                    icon: AppIcons.history,
                    label: copy.menu.history,
                    onTap: () => open('/history'),
                  ),
                  const SizedBox(height: 4),
                  _MenuButton(
                    icon: AppIcons.tutorial,
                    label: copy.menu.learn,
                    onTap: () => open('/learn'),
                  ),
                ],
              ),
              const Spacer(),
              Divider(color: colorScheme.outline),
              // Logout, and Settings as a cog beside it.
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    _MenuButton(
                      icon: AppIcons.logout,
                      label: copy.menu.logout,
                      color: colorScheme.error,
                      onTap: () {
                        Navigator.pop(context);
                        authProvider.logout();
                        context.go('/login');
                      },
                      edgeToEdge: false,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: copy.menu.settings,
                      onPressed: () => open('/settings'),
                      icon: Icon(
                        AppIcons.settings,
                        size: 28,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // The shell has no bar, so what's first on screen keeps clear of
      // the status bar itself: the join request when there is one (and
      // the page under it then starts below it), else the page, by its
      // title bar or (home, the workout) its own safe area.
      body: Builder(
        builder: (context) {
          final page = AppMenu(
            open: Scaffold.of(context).openEndDrawer,
            inSession: inSession,
            child: child,
          );
          if (mp.incomingRequests.isEmpty) return page;
          return Column(
            children: [
              SafeArea(
                bottom: false,
                child: JoinRequestBanner(request: mp.incomingRequests.first),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: page,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: WorkoutBottomBar(
        key: ValueKey(wp.workout?.id ?? 'none'),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// Runs to the menu's edges (the list items, whose highlight and dividers
  /// span the full width) rather than sitting inside padding (Logout).
  final bool edgeToEdge;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.edgeToEdge = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      borderRadius: edgeToEdge ? null : context.tokens.brSm,
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
              Icon(icon, size: 28, color: effectiveColor),
              const SizedBox(width: 20),
              Text(
                label,
                style: TextStyle(
                  fontWeight: context.tokens.weight.heavy,
                  fontSize: context.tokens.size.title,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
