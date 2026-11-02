import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../services/account_sync.dart';
import '../services/error_modal_service.dart';
import '../services/grpc_client.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';
import '../widgets/top_level_back_scope.dart';
import '../theme/app_icons.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final unitLabel = settings.weightUnit == WeightUnit.WEIGHT_UNIT_KG
        ? 'Kilograms (🌍)'
        : 'Pounds (🦅)';
    final bodyWeightLabel = auth.bodyWeightKg > 0
        ? settings.weightUnit == WeightUnit.WEIGHT_UNIT_KG
              ? '${auth.bodyWeightKg.toStringAsFixed(1)} kg'
              : '${(auth.bodyWeightKg * 2.20462).toStringAsFixed(1)} lb'
        : 'Not set';
    return TopLevelBackScope(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            onPressed: () => context.go('/'),
          ),
          title: PageTitle('Settings'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const FlatHeading('You'),
            FlatRow(
              icon: AppIcons.bodyWeight,
              label: 'Body weight',
              subtitle: bodyWeightLabel,
              trailing: IconButton(
                icon: const Icon(AppIcons.refresh),
                tooltip: 'Sync from health data',
                onPressed: () => _syncBodyWeightFromHealth(context, auth),
              ),
              onTap: () => _showBodyWeightPicker(context, auth, settings),
            ),
            FlatRow(
              icon: AppIcons.weightUnit,
              label: 'Weight unit',
              subtitle: unitLabel,
              onTap: () => _showWeightUnitPicker(context, settings),
            ),
            FlatRow(
              icon: AppIcons.palette,
              label: 'Plate colours',
              subtitle: 'Assign colours to plate weights',
              onTap: () => context.push('/settings/plate-colors'),
            ),
            const FlatHeading('Account'),
            FlatRow(
              icon: AppIcons.cloud,
              label: 'Sync',
              subtitle: _syncLabel(context.watch<AccountSync>()),
            ),
            FlatRow(
              icon: AppIcons.download,
              label: 'Export your data',
              subtitle: 'Everything, as one SQLite file',
              onTap: () => _export(context, auth),
            ),
            FlatRow(
              icon: AppIcons.upload,
              label: 'Import a file',
              subtitle: 'Bring back an export of this account',
              onTap: () => _import(context),
            ),
            FlatRow(
              icon: AppIcons.key,
              label: 'Passkeys',
              subtitle: 'Manage your login credentials',
              onTap: () => context.push('/passkeys'),
            ),
            const FlatHeading('Sounds'),
            FlatRow(
              icon: AppIcons.notifications,
              label: 'Pick sound',
              subtitle: 'Choose notification sound',
              onTap: () => context.push('/sound-settings'),
            ),
            const FlatHeading('Behind the scenes'),
            FlatRow(
              icon: AppIcons.debug,
              label: 'Debug',
              subtitle: 'Notification debugging',
              onTap: () => context.push('/debug-notifications'),
            ),
            FlatRow(
              icon: AppIcons.article,
              label: 'App Logs',
              subtitle: 'View and share diagnostic logs',
              onTap: () => context.push('/debug-logs'),
            ),
            FlatRow(
              icon: AppIcons.info,
              label: 'Build info',
              subtitle: 'Version, device, and watch details',
              onTap: () => context.push('/build-info'),
            ),
          ],
        ),
      ),
    );
  }

  /// Where the server's copy of the account is up to.
  static String _syncLabel(AccountSync sync) {
    if (sync.diverged) {
      return 'Stopped: the server has a different history for this account';
    }
    final waiting = sync.unsynced;
    if (sync.connected) {
      return waiting == 0 ? 'Up to date' : 'Sending $waiting changes';
    }
    return waiting == 0
        ? 'Offline, nothing waiting'
        : 'Offline, $waiting changes waiting';
  }

  Future<void> _export(BuildContext context, AuthProvider auth) async {
    final sync = context.read<AccountSync>();
    try {
      final file = await sync.export(auth.username ?? '');
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      ErrorModalService.showError('EXPORT FAILED: $e');
    }
  }

  /// Replace this phone's copy of the account with an exported file.
  Future<void> _import(BuildContext context) async {
    final sync = context.read<AccountSync>();
    final workouts = context.read<WorkoutProvider>();
    final settings = context.read<SettingsProvider>();
    final userId = context.read<AuthProvider>().userId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import a file?'),
        content: const Text(
          "This phone's copy of your account is replaced by the file. "
          'Anything the server already has comes back when it syncs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || userId == null) return;
    // A document picker only: no photo library, so no purpose string.
    final path = (await openFile())?.path;
    if (path == null) return;
    try {
      await sync.importFile(path);
      await settings.load();
      await workouts.loadActiveWorkout(userId);
    } catch (e) {
      ErrorModalService.showError('IMPORT FAILED: $e');
    }
  }

  /// Open one of the full-screen reading pages over everything.
  Future<void> _showBodyWeightPicker(
    BuildContext context,
    AuthProvider auth,
    SettingsProvider settings,
  ) async {
    final savedKg = await showModalBottomSheet<double>(
      context: context,
      routeSettings: const RouteSettings(name: 'sheet/body-weight'),
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) => _BodyWeightBottomSheet(
        weightUnit: settings.weightUnit,
        currentBodyWeightKg: auth.bodyWeightKg,
      ),
    );

    if (savedKg == null || !context.mounted) return;

    try {
      final user = await UserServiceWrapper(
        context.read<GrpcClient>(),
      ).updateMyBodyWeight(bodyWeightKg: savedKg);
      if (context.mounted) {
        auth.setBodyWeight(user.bodyWeightKg.toDouble());
      }
    } catch (e) {
      debugPrint('Body weight save failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save body weight')),
        );
      }
    }
  }

  Future<void> _syncBodyWeightFromHealth(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final syncedKg = await auth.syncBodyWeightFromHealth();
    if (!context.mounted) return;
    if (syncedKg != null && syncedKg > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Synced body weight to ${syncedKg.toStringAsFixed(1)} kg',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('No body weight found in health data')),
      );
    }
  }

  Future<void> _showWeightUnitPicker(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final choice = await showModalBottomSheet<WeightUnit>(
      context: context,
      routeSettings: const RouteSettings(name: 'sheet/weight-unit'),
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTheme.sheetHandle(context),
              ListTile(
                title: const Text('Pounds (🦅)'),
                subtitle: const Text('Standard US gym loading'),
                trailing: settings.weightUnit == WeightUnit.WEIGHT_UNIT_LB
                    ? const Icon(AppIcons.check)
                    : null,
                onTap: () => Navigator.pop(context, WeightUnit.WEIGHT_UNIT_LB),
              ),
              ListTile(
                title: const Text('Kilograms (🌍)'),
                subtitle: const Text('Standard international gym loading'),
                trailing: settings.weightUnit == WeightUnit.WEIGHT_UNIT_KG
                    ? const Icon(AppIcons.check)
                    : null,
                onTap: () => Navigator.pop(context, WeightUnit.WEIGHT_UNIT_KG),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) {
      await settings.updateWeightUnit(choice);
    }
  }
}

class _BodyWeightBottomSheet extends StatefulWidget {
  final WeightUnit weightUnit;
  final double currentBodyWeightKg;

  const _BodyWeightBottomSheet({
    required this.weightUnit,
    required this.currentBodyWeightKg,
  });

  @override
  State<_BodyWeightBottomSheet> createState() => _BodyWeightBottomSheetState();
}

class _BodyWeightBottomSheetState extends State<_BodyWeightBottomSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final isKg = widget.weightUnit == WeightUnit.WEIGHT_UNIT_KG;
    final currentDisplayValue = widget.currentBodyWeightKg > 0
        ? isKg
              ? widget.currentBodyWeightKg
              : widget.currentBodyWeightKg * 2.20462
        : null;
    _controller = TextEditingController(
      text: currentDisplayValue != null
          ? currentDisplayValue.toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = double.tryParse(_controller.text.trim());
    if (raw == null || raw <= 0) {
      Navigator.pop(context);
      return;
    }
    final isKg = widget.weightUnit == WeightUnit.WEIGHT_UNIT_KG;
    final kg = isKg ? raw : raw / 2.20462;
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pop(context, kg);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKg = widget.weightUnit == WeightUnit.WEIGHT_UNIT_KG;
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: AppTheme.sheetHandle(context, inset: 20)),
              Text(
                'Body weight',
                style: TextStyle(
                  fontSize: context.tokens.size.subtitle,
                  fontWeight: context.tokens.weight.heavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Used to estimate calories burned. Stored on your profile.',
                style: TextStyle(
                  fontSize: context.tokens.size.body,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: isKg ? 'kg' : 'lb',
                  border: const OutlineInputBorder(),
                  labelText: 'Weight',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(
                    'SAVE',
                    style: TextStyle(fontWeight: context.tokens.weight.heavy),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
