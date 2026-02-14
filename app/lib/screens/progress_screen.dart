import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbenum.dart';
import '../logic/exercises.dart';
import '../logic/exercise_groups.dart';
import '../services/grpc_client.dart';
import '../services/workout_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Map<Exercise, List<_WeightPoint>>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final grpc = context.read<GrpcClient>();
    final service = WorkoutServiceWrapper(grpc);

    try {
      final workouts = await service.listWorkouts();
      final data = <Exercise, List<_WeightPoint>>{};

      for (final workout in workouts) {
        if (workout.endTime == Int64.ZERO) continue;

        final response = await service.getWorkout(workout.id);
        final groups = groupSetsByExercise(response.proposedSets);

        for (final group in groups) {
          final workingSets = group.sets.where((s) => !s.warmup).toList();
          if (workingSets.isEmpty) continue;

          final weight = workingSets.first.targetWeight.toDouble();
          final date = DateTime.fromMillisecondsSinceEpoch(
            workout.startTime.toInt() * 1000,
          );

          data.putIfAbsent(group.exercise, () => []);
          data[group.exercise]!.add(_WeightPoint(date, weight));
        }
      }

      // Sort by date
      for (final list in data.values) {
        list.sort((a, b) => a.date.compareTo(b.date));
      }

      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_data == null || _data!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Progress')),
        body: const Center(child: Text('No workout history yet')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _data!.entries.map((entry) {
          final name = exerciseNames[entry.key] ?? '?';
          final points = entry.value;
          if (points.length < 2) {
            return Card(
              child: ListTile(
                title: Text(name),
                subtitle: Text('${points.first.weight.toInt()} lbs (1 session)'),
              ),
            );
          }

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                          ),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: points
                                .asMap()
                                .entries
                                .map((e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.weight,
                                    ))
                                .toList(),
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WeightPoint {
  final DateTime date;
  final double weight;
  _WeightPoint(this.date, this.weight);
}
