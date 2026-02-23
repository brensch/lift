import 'dart:async';
import 'dart:ui';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../widgets/exercise_group_widget.dart';
import '../widgets/participant_ticker.dart';
import '../widgets/set_log.dart';
import '../widgets/workout_modals.dart';
import '../services/wearable_bridge_service.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.read<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (wp.workout == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = wp.exerciseGroups;
    final activeSetId = wp.activeSetId;
    final isEnded = wp.isWorkoutEnded;
    final regimeContext = wp.regimeContext;

    final nextUpUserId = mp.sessionStatus?.nextUpUserId ?? '';
    final otherParticipants = mp.participants
        .where((p) => p.user.id != auth.userId)
        .toList();
    final sessionLedgerProposed = <ProposedSet>[];
    final sessionLedgerCompleted = <CompletedSet>[];
    final workoutOwnerLabels = <String, String>{};
    if (mp.isInSession && mp.sessionStatus != null) {
      for (final participant in mp.participants) {
        sessionLedgerProposed.addAll(participant.proposedSets);
        sessionLedgerCompleted.addAll(participant.completedSets);
        if (participant.activeWorkoutId.isNotEmpty) {
          final rawName = participant.user.id == auth.userId
              ? 'You'
              : (participant.user.name.isNotEmpty
                    ? participant.user.name
                    : participant.user.id);
          workoutOwnerLabels[participant.activeWorkoutId] = rawName;
        }
      }
    }
    final logProposedSets = sessionLedgerProposed.isNotEmpty
        ? sessionLedgerProposed
        : wp.proposedSets;
    final logCompletedSets = sessionLedgerCompleted.isNotEmpty
        ? sessionLedgerCompleted
        : wp.completedSets;

    final workout = wp.workout!;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEnded ? 'Workout Completed' : 'Workout In Progress',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                workout.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              if (regimeContext != null &&
                  regimeContext.sessionDescription.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  regimeContext.sessionDescription,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: colorScheme.tertiary,
                  ),
                ),
              ],
              if (regimeContext != null &&
                  regimeContext.coachingNotes.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...regimeContext.coachingNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '· ',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.tertiary.withValues(alpha: 0.7),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            note,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.tertiary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isEnded) const _WatchCompanionBanner(),

        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

        Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),

                child: Text(
                  'Exercises In Workout',

                  style: TextStyle(
                    fontSize: 11,

                    fontWeight: FontWeight.bold,

                    letterSpacing: 1.5,

                    color: colorScheme.tertiary,
                  ),
                ),
              ),

              if (groups.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: groups.length,
                  onReorder: (oldIndex, newIndex) {
                    if (isEnded) return;

                    final completedFlags = groups
                        .map((g) => _isGroupCompleted(g, wp.completedSets))
                        .toList();

                    // Don't allow dragging completed groups
                    if (completedFlags[oldIndex]) return;

                    // Can't jump over any completed group in either direction.
                    // newIndex here is the pre-adjustment Flutter value.
                    if (oldIndex > newIndex) {
                      // Moving up: check range [newIndex, oldIndex-1]
                      for (int i = newIndex; i < oldIndex; i++) {
                        if (completedFlags[i]) return;
                      }
                    } else {
                      // Moving down: check range [oldIndex+1, newIndex-1]
                      for (int i = oldIndex + 1; i < newIndex; i++) {
                        if (completedFlags[i]) return;
                      }
                    }

                    if (oldIndex < newIndex) newIndex -= 1;

                    HapticFeedback.mediumImpact();

                    final items = List<ExerciseGroupData>.from(
                      wp.exerciseGroups,
                    );
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);

                    final groupIds = items.map((g) => g.group!.id).toList();
                    wp.reorderExerciseGroups(groupIds);
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final animValue = Curves.easeInOut.transform(
                          animation.value,
                        );
                        final elevation = lerpDouble(0, 4, animValue)!;
                        return Material(
                          elevation: elevation,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, idx) {
                    final group = groups[idx];
                    final isCompleted = _isGroupCompleted(
                      group,
                      wp.completedSets,
                    );
                    final stableKey = group.sets.isNotEmpty
                        ? group.sets.first.id
                        : 'empty-$idx';

                    return Padding(
                      key: ValueKey('reorder-$stableKey'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Dismissible(
                        key: ValueKey('dismiss-$stableKey'),
                        direction: isEnded
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                        confirmDismiss: (_) => showDeleteGroupDialog(
                          context,
                          exerciseNames[group.exercise] ?? '?',
                        ),
                        onDismissed: (_) => _deleteGroup(context, wp, idx),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: colorScheme.error,
                          child: Icon(
                            Icons.delete_outline,
                            color: colorScheme.onError,
                            size: 20,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          clipBehavior: Clip.antiAlias,
                          child: ExerciseGroupWidget(
                            group: group,
                            completedSets: wp.completedSets,
                            activeSetId: activeSetId,
                            isWorkoutEnded: isEnded,
                            onEdit: () => _editGroup(context, wp, idx, group),
                            groupIndex: isCompleted ? null : idx,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              if (!isEnded) ...[
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,

                  height: 44,

                  child: OutlinedButton.icon(
                    onPressed: () => _showAddExercise(context, wp),

                    icon: const Icon(Icons.add, size: 18),

                    label: const Text(
                      'Add Exercise',

                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Participant cards (multiplayer)
        if (mp.isInSession && otherParticipants.isNotEmpty) ...[
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),

                  child: Text(
                    'SESSION MEMBERS',

                    style: TextStyle(
                      fontSize: 11,

                      fontWeight: FontWeight.bold,

                      letterSpacing: 1.5,

                      color: colorScheme.tertiary,
                    ),
                  ),
                ),

                ...otherParticipants.map((p) {
                  final isNextUp =
                      nextUpUserId.isNotEmpty && nextUpUserId == p.user.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),

                    child: ParticipantCard(
                      participant: p,
                      isNextUp: isNextUp,
                      onTap: () => showParticipantWorkoutModal(context, p),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

        Padding(
          padding: const EdgeInsets.all(16),

          child: SetLog(
            proposedSets: logProposedSets,
            completedSets: logCompletedSets,
            onDelete: isEnded ? null : (id) => wp.deleteCompletedSet(id),
            deletableWorkoutId: wp.workout?.id,
            workoutOwnerLabels: workoutOwnerLabels,
          ),
        ),

        if (!isEnded) ...[
          const SizedBox(height: 8),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),

            child: SizedBox(
              width: double.infinity,

              height: 44,

              child: OutlinedButton(
                onPressed: () => endWorkout(context),

                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,

                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),

                child: const Text(
                  'End Workout',

                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static bool _isGroupCompleted(
    ExerciseGroupData group,
    List<CompletedSet> completedSets,
  ) {
    final workingSets = group.sets.where((s) => !s.warmup).toList();
    if (workingSets.isEmpty) return false;
    final completedCount = workingSets
        .where(
          (s) => completedSets.any(
            (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO,
          ),
        )
        .length;
    return completedCount == workingSets.length;
  }

  void _deleteGroup(BuildContext context, WorkoutProvider wp, int index) {
    wp.deleteExerciseGroup(index);
  }

  void _editGroup(
    BuildContext context,
    WorkoutProvider wp,
    int index,
    ExerciseGroupData group,
  ) {
    showEditExerciseDialog(
      context,
      group: group,
      groupIndex: index,
      exerciseStatuses: wp.exerciseStatuses,
      isSetDone: wp.isSetDone,
      onSave:
          (
            groupIndex, {
            required int sets,
            required bool interleaveWarmups,
            required List<ExerciseTypeConfig> exerciseConfigs,
            RestConfig? restConfig,
          }) {
            wp.updateGroup(
              groupIndex,
              sets: sets,
              interleaveWarmups: interleaveWarmups,
              exerciseConfigs: exerciseConfigs,
              restConfig: restConfig,
            );
          },
    );
  }

  void _showAddExercise(BuildContext context, WorkoutProvider wp) {
    showAddExerciseDialog(
      context,
      exerciseStatuses: wp.exerciseStatuses,
      onAdd: (name, sets, interleaveWarmups, exerciseConfigs, restConfig) {
        final finalName = name.isNotEmpty
            ? name
            : exerciseConfigs
                  .map(
                    (c) =>
                        exerciseNames[Exercise.valueOf(c.exercise.value)] ??
                        '?',
                  )
                  .join(' / ');

        wp.addExerciseGroup(
          name: finalName,
          sets: sets,
          interleaveWarmups: interleaveWarmups,
          exerciseConfigs: exerciseConfigs,
          restConfig: restConfig,
        );
      },
    );
  }
}

class _WatchCompanionBanner extends StatefulWidget {
  const _WatchCompanionBanner();

  @override
  State<_WatchCompanionBanner> createState() => _WatchCompanionBannerState();
}

class _WatchCompanionBannerState extends State<_WatchCompanionBanner> {
  Timer? _pollTimer;
  bool _watchAppAvailable = false;
  bool _watchAppOpenOnWatch = false;
  bool _isVisible = false;
  bool _dismissed = false;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    _refreshAvailability();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshAvailability(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAvailability() async {
    final bridge = context.read<WearableBridgeService>();
    final available = await bridge.isWatchAppAvailable();
    final isOpenOnWatch = await bridge.isWatchAppOpenOnWatch();
    if (!mounted) return;
    setState(() {
      if (_watchAppAvailable != available ||
          _watchAppOpenOnWatch != isOpenOnWatch) {
        _dismissed = false;
      }
      _watchAppAvailable = available;
      _watchAppOpenOnWatch = isOpenOnWatch;
      _isVisible = !_dismissed && !_watchAppOpenOnWatch;
    });
  }

  Future<void> _launchWatchApp() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    final bridge = context.read<WearableBridgeService>();
    final opened = await bridge.openWatchApp();
    if (!mounted) return;
    setState(() => _isLaunching = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened ? 'Sent open request to watch' : 'No connected watch found',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pinkBg = Color(0xFFFFE1EC);
    const pinkBorder = Color(0xFFF06292);
    const pinkText = Color(0xFF8E244D);
    final bannerText = _watchAppAvailable
        ? 'launch app on phone to track heartrate and control workout'
        : 'do you know we have a watch companion app to track heartrate and control the workout?';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: !_isVisible
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('watch-banner'),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: pinkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pinkBorder),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Icon(Icons.watch, size: 20, color: pinkText)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Center(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            bannerText,
                            style: const TextStyle(
                              color: pinkText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_watchAppAvailable) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: double.infinity,
                        child: FilledButton(
                          onPressed: _isLaunching ? null : _launchWatchApp,
                          style: FilledButton.styleFrom(
                            backgroundColor: pinkBorder,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: _isLaunching
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Launch Watch',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                    Center(
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        tooltip: 'Dismiss',
                        onPressed: () {
                          setState(() {
                            _dismissed = true;
                            _isVisible = false;
                          });
                        },
                        icon: Icon(Icons.close, size: 16, color: pinkText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
