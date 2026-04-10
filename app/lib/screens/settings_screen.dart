import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../providers/settings_provider.dart';
import '../widgets/top_level_back_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final unitLabel = settings.weightUnit == WeightUnit.WEIGHT_UNIT_KG
        ? 'Kilograms (🌍)'
        : 'Pounds (🦅)';
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
          ],
        ),
      ),
    );
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

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
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
