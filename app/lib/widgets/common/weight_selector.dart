/// Picking a weight: the number, big and typeable; for a barbell the bar
/// drawn loaded, live, and the plates each side; steps down and up a plate
/// pair or a big plate at a time; and a slider for the long way. Used
/// wherever a lift's weight is chosen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../logic/plate_calculator.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../theme/theme_spec.dart';
import '../plate_visualization.dart';

class WeightSelector extends StatefulWidget {
  /// The weight, in pounds (stored weights always are).
  final double weightLb;
  final ValueChanged<double> onChanged;

  /// A barbell: the bar and plates are shown, steps are a plate pair and a
  /// big plate pair, and it never goes under the empty bar.
  final bool barbell;

  /// Enter on the keyboard.
  final VoidCallback? onSubmitted;

  const WeightSelector({
    super.key,
    required this.weightLb,
    required this.onChanged,
    this.barbell = true,
    this.onSubmitted,
  });

  @override
  State<WeightSelector> createState() => _WeightSelectorState();
}

class _WeightSelectorState extends State<WeightSelector> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// The latest weight given out, so taps faster than a redraw add up.
  late double _current = widget.weightLb;

  @override
  void initState() {
    super.initState();
    _text.text = _shown(widget.weightLb);
    _focus.addListener(() {
      // Leaving the field settles what was typed onto the grid.
      if (!_focus.hasFocus) _set(_display(_current));
    });
  }

  @override
  void didUpdateWidget(WeightSelector old) {
    super.didUpdateWidget(old);
    // A step or the slider moved it: show that, unless it's being typed.
    if (old.weightLb != widget.weightLb) {
      _current = widget.weightLb;
      if (!_focus.hasFocus) _text.text = _shown(widget.weightLb);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  WeightUnit get _unit => context.read<SettingsProvider>().weightUnit;
  bool get _kg => isMetricUnit(_unit);

  double _display(double lb) => displayWeightFromPounds(lb, _unit);
  String _shown(double lb) => formatWeight(lb, _unit);

  double get _small => _kg ? 2.5 : 5;
  double get _big => widget.barbell ? (_kg ? 20 : 45) : (_kg ? 10 : 25);
  double get _min => widget.barbell ? standardBarWeight(_unit) : 0;
  double get _max => _kg ? 300 : 650;

  /// Set from the display unit, snapped to the small step and in range.
  void _set(double display) {
    final snapped = ((display / _small).round() * _small).clamp(_min, _max);
    final lb = poundsFromDisplayWeight(snapped.toDouble(), _unit);
    _current = lb;
    if (!_focus.hasFocus) _text.text = _shown(lb);
    widget.onChanged(lb);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final settings = context.watch<SettingsProvider>();
    final display = _display(widget.weightLb);
    String num(double v) => v % 1 == 0 ? v.toInt().toString() : '$v';

    Widget step(double by, {bool last = false}) => Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_focus.hasFocus) _focus.unfocus();
            HapticFeedback.selectionClick();
            _set(_display(_current) + by);
          },
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                right: last ? BorderSide.none : BorderSide(color: t.hairline),
              ),
            ),
            child: Text(
              '${by > 0 ? '+' : '−'}${num(by.abs())}',
              style: t.mono(
                TextStyle(
                  fontSize: t.size.title,
                  fontWeight: t.weight.bold,
                  color: t.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final plates = calcPlatesPerSide(
      displayWeightFromPounds(widget.weightLb, unit),
      unit,
    ).plates;
    final perSide = plates.isEmpty
        ? 'Empty bar'
        : '${plates.map(num).join(' · ')}  each side';

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The number: type it, or step and slide it below.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    textAlign: TextAlign.center,
                    onChanged: (value) {
                      final typed = double.tryParse(value);
                      if (typed != null) {
                        _current = poundsFromDisplayWeight(typed, unit);
                        widget.onChanged(_current);
                      }
                    },
                    onSubmitted: (_) {
                      _focus.unfocus();
                      widget.onSubmitted?.call();
                    },
                    style: t.mono(
                      TextStyle(
                        fontSize: t.size.giant,
                        fontWeight: t.weight.bold,
                        color: t.text,
                        height: 1.1,
                      ),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  weightUnitSuffix(unit),
                  style: t.mono(
                    TextStyle(
                      fontSize: t.size.title,
                      fontWeight: t.weight.bold,
                      color: t.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The bar as it's loaded, on white, and the plates each side.
          if (widget.barbell)
            Container(
              height: 96,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.symmetric(
                  horizontal: BorderSide(color: t.outline),
                ),
              ),
              child: FittedBox(
                child: BigBarbell(
                  plates: plates,
                  colorOf: settings.plateColor,
                  heaviest: standardPlates(unit).first,
                ),
              ),
            ),
          if (widget.barbell)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              // One line always, shrunk to fit: a long load wrapping onto a
              // second line made the selector jump in height as it changed.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  perSide,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: t.mono(
                    TextStyle(
                      fontSize: t.size.body,
                      fontWeight: t.weight.bold,
                      color: t.muted,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.hairline)),
            ),
            child: Row(
              children: [
                step(-_big),
                step(-_small),
                step(_small),
                step(_big, last: true),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.hairline)),
            ),
            child: Slider(
              value: display.clamp(_min, _max).toDouble(),
              min: _min,
              max: _max,
              divisions: ((_max - _min) / _small).round(),
              onChanged: (value) {
                if (_focus.hasFocus) _focus.unfocus();
                _set(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
