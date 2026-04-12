import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/health_service.dart';
import '../widgets/top_level_back_scope.dart';

class MathsScreen extends StatelessWidget {
  const MathsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final bodyWeightKg = auth.bodyWeightKg;
    final hasWeight = bodyWeightKg > 0;

    // Example: 60-minute session
    final exampleDuration = 60.0;
    final exampleCalories = HealthService.estimateCalories(
      durationMinutes: exampleDuration,
      bodyWeightKg: bodyWeightKg,
    );

    return TopLevelBackScope(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Maths',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _SectionLabel('CALORIE ESTIMATION', cs),
            const SizedBox(height: 8),
            const Text(
              'How we estimate calories burned',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              'We use the MET (Metabolic Equivalent of Task) formula from the '
              '2011 Compendium of Physical Activities (Ainsworth et al., Med Sci '
              'Sports Exerc 43(8):1575–81). Traditional strength training has a '
              'MET value of 3.5.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            _FormulaCard(cs),
            const SizedBox(height: 20),
            if (hasWeight) ...[
              _SectionLabel('YOUR ESTIMATE', cs),
              const SizedBox(height: 8),
              _ExampleCard(
                cs: cs,
                bodyWeightKg: bodyWeightKg,
                durationMinutes: exampleDuration,
                calories: exampleCalories,
              ),
              const SizedBox(height: 20),
            ] else ...[
              _NoWeightCard(cs),
              const SizedBox(height: 20),
            ],
            _SectionLabel('WHAT ABOUT TONNAGE?', cs),
            const SizedBox(height: 8),
            const Text(
              'Volume and calorie burn',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              'Tonnage (sets × reps × weight lifted) does predict calorie '
              'expenditure during strength training. A 2006 study by Haddock & '
              'Wilkin (Int J Sports Med 27(2):143–8) found that 3-set protocols '
              'burned ~2.8× more calories than 1-set protocols of the same '
              'exercise.\n\n'
              'However, when normalised per minute of actual exercise time, '
              'calorie rate is roughly constant — meaning total duration already '
              'captures most of the tonnage effect. More volume → longer sessions '
              '→ more calories, which the MET × duration formula handles '
              'automatically.\n\n'
              'A 2020 regression study found that session time and volume load '
              'together explained ~61% of energy expenditure variance (R² = 0.61). '
              'The remaining 39% is individual variation in rest periods, exercise '
              'selection, and body composition that no formula can capture without '
              'direct measurement.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel('ACCURACY', cs),
            const SizedBox(height: 8),
            const Text(
              'Why this is an estimate',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              'Resistance training has a large anaerobic component (up to 40% of '
              'total energy expenditure) that standard indirect calorimetry cannot '
              'fully capture — and no phone app can measure it at all. A 2024 '
              'systematic review (PMC11393209) found no gold-standard method for '
              'resistance training energy expenditure. The MET formula gives a '
              'reasonable population-average estimate, accurate to perhaps ±25% '
              'for any individual session.\n\n'
              'If no bodyweight is set, we fall back to a flat 5 kcal/min — '
              'roughly the midpoint of the 4–10 kcal/min range observed across '
              'studies.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel('REFERENCES', cs),
            const SizedBox(height: 8),
            ..._references(cs),
          ],
        ),
      ),
    );
  }

  List<Widget> _references(ColorScheme cs) {
    final refs = [
      'Ainsworth BE et al. (2011). 2011 Compendium of Physical Activities: A Second Update of Codes and MET Values. Med Sci Sports Exerc, 43(8):1575–81.',
      'Haddock CK & Wilkin LD (2006). Resistance training volume and post exercise energy expenditure. Int J Sports Med, 27(2):143–8.',
      'Dinyer-McNeely TK et al. (2024). Methods to Assess Energy Expenditure of Resistance Exercise: A Systematic Scoping Review. PMC11393209.',
    ];
    return refs
        .map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Expanded(
                  child: Text(
                    r,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;

  const _SectionLabel(this.text, this.cs);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.4,
        color: cs.tertiary,
      ),
    );
  }
}

class _FormulaCard extends StatelessWidget {
  final ColorScheme cs;

  const _FormulaCard(this.cs);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FORMULA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'calories = MET × 3.5 × weight_kg × minutes ÷ 200',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          _row(cs, 'MET', '3.5 (traditional strength training)'),
          _row(cs, '3.5', 'ml O₂ per kg per min at 1 MET (standard constant)'),
          _row(cs, 'weight_kg', 'your bodyweight in kilograms'),
          _row(cs, 'minutes', 'total workout duration'),
          _row(cs, '÷ 200', 'converts ml O₂/min to kcal/min (5 kcal/L O₂ ÷ 1000 × 40)'),
        ],
      ),
    );
  }

  Widget _row(ColorScheme cs, String term, String definition) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              term,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: cs.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              definition,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final ColorScheme cs;
  final double bodyWeightKg;
  final double durationMinutes;
  final int calories;

  const _ExampleCard({
    required this.cs,
    required this.bodyWeightKg,
    required this.durationMinutes,
    required this.calories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXAMPLE — ${durationMinutes.toInt()} MIN SESSION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '3.5 × 3.5 × ${bodyWeightKg.toStringAsFixed(1)} × ${durationMinutes.toInt()} ÷ 200',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '≈ $calories kcal',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoWeightCard extends StatelessWidget {
  final ColorScheme cs;

  const _NoWeightCard(this.cs);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Set your bodyweight in Settings → Body weight to get a personalised calorie estimate.',
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
