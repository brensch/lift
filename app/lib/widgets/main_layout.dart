import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../gen/copy.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import 'common/flat.dart';
import 'dialogs/confirm_dialog.dart';
import 'join_request_banner.dart';
import 'menu_profile.dart';
import 'menu_button.dart';
import 'workout_bar/workout_bottom_bar.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

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
              // You, and your totals. Tap to edit your profile.
              MenuProfile(
                onEditProfile: () => open('/settings/profile-marker'),
              ),
              // The pages, as rows like every other list in the app (the
              // Settings page's): an icon, the name, a line under each.
              FlatRow(
                icon: AppIcons.progress,
                large: true,
                label: copy.menu.progress,
                onTap: () => open('/progress'),
              ),
              FlatRow(
                icon: AppIcons.history,
                large: true,
                label: copy.menu.history,
                onTap: () => open('/history'),
              ),
              FlatRow(
                icon: AppIcons.tutorial,
                large: true,
                label: copy.menu.learn,
                onTap: () => open('/learn'),
              ),
              const Spacer(),
              // Settings as one more row along the bottom, and logging out
              // in the corner beside it: red, and it asks before it does it.
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: context.tokens.hairline),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FlatRow(
                        icon: AppIcons.settings,
                        large: true,
                        label: copy.menu.settings,
                        onTap: () => open('/settings'),
                      ),
                    ),
                    IconButton(
                      tooltip: copy.menu.logout,
                      onPressed: () async {
                        final sure = await confirmDialog(
                          context,
                          title: copy.menu.logoutTitle,
                          body: copy.menu.logoutBody,
                          confirm: copy.menu.logout,
                          cancel: copy.menu.logoutCancel,
                          destructive: true,
                        );
                        if (!sure || !context.mounted) return;
                        Navigator.pop(context);
                        authProvider.logout();
                        context.go('/login');
                      },
                      icon: Icon(
                        AppIcons.logout,
                        size: context.tokens.size.titleLg,
                        color: colorScheme.error,
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
