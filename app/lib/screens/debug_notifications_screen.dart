import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../services/notification_service.dart';

class DebugNotificationsScreen extends StatefulWidget {
  const DebugNotificationsScreen({super.key});

  @override
  State<DebugNotificationsScreen> createState() =>
      _DebugNotificationsScreenState();
}

class _DebugNotificationsScreenState extends State<DebugNotificationsScreen> {
  List<PendingNotificationRequest> _pending = [];
  List<ActiveNotification> _active = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _loadData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final pending = await NotificationService.getPendingNotifications();
    final active = await NotificationService.getActiveNotifications();
    if (mounted) {
      setState(() {
        _pending = pending;
        _active = active;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: Notifications'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Bottom Bar State', [
            _row('state', () {
              final activeSetId = wp.activeSetId;
              final isResting = wp.restingSet != null;
              final lastRestEnd = wp.lastRestEndTimestamp ?? 0;
              final nextSet = wp.nextPendingSet;
              final allDone =
                  wp.activeProposedSets.isNotEmpty &&
                  wp.activeProposedSets.every((p) => wp.isSetDone(p.id)) &&
                  activeSetId == null;
              if (allDone) return 'All done';
              if (activeSetId != null) return 'Lifting';
              if (isResting) return 'Resting (${wp.restSecondsRemaining}s)';
              if (!isResting &&
                  activeSetId == null &&
                  lastRestEnd > 0 &&
                  lastRestEnd <= nowUnix &&
                  nextSet != null) {
                return 'Yapping (+${nowUnix - lastRestEnd}s)';
              }
              if (nextSet != null) return 'Next up';
              return 'Idle';
            }()),
            _row('wasResting', '${wp.debugWasResting}'),
            _row(
              'lastSoundedRestUntil',
              '${wp.debugLastSoundedRestUntil ?? "null"}',
            ),
            _row('restSecondsRemaining', '${wp.restSecondsRemaining}'),
            _row('now (unix)', '$nowUnix'),
          ], colorScheme),
          const SizedBox(height: 16),
          _section('Pending OS Notifications (${_pending.length})', [
            if (_pending.isEmpty) ...[
              _row('', 'None'),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'NOTE: "None" here means no future notifications are scheduled. '
                  'If a notification fires now, it was likely already in the OS '
                  'delivery pipeline or was just moved from "Pending" to "Active".',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ] else
              for (final n in _pending)
                _row('id=${n.id}', () {
                  final scheduledUnix = int.tryParse(n.payload ?? '');
                  if (scheduledUnix != null) {
                    final diff = scheduledUnix - nowUnix;
                    final timeStr = diff > 0
                        ? '${diff}s from now'
                        : '${-diff}s ago';
                    return '${n.title} — fires $timeStr (unix=$scheduledUnix)';
                  }
                  return '${n.title}: ${n.body}';
                }()),
          ], colorScheme),
          const SizedBox(height: 16),
          _section('Active (Delivered) Notifications (${_active.length})', [
            if (_active.isEmpty)
              _row('', 'None')
            else
              for (final n in _active)
                _row('id=${n.id}', '${n.title}: ${n.body}'),
          ], colorScheme),
          const SizedBox(height: 16),
          _section('Completed Sets (${wp.completedSets.length})', [
            for (final c in wp.completedSets.reversed) ...[
              _row(
                'set ${c.proposedSetId.substring(0, 8)}...',
                'restUntil=${c.restUntil.toInt()} '
                    '(${c.restUntil.toInt() > nowUnix ? "${c.restUntil.toInt() - nowUnix}s left" : "expired"}) '
                    'ended=${c.endedAt.toInt() > 0 ? "yes" : "no"}',
              ),
            ],
          ], colorScheme),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<Widget> children,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
