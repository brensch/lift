/// One workout in a list, compact: a tick box (when it can be ticked), the
/// name, any actions, and a chevron that drops down what's in it — so a
/// whole library fits on screen until you want detail. Onboarding's pick
/// and the home Edit sheet are the same rows.
library;

import 'package:flutter/material.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';

class TemplateRow extends StatefulWidget {
  final String name;
  final String blurb;
  final List<Exercise> exercises;

  /// Ticked or not; null for no tick box.
  final bool? selected;

  /// The user's own (cloned or made): marked as such.
  final bool personal;

  final VoidCallback? onTap;

  /// Between the name and the chevron.
  final List<Widget> actions;

  const TemplateRow({
    super.key,
    required this.name,
    required this.exercises,
    this.blurb = '',
    this.selected,
    this.personal = false,
    this.onTap,
    this.actions = const [],
  });

  @override
  State<TemplateRow> createState() => _TemplateRowState();
}

class _TemplateRowState extends State<TemplateRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = widget.selected;
    final names = widget.exercises
        .map((e) => exerciseNames[e] ?? e.name)
        .join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: widget.onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
            child: Row(
              children: [
                if (selected != null) ...[
                  SelectBox(selected: selected, colorScheme: cs),
                  const SizedBox(width: 12),
                ],
                if (widget.personal) ...[
                  Icon(AppIcons.copy, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: context.tokens.size.bodyLg,
                      fontWeight: selected ?? true
                          ? context.tokens.weight.heavy
                          : context.tokens.weight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                ...widget.actions,
                IconButton(
                  onPressed: () => setState(() => _open = !_open),
                  icon: Icon(_open ? AppIcons.expandUp : AppIcons.expandDown),
                  color: cs.onSurface.withValues(alpha: 0.6),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: EdgeInsets.fromLTRB(selected != null ? 36 : 2, 6, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.personal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      copy.library.personal.toUpperCase(),
                      style: TextStyle(
                        fontSize: context.tokens.size.small,
                        fontWeight: context.tokens.weight.heavy,
                        letterSpacing: 0.8,
                        color: cs.primary,
                      ),
                    ),
                  ),
                if (widget.blurb.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.blurb,
                      style: TextStyle(
                        fontSize: context.tokens.size.small,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                Text(
                  names,
                  style: TextStyle(
                    fontSize: context.tokens.size.small,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A square tick box for multi-select lists. Deliberately not a circle, which
/// reads as a radio button (pick one) when the user can pick many.
class SelectBox extends StatelessWidget {
  final bool selected;
  final ColorScheme colorScheme;

  const SelectBox({
    super.key,
    required this.selected,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? cs.primary : Colors.transparent,
        borderRadius: context.tokens.br(5),
        border: Border.all(
          color: selected ? cs.primary : cs.outline,
          width: 1.5,
        ),
      ),
      child: selected
          ? Icon(AppIcons.check, size: 16, color: cs.onPrimary)
          : null,
    );
  }
}

/// Marks a workout as the user's own: on the home card.
class PersonalTag extends StatelessWidget {
  const PersonalTag({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.copy, size: 13, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            copy.library.personal.toUpperCase(),
            style: TextStyle(
              fontSize: context.tokens.size.small,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: 0.8,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}
