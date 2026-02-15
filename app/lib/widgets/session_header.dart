import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/auth_provider.dart';
import 'participant_ticker.dart';
import 'multiplayer_modal.dart';

class SessionHeader extends StatelessWidget {
  const SessionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: mp.isInSession
                  ? OutlinedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => const MultiplayerModal(),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group, size: 16, color: colorScheme.onSurface),
                          const SizedBox(width: 4),
                          Icon(Icons.add, size: 14, color: colorScheme.onSurface),
                        ],
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => const MultiplayerModal(),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('START GROUP SESSION'),
                    ),
            ),

            if (mp.isInSession) ...[
              ...mp.participants
                  .where((p) => p.user.id != auth.userId)
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ParticipantTicker(participant: p),
                      )),

              if (mp.participants.where((p) => p.user.id != auth.userId).isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Waiting for others...',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.tertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
