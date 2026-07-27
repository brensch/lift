import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/group.pb.dart';
import '../providers/multiplayer_provider.dart';

/// A prompt shown at the top of the app when a training partner asks to train
/// together. The recipient approves or declines; approving pairs them into a
/// session. Sits above the page content so it can't be missed.
class JoinRequestBanner extends StatelessWidget {
  final JoinRequest request;

  const JoinRequestBanner({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = request.fromUser.name.isNotEmpty ? request.fromUser.name : 'A friend';
    final mp = context.read<MultiplayerProvider>();

    return Material(
      color: cs.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              const Text('🏋️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$name wants to train with you',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    mp.respondToJoinRequest(request.requestId, false),
                child: Text('Decline',
                    style: TextStyle(color: cs.onPrimaryContainer)),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () =>
                    mp.respondToJoinRequest(request.requestId, true),
                child: const Text('Accept'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
