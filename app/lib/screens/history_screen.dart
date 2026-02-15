import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../services/grpc_client.dart';
import '../services/workout_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Workout>? _workouts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final grpc = context.read<GrpcClient>();
    final service = WorkoutServiceWrapper(grpc);

    try {
      final workouts = await service.listWorkouts();
      setState(() {
        _workouts = workouts.where((w) => w.endTime != Int64.ZERO).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HISTORY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: _workouts == null || _workouts!.isEmpty
          ? Center(
              child: Text(
                'No completed workouts yet',
                style: TextStyle(color: colorScheme.tertiary),
              ),
            )
          : ListView.separated(
              itemCount: _workouts!.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: colorScheme.outline,
              ),
              itemBuilder: (context, index) {
                final workout = _workouts![index];
                final date = DateTime.fromMillisecondsSinceEpoch(
                  workout.startTime.toInt() * 1000,
                );
                final duration = Duration(
                  seconds: (workout.endTime - workout.startTime).toInt(),
                );

                return ListTile(
                  title: Text(
                    '${date.month}/${date.day}/${date.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _formatDuration(duration),
                    style: TextStyle(color: colorScheme.tertiary, fontSize: 13),
                  ),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.tertiary),
                  onTap: () {
                    context.go('/workout/${workout.id}/completed');
                  },
                );
              },
            ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
