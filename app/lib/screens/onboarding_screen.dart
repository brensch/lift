import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../logic/regime_data.dart';
import '../providers/settings_provider.dart';
import 'regime_info_screen.dart';

// ─── Main screen ─────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Selection state
  int _selectedRegimeIndex = 0;
  int _selectedDays = 3;
  final Map<int, TextEditingController> _weightControllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final ex in exerciseDefs) {
      _weightControllers[ex.exerciseInt] = TextEditingController(
        text: ex.defaultWeight.toStringAsFixed(0),
      );
    }
    _selectedDays = _currentRegime.defaultDays;
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  RegimeDef get _currentRegime => regimeDefs[_selectedRegimeIndex];

  void _selectRegime(int idx) {
    setState(() {
      _selectedRegimeIndex = idx;
      _selectedDays = regimeDefs[idx].defaultDays;
    });
  }

  void _goNext() {
    FocusScope.of(context).unfocus();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveAndGo() async {
    setState(() => _isSaving = true);
    try {
      final oneRepMaxes = <int, double>{};
      for (final ex in exerciseDefs) {
        final text = _weightControllers[ex.exerciseInt]?.text.trim() ?? '';
        final val = double.tryParse(text);
        if (val != null && val > 0) {
          oneRepMaxes[ex.exerciseInt] = val;
        }
      }

      final config = UserWorkoutConfig(
        regimeType: _currentRegime.type,
        daysPerWeek: _selectedDays,
        oneRepMaxes: oneRepMaxes.entries
            .map((e) => MapEntry(e.key, e.value.toDouble())),
        regimeStateJson: '{}',
      );

      await context.read<SettingsProvider>().updateWorkoutConfig(config);
      if (mounted) context.go('/');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _skip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Starting you on Linear 5×5',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "We'll enrol you in Linear 5×5 — the best program for beginners. "
          "You can change this anytime in Settings → Training Program.",
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Got it'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Save default Linear 5x5 config so hasWorkoutConfig becomes true.
    final defaults = regimeDefs.first; // Linear 5x5
    final defaultWeights = {
      for (final ex in exerciseDefs)
        ex.exerciseInt: ex.defaultWeight,
    };
    final config = UserWorkoutConfig(
      regimeType: defaults.type,
      daysPerWeek: defaults.defaultDays,
      oneRepMaxes: defaultWeights.entries
          .map((e) => MapEntry(e.key, e.value)),
      regimeStateJson: '{}',
    );
    await context.read<SettingsProvider>().updateWorkoutConfig(config);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress + skip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Row(
                    children: List.generate(3, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _currentPage ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _RegimePage(
                    selectedIndex: _selectedRegimeIndex,
                    onSelect: _selectRegime,
                    onNext: _goNext,
                  ),
                  _DaysAndWeightsPage(
                    regime: _currentRegime,
                    selectedDays: _selectedDays,
                    onDaysChanged: (d) => setState(() => _selectedDays = d),
                    weightControllers: _weightControllers,
                    onBack: _goBack,
                    onNext: _goNext,
                  ),
                  _ConfirmPage(
                    regime: _currentRegime,
                    selectedDays: _selectedDays,
                    weightControllers: _weightControllers,
                    onBack: _goBack,
                    onSave: _saveAndGo,
                    onSkip: _skip,
                    isSaving: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1: Regime selection ─────────────────────────────────────────────────

class _RegimePage extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onSelect;
  final VoidCallback onNext;

  const _RegimePage({
    required this.selectedIndex,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHOOSE YOUR PROGRAM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How do you train?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick the program that matches your experience and goals. You can change this anytime in Settings.',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: regimeDefs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final regime = regimeDefs[idx];
                final selected = selectedIndex == idx;
                return _RegimeCard(
                  regime: regime,
                  isSelected: selected,
                  onTap: () => onSelect(idx),
                  onInfo: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        RegimeInfoScreen(regimeType: regime.type),
                  )),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'NEXT',
                style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegimeCard extends StatelessWidget {
  final RegimeDef regime;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  const _RegimeCard({
    required this.regime,
    required this.isSelected,
    required this.onTap,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radio dot
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outline,
                    width: 2,
                  ),
                  color:
                      isSelected ? cs.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check,
                        size: 10, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        regime.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.3,
                          color: isSelected
                              ? cs.primary
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.tertiary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          regime.tagline,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: cs.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    regime.description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.8)
                          : cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onInfo,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 13, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Learn more',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 2: Days per week + starting weights ─────────────────────────────────

class _DaysAndWeightsPage extends StatelessWidget {
  final RegimeDef regime;
  final int selectedDays;
  final void Function(int) onDaysChanged;
  final Map<int, TextEditingController> weightControllers;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _DaysAndWeightsPage({
    required this.regime,
    required this.selectedDays,
    required this.onDaysChanged,
    required this.weightControllers,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWendler =
        regime.type == RegimeType.REGIME_TYPE_WENDLER_531;

    final exercisesToShow = isWendler
        ? exerciseDefs.where((e) => e.isWendlerMain).toList()
        : exerciseDefs;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            regime.name.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isWendler
                ? 'Enter your 1-rep maxes.'
                : 'Set your starting weights.',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isWendler
                ? 'Your Training Max (TM) = 90% of each 1RM. Leave blank for defaults.'
                : 'Enter your current 5-rep working weight. Leave blank for defaults.',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          if (regime.daysOptions.length > 1) ...[
            Text(
              'DAYS PER WEEK',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: regime.daysOptions.map((d) {
                final selected = d == selectedDays;
                return ChoiceChip(
                  label: Text('$d days'),
                  selected: selected,
                  onSelected: (_) => onDaysChanged(d),
                  selectedColor: cs.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? cs.onPrimary : cs.onSurface,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          Expanded(
            child: ListView.separated(
              itemCount: exercisesToShow.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final ex = exercisesToShow[idx];
                final controller = weightControllers[ex.exerciseInt]!;
                return _WeightField(
                  label: ex.name,
                  controller: controller,
                  hint: '${ex.defaultWeight.toStringAsFixed(0)} lbs',
                  isWendler: isWendler,
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('BACK',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('NEXT',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isWendler;

  const _WeightField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.isWendler,
  });

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final val = double.tryParse(widget.controller.text);
    final tmText = widget.isWendler && val != null && val > 0
        ? 'Training Max: ${(val * 0.9).round()} lbs'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const Spacer(),
            if (tmText != null)
              Text(
                tmText,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixText: 'lbs',
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: cs.outline.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Page 3: Confirm ──────────────────────────────────────────────────────────

class _ConfirmPage extends StatelessWidget {
  final RegimeDef regime;
  final int selectedDays;
  final Map<int, TextEditingController> weightControllers;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onSkip;
  final bool isSaving;

  const _ConfirmPage({
    required this.regime,
    required this.selectedDays,
    required this.weightControllers,
    required this.onBack,
    required this.onSave,
    required this.onSkip,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWendler =
        regime.type == RegimeType.REGIME_TYPE_WENDLER_531;

    final exercisesToShow = isWendler
        ? exerciseDefs.where((e) => e.isWendlerMain).toList()
        : exerciseDefs;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFIRM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: cs.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "You're all set.",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(regime.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    )),
                const SizedBox(height: 4),
                Text(
                  '$selectedDays days/week',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < exercisesToShow.length; i++) ...[
                  _SummaryRow(
                    exercise: exercisesToShow[i],
                    controller:
                        weightControllers[exercisesToShow[i].exerciseInt]!,
                    isWendler: isWendler,
                    cs: cs,
                  ),
                  if (i < exercisesToShow.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton(
              onPressed: isSaving ? null : onSave,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: isSaving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Text(
                      "LET'S GO",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('BACK',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                        color:
                            cs.onSurface.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final ExerciseDef exercise;
  final TextEditingController controller;
  final bool isWendler;
  final ColorScheme cs;

  const _SummaryRow({
    required this.exercise,
    required this.controller,
    required this.isWendler,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    final val = double.tryParse(text);
    final displayWeight = val != null && val > 0
        ? '${val.toStringAsFixed(0)} lbs'
        : '${exercise.defaultWeight.toStringAsFixed(0)} lbs (default)';
    final tmDisplay = isWendler && val != null && val > 0
        ? '  →  TM: ${(val * 0.9).round()} lbs'
        : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(exercise.name,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        Text(
          '$displayWeight$tmDisplay',
          style: TextStyle(
            fontSize: 12,
            color: cs.primary.withValues(alpha: 0.8),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
