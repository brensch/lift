import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pbenum.dart';
import '../gen/workout/v1/wearable.pb.dart';
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final hr60s = wp.wearHeartRateSamples
        .where((s) => s.sampledAt.toInt() >= nowMs - 60000)
        .toList()
      ..sort((a, b) => b.sampledAt.compareTo(a.sampledAt));
    final bpmValues = hr60s.map((s) => s.bpm).toList();
    final latest = hr60s.isNotEmpty ? hr60s.first : null;
    final minBpm = bpmValues.isEmpty
        ? null
        : bpmValues.reduce((a, b) => a < b ? a : b);
    final maxBpm = bpmValues.isEmpty
        ? null
        : bpmValues.reduce((a, b) => a > b ? a : b);
    final avgBpm = bpmValues.isEmpty
        ? null
        : bpmValues.reduce((a, b) => a + b) / bpmValues.length;

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
              final snapshot = wp.stateSnapshot;
              final state = snapshot?.state;
              final nextSet = wp.nextPendingSet;
              if (state == WorkoutState.WORKOUT_STATE_ALL_DONE) {
                return 'All done';
              }
              if (state == WorkoutState.WORKOUT_STATE_LIFTING) return 'Lifting';
              if (state == WorkoutState.WORKOUT_STATE_RESTING) {
                final restUntil = snapshot?.restUntil.toInt() ?? 0;
                if (restUntil > 0 && restUntil < nowUnix && nextSet != null) {
                  return 'Yapping (+${nowUnix - restUntil}s)';
                }
                return 'Resting (${wp.restSecondsRemaining}s)';
              }
              final lastRestEnd = snapshot?.lastRestEnd.toInt() ?? 0;
              if ((state == WorkoutState.WORKOUT_STATE_READY ||
                      nextSet != null) &&
                  nextSet != null &&
                  lastRestEnd > 0 &&
                  lastRestEnd <= nowUnix) {
                return 'Yapping (+${nowUnix - lastRestEnd}s)';
              }
              if (state == WorkoutState.WORKOUT_STATE_READY ||
                  nextSet != null) {
                return 'Next up';
              }
              return 'Idle';
            }()),
            _row('restSecondsRemaining', '${wp.restSecondsRemaining}'),
            _row('now (unix)', '$nowUnix'),
          ], colorScheme),
          const SizedBox(height: 16),
          _section('Wear Heart Rate (Last 60s)', [
            _row('sampleCount', '${hr60s.length}'),
            _row('latestBpm', latest != null ? latest.bpm.toStringAsFixed(1) : 'n/a'),
            _row('minBpm', minBpm != null ? minBpm.toStringAsFixed(1) : 'n/a'),
            _row('maxBpm', maxBpm != null ? maxBpm.toStringAsFixed(1) : 'n/a'),
            _row('avgBpm', avgBpm != null ? avgBpm.toStringAsFixed(1) : 'n/a'),
            const Divider(height: 1),
            _hrTable(hr60s, nowMs),
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

  Widget _hrTable(List<HeartRateSample> samples, int nowMs) {
    if (samples.isEmpty) {
      return _row('', 'No samples in the last 60s');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 520),
        child: Column(
          children: [
            _tableHeader(),
            const Divider(height: 1),
            for (final s in samples.take(120))
              _tableRow(
                time: _fmtTime(DateTime.fromMillisecondsSinceEpoch(s.sampledAt.toInt())),
                ageSec:
                    ((nowMs - s.sampledAt.toInt()) / 1000).clamp(0, 9999).toStringAsFixed(1),
                bpm: s.bpm.toStringAsFixed(1),
                availability: s.availability.value.toString(),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Widget _tableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: const [
          SizedBox(
            width: 90,
            child: Text(
              'Time',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              'Age(s)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              'BPM',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              'Avail',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow({
    required String time,
    required String ageSec,
    required String bpm,
    required String availability,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(time, style: const TextStyle(fontSize: 12))),
          SizedBox(width: 70, child: Text(ageSec, style: const TextStyle(fontSize: 12))),
          SizedBox(width: 70, child: Text(bpm, style: const TextStyle(fontSize: 12))),
          SizedBox(width: 100, child: Text(availability, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
