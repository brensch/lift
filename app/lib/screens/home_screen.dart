import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../services/grpc_client.dart';
import '../services/workout_service.dart';
import '../logic/utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ExerciseStatus>? _schedule;
  List<ProposedExerciseGroup>? _proposedGroups;
  Set<int> _selectedGroupIndices = {};
  // Non-recommended sections start collapsed.
  final Set<String> _expandedSections = {};
  bool _isLoading = true;
  bool _isStarting = false;
  String? _error;
  late final TextEditingController _nameController = TextEditingController(
    text: _getDefaultWorkoutName(),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getDefaultWorkoutName() {
    return greetingTime().toUpperCase();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final grpc = context.read<GrpcClient>();
    final workoutService = WorkoutServiceWrapper(grpc);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final scheduleRes = await workoutService.getProposedWorkoutSchedule(
        auth.userId!,
      );

      if (!mounted) return;

      final schedule = scheduleRes.exerciseStatuses;
      final proposedGroups = scheduleRes.proposedGroups;

      // Auto-select all groups tagged "recommended".
      final autoSelected = <int>{};
      for (int i = 0; i < proposedGroups.length; i++) {
        if (proposedGroups[i].tags.contains('recommended')) {
          autoSelected.add(i);
        }
      }

      setState(() {
        _schedule = schedule;
        _proposedGroups = proposedGroups;
        _selectedGroupIndices = autoSelected;
        _nameController.text = _getDefaultWorkoutName();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = cleanErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startWorkout() async {
    if (_selectedGroupIndices.isEmpty || _proposedGroups == null) return;

    setState(() => _isStarting = true);

    try {
      final exerciseGroups = <ExerciseGroup>[];
      int groupOrder = 0;

      final statusMap = <int, ExerciseStatus>{};
      if (_schedule != null) {
        for (final s in _schedule!) {
          statusMap[s.exercise.value] = s;
        }
      }

      for (final idx in _selectedGroupIndices.toList()..sort()) {
        final proposed = _proposedGroups![idx];
        final groupId = _uuid.v4();

        final configs = proposed.exerciseConfigs.map((c) {
          final status = statusMap[c.exercise.value];
          final weight = status?.targetWeight ?? c.startWeight;
          final cfg = ExerciseTypeConfig()
            ..exercise = c.exercise
            ..startWeight = weight
            ..endWeight = weight
            ..reps = c.reps
            ..includeWarmup = c.includeWarmup;
          if (c.hasRestConfig()) {
            cfg.restConfig = RestConfig()..mergeFromMessage(c.restConfig);
          }
          return cfg;
        }).toList();

        final group = ExerciseGroup()
          ..id = groupId
          ..name = proposed.name
          ..sets = proposed.sets
          ..interleaveWarmups = proposed.interleaveWarmups
          ..workoutOrder = groupOrder++
          ..exerciseConfigs.addAll(configs);
        if (proposed.hasRestConfig()) {
          group.restConfig = RestConfig()..mergeFromMessage(proposed.restConfig);
        }
        exerciseGroups.add(group);
      }

      final now = DateTime.now();
      final dateStr =
          "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";

      final summaryNames = (_selectedGroupIndices.toList()..sort())
          .map((idx) => _proposedGroups![idx].name)
          .join(' / ');

      final baseName = _nameController.text.trim().isEmpty
          ? _getDefaultWorkoutName()
          : _nameController.text.trim().toUpperCase();

      final workoutName = "$dateStr - $summaryNames - $baseName".toUpperCase();

      final workoutProvider = context.read<WorkoutProvider>();
      final workoutId = await workoutProvider.startWorkout(
        workoutName,
        exerciseGroups,
      );

      if (workoutId != null && mounted) {
        final mp = context.read<MultiplayerProvider>();
        if (mp.isInSession) {
          await mp.updateActiveWorkout(workoutId);
        }
      }
    } catch (e) {
      debugPrint('Error starting workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start workout: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _toggleGroup(int index) {
    setState(() {
      if (_selectedGroupIndices.contains(index)) {
        _selectedGroupIndices.remove(index);
      } else {
        _selectedGroupIndices.add(index);
      }
    });
  }

  void _toggleSection(String tag) {
    setState(() {
      if (_expandedSections.contains(tag)) {
        _expandedSections.remove(tag);
      } else {
        _expandedSections.add(tag);
      }
    });
  }

  /// Ordered map of tag → group indices. "recommended" always first.
  Map<String, List<int>> _buildTagSections() {
    final groups = _proposedGroups;
    if (groups == null) return {};

    final Map<String, List<int>> sections = {};
    const recommendedTag = 'recommended';

    for (int i = 0; i < groups.length; i++) {
      if (groups[i].tags.contains(recommendedTag)) {
        sections.putIfAbsent(recommendedTag, () => []).add(i);
      }
    }
    for (int i = 0; i < groups.length; i++) {
      for (final tag in groups[i].tags) {
        if (tag != recommendedTag) {
          sections.putIfAbsent(tag, () => []).add(i);
        }
      }
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final userName = context.read<AuthProvider>().username ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final tagSections = _buildTagSections();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'SELECT YOUR EXERCISE GROUPS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                for (final entry in tagSections.entries) ...[
                  _SectionHeader(
                    tag: entry.key,
                    isRecommended: entry.key == 'recommended',
                    isExpanded: entry.key == 'recommended' ||
                        _expandedSections.contains(entry.key),
                    onTap: entry.key == 'recommended'
                        ? null
                        : () => _toggleSection(entry.key),
                  ),
                  if (entry.key == 'recommended' ||
                      _expandedSections.contains(entry.key))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _GroupGrid(
                        indices: entry.value,
                        proposedGroups: _proposedGroups!,
                        selectedIndices: _selectedGroupIndices,
                        onToggle: _toggleGroup,
                      ),
                    ),
                ],
              ]),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            left: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
            right: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.5)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GOOD ${greetingTime().toUpperCase()} ${userName.split(' ').first.toUpperCase()}.',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'WORKOUT NAME (OPTIONAL)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: _getDefaultWorkoutName(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed:
                    _selectedGroupIndices.isEmpty || _isStarting
                        ? null
                        : _startWorkout,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isStarting
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        'START WORKOUT (${_selectedGroupIndices.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String greetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String tag;
  final bool isRecommended;
  final bool isExpanded;
  final VoidCallback? onTap;

  const _SectionHeader({
    required this.tag,
    required this.isRecommended,
    required this.isExpanded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget header = Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Text(
            tag.toUpperCase(),
            style: TextStyle(
              fontSize: isRecommended ? 13 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: isRecommended
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: colorScheme.outline.withValues(alpha: 0.3),
              height: 1,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 10),
            AnimatedRotation(
              turns: isExpanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: header);
    }
    return header;
  }
}

// ─── 3-column grid of group chips ────────────────────────────────────────────

class _GroupGrid extends StatelessWidget {
  final List<int> indices;
  final List<ProposedExerciseGroup> proposedGroups;
  final Set<int> selectedIndices;
  final void Function(int) onToggle;

  const _GroupGrid({
    required this.indices,
    required this.proposedGroups,
    required this.selectedIndices,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const columns = 3;
    const gap = 8.0;
    final rows = <Widget>[];

    for (int i = 0; i < indices.length; i += columns) {
      final rowIndices = indices.sublist(i, min(i + columns, indices.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: gap),
                Expanded(
                  child: j < rowIndices.length
                      ? _GroupChip(
                          group: proposedGroups[rowIndices[j]],
                          isSelected: selectedIndices.contains(rowIndices[j]),
                          onTap: () => onToggle(rowIndices[j]),
                        )
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + columns < indices.length) {
        rows.add(const SizedBox(height: gap));
      }
    }

    return Column(children: rows);
  }
}

// ─── Group chip ───────────────────────────────────────────────────────────────

class _GroupChip extends StatelessWidget {
  final ProposedExerciseGroup group;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupChip({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    group.name.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: -0.3,
                      height: 1.25,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${group.sets}×${group.exerciseConfigs.first.reps}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.7)
                    : colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
