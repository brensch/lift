import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/group.pb.dart';
import '../providers/multiplayer_provider.dart';
import '../theme/theme_spec.dart';

/// A prompt shown at the top of the app when a training partner asks to train
/// together. The recipient approves or declines; approving pairs them into a
/// session. Sits above the page content so it can't be missed.
class JoinRequestBanner extends StatelessWidget {
  final JoinRequest request;

  const JoinRequestBanner({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = request.fromUser.name.isNotEmpty
        ? request.fromUser.name
        : copy.joinRequest.someone;
    final mp = context.read<MultiplayerProvider>();

    // A panel with an orange rule under it, so the orange Accept button
    // stands out from it.
    return Material(
      color: t.panel,
      shape: Border(bottom: BorderSide(color: t.primary, width: 2)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Text(
                copy.joinRequest.icon,
                style: TextStyle(fontSize: t.size.title),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  copy.joinRequest.wants.replaceAll('{name}', name),
                  style: TextStyle(
                    color: t.text,
                    fontWeight: t.weight.bold,
                    fontSize: t.size.body,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    mp.respondToJoinRequest(request.requestId, false),
                child: Text(
                  copy.joinRequest.decline,
                  style: TextStyle(color: t.text),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () =>
                    mp.respondToJoinRequest(request.requestId, true),
                child: Text(copy.joinRequest.accept),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
