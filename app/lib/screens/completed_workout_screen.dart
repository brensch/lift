import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_group_widget.dart';
import '../widgets/set_log.dart';

class CompletedWorkoutScreen extends StatefulWidget {
  final String workoutId;
  final bool isHistory;

  const CompletedWorkoutScreen({
    super.key, 
    required this.workoutId,
    this.isHistory = false,
  });

  @override
  State<CompletedWorkoutScreen> createState() => _CompletedWorkoutScreenState();
}

class _CompletedWorkoutScreenState extends State<CompletedWorkoutScreen> {
  late int _currentPage;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // If it's history, we go straight to stats. If just finished, show celebration.
    _currentPage = widget.isHistory ? 1 : 0;
    _pageController = PageController(initialPage: _currentPage);
    
    final wp = context.read<WorkoutProvider>();
    wp.loadWorkout(widget.workoutId, asHistory: widget.isHistory);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();

    if (wp.workout == null || wp.workout!.id != widget.workoutId) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(widget.isHistory ? Icons.history : Icons.close),
          onPressed: () {
            if (widget.isHistory) {
              wp.stopViewingHistory();
            } else {
              if (wp.workout?.id == widget.workoutId && !wp.hasActiveWorkout) {
                wp.clear();
              }
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          _currentPage == 0 ? 'CELEBRATION' : 'SUMMARY',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          if (!widget.isHistory)
            IconButton(
              icon: Icon(_currentPage == 0 ? Icons.bar_chart : Icons.celebration),
              onPressed: () {
                _pageController.animateToPage(
                  _currentPage == 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: widget.isHistory ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: [
          _CelebrationView(
            wp: wp, 
            onViewSummary: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
          ),
          _StatsView(wp: wp),
        ],
      ),
    );
  }
}

class _CelebrationView extends StatelessWidget {
  final WorkoutProvider wp;
  final VoidCallback onViewSummary;

  const _CelebrationView({required this.wp, required this.onViewSummary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = wp.workout!.endTime != Int64.ZERO
        ? Duration(seconds: (wp.workout!.endTime - wp.workout!.startTime).toInt())
        : Duration.zero;

    final completedWorking = wp.completedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .where((c) {
          final proposed = wp.proposedSets.cast<ProposedSet?>().firstWhere(
            (p) => p!.id == c.proposedSetId,
            orElse: () => null,
          );
          return proposed != null && !proposed.warmup;
        })
        .length;

    final totalVolume = wp.completedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .fold(0.0, (sum, c) => sum + (c.actualReps * c.actualWeight));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.stars, color: AppTheme.successFg, size: 80),
        const SizedBox(height: 16),
        const Text(
          'WORKOUT COMPLETE',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You crushed it!',
          style: TextStyle(color: colorScheme.tertiary, fontSize: 18),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatMetric(
              label: 'DURATION',
              value: _formatDuration(duration),
              icon: Icons.timer_outlined,
            ),
            _StatMetric(
              label: 'SETS',
              value: '$completedWorking',
              icon: Icons.fitness_center,
            ),
            _StatMetric(
              label: 'VOLUME',
              value: '${totalVolume.toInt()} lb',
              icon: Icons.line_weight,
            ),
          ],
        ),
        const SizedBox(height: 48),
        FilledButton.icon(
          onPressed: onViewSummary,
          icon: const Icon(Icons.bar_chart),
          label: const Text('VIEW SUMMARY'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sharing coming soon!')),
            );
          },
          icon: const Icon(Icons.share),
          label: const Text('SHARE WORKOUT'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _StatMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colorScheme.tertiary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _StatsView extends StatelessWidget {
  final WorkoutProvider wp;

  const _StatsView({required this.wp});

  @override
  Widget build(BuildContext context) {
    final groups = wp.exerciseGroups;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...groups.map((group) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ExerciseGroupWidget(
                group: group,
                completedSets: wp.completedSets,
                isWorkoutEnded: true,
              ),
            )),
        const SizedBox(height: 16),
        SetLog(
          proposedSets: wp.proposedSets,
          completedSets: wp.completedSets,
        ),
      ],
    );
  }
}
