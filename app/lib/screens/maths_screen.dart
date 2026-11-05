import 'package:flutter/material.dart';
import '../widgets/common/flat.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../providers/auth_provider.dart';
import '../services/health_service.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

class MathsScreen extends StatelessWidget {
  const MathsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = copy.maths;
    final auth = context.watch<AuthProvider>();
    final bodyWeightKg = auth.bodyWeightKg;
    final hasWeight = bodyWeightKg > 0;

    // Example: 60-minute session
    final exampleDuration = 60.0;
    final exampleCalories = HealthService.estimateCalories(
      durationMinutes: exampleDuration,
      bodyWeightKg: bodyWeightKg,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: PageTitle(c.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _SectionLabel(c.estimationLabel, cs),
          const SizedBox(height: 8),
          Text(
            c.estimationTitle,
            style: TextStyle(
              fontSize: context.tokens.size.titleLg,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.estimationBody,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _FormulaCard(cs),
          const SizedBox(height: 20),
          if (hasWeight) ...[
            _SectionLabel(c.yourEstimateLabel, cs),
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
          _SectionLabel(c.tonnageLabel, cs),
          const SizedBox(height: 8),
          Text(
            c.tonnageTitle,
            style: TextStyle(
              fontSize: context.tokens.size.title,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.tonnageBody,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(c.accuracyLabel, cs),
          const SizedBox(height: 8),
          Text(
            c.accuracyTitle,
            style: TextStyle(
              fontSize: context.tokens.size.title,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.accuracyBody,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(c.referencesLabel, cs),
          const SizedBox(height: 8),
          ..._references(context, cs),
        ],
      ),
    );
  }

  List<Widget> _references(BuildContext context, ColorScheme cs) {
    return copy.maths.references
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
                    fontWeight: context.tokens.weight.heavy,
                  ),
                ),
                Expanded(
                  child: Text(
                    r,
                    style: TextStyle(
                      fontSize: context.tokens.size.small,
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
        fontSize: context.tokens.size.small,
        fontWeight: context.tokens.weight.heavy,
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
        borderRadius: context.tokens.brLg,
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.maths.formulaLabel,
            style: TextStyle(
              fontSize: context.tokens.size.caption,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: 1.2,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'calories = MET × 3.5 × weight_kg × minutes ÷ 200',
            style: context.tokens.mono(
              TextStyle(
                fontSize: context.tokens.size.bodyLg,
                fontWeight: context.tokens.weight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _row(context, cs, 'MET', copy.maths.termMet),
          _row(context, cs, '3.5', copy.maths.termConstant),
          _row(context, cs, 'weight_kg', copy.maths.termWeight),
          _row(context, cs, 'minutes', copy.maths.termMinutes),
          _row(context, cs, '÷ 200', copy.maths.termDivisor),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ColorScheme cs,
    String term,
    String definition,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              term,
              style: context.tokens.mono(
                TextStyle(
                  fontSize: context.tokens.size.small,
                  fontWeight: context.tokens.weight.heavy,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              definition,
              style: TextStyle(
                fontSize: context.tokens.size.small,
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
        borderRadius: context.tokens.brLg,
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.maths.example.replaceAll(
              '{min}',
              '${durationMinutes.toInt()}',
            ),
            style: TextStyle(
              fontSize: context.tokens.size.caption,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: 1.2,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '3.5 × 3.5 × ${bodyWeightKg.toStringAsFixed(1)} × ${durationMinutes.toInt()} ÷ 200',
            style: context.tokens.mono(
              TextStyle(
                fontSize: context.tokens.size.body,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.maths.exampleResult.replaceAll('{kcal}', '$calories'),
            style: TextStyle(
              fontSize: context.tokens.size.headline,
              fontWeight: context.tokens.weight.heavy,
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
        borderRadius: context.tokens.brMd,
      ),
      child: Row(
        children: [
          Icon(AppIcons.info, color: cs.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              copy.maths.noWeight,
              style: TextStyle(
                fontSize: context.tokens.size.body,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
