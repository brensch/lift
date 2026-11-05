import 'package:flutter/material.dart';
import '../widgets/common/flat.dart';
import 'package:provider/provider.dart';
import '../gen/copy.dart';
import '../providers/sound_provider.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final soundProvider = context.watch<SoundProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final presets = copy.sounds;

    return Scaffold(
      appBar: AppBar(title: PageTitle(copy.settings.sound)),
      body: ListView.separated(
        itemCount: presets.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colorScheme.outline),
        itemBuilder: (context, index) {
          final entry = presets[index];
          final isSelected = entry.id == soundProvider.currentPreset;

          return ListTile(
            leading: Icon(
              isSelected ? AppIcons.checkCircle : AppIcons.circle,
              color: isSelected ? colorScheme.primary : colorScheme.tertiary,
            ),
            title: Text(
              entry.name,
              style: TextStyle(
                fontWeight: isSelected
                    ? context.tokens.weight.bold
                    : context.tokens.weight.regular,
              ),
            ),
            onTap: () {
              soundProvider.setPreset(entry.id);
              soundProvider.playPreview(entry.id);
            },
          );
        },
      ),
    );
  }
}
