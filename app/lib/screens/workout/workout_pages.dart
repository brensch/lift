/// The live workout's two side pages, opened from the boxes over the status
/// box and left with back: the log of sets done (from the clock) and heart
/// rate (from the heart). Pages of the shell like the menu's, so the status
/// box stays under them.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/common/flat.dart';
import '../../widgets/heart_rate/heart_rate_chart.dart';
import '../../widgets/set_log.dart';
import 'workout_panels.dart';

/// Push the workout page at [path] over the workout, unless it is already
/// the page on show (the boxes that open them are under every page). The
/// tutorial's sandbox is outside the router: there [page] is pushed as it is.
void _open(BuildContext context, String path, Widget page) {
  final String current;
  try {
    current = GoRouterState.of(context).uri.path;
  } on GoError {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return;
  }
  if (current != path) context.push(path);
}

/// The log of sets done: the status box stays under it.
void openWorkoutLog(BuildContext context) =>
    _open(context, '/workout/log', const WorkoutLogPage());

/// Heart rate: the status box stays under it.
void openWorkoutHeart(BuildContext context) =>
    _open(context, '/workout/heart', const WorkoutHeartPage());

/// Every set done this workout, yours and your session partners', newest
/// first; yours can be deleted while the workout is open.
class WorkoutLogPage extends StatelessWidget {
  const WorkoutLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.watch<AuthProvider>();
    final workout = wp.workout;

    final proposed = <ProposedSet>[...wp.proposedSets];
    final completed = <CompletedSet>[...wp.completedSets];
    final ownerEmojis = <String, String>{
      if (workout != null)
        workout.id: normalizedProfileEmoji(auth.profileEmoji),
    };
    if (mp.isInSession) {
      for (final participant in mp.participants) {
        proposed.addAll(participant.proposedSets);
        completed.addAll(participant.completedSets);
        if (participant.activeWorkoutId.isNotEmpty) {
          ownerEmojis[participant.activeWorkoutId] = normalizedProfileEmoji(
            participant.user.profileEmoji,
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: PageTitle(copy.workoutPage.tabLog)),
      body: SafeArea(
        top: false,
        child: SetLog(
          proposedSets: proposed,
          completedSets: completed,
          // The workout gone (ended from the watch while this was open):
          // nothing left to delete from.
          onDelete: workout == null || wp.isWorkoutEnded
              ? null
              : (id) => wp.deleteCompletedSet(id),
          deletableWorkoutId: workout?.id,
          workoutOwnerEmojis: ownerEmojis,
          stickyHeader: true,
        ),
      ),
    );
  }
}

/// Heart rate over the workout, or how to get one when nothing sends it.
class WorkoutHeartPage extends StatelessWidget {
  const WorkoutHeartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final workout = wp.workout;
    return Scaffold(
      appBar: AppBar(title: PageTitle(copy.workoutPage.tabHeart)),
      body: SafeArea(
        top: false,
        child: workout == null || wp.wearHeartRateSamples.isEmpty
            ? const NoHeartRateMonitor()
            : ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                children: [
                  // The figures' grid edge to edge, the rest in margins.
                  HeartRateChart(
                    heartRateSamples: wp.wearHeartRateSamples,
                    completedSets: wp.completedSets,
                    workoutStartTime: workout.startTime,
                    now: wp.now,
                    stateSnapshot: wp.stateSnapshot,
                    inset: 16,
                  ),
                ],
              ),
      ),
    );
  }
}
