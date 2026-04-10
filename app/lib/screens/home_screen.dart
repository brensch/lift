import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../services/grpc_client.dart';
import '../services/wearable_bridge_service.dart';
import '../services/workout_service.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../logic/utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _draftSaveDebounce = Duration(milliseconds: 400);
  List<ExerciseStatus>? _schedule;
  List<ProposedExerciseGroup>? _proposedGroups;
  RegimeContext? _regimeContext;
  SessionReadiness? _sessionReadiness;
  List<PendingStateUpdate> _pendingUpdates = [];
  bool _canStartWorkout = true;
  Set<int> _selectedGroupIndices = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isStarting = false;
  String? _error;
  Timer? _draftSaveTimer;
  late final TextEditingController _nameController = TextEditingController(
    text: _getDefaultWorkoutName(),
  );

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_queueDraftSave);
    _loadData();
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  String _getDefaultWorkoutName() {
    return 'Workout';
  }

  Future<void> _loadData({bool refreshOnly = false}) async {
    final auth = context.read<AuthProvider>();
    final grpc = context.read<GrpcClient>();
    final workoutService = WorkoutServiceWrapper(grpc);

    setState(() {
      if (refreshOnly && !_isLoading) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
        _error = null;
      }
    });

    try {
      final scheduleRes = await workoutService.getProposedWorkoutSchedule(
        auth.userId!,
      );

      if (!mounted) return;

      final schedule = scheduleRes.exerciseStatuses;
      final proposedGroups = scheduleRes.proposedGroups;

      // Auto-select all groups tagged "recommended" on each load/refresh.
      final autoSelected = <int>{};
      for (int i = 0; i < proposedGroups.length; i++) {
        if (proposedGroups[i].tags.contains('recommended')) autoSelected.add(i);
      }

      final suggestedName = scheduleRes.suggestedWorkoutName.isNotEmpty
          ? scheduleRes.suggestedWorkoutName
          : null;
      final draft = scheduleRes.hasDraft() ? scheduleRes.draft : null;
      final selectedFromDraft = <int>{};
      if (draft != null && draft.exerciseGroups.isNotEmpty) {
        for (final group in draft.exerciseGroups) {
          final idx = proposedGroups.indexWhere((p) => p.name == group.name);
          if (idx != -1) selectedFromDraft.add(idx);
        }
      }

      setState(() {
        _schedule = schedule;
        _proposedGroups = proposedGroups;
        _regimeContext = scheduleRes.hasRegimeContext()
            ? scheduleRes.regimeContext
            : null;
        _sessionReadiness = scheduleRes.hasSessionReadiness()
            ? scheduleRes.sessionReadiness
            : null;
        _pendingUpdates = scheduleRes.pendingStateUpdates;
        _canStartWorkout = scheduleRes.canStartWorkout;
        _selectedGroupIndices = selectedFromDraft.isNotEmpty
            ? selectedFromDraft
            : autoSelected;
        _nameController.text = draft != null && draft.name.isNotEmpty
            ? draft.name
            : (suggestedName ?? _getDefaultWorkoutName());
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (isUnauthenticatedError(e)) {
        await auth.expireSession(
          message: 'Your saved session expired. Sign in again.',
        );
        return;
      }
      if (mounted) {
        setState(() {
          if (_isLoading) {
            _error = cleanErrorMessage(e);
          }
          _isLoading = false;
          _isRefreshing = false;
        });
        if (refreshOnly && (_schedule != null || _proposedGroups != null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Refresh failed: ${cleanErrorMessage(e)}')),
          );
        }
      }
    }
  }

  Future<void> _startWorkout() async {
    if (_selectedGroupIndices.isEmpty || _proposedGroups == null) return;

    setState(() => _isStarting = true);

    try {
      final exerciseGroups = _buildExerciseGroupsFromSelection();
      final grpc = context.read<GrpcClient>();
      final wearableBridge = context.read<WearableBridgeService>();
      final mp = context.read<MultiplayerProvider>();

      final now = DateTime.now();
      final dateStr =
          "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";

      final baseName = _nameController.text.trim().isEmpty
          ? _getDefaultWorkoutName()
          : _nameController.text.trim();

      final workoutName = "$dateStr - $baseName";

      final workoutProvider = context.read<WorkoutProvider>();
      final workoutId = await workoutProvider.startWorkout(
        workoutName,
        exerciseGroups,
      );

      if (workoutId != null && mounted) {
        await WorkoutServiceWrapper(grpc).clearWorkoutDraft();
        unawaited(_attemptAutoLaunchWatchApp(wearableBridge));
        if (mp.isInSession) {
          await mp.updateActiveWorkout(workoutId);
        }
      }
    } catch (e) {
      debugPrint('Error starting workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start workout: $e')));
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _attemptAutoLaunchWatchApp(WearableBridgeService bridge) async {
    try {
      await bridge.openWatchApp();
    } catch (e) {
      debugPrint('Auto watch launch failed: $e');
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
    _queueDraftSave();
  }

  List<ExerciseGroup> _buildExerciseGroupsFromSelection() {
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
        final startWeight = status?.targetWeight ?? c.startWeight;
        final endWeight = c.endWeight != c.startWeight
            ? c.endWeight
            : startWeight;
        final cfg = ExerciseTypeConfig()
          ..exercise = c.exercise
          ..startWeight = startWeight
          ..endWeight = endWeight
          ..reps = c.reps
          ..includeWarmup = c.includeWarmup
          ..lastSetAmrap = c.lastSetAmrap;
        cfg.workingSets.addAll(
          c.workingSets.map(
            (ws) => WorkingSetSpec()
              ..targetWeight = ws.targetWeight
              ..targetReps = ws.targetReps
              ..isAmrap = ws.isAmrap
              ..instruction = ws.instruction
              ..progressionHint = ws.progressionHint.deepCopy(),
          ),
        );
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
        ..prescribedByRegime = proposed.prescribedByRegime
        ..exerciseConfigs.addAll(configs)
        ..instruction = proposed.explanation;
      if (proposed.hasRestConfig()) {
        group.restConfig = RestConfig()..mergeFromMessage(proposed.restConfig);
      }
      exerciseGroups.add(group);
    }
    return exerciseGroups;
  }

  void _queueDraftSave() {
    if (!mounted) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDebounce, () {
      unawaited(_saveDraftToServer());
    });
  }

  Future<void> _saveDraftToServer() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId == null) return;
    final grpc = context.read<GrpcClient>();
    final workoutService = WorkoutServiceWrapper(grpc);
    try {
      final draft = WorkoutDraft()
        ..name = _nameController.text.trim()
        ..exerciseGroups.addAll(_buildExerciseGroupsFromSelection())
        ..updatedAt = Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      await workoutService.saveWorkoutDraft(draft);
    } catch (e) {
      debugPrint('Failed to save workout draft: $e');
    }
  }

  List<int> _buildVisibleGroupIndices() {
    final groups = _proposedGroups;
    if (groups == null) return [];
    const recommendedTag = 'recommended';
    final recommended = <int>[];
    final rest = <int>[];
    for (int i = 0; i < groups.length; i++) {
      if (groups[i].tags.contains(recommendedTag)) {
        recommended.add(i);
      } else {
        rest.add(i);
      }
    }
    return [...recommended, ...rest];
  }

  int _estimatedWorkoutMinutes() {
    if (_proposedGroups == null || _selectedGroupIndices.isEmpty) return 0;

    const workingSetSeconds = 45;
    const warmupSetSeconds = 30;
    const setupSecondsPerExercise = 75;
    const transitionSecondsPerGroup = 90;
    const defaultWorkingRest = 180;
    const defaultWarmupRest = 45;

    int totalSeconds = 0;

    for (final idx in _selectedGroupIndices.toList()..sort()) {
      final group = _proposedGroups![idx];
      totalSeconds += transitionSecondsPerGroup;

      for (final cfg in group.exerciseConfigs) {
        totalSeconds += setupSecondsPerExercise;

        final workingSets = cfg.workingSets.isNotEmpty
            ? cfg.workingSets.length
            : (group.sets <= 0 ? 1 : group.sets);
        final warmupSets = cfg.includeWarmup ? 2 : 0;
        final restConfig = cfg.hasRestConfig()
            ? cfg.restConfig
            : (group.hasRestConfig() ? group.restConfig : null);
        final workingRest = restConfig?.restAfterSuccess ?? defaultWorkingRest;
        final warmupRest = restConfig?.restAfterWarmup ?? defaultWarmupRest;

        totalSeconds += workingSets * workingSetSeconds;
        totalSeconds += warmupSets * warmupSetSeconds;
        totalSeconds += (workingSets > 0 ? workingSets - 1 : 0) * workingRest;
        totalSeconds += warmupSets * warmupRest;
      }
    }

    return (totalSeconds / 60).ceil();
  }

  String _predictedWorkoutTimeLabel() {
    final minutes = _estimatedWorkoutMinutes();
    if (minutes <= 0) return '--';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return '${hours}h';
    return '${hours}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
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

    final visibleGroupIndices = _buildVisibleGroupIndices();

    final workoutPanelColor = colorScheme.brightness == Brightness.dark
        ? const Color(0xFF222222)
        : const Color(0xFFF0F0F0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _loadData(refreshOnly: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            if (_sessionReadiness != null || _regimeContext != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _ReadinessBanner(
                    sessionReadiness: _sessionReadiness,
                    regimeContext: _regimeContext,
                  ),
                ),
              ),
            if (_pendingUpdates.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final update in _pendingUpdates)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PendingUpdateCard(
                          update: update,
                          onResolved: () => _loadData(refreshOnly: true),
                        ),
                      ),
                  ]),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                (_sessionReadiness != null || _regimeContext != null) ? 12 : 20,
                20,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text(
                        'Select exercise groups',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: colorScheme.tertiary,
                        ),
                      ),
                      if (_isRefreshing) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _GroupGrid(
                    indices: visibleGroupIndices,
                    proposedGroups: _proposedGroups!,
                    selectedIndices: _selectedGroupIndices,
                    onToggle: _toggleGroup,
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: workoutPanelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: colorScheme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.10),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Predicted workout time:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _predictedWorkoutTimeLabel(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Workout name field
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Name This Workout (Optional)',
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withValues(alpha: 0.28),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 62,
              child: FilledButton(
                onPressed:
                    _selectedGroupIndices.isEmpty ||
                        _isStarting ||
                        !_canStartWorkout
                    ? null
                    : _startWorkout,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isStarting
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        'START WORKOUT',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
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
}

// ─── Readiness banner ─────────────────────────────────────────────────────────

class _ReadinessBanner extends StatelessWidget {
  final SessionReadiness? sessionReadiness;
  final RegimeContext? regimeContext;

  const _ReadinessBanner({this.sessionReadiness, this.regimeContext});

  @override
  Widget build(BuildContext context) {
    final sr = sessionReadiness;
    final rc = regimeContext;

    Color bannerColor;
    Color textColor;
    Color accentColor;
    IconData icon;
    String label;

    if (sr != null && sr.readinessLabel.isNotEmpty) {
      if (sr.isReady) {
        bannerColor = const Color(0xFF1F6F43);
        textColor = Colors.white;
        accentColor = const Color(0xFFDDF5E6);
        icon = Icons.fitness_center_rounded;
      } else if (sr.isOverdue) {
        bannerColor = const Color(0xFF8C2F1E);
        textColor = Colors.white;
        accentColor = const Color(0xFFFFE1D8);
        icon = Icons.warning_amber_rounded;
      } else {
        bannerColor = const Color(0xFF1E4F8C);
        textColor = Colors.white;
        accentColor = const Color(0xFFE0ECFF);
        icon = Icons.schedule_rounded;
      }
      label = sr.readinessLabel;
    } else {
      bannerColor = const Color(0xFF304255);
      textColor = Colors.white;
      accentColor = const Color(0xFFE4EDF7);
      icon = Icons.fitness_center_rounded;
      label = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rc != null && rc.regimeDisplayName.isNotEmpty) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        rc.regimeDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (label.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Training status',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: textColor,
                    ),
                  ),
                if (rc != null && rc.sessionDescription.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    rc.sessionDescription,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: textColor.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => context.go('/training-program'),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              foregroundColor: Colors.white,
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            tooltip: 'Training cycle details',
          ),
        ],
      ),
    );
  }
}

// ─── Variable-column grid of group chips ───────────────────────────────────────────

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
    return Column(
      children: [
        for (int i = 0; i < indices.length; i++) ...[
          _GroupChip(
            group: proposedGroups[indices[i]],
            isSelected: selectedIndices.contains(indices[i]),
            onTap: () => onToggle(indices[i]),
          ),
          if (i < indices.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
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

  List<WorkingSetSpec> _workingSetsForConfig(ExerciseTypeConfig cfg) {
    if (cfg.workingSets.isNotEmpty) return cfg.workingSets;
    final count = group.sets <= 0 ? 1 : group.sets;
    return List.generate(
      count,
      (i) => WorkingSetSpec()
        ..targetWeight = count <= 1
            ? cfg.startWeight
            : (cfg.startWeight +
                  (i / (count - 1)) * (cfg.endWeight - cfg.startWeight))
        ..targetReps = cfg.reps
        ..isAmrap = cfg.lastSetAmrap && i == count - 1,
    );
  }

  String _setPlanSummary() {
    if (group.exerciseConfigs.isEmpty) return 'Set plan';
    final allWorking = group.exerciseConfigs
        .expand(_workingSetsForConfig)
        .toList(growable: false);
    if (allWorking.isEmpty) return 'Set plan';

    final amrapCount = allWorking.where((s) => s.isAmrap).length;
    final warmupsIncluded = group.exerciseConfigs
        .where((c) => c.includeWarmup)
        .length;

    if (group.exerciseConfigs.length == 1) {
      final pattern = allWorking
          .map((s) => s.isAmrap ? '${s.targetReps}+' : '${s.targetReps}')
          .join(' / ');
      final uniqueWeights = allWorking
          .map((s) => s.targetWeight)
          .toSet()
          .length;
      final weightText = uniqueWeights > 1 ? 'ramped weights' : 'fixed weight';
      final warmupText = warmupsIncluded > 0 ? ' • warmups' : '';
      return '$pattern • ${allWorking.length} working sets • $weightText$warmupText';
    }

    final repSet = allWorking.map((s) => s.targetReps).toSet().toList()..sort();
    final repText = repSet.length <= 3
        ? repSet.join('/')
        : '${repSet.first}-${repSet.last} reps';
    final amrapText = amrapCount > 0 ? ' • $amrapCount AMRAP' : '';
    final warmupText = warmupsIncluded > 0 ? ' • $warmupsIncluded warmups' : '';
    return '${group.exerciseConfigs.length} exercises • ${allWorking.length} working sets • $repText reps$amrapText$warmupText';
  }

  String _formatSetLine(WorkingSetSpec set, WeightUnit unit) {
    final reps = set.isAmrap ? '${set.targetReps}+' : '${set.targetReps}';
    return '${formatWeight(set.targetWeight.toDouble(), unit, includeUnit: true)} x $reps';
  }

  double? _maxWorkingWeight() {
    double? maxWeight;
    for (final cfg in group.exerciseConfigs) {
      for (final set in _workingSetsForConfig(cfg)) {
        final weight = set.targetWeight.toDouble();
        if (maxWeight == null || weight > maxWeight) {
          maxWeight = weight;
        }
      }
    }
    return maxWeight;
  }

  int _workingSetCount() => group.exerciseConfigs
      .map(_workingSetsForConfig)
      .fold(0, (total, sets) => total + sets.length);

  int _exerciseCount() => group.exerciseConfigs.length;

  bool get _isRecommended => group.tags.contains('recommended');

  Widget _chip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
  }

  Widget _recommendedIcon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        size: 14,
        color: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    final unit = context.read<SettingsProvider>().weightUnit;
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              if (group.explanation.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  group.explanation,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _setPlanSummary(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 18),
              for (final cfg in group.exerciseConfigs)
                _ExerciseConfigDetailsCard(
                  title: exerciseNames[cfg.exercise] ?? 'Exercise',
                  setLines: [
                    for (int i = 0; i < _workingSetsForConfig(cfg).length; i++)
                      (
                        index: i + 1,
                        text: _formatSetLine(
                          _workingSetsForConfig(cfg)[i],
                          unit,
                        ),
                        note: _workingSetsForConfig(cfg)[i].instruction,
                      ),
                  ],
                  meta: [
                    if (cfg.includeWarmup) 'Warmups included',
                    if (cfg.hasRestConfig())
                      'Rest ${cfg.restConfig.restAfterSuccess}s',
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final maxWeight = _maxWorkingWeight();
    final weightLabel = maxWeight == null
        ? 'No weight'
        : formatWeight(maxWeight, unit, includeUnit: true);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 0),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.45),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isRecommended) ...[
                    _recommendedIcon(context),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        height: 1.0,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    weightLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.9)
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chip(context, '${_workingSetCount()} sets'),
                      if (_exerciseCount() > 1) ...[
                        const SizedBox(width: 6),
                        _chip(context, '${_exerciseCount()} ex'),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _showDetails(context),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _SetLine = ({int index, String text, String note});

class _ExerciseConfigDetailsCard extends StatelessWidget {
  final String title;
  final List<_SetLine> setLines;
  final List<String> meta;

  const _ExerciseConfigDetailsCard({
    required this.title,
    required this.setLines,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final set in setLines) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${set.index}.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      set.text,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (set.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 6),
                child: Text(
                  set.note,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in meta)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Pending update card ──────────────────────────────────────────────────────

class _PendingUpdateCard extends StatelessWidget {
  final PendingStateUpdate update;
  final VoidCallback onResolved;

  const _PendingUpdateCard({required this.update, required this.onResolved});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: cs.onErrorContainer,
                  ),
                ),
                if (update.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    update.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onErrorContainer.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _showResolveDialog(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Resolve',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResolveDialog(BuildContext context) async {
    final controllers = <String, TextEditingController>{};
    for (final f in update.fields) {
      final defaultText = _defaultText(f);
      controllers[f.key] = TextEditingController(text: defaultText);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _PendingUpdateDialog(update: update, controllers: controllers),
    );

    for (final c in controllers.values) {
      c.dispose();
    }

    if (confirmed != true || !context.mounted) return;

    final settingsProvider = context.read<SettingsProvider>();
    final fieldValues = <String, StateFieldValue>{};
    for (final f in update.fields) {
      final text = controllers[f.key]?.text.trim() ?? '';
      // Convert PendingStateUpdateField to StateFieldKind for value building
      final schema = TrainingProgramStateFieldSchema(key: f.key, kind: f.kind);
      final val = SettingsProvider.fieldValueFromText(
        schema,
        text,
        unit: settingsProvider.weightUnit,
      );
      if (val != null) fieldValues[f.key] = val;
    }

    try {
      await settingsProvider.applyPendingStateUpdate(
        updateId: update.updateId,
        fieldValues: fieldValues,
      );
      onResolved();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply update: $e')));
      }
    }
  }

  String _defaultText(PendingStateUpdateField f) {
    switch (f.defaultValue.whichValue()) {
      case StateFieldValue_Value.floatVal:
        return f.defaultValue.floatVal.toStringAsFixed(0);
      case StateFieldValue_Value.intVal:
        return f.defaultValue.intVal.toString();
      case StateFieldValue_Value.boolVal:
        return f.defaultValue.boolVal ? 'true' : 'false';
      case StateFieldValue_Value.stringVal:
        return f.defaultValue.stringVal;
      default:
        return '';
    }
  }
}

class _PendingUpdateDialog extends StatefulWidget {
  final PendingStateUpdate update;
  final Map<String, TextEditingController> controllers;

  const _PendingUpdateDialog({required this.update, required this.controllers});

  @override
  State<_PendingUpdateDialog> createState() => _PendingUpdateDialogState();
}

class _PendingUpdateDialogState extends State<_PendingUpdateDialog> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        widget.update.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.update.message.isNotEmpty) ...[
              Text(
                widget.update.message,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final f in widget.update.fields)
              _buildFieldInput(context, f, cs),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildFieldInput(
    BuildContext context,
    PendingStateUpdateField f,
    ColorScheme cs,
  ) {
    final controller = widget.controllers[f.key]!;
    if (f.kind == StateFieldKind.STATE_FIELD_KIND_ENUM &&
        f.enumOptions.isNotEmpty) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: f.enumOptions.map((opt) {
                    return ChoiceChip(
                      label: Text(opt.label.isNotEmpty ? opt.label : opt.value),
                      selected: opt.value == controller.text,
                      onSelected: (_) =>
                          setState(() => controller.text = opt.value),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      );
    }

    final isNumeric =
        f.kind == StateFieldKind.STATE_FIELD_KIND_FLOAT ||
        f.kind == StateFieldKind.STATE_FIELD_KIND_INT;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final isWeightField =
        '${f.label} ${f.key}'.toLowerCase().contains('weight') ||
        '${f.label} ${f.key}'.toLowerCase().contains('max');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(f.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              suffixText: isWeightField ? weightUnitSuffixPlural(unit) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: cs.outline.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
