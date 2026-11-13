/// Supporting panels for the workout screen: the missing-HR notice, the
/// first row, the add-exercise row.
library;

import '../../gen/copy.dart';
import 'package:flutter/material.dart';
import '../../theme/theme_spec.dart';
import '../../theme/app_icons.dart';
import '../../widgets/menu_button.dart';
import '../../widgets/multiplayer_button.dart';

class NoHeartRateMonitor extends StatelessWidget {
  const NoHeartRateMonitor({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.watch, size: 52, color: colorScheme.tertiary),
            const SizedBox(height: 18),
            Text(
              copy.workoutPage.noHeartRate,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.tokens.size.subtitle,
                fontWeight: context.tokens.weight.heavy,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              copy.workoutPage.noHeartRateBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.tokens.size.body,
                height: 1.45,
                fontWeight: context.tokens.weight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Session strip (top block: workout name + a single slim progress bar) ────

/// The live workout's first row, in place of a banner: the workout's name,
/// the multiplayer button, the menu.
class WorkoutRow extends StatelessWidget {
  final String title;

  const WorkoutRow({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      // Room above and below the buttons: the count on the multiplayer
      // button stands over its corner.
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.size.title,
                fontWeight: t.weight.heavy,
                color: t.text,
              ),
            ),
          ),
          const MultiplayerButton(),
          const MenuButton(showCount: false),
        ],
      ),
    );
  }
}

/// A figure in a box that opens a page: bordered, so it reads as something
/// to tap. The workout's heart rate (opens Heart) and
/// clock (opens Log), side by side over the status box.
class OpenBox extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final List<Widget> children;

  const OpenBox({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: t.outline.withValues(alpha: 0.5)),
          borderRadius: t.brMd,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class AddExerciseRow extends StatelessWidget {
  final VoidCallback onTap;

  const AddExerciseRow({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(AppIcons.add, size: t.size.title, color: t.muted),
            const SizedBox(width: 8),
            Text(
              copy.workoutPage.addExercise,
              style: TextStyle(
                fontSize: t.size.bodyLg,
                fontWeight: t.weight.bold,
                color: t.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
