import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/group.pb.dart';

class GroupNextUpData {
  final ParticipantStatus participant;
  final int restUntil;
  final ProposedSet? nextSet;
  final bool isMe;

  GroupNextUpData({
    required this.participant,
    required this.restUntil,
    this.nextSet,
    required this.isMe,
  });
}

class _GroupNextUpCandidate {
  final ParticipantStatus participant;
  final ProposedSet nextSet;
  final int restUntil;
  final bool isResting;
  final int score;
  final bool isMe;

  _GroupNextUpCandidate({
    required this.participant,
    required this.nextSet,
    required this.restUntil,
    required this.isResting,
    required this.score,
    required this.isMe,
  });
}

GroupNextUpData? computeGroupNextUp(
  SessionStatus? status,
  String? myUserId,
  int nowUnix,
) {
  if (status == null) return null;

  final candidates = <_GroupNextUpCandidate>[];

  for (final p in status.participants) {
    final hasActive = p.completedSets.any((c) => c.endedAt == Int64.ZERO);
    if (hasActive) continue;

    bool isPDone(String setId) =>
        p.completedSets.any((c) => c.proposedSetId == setId && c.endedAt != Int64.ZERO);
    final sortedProposed = List<ProposedSet>.from(p.proposedSets)..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    final pNext = sortedProposed.cast<ProposedSet?>().firstWhere(
      (s) => !isPDone(s!.id),
      orElse: () => null,
    );
    if (pNext == null) continue;

    final restingSets = p.completedSets
        .where((c) => c.endedAt != Int64.ZERO && c.restUntil != Int64.ZERO)
        .toList();
    restingSets.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final restUntil = restingSets.isNotEmpty ? restingSets.first.restUntil.toInt() : 0;

    final isResting = restUntil > nowUnix;
    final score = isResting ? (restUntil - nowUnix) : (nowUnix - restUntil);

    candidates.add(_GroupNextUpCandidate(
      participant: p,
      nextSet: pNext,
      restUntil: restUntil,
      isResting: isResting,
      score: score,
      isMe: p.user.id == myUserId,
    ));
  }

  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    if (!a.isResting && b.isResting) return -1;
    if (a.isResting && !b.isResting) return 1;
    if (!a.isResting && !b.isResting) return b.score.compareTo(a.score);
    return a.score.compareTo(b.score);
  });

  final top = candidates.first;
  return GroupNextUpData(
    participant: top.participant,
    restUntil: top.restUntil,
    nextSet: top.nextSet,
    isMe: top.isMe,
  );
}
