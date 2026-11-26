/// The controls the hand editors of the program are built from: a number
/// with − and + as a full-width row, a switch row, the save bar, and
/// saving a changed document with its problems shown.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme_spec.dart';
import '../../widgets/common/flat.dart';

/// A number as a full-width row: its label, − and +, the value between.
/// [step] each tap, within [min]–[max]; [show] formats it.
class NumberRow extends StatelessWidget {
  final String label;
  final num value;
  final num min;
  final num max;
  final num step;
  final ValueChanged<num> onChanged;
  final String Function(num)? show;

  const NumberRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.show,
  });

  num _clamp(num v) => v < min ? min : (v > max ? max : v);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = show?.call(value) ?? _plain(value);
    return Container(
      padding: const EdgeInsets.fromLTRB(FlatSection.margin, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: t.size.body, color: t.text),
            ),
          ),
          IconButton(
            onPressed: value > min
                ? () => onChanged(_round(_clamp(value - step)))
                : null,
            icon: const Icon(AppIcons.removeCircle),
          ),
          SizedBox(
            width: 64,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: t.mono(
                TextStyle(fontSize: t.size.bodyLg, fontWeight: t.weight.bold),
              ),
            ),
          ),
          IconButton(
            onPressed: value < max
                ? () => onChanged(_round(_clamp(value + step)))
                : null,
            icon: const Icon(AppIcons.addCircle),
          ),
        ],
      ),
    );
  }

  static num _round(num v) => v is int ? v : (v * 1000).roundToDouble() / 1000;

  static String _plain(num v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// One of a few choices as a full-width row: its label over a quieter
/// line, and a tick when it's the one chosen (no chevron: it opens
/// nothing). Without [onTap] it's shown but not choosable.
class PickRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback? onTap;

  const PickRow({
    super.key,
    required this.label,
    required this.sub,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FlatSection.margin,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: t.size.bodyLg,
                        fontWeight: t.weight.bold,
                        color: t.text,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: t.size.small,
                          color: t.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Visibility.maintain(
                visible: selected,
                child: Icon(
                  AppIcons.check,
                  size: t.size.title,
                  color: t.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A yes-or-no as a full-width row.
class SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(FlatSection.margin, 2, 8, 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: t.size.body)),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The Save button along the bottom, over a hairline.
class SaveBar extends StatelessWidget {
  final VoidCallback? onSave;
  final bool busy;

  const SaveBar({super.key, required this.onSave, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FlatSection.margin,
            12,
            FlatSection.margin,
            12,
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: busy ? null : onSave,
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      copy.rules.save,
                      style: TextStyle(fontWeight: t.weight.heavy),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Set [doc] as the program; true when it was. The core's problems, or
/// what went wrong, are shown when it wasn't.
Future<bool> saveDocument(
  BuildContext context,
  Map<String, dynamic> doc,
) async {
  final wp = context.read<WorkoutProvider>();
  final messenger = ScaffoldMessenger.of(context);
  void tell(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  final r = copy.rules;
  try {
    final errors = await wp.setProgramDocument(doc);
    if (errors.isEmpty) {
      tell(r.saved);
      return true;
    }
    tell(
      errors
          .map(
            (e) => r.problem
                .replaceAll('{path}', e.path)
                .replaceAll('{message}', e.message),
          )
          .join('\n'),
    );
  } catch (e) {
    tell(r.failed.replaceAll('{error}', '$e'));
  }
  return false;
}
