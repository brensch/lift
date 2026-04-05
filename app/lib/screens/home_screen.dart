import 'dart:async';
import 'dart:math';

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
  List<ExerciseStatus>? _schedule;
  List<ProposedExerciseGroup>? _proposedGroups;
  RegimeContext? _regimeContext;
  SessionReadiness? _sessionReadiness;
  List<PendingStateUpdate> _pendingUpdates = [];
  bool _canStartWorkout = true;
  Set<int> _selectedGroupIndices = {};
  // Non-recommended sections start collapsed.
  final Set<String> _expandedSections = {};
  bool _isLoading = true;
  bool _isRefreshing = false;
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
    return greetingTime();
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
        _selectedGroupIndices = autoSelected;
        _nameController.text = suggestedName ?? _getDefaultWorkoutName();
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
          // Keep regime's weight ramp (e.g. Wendler 65%→85% TM).
          // For Linear/GZCLP start==end so endWeight = startWeight.
          final endWeight = c.endWeight != c.startWeight
              ? c.endWeight
              : startWeight;
          final cfg = ExerciseTypeConfig()
            ..exercise = c.exercise
            ..startWeight = startWeight
            ..endWeight = endWeight
            ..reps = c.reps
            ..includeWarmup = c.includeWarmup
            ..lastSetAmrap = c.lastSetAmrap; // carry AMRAP flag from regime
          cfg.workingSets.addAll(
            c.workingSets.map(
              (ws) => WorkingSetSpec()
                ..targetWeight = ws.targetWeight
                ..targetReps = ws.targetReps
                ..isAmrap = ws.isAmrap
                ..instruction = ws.instruction,
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
          ..instruction = proposed.explanation; // carry regime coaching text
        if (proposed.hasRestConfig()) {
          group.restConfig = RestConfig()
            ..mergeFromMessage(proposed.restConfig);
        }
        exerciseGroups.add(group);
      }

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
        final wearableBridge = context.read<WearableBridgeService>();
        unawaited(_attemptAutoLaunchWatchApp(wearableBridge));
        final mp = context.read<MultiplayerProvider>();
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  for (final entry in tagSections.entries) ...[
                    _SectionHeader(
                      tag: entry.key,
                      isRecommended: entry.key == 'recommended',
                      isExpanded:
                          entry.key == 'recommended' ||
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
                          columns: entry.key == 'recommended' ? 1 : 3,
                        ),
                      ),
                  ],
                ]),
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
            // Greeting + selected count badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Good ${greetingTime()}, ${userName.split(' ').first}.',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _selectedGroupIndices.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          key: const ValueKey('badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedGroupIndices.length} Groups',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                ),
              ],
            ),

            // Selected groups — wrapping pills
            if (_selectedGroupIndices.isNotEmpty &&
                _proposedGroups != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final idx in (_selectedGroupIndices.toList()..sort()))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        _proposedGroups![idx].name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],

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

  String greetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ─── Readiness banner ─────────────────────────────────────────────────────────

class _ReadinessBanner extends StatelessWidget {
  final SessionReadiness? sessionReadiness;
  final RegimeContext? regimeContext;

  const _ReadinessBanner({this.sessionReadiness, this.regimeContext});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sr = sessionReadiness;

    Color bannerColor;
    Color textColor;
    IconData icon;
    String label;

    if (sr != null && sr.readinessLabel.isNotEmpty) {
      if (sr.isReady) {
        bannerColor = const Color(0xFF1B5E20).withValues(alpha: 0.15);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.fitness_center_rounded;
      } else if (sr.isOverdue) {
        bannerColor = cs.errorContainer;
        textColor = cs.onErrorContainer;
        icon = Icons.warning_amber_rounded;
      } else {
        bannerColor = cs.tertiaryContainer.withValues(alpha: 0.5);
        textColor = cs.onTertiaryContainer;
        icon = Icons.schedule_rounded;
      }
      label = sr.readinessLabel;
    } else {
      bannerColor = cs.primaryContainer.withValues(alpha: 0.4);
      textColor = cs.onPrimaryContainer;
      icon = Icons.fitness_center_rounded;
      label = '';
    }

    final rc = regimeContext;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rc != null && rc.regimeDisplayName.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.push('/settings/regime'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 13,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rc.regimeDisplayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          if (label.isNotEmpty) ...[
            if (rc != null && rc.regimeDisplayName.isNotEmpty)
              const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 17, color: textColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
          if (rc != null && rc.sessionDescription.isNotEmpty) ...[
            if (label.isNotEmpty)
              const SizedBox(height: 6)
            else
              const SizedBox(height: 2),
            Text(
              rc.sessionDescription,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
          if (sr != null && sr.readinessDetail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sr.readinessDetail,
              style: TextStyle(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );
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
            tag,
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
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: header,
      );
    }
    return header;
  }
}

// ─── Variable-column grid of group chips ───────────────────────────────────────────

class _GroupGrid extends StatelessWidget {
  final List<int> indices;
  final List<ProposedExerciseGroup> proposedGroups;
  final Set<int> selectedIndices;
  final void Function(int) onToggle;
  final int columns;

  const _GroupGrid({
    required this.indices,
    required this.proposedGroups,
    required this.selectedIndices,
    required this.onToggle,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasExplanation = group.explanation.isNotEmpty;

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
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
                if (hasExplanation) ...[
                  const SizedBox(height: 6),
                  Text(
                    group.explanation,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.8)
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _setPlanSummary(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.7)
                    : colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
