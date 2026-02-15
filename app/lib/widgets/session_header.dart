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
    
    // Web parity: Always visible.
    // If not in session -> "Start Group Session" button
    // If in session -> Participants list + "Add" button + "Leave" logic (handled in modal or ticker?)
    
    // The web app has a horizontal scrollable area.
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Only show background if in session or always? Web doesn't seem to have a heavy background unless active?
      // Web uses: "w-full space-y-2" and inside a flex container.
      // Let's keep it clean.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Main Action Button (Start or Add)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => const MultiplayerModal(),
                  );
                },
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: mp.isInSession 
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group, size: 16),
                        SizedBox(width: 4),
                        Icon(Icons.add, size: 14),
                      ],
                    )
                  : const Text('START GROUP SESSION'),
              ),
            ),

            // Participants
            if (mp.isInSession) ...[
              // We should show "Session" label or ID? Web shows tickers.
              // Let's show other participants.
              ...mp.participants
                  .where((p) => p.user.id != auth.userId)
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ParticipantTicker(participant: p),
                      )),
              
              // If no other participants yet
              if (mp.participants.where((p) => p.user.id != auth.userId).isEmpty)
                 Padding(
                   padding: const EdgeInsets.only(left: 4),
                   child: Text(
                     'Waiting for others...',
                     style: TextStyle(
                       fontSize: 12, 
                       color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
