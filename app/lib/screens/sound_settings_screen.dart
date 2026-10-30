import 'package:flutter/material.dart';
import '../widgets/common/flat.dart';
import 'package:provider/provider.dart';
import '../logic/audio.dart';
import '../providers/sound_provider.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final soundProvider = context.watch<SoundProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final presets = getPresets();

    return Scaffold(
      appBar: AppBar(title: PageTitle('Pick sound')),
      body: ListView.separated(
        itemCount: presets.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colorScheme.outline),
        itemBuilder: (context, index) {
          final entry = presets[index];
          final isSelected = entry.key == soundProvider.currentPreset;

          return ListTile(
            leading: Icon(
              isSelected ? AppIcons.checkCircle : AppIcons.circle,
              color: isSelected ? colorScheme.primary : colorScheme.tertiary,
            ),
            title: Text(
              entry.value.name,
              style: TextStyle(
                fontWeight: isSelected
                    ? context.tokens.weight.bold
                    : context.tokens.weight.regular,
              ),
            ),
            onTap: () {
              soundProvider.setPreset(entry.key);
              soundProvider.playPreview(entry.key);
            },
          );
        },
      ),
    );
  }
}
