/// Recovery- and frequency-aware home hero. Answers "should I train today?" from
/// a per-muscle recovery model rather than a flat clock: a state tag, the named
/// next session, a "why", the muscle recovery strip, a learned-cadence line, and
/// a one-tap A/B session swap.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../widgets/phase_explanation.dart';

// Fixed accent palette (the hero is a dark card in both themes, like the mockup).
const _green = Color(0xFF3AD98B);
const _amber = Color(0xFFF5B544);
const _blue = Color(0xFF6EA8FF);

class _StateStyle {
  final Color accent;
  final List<Color> gradient;
  final IconData icon;
  final String tag;
  const _StateStyle(this.accent, this.gradient, this.icon, this.tag);
}

class ReadinessBanner extends StatelessWidget {
  final TrainingStatus? trainingStatus;
  final RegimeContext? regimeContext;
  final List<NextSessionOption> selectableNextSessions;
  final bool isSwapping;
  final ValueChanged<String>? onSwapSession;

  const ReadinessBanner({
    super.key,
    this.trainingStatus,
    this.regimeContext,
    this.selectableNextSessions = const [],
    this.isSwapping = false,
    this.onSwapSession,
  });

  _StateStyle _styleFor(ReadinessState state) {
    switch (state) {
      case ReadinessState.READINESS_STATE_RECOVERING:
        return const _StateStyle(
          _blue,
          [Color(0xFF1A2A3E), Color(0xFF111418)],
          Icons.hourglass_bottom_rounded,
          'Rest day',
        );
      case ReadinessState.READINESS_STATE_OVERDUE:
        return const _StateStyle(
          _amber,
          [Color(0xFF1C150A), Color(0xFF141014)],
          Icons.notifications_active_rounded,
          'Been a while',
        );
      case ReadinessState.READINESS_STATE_AHEAD:
        return const _StateStyle(
          _green,
          [Color(0xFF123726), Color(0xFF0C2419)],
          Icons.auto_awesome_rounded,
          'Bonus',
        );
      case ReadinessState.READINESS_STATE_FIRST_TIME:
        return const _StateStyle(
          _green,
          [Color(0xFF123726), Color(0xFF0C2419)],
          Icons.rocket_launch_rounded,
          'Ready',
        );
      case ReadinessState.READINESS_STATE_READY:
      default:
        return const _StateStyle(
          _green,
          [Color(0xFF123726), Color(0xFF0C2419)],
          Icons.fitness_center_rounded,
          'Train today',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = trainingStatus;
    final rc = regimeContext;

    // Fallback for a status with no readiness (older server / no program).
    final state = ts?.readinessState ?? ReadinessState.READINESS_STATE_UNSPECIFIED;
    final style = _styleFor(state);
    const textColor = Color(0xFFF4F4F3);
    final mutedColor = Colors.white.withValues(alpha: 0.60);

    final headline = (ts != null && ts.headline.isNotEmpty)
        ? ts.headline
        : 'Training status';
    final why = ts == null ? '' : _whyLine(ts, state);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: style.gradient,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: style.accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State tag + program chip on one row.
          Row(
            children: [
              _StateTag(style: style),
              const Spacer(),
              if (rc != null && rc.regimeDisplayName.isNotEmpty)
                ProgramChip(
                  label: rc.regimeDisplayName,
                  textColor: textColor,
                  accentColor: style.accent,
                  onTap: () => context.go('/training-program'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            headline,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.05,
              color: textColor,
            ),
          ),
          if (why.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              why,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: mutedColor,
              ),
            ),
          ],

          // Compact cycle-phase line: where you are + what changed last time.
          if (rc != null) ...[
            const SizedBox(height: 12),
            PhaseExplanation(
              context: rc,
              compact: true,
              textColor: textColor,
              mutedColor: mutedColor,
              accentColor: style.accent,
            ),
          ],

          // Muscle recovery strip — the heart of the redesign.
          if (ts != null && ts.muscleRecovery.isNotEmpty) ...[
            const SizedBox(height: 16),
            _StripLabel('Recovery', color: mutedColor),
            const SizedBox(height: 8),
            _RecoveryStrip(muscles: _stripMuscles(ts)),
          ],

          // A/B (or session) swap chooser.
          if (selectableNextSessions.length >= 2 && onSwapSession != null) ...[
            const SizedBox(height: 16),
            _StripLabel('Up next', color: mutedColor),
            const SizedBox(height: 8),
            _SessionSwap(
              options: selectableNextSessions,
              accent: style.accent,
              isSwapping: isSwapping,
              onSwap: onSwapSession!,
            ),
          ],

          // Cadence line.
          if (ts != null) ...[
            const SizedBox(height: 14),
            _CadenceLine(ts: ts, accent: style.accent, muted: mutedColor),
          ],
        ],
      ),
    );
  }

  List<MuscleRecoveryStatus> _stripMuscles(TrainingStatus ts) {
    // Prefer the muscles the next session actually trains; fall back to all.
    final inNext = ts.muscleRecovery.where((m) => m.inNextWorkout).toList();
    final list = inNext.isNotEmpty ? inNext : ts.muscleRecovery.toList();
    // Recovering ones first (they carry the "wait" information), then by label.
    list.sort((a, b) {
      final ar = a.recovered ? 1 : 0;
      final br = b.recovered ? 1 : 0;
      if (ar != br) return ar - br;
      return a.label.compareTo(b.label);
    });
    return list;
  }

  String _whyLine(TrainingStatus ts, ReadinessState state) {
    switch (state) {
      case ReadinessState.READINESS_STATE_RECOVERING:
        final blocking = ts.blockingMuscles;
        // The muscle with the most hours left drives the wait.
        int maxHours = 0;
        for (final m in ts.muscleRecovery) {
          if (m.inNextWorkout && !m.recovered) {
            final h = m.hoursRemaining.toInt();
            if (h > maxHours) maxHours = h;
          }
        }
        final who = blocking.isEmpty
            ? 'those muscles'
            : (blocking.length == 1
                  ? blocking.first.toLowerCase()
                  : '${blocking.take(blocking.length - 1).map((m) => m.toLowerCase()).join(', ')} and ${blocking.last.toLowerCase()}');
        if (maxHours > 0) {
          return 'Your $who want about ${_hoursLabel(maxHours)} before the next session hits them well.';
        }
        return 'Your $who are still recovering.';
      case ReadinessState.READINESS_STATE_OVERDUE:
        return 'Everything\'s recovered — no need to restart, just pick up where you left off.';
      case ReadinessState.READINESS_STATE_AHEAD:
        return 'You\'ve hit this week\'s target — recovered and ready, so this one\'s a bonus.';
      case ReadinessState.READINESS_STATE_FIRST_TIME:
        return 'Nothing to recover from yet — jump in whenever you\'re ready.';
      case ReadinessState.READINESS_STATE_READY:
      default:
        final idle = _idleDaysLabel(ts.lastSessionAt.toInt());
        return idle.isEmpty
            ? 'Recovered and ready — a good day to go.'
            : 'Recovered and $idle since your last lift — a good day to go.';
    }
  }
}

String _hoursLabel(int hours) {
  if (hours >= 24) {
    final days = (hours / 24).round();
    return days <= 1 ? 'a day' : '$days days';
  }
  return '${hours}h';
}

String _idleDaysLabel(int lastSessionAt) {
  if (lastSessionAt <= 0) return '';
  final last = DateTime.fromMillisecondsSinceEpoch(lastSessionAt * 1000);
  final days = DateTime.now().difference(last).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return '1 day';
  return '$days days';
}

class _StateTag extends StatelessWidget {
  final _StateStyle style;
  const _StateTag({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: style.accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.accent),
          const SizedBox(width: 6),
          Text(
            style.tag.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: style.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _StripLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: color,
      ),
    );
  }
}

class _RecoveryStrip extends StatelessWidget {
  final List<MuscleRecoveryStatus> muscles;
  const _RecoveryStrip({required this.muscles});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in muscles) _MuscleChip(muscle: m),
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  final MuscleRecoveryStatus muscle;
  const _MuscleChip({required this.muscle});

  @override
  Widget build(BuildContext context) {
    final recovered = muscle.recovered;
    final accent = recovered ? _green : _amber;
    final hours = muscle.hoursRemaining.toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            muscle.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          if (!recovered && hours > 0) ...[
            const SizedBox(width: 5),
            Text(
              _hoursLabel(hours),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.45),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionSwap extends StatelessWidget {
  final List<NextSessionOption> options;
  final Color accent;
  final bool isSwapping;
  final ValueChanged<String> onSwap;

  const _SessionSwap({
    required this.options,
    required this.accent,
    required this.isSwapping,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final opt in options) ...[
          Expanded(
            child: _SwapPill(
              option: opt,
              accent: accent,
              disabled: isSwapping,
              onTap: opt.isCurrent ? null : () => onSwap(opt.key),
            ),
          ),
          if (opt != options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SwapPill extends StatelessWidget {
  final NextSessionOption option;
  final Color accent;
  final bool disabled;
  final VoidCallback? onTap;

  const _SwapPill({
    required this.option,
    required this.accent,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final current = option.isCurrent;
    // Prefer the short "Workout A" prefix; drop the "· lifts" tail if present.
    final short = option.label.split('·').first.trim();
    final lifts = option.label.contains('·')
        ? option.label.split('·').last.trim()
        : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: current
                ? accent.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: current
                  ? accent.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    short,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: current
                          ? accent
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const Spacer(),
                  if (current)
                    Icon(Icons.check_circle_rounded, size: 14, color: accent)
                  else
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                ],
              ),
              if (lifts.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  lifts,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CadenceLine extends StatelessWidget {
  final TrainingStatus ts;
  final Color accent;
  final Color muted;
  const _CadenceLine({required this.ts, required this.accent, required this.muted});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    final last = _idleDaysLabel(ts.lastSessionAt.toInt());
    if (last.isNotEmpty) {
      parts.add(last == 'today' ? 'Last: today' : 'Last: $last ago');
    }
    if (ts.avgGapHours > 0) {
      final perWeek = (168 / ts.avgGapHours);
      parts.add('~${perWeek.toStringAsFixed(perWeek >= 3 ? 0 : 1)}×/week');
    }
    if (ts.targetSessionsPer7Days > 0) {
      parts.add('${ts.completedSessionsPer7Days}/${ts.targetSessionsPer7Days} this week');
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    // Week dot indicator: filled for completed sessions this week.
    final target = ts.targetSessionsPer7Days > 0 ? ts.targetSessionsPer7Days : 3;
    final done = ts.completedSessionsPer7Days.clamp(0, target);

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < target; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i < done
                          ? accent
                          : Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
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

class ProgramChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color accentColor;
  final VoidCallback onTap;

  const ProgramChip({
    super.key,
    required this.label,
    required this.textColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, size: 12, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.arrow_outward_rounded, size: 12, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}
