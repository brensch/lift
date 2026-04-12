import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../logic/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/grpc_client.dart';
import '../services/user_service.dart';
import '../widgets/top_level_back_scope.dart';

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
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsTile(
              icon: Icons.mood_outlined,
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
              icon: Icons.monitor_weight_outlined,
              label: 'Body weight',
              subtitle: bodyWeightLabel,
              onTap: () => _showBodyWeightPicker(context, auth, settings),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.scale_outlined,
              label: 'Weight unit',
              subtitle: unitLabel,
              onTap: () => _showWeightUnitPicker(context, settings),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.palette_outlined,
              label: 'Plate colours',
              subtitle: 'Assign colours to plate weights',
              onTap: () => context.push('/settings/plate-colors'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.key_outlined,
              label: 'Passkeys',
              subtitle: 'Manage your login credentials',
              onTap: () => context.push('/passkeys'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Pick sound',
              subtitle: 'Choose notification sound',
              onTap: () => context.push('/sound-settings'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.bug_report_outlined,
              label: 'Debug',
              subtitle: 'Notification debugging',
              onTap: () => context.push('/debug-notifications'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.article_outlined,
              label: 'App Logs',
              subtitle: 'View and share diagnostic logs',
              onTap: () => context.push('/debug-logs'),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.functions_outlined,
              label: 'Maths',
              subtitle: 'How calories are calculated',
              onTap: () => context.push('/settings/maths'),
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
    final isKg = settings.weightUnit == WeightUnit.WEIGHT_UNIT_KG;
    final currentDisplayValue = auth.bodyWeightKg > 0
        ? isKg
            ? auth.bodyWeightKg
            : auth.bodyWeightKg * 2.20462
        : null;

    final controller = TextEditingController(
      text: currentDisplayValue != null
          ? currentDisplayValue.toStringAsFixed(1)
          : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Body weight',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Used to estimate calories burned. Stored on your profile.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: isKg ? 'kg' : 'lb',
                border: const OutlineInputBorder(),
                labelText: 'Weight',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  final raw = double.tryParse(controller.text.trim());
                  if (raw == null || raw <= 0) {
                    Navigator.of(ctx).pop();
                    return;
                  }
                  final kg = isKg ? raw : raw / 2.20462;
                  Navigator.of(ctx).pop();
                  try {
                    final user = await UserServiceWrapper(
                      context.read<GrpcClient>(),
                    ).updateMyBodyWeight(bodyWeightKg: kg);
                    if (context.mounted) {
                      context.read<AuthProvider>().setBodyWeight(
                        user.bodyWeightKg.toDouble(),
                      );
                    }
                  } catch (e) {
                    debugPrint('Body weight save failed: $e');
                  }
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _showWeightUnitPicker(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final choice = await showModalBottomSheet<WeightUnit>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Pounds (🦅)'),
              subtitle: const Text('Standard US gym loading'),
              trailing: settings.weightUnit == WeightUnit.WEIGHT_UNIT_LB
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, WeightUnit.WEIGHT_UNIT_LB),
            ),
            ListTile(
              title: const Text('Kilograms (🌍)'),
              subtitle: const Text('Standard international gym loading'),
              trailing: settings.weightUnit == WeightUnit.WEIGHT_UNIT_KG
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, WeightUnit.WEIGHT_UNIT_KG),
            ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await settings.updateWeightUnit(choice);
    }
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
      borderRadius: BorderRadius.circular(12),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
