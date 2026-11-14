import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../logic/weight_units.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';

import '../services/account_sync.dart';
import '../services/grpc_client.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';
import '../theme/app_icons.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final c = copy.settings;
    final unitLabel = isMetricUnit(settings.weightUnit)
        ? c.kilograms
        : c.pounds;
    final bodyWeightLabel = auth.bodyWeightKg > 0
        ? _bodyWeightText(auth.bodyWeightKg, settings.weightUnit)
        : c.bodyWeightNotSet;
    return Scaffold(
      appBar: AppBar(title: PageTitle(c.title)),
      body: ListView(
        // A pixel on top: room for the first heading band's top line.
        padding: const EdgeInsets.only(top: 1, bottom: 24),
        children: [
          FlatHeading(c.youHeading),
          FlatRow(
            icon: AppIcons.bodyWeight,
            label: c.bodyWeight,
            subtitle: bodyWeightLabel,
            trailing: IconButton(
              icon: const Icon(AppIcons.refresh),
              tooltip: c.bodyWeightSync,
              onPressed: () =>
                  _syncBodyWeightFromHealth(context, auth, settings.weightUnit),
            ),
            onTap: () => _showBodyWeightPicker(context, auth, settings),
          ),
          FlatRow(
            icon: AppIcons.weightUnit,
            label: c.weightUnit,
            subtitle: unitLabel,
            onTap: () => _showWeightUnitPicker(context, settings),
          ),
          // Making it yours: how the plates, the icon and the rest's end
          // look and sound.
          FlatHeading(c.personaliseHeading),
          FlatRow(
            icon: AppIcons.palette,
            label: c.plateColours,
            subtitle: c.plateColoursSub,
            onTap: () => context.push('/settings/plate-colors'),
          ),
          FlatRow(
            icon: AppIcons.appIcon,
            label: copy.appIcon.title,
            subtitle: copy.appIcon.settingsSub,
            onTap: () => context.push('/settings/app-icon'),
          ),
          FlatRow(
            icon: AppIcons.notifications,
            label: c.sound,
            subtitle: c.soundSub,
            onTap: () => context.push('/sound-settings'),
          ),
          FlatHeading(c.accountHeading),
          FlatRow(
            icon: AppIcons.cloud,
            label: c.sync,
            subtitle: _syncLabel(context.watch<AccountSync>()),
          ),
          FlatRow(
            icon: AppIcons.download,
            label: copy.yourData.settingsRow,
            subtitle: copy.yourData.settingsRowSub,
            onTap: () => context.push('/settings/data'),
          ),
          FlatRow(
            icon: AppIcons.key,
            label: c.passkeys,
            subtitle: c.passkeysSub,
            onTap: () => context.push('/passkeys'),
          ),
          FlatHeading(c.behindHeading),
          FlatRow(
            icon: AppIcons.debug,
            label: c.debug,
            subtitle: c.debugSub,
            onTap: () => context.push('/debug-notifications'),
          ),
          FlatRow(
            icon: AppIcons.article,
            label: c.logs,
            subtitle: c.logsSub,
            onTap: () => context.push('/debug-logs'),
          ),
          FlatRow(
            icon: AppIcons.info,
            label: c.buildInfo,
            subtitle: c.buildInfoSub,
            onTap: () => context.push('/build-info'),
          ),
        ],
      ),
    );
  }

  /// Where the server's copy of the account is up to.
  static String _syncLabel(AccountSync sync) {
    final c = copy.settings;
    final waiting = sync.unsynced;
    final label = sync.connected
        ? (waiting == 0 ? c.syncUpToDate : c.syncSending)
        : (waiting == 0 ? c.syncOffline : c.syncOfflineWaiting);
    return label.replaceAll('{n}', '$waiting');
  }

  /// A body weight in the unit the user picked: "81.2 kg", "179.0 lb".
  static String _bodyWeightText(double kg, WeightUnit unit) {
    final value = isMetricUnit(unit) ? kg : kilogramsToPounds(kg);
    return '${value.toStringAsFixed(1)} ${weightUnitSuffix(unit)}';
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
          SnackBar(content: Text(copy.settings.bodyWeightSaveFailed)),
        );
      }
    }
  }

  Future<void> _syncBodyWeightFromHealth(
    BuildContext context,
    AuthProvider auth,
    WeightUnit unit,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final synced = await auth.syncBodyWeightFromHealth();
    if (!context.mounted) return;
    final message = switch (synced) {
      BodyWeightSynced(:final kg) => copy.settings.bodyWeightSynced.replaceAll(
        '{weight}',
        _bodyWeightText(kg, unit),
      ),
      BodyWeightNotInHealth() => copy.settings.bodyWeightNotFound,
      BodyWeightSyncFailed() => copy.settings.bodyWeightSyncFailed,
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
                title: Text(copy.settings.pounds),
                subtitle: Text(copy.settings.poundsSub),
                trailing: settings.weightUnit == WeightUnit.WEIGHT_UNIT_LB
                    ? const Icon(AppIcons.check)
                    : null,
                onTap: () => Navigator.pop(context, WeightUnit.WEIGHT_UNIT_LB),
              ),
              ListTile(
                title: Text(copy.settings.kilograms),
                subtitle: Text(copy.settings.kilogramsSub),
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
      // The core plans in the account's unit: replan home in the new one.
      if (context.mounted) await context.read<WorkoutProvider>().refreshHome();
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
    final isKg = isMetricUnit(widget.weightUnit);
    final currentDisplayValue = widget.currentBodyWeightKg > 0
        ? isKg
              ? widget.currentBodyWeightKg
              : kilogramsToPounds(widget.currentBodyWeightKg)
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
    final raw = parseDisplayWeight(_controller.text);
    if (raw == null || raw <= 0) {
      Navigator.pop(context);
      return;
    }
    final isKg = isMetricUnit(widget.weightUnit);
    final kg = isKg ? raw : poundsToKilograms(raw);
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pop(context, kg);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                copy.settings.bodyWeight,
                style: TextStyle(
                  fontSize: context.tokens.size.subtitle,
                  fontWeight: context.tokens.weight.heavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                copy.settings.bodyWeightBody,
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
                  suffixText: weightUnitSuffix(widget.weightUnit),
                  border: const OutlineInputBorder(),
                  labelText: copy.settings.bodyWeightField,
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
                    copy.settings.save,
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
