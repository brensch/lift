/// Onboarding: choose pounds or kilograms.
library;

import 'package:material_ui/material_ui.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/settings.pb.dart';
import '../widgets/onboarding_page.dart';

class UnitStep extends StatelessWidget {
  final WeightUnit selectedUnit;
  final Future<void> Function(WeightUnit unit) onSelect;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const UnitStep({
    super.key,
    required this.selectedUnit,
    required this.onSelect,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = copy.onboarding.unit;
    return OnboardingPage(
      title: t.title,
      body: t.body,
      onBack: onBack,
      primary: OnboardingNext(label: copy.onboarding.next, onPressed: onNext),
      children: [
        ChoiceRow(
          badge: '🦅',
          title: t.pounds,
          subtitle: t.poundsBody,
          selected: selectedUnit == WeightUnit.WEIGHT_UNIT_LB,
          onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_LB),
        ),
        ChoiceRow(
          badge: '🌍',
          title: t.kilograms,
          subtitle: t.kilogramsBody,
          selected: selectedUnit == WeightUnit.WEIGHT_UNIT_KG,
          onTap: () => onSelect(WeightUnit.WEIGHT_UNIT_KG),
        ),
      ],
    );
  }
}
