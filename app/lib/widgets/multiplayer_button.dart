/// The multiplayer button on the workout's first row: the orange square
/// that opens the train-together sheet, with how many are in the session.
library;

import 'package:flutter/material.dart';

import '../gen/copy.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';
import 'menu_button.dart';
import 'multiplayer_modal.dart';

/// Opens the sheet to invite, join or leave a training session.
void showMultiplayerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    routeSettings: const RouteSettings(name: 'sheet/multiplayer'),
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) => const MultiplayerModal(),
  );
}

class MultiplayerButton extends StatelessWidget {
  const MultiplayerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inSession = AppMenu.maybeOf(context)?.inSession ?? 0;
    return Badge(
      isLabelVisible: inSession > 1,
      label: Text('$inSession'),
      backgroundColor: cs.onSurface,
      textColor: cs.surface,
      child: IconButton.filled(
        tooltip: copy.menu.multiplayer,
        onPressed: () => showMultiplayerSheet(context),
        visualDensity: VisualDensity.compact,
        iconSize: context.tokens.size.title,
        icon: const Icon(AppIcons.multiplayer),
        style: IconButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: context.tokens.brSm),
        ),
      ),
    );
  }
}
