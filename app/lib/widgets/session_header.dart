import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/auth_provider.dart';
import 'participant_ticker.dart';

class SessionHeader extends StatelessWidget {
  const SessionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.watch<AuthProvider>();

    if (!mp.isInSession) return const SizedBox.shrink();

    final others = mp.participants.where((p) => p.user.id != auth.userId).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Session',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => mp.leaveSession(),
                child: const Text('Leave', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (others.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: others.map((p) => ParticipantTicker(participant: p)).toList(),
            ),
        ],
      ),
    );
  }
}
