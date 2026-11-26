/// Setup: bodyweight, for calories. Optional. Words in app/copy.yaml.
library;

import 'package:material_ui/material_ui.dart';

import '../../../gen/copy.dart';
import '../../../gen/workout/v1/settings.pb.dart';
import '../../../logic/weight_units.dart';
import '../../../theme/theme_spec.dart';
import '../../../widgets/common/flat.dart';
import '../widgets/onboarding_page.dart';

class WeightStep extends StatelessWidget {
  final WeightUnit unit;
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const WeightStep({
    super.key,
    required this.unit,
    required this.controller,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = copy.onboarding.weight;
    return OnboardingPage(
      title: t.title,
      body: t.body,
      bigBody: true,
      onBack: onBack,
      primary: OnboardingNext(label: copy.onboarding.next, onPressed: onNext),
      children: [
        FlatSection(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: t.field,
              suffixText: weightUnitSuffix(unit),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FlatSection.margin,
            10,
            FlatSection.margin,
            0,
          ),
          child: Text(
            t.note,
            style: TextStyle(
              fontSize: context.tokens.size.small,
              height: 1.4,
              color: context.tokens.muted,
            ),
          ),
        ),
      ],
    );
  }
}
