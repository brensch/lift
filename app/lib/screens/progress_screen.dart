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
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_data == null || _data!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'PROGRESS',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ),
        body: Center(
          child: Text(
            'No workout history yet',
            style: TextStyle(color: colorScheme.tertiary),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PROGRESS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _data!.entries.map((entry) {
          final name = exerciseNames[entry.key] ?? '?';
          final points = entry.value;
          if (points.length < 2) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${points.first.weight.toInt()} lbs',
                    style: TextStyle(color: colorScheme.tertiary),
                  ),
                ],
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                          color: colorScheme.onSurface,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                              radius: 3,
                              color: colorScheme.onSurface,
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: colorScheme.onSurface.withValues(alpha: 0.05),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
