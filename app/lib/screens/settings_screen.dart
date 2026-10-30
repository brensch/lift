import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../logic/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/grpc_client.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_spec.dart';
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
          title: Text(
            'Settings',
            style: TextStyle(
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsTile(
              icon: AppIcons.profileMarker,
              label: 'Profile marker',
              subtitle: '${auth.profileEmoji} · ${auth.username ?? 'You'}',
              trailing: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: profileColorFromHex(auth.profileColorHex),
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () => context.push('/settings/profile-marker'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
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
            const SizedBox(height: 8),
            _SettingsTile(
              icon: AppIcons.weightUnit,
              label: 'Weight unit',
              subtitle: unitLabel,
              onTap: () => _showWeightUnitPicker(context, settings),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: AppIcons.palette,
              label: 'Plate colours',
              subtitle: 'Assign colours to plate weights',
              onTap: () => context.push('/settings/plate-colors'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: AppIcons.key,
              label: 'Passkeys',
              subtitle: 'Manage your login credentials',
              onTap: () => context.push('/passkeys'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: AppIcons.notifications,
              label: 'Pick sound',
              subtitle: 'Choose notification sound',
              onTap: () => context.push('/sound-settings'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              _SettingsTile(
                icon: AppIcons.title,
                label: 'Wordmark lab',
                subtitle: 'SCHLIFT banner candidates',
                onTap: () => context.push('/wordmarks'),
              ),
            ],
            const SizedBox(height: 8),
            _SettingsTile(
              icon: AppIcons.debug,
              label: 'Debug',
              subtitle: 'Notification debugging',
              onTap: () => context.push('/debug-notifications'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: AppIcons.article,
              label: 'App Logs',
              subtitle: 'View and share diagnostic logs',
              onTap: () => context.push('/debug-logs'),
            ),

            const SizedBox(height: 8),
            _SettingsTile(
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
              Center(child: AppTheme.sheetHandle(context)),
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: context.tokens.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 24, color: colorScheme.onSurface),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: context.tokens.weight.heavy,
                        fontSize: context.tokens.size.body,
                        letterSpacing: -0.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: context.tokens.size.small,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              Icon(
                AppIcons.forward,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
