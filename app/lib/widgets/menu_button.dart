/// The menu, and the button that opens it. No page has the app's banner any
/// more, so each page that offers the menu puts this button in a row of its
/// own: home beside the tracker's heading, the workout at the end of its
/// one row, the pages the menu opens at the end of their title bar.
library;

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

/// Lets anything under the app's shell open the shell's menu: a page has a
/// scaffold of its own, so `Scaffold.of` from inside it finds the wrong one.
class AppMenu extends InheritedWidget {
  final VoidCallback open;

  /// How many are in your training session, you included; 0 or 1 alone.
  final int inSession;

  const AppMenu({
    super.key,
    required this.open,
    required this.inSession,
    required super.child,
  });

  /// Null outside the shell (a page pumped alone in a test).
  static AppMenu? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppMenu>();

  @override
  bool updateShouldNotify(AppMenu oldWidget) =>
      inSession != oldWidget.inSession;
}

/// Opens the menu. While others are training with you it carries how many
/// are in the session: on home and the menu's pages there is no multiplayer
/// button to say so.
class MenuButton extends StatelessWidget {
  /// False beside the multiplayer button, which carries the count itself.
  final bool showCount;

  const MenuButton({super.key, this.showCount = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final menu = AppMenu.maybeOf(context);
    final inSession = menu?.inSession ?? 0;
    return IconButton(
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      visualDensity: VisualDensity.compact,
      onPressed: menu?.open,
      icon: Badge(
        isLabelVisible: showCount && inSession > 1,
        label: Text('$inSession'),
        backgroundColor: cs.primary,
        textColor: cs.onPrimary,
        child: const Icon(AppIcons.menu, size: 32),
      ),
    );
  }
}
