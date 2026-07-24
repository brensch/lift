/// Weight entry: display box, wheel picker, and +/- adjust buttons, with plate visualisation.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../plate_visualization.dart';

class WeightDisplayBox extends StatelessWidget {
  final double weight;
  final VoidCallback onTap;

  const WeightDisplayBox({super.key, required this.weight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final displayWeight = snapDisplayWeight(
      displayWeightFromPounds(weight, unit),
      unit,
      poundStep: 5,
      kilogramStep: isMetricUnit(unit) ? 2.5 : 5,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              width: 56,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                child: PlateVisualization(weight: weight, isInteractive: false),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              displayWeight % 1 == 0
                  ? displayWeight.toStringAsFixed(0)
                  : displayWeight.toStringAsFixed(1),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 4),
            Text(
              weightUnitSuffix(unit),
              style: TextStyle(fontSize: 12, color: colorScheme.tertiary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: colorScheme.tertiary),
          ],
        ),
      ),
    );
  }
}

class WeightPicker extends StatefulWidget {
  final double initialWeight;
  final ValueChanged<double> onChanged;

  const WeightPicker({super.key, required this.initialWeight, required this.onChanged});

  @override
  State<WeightPicker> createState() => WeightPickerState();
}

class WeightPickerState extends State<WeightPicker> {
  late double _displayWeight;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final unit = context.read<SettingsProvider>().weightUnit;
    _displayWeight = snapDisplayWeight(
      displayWeightFromPounds(widget.initialWeight, unit),
      unit,
      poundStep: 5,
      kilogramStep: isMetricUnit(unit) ? 2.5 : 5,
    );
    _textController = TextEditingController(
      text: _displayWeight % 1 == 0
          ? _displayWeight.toStringAsFixed(0)
          : _displayWeight.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateWeight(double newDisplayWeight) {
    final unit = context.read<SettingsProvider>().weightUnit;
    setState(() {
      _displayWeight = newDisplayWeight.clamp(
        0,
        isMetricUnit(unit) ? 300 : 600,
      );
      _textController.text = _displayWeight % 1 == 0
          ? _displayWeight.toStringAsFixed(0)
          : _displayWeight.toStringAsFixed(1);
    });
    widget.onChanged(poundsFromDisplayWeight(_displayWeight, unit));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final smallStep = isMetricUnit(unit) ? 2.5 : 5.0;
    final bigStep = isMetricUnit(unit) ? 20.0 : 45.0;
    final maxDisplay = isMetricUnit(unit) ? 300.0 : 600.0;
    final sliderDivisions = (maxDisplay / smallStep).round();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SET WEIGHT',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Weight Input & Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final w = double.tryParse(val);
                    if (w != null) {
                      _updateWeight(w);
                    }
                  },
                ),
              ),
              Text(
                weightUnitSuffix(unit).toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          PlateVisualization(
            weight: poundsFromDisplayWeight(_displayWeight, unit),
            scale: 1.2,
          ),
          const SizedBox(height: 24),

          // Quick Adjust Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              WeightAdjustBtn(
                label: '-${bigStep % 1 == 0 ? bigStep.toInt() : bigStep}',
                onPressed: () => _updateWeight(_displayWeight - bigStep),
              ),
              WeightAdjustBtn(
                label: '-${smallStep % 1 == 0 ? smallStep.toInt() : smallStep}',
                onPressed: () => _updateWeight(_displayWeight - smallStep),
              ),
              WeightAdjustBtn(
                label: '+${smallStep % 1 == 0 ? smallStep.toInt() : smallStep}',
                onPressed: () => _updateWeight(_displayWeight + smallStep),
              ),
              WeightAdjustBtn(
                label: '+${bigStep % 1 == 0 ? bigStep.toInt() : bigStep}',
                onPressed: () => _updateWeight(_displayWeight + bigStep),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Slider
          Slider(
            value: _displayWeight.clamp(0, maxDisplay),
            min: 0,
            max: maxDisplay,
            divisions: sliderDivisions,
            label: _displayWeight % 1 == 0
                ? _displayWeight.toStringAsFixed(0)
                : _displayWeight.toStringAsFixed(1),
            onChanged: _updateWeight,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class WeightAdjustBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const WeightAdjustBtn({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}
