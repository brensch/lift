import 'dart:async';
import '../widgets/common/flat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pbenum.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../providers/workout_provider.dart';
import '../services/notification_service.dart';
import '../services/wearable_bridge_service.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

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
  Timer? _watchClockTimer;
  WatchClockSync? _watchClockSync;

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _loadData());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWatchClockSync();
      _watchClockTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _refreshWatchClockSync(),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _watchClockTimer?.cancel();
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

  Future<void> _refreshWatchClockSync() async {
    if (!mounted) return;
    final bridge = context.read<WearableBridgeService>();
    final sync = await bridge.getWatchClockSync();
    if (!mounted) return;
    setState(() {
      _watchClockSync = sync;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    return ValueListenableBuilder<DateTime>(
      valueListenable: wp.clock,
      builder: (context, now, _) {
        final nowUnix = now.millisecondsSinceEpoch ~/ 1000;
        final nowMs = now.millisecondsSinceEpoch;
        final hr60s =
            wp.wearHeartRateSamples
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
            title: PageTitle('Debug'),
            actions: [
              IconButton(
                icon: const Icon(AppIcons.refresh),
                onPressed: _loadData,
              ),
            ],
          ),
          body: ListView(
            // A pixel on top: room for the first heading band's top line.
            padding: const EdgeInsets.only(top: 1, bottom: 24),
            children: [
              _section('Bottom bar', [
                _row('state', () {
                  final snapshot = wp.stateSnapshot;
                  final state = snapshot?.state;
                  final nextSet = wp.nextPendingSet;
                  if (state == WorkoutState.WORKOUT_STATE_ALL_DONE) {
                    return 'All done';
                  }
                  if (state == WorkoutState.WORKOUT_STATE_RESTING) {
                    return 'Resting (${wp.restSecondsRemaining}s)';
                  }
                  if (state == WorkoutState.WORKOUT_STATE_YAPPING) {
                    final since = snapshot!.restUntil.toInt();
                    return 'Yapping (+${nowUnix - since}s)';
                  }
                  if (state == WorkoutState.WORKOUT_STATE_READY ||
                      nextSet != null) {
                    return 'Ready';
                  }
                  return 'Idle';
                }()),
                _row('restSecondsRemaining', '${wp.restSecondsRemaining}'),
                _row('now (unix)', '$nowUnix'),
              ]),
              _section('Watch clock sync', [
                _row(
                  'delta',
                  _watchClockSync == null
                      ? 'unavailable'
                      : '${_watchClockSync!.deltaMs}ms',
                ),
                _row(
                  'rtt',
                  _watchClockSync == null
                      ? 'unavailable'
                      : '${_watchClockSync!.roundTripMs}ms',
                ),
                _row(
                  'watchTime',
                  _watchClockSync == null
                      ? 'unavailable'
                      : _fmtTime(
                          DateTime.fromMillisecondsSinceEpoch(
                            _watchClockSync!.watchTimeMs,
                          ),
                        ),
                ),
                _row(
                  'phoneMidpoint',
                  _watchClockSync == null
                      ? 'unavailable'
                      : _fmtTime(
                          DateTime.fromMillisecondsSinceEpoch(
                            _watchClockSync!.estimatedPhoneMidpointMs,
                          ),
                        ),
                ),
              ]),
              _section('Watch heart rate · last 60 s', [
                _row('sampleCount', '${hr60s.length}'),
                _row(
                  'latestBpm',
                  latest != null ? latest.bpm.toStringAsFixed(1) : 'n/a',
                ),
                _row(
                  'minBpm',
                  minBpm != null ? minBpm.toStringAsFixed(1) : 'n/a',
                ),
                _row(
                  'maxBpm',
                  maxBpm != null ? maxBpm.toStringAsFixed(1) : 'n/a',
                ),
                _row(
                  'avgBpm',
                  avgBpm != null ? avgBpm.toStringAsFixed(1) : 'n/a',
                ),
                _hrTable(hr60s, nowMs),
              ]),
              _section('Pending notifications · ${_pending.length}', [
                if (_pending.isEmpty) ...[
                  _row('', 'None'),
                  _note(
                    'NOTE: "None" here means no future notifications are scheduled. If a notification fires now, it was likely already in the OS delivery pipeline or was just moved from "Pending" to "Active".',
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
                        return '${n.title}: fires $timeStr (unix=$scheduledUnix)';
                      }
                      return '${n.title}: ${n.body}';
                    }()),
              ]),
              _section('Delivered notifications · ${_active.length}', [
                if (_active.isEmpty)
                  _row('', 'None')
                else
                  for (final n in _active)
                    _row('id=${n.id}', '${n.title}: ${n.body}'),
              ]),
              _section('Completed sets · ${wp.completedSets.length}', [
                for (final c in wp.completedSets.reversed) ...[
                  _row(
                    'set ${c.proposedSetId.substring(0, 8)}...',
                    'restUntil=${c.restUntil.toInt()} '
                        '(${c.restUntil.toInt() > nowUnix ? "${c.restUntil.toInt() - nowUnix}s left" : "expired"}) '
                        'ended=${c.endedAt.toInt() > 0 ? "yes" : "no"}',
                  ),
                ],
              ]),
            ],
          ),
        );
      },
    );
  }

  /// A section: its heading band, then its rows.
  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [FlatHeading(title), ...children],
  );

  /// One fact as a full-width row: what, and its value, in the mono face.
  Widget _row(String label, String value) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: TextStyle(fontSize: t.size.body, color: t.muted),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(
              value,
              textAlign: label.isEmpty ? TextAlign.start : TextAlign.end,
              style: t.mono(
                TextStyle(
                  fontSize: t.size.body,
                  fontWeight: t.weight.bold,
                  color: t.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A muted aside under a section's rows.
  Widget _note(String text) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: t.size.small, color: t.muted),
      ),
    );
  }

  Widget _hrTable(List<HeartRateSample> samples, int nowMs) {
    if (samples.isEmpty) {
      return _row('', 'No samples in the last 60 s');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tableRow(
          time: 'Time',
          ageSec: 'Age s',
          bpm: 'BPM',
          availability: 'Avail',
          heading: true,
        ),
        for (final s in samples.take(120))
          _tableRow(
            time: _fmtTime(
              DateTime.fromMillisecondsSinceEpoch(s.sampledAt.toInt()),
            ),
            ageSec: ((nowMs - s.sampledAt.toInt()) / 1000)
                .clamp(0, 9999)
                .toStringAsFixed(1),
            bpm: s.bpm.toStringAsFixed(1),
            availability: s.availability.value.toString(),
          ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  /// A sample as a full-width row of four columns; [heading], their names.
  Widget _tableRow({
    required String time,
    required String ageSec,
    required String bpm,
    required String availability,
    bool heading = false,
  }) {
    final t = context.tokens;
    final style = t.mono(
      TextStyle(
        fontSize: t.size.small,
        fontWeight: heading ? t.weight.bold : t.weight.regular,
        color: heading ? t.muted : t.text,
      ),
    );
    Widget cell(String text, int flex) => Expanded(
      flex: flex,
      child: Text(text, style: style),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          cell(time, 3),
          cell(ageSec, 2),
          cell(bpm, 2),
          cell(availability, 2),
        ],
      ),
    );
  }
}
