import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../logic/regime_data.dart';
import '../providers/settings_provider.dart';
import 'regime_info_screen.dart';

class RegimeSettingsScreen extends StatefulWidget {
  const RegimeSettingsScreen({super.key});

  @override
  State<RegimeSettingsScreen> createState() => _RegimeSettingsScreenState();
}

class _RegimeSettingsScreenState extends State<RegimeSettingsScreen> {
  int _selectedRegimeIndex = 0;
  int _selectedDays = 3;
  final Map<int, TextEditingController> _weightControllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with defaults
    for (final ex in exerciseDefs) {
      _weightControllers[ex.exerciseInt] = TextEditingController(
        text: ex.defaultWeight.toStringAsFixed(0),
      );
    }

    // Load existing config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = context.read<SettingsProvider>().workoutConfig;
      if (config == null) return;

      final idx = regimeDefs.indexWhere(
        (r) => r.type == config.regimeType,
      );
      if (idx >= 0) {
        setState(() {
          _selectedRegimeIndex = idx;
          _selectedDays = config.daysPerWeek > 0
              ? config.daysPerWeek
              : regimeDefs[idx].defaultDays;
        });
      }

      // Load stored 1RMs / weights
      for (final ex in exerciseDefs) {
        final stored = config.oneRepMaxes[ex.exerciseInt];
        if (stored != null && stored > 0) {
          _weightControllers[ex.exerciseInt]?.text =
              stored.toStringAsFixed(0);
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in _weightControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  RegimeDef get _currentRegime => regimeDefs[_selectedRegimeIndex];

  Future<void> _save() async {
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

      // Preserve existing regime_state_json if regime hasn't changed
      final existing = context.read<SettingsProvider>().workoutConfig;
      final sameRegime = existing?.regimeType == _currentRegime.type;
      final stateJson =
          sameRegime ? (existing?.regimeStateJson ?? '{}') : '{}';

      final config = UserWorkoutConfig(
        regimeType: _currentRegime.type,
        daysPerWeek: _selectedDays,
        oneRepMaxes: oneRepMaxes.entries
            .map((e) => MapEntry(e.key, e.value.toDouble())),
        regimeStateJson: stateJson,
      );

      await context.read<SettingsProvider>().updateWorkoutConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training program saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWendler =
        _currentRegime.type == RegimeType.REGIME_TYPE_WENDLER_531;
    final exercisesToShow = isWendler
        ? exerciseDefs.where((e) => e.isWendlerMain).toList()
        : exerciseDefs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Program'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // Program picker
          Text(
            'PROGRAM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(regimeDefs.length, (idx) {
            final regime = regimeDefs[idx];
            final selected = _selectedRegimeIndex == idx;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RegimeTile(
                regime: regime,
                isSelected: selected,
                onTap: () {
                  setState(() {
                    _selectedRegimeIndex = idx;
                    _selectedDays = regime.defaultDays;
                  });
                },
                onInfo: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RegimeInfoScreen(regimeType: regime.type),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Days per week
          if (_currentRegime.daysOptions.length > 1) ...[
            Text(
              'DAYS PER WEEK',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _currentRegime.daysOptions.map((d) {
                final sel = d == _selectedDays;
                return ChoiceChip(
                  label: Text('$d days'),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    _selectedDays = d;
                  }),
                  selectedColor: cs.primary,
                  checkmarkColor: cs.onPrimary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sel ? cs.onPrimary : cs.onSurface,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Weight / 1RM inputs
          Text(
            isWendler ? '1-REP MAXES' : 'STARTING WEIGHTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isWendler
                ? 'Your Training Max = 90% of 1RM. Used for all percentage calculations.'
                : 'The starting weight for each exercise.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          ...exercisesToShow.map((ex) {
            final controller = _weightControllers[ex.exerciseInt]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _WeightRow(
                label: ex.name,
                controller: controller,
                isWendler: isWendler,
                onChanged: () => setState(() {}),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Regime tile ─────────────────────────────────────────────────────────────

class _RegimeTile extends StatelessWidget {
  final RegimeDef regime;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  const _RegimeTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: 2,
                ),
                color: isSelected ? cs.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 10, color: cs.onPrimary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    regime.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  Text(
                    regime.tagline,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? cs.primary.withValues(alpha: 0.7)
                          : cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onInfo,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.info_outline_rounded,
                    size: 18, color: cs.primary.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Weight row ───────────────────────────────────────────────────────────────

class _WeightRow extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool isWendler;
  final VoidCallback onChanged;

  const _WeightRow({
    required this.label,
    required this.controller,
    required this.isWendler,
    required this.onChanged,
  });

  @override
  State<_WeightRow> createState() => _WeightRowState();
}

class _WeightRowState extends State<_WeightRow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {});
      widget.onChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final val = double.tryParse(widget.controller.text);
    final tmText = widget.isWendler && val != null && val > 0
        ? 'TM: ${(val * 0.9).round()} lbs'
        : null;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              if (tmText != null)
                Text(tmText,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    )),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: widget.controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            decoration: InputDecoration(
              suffixText: 'lbs',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
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
        ),
      ],
    );
  }
}
