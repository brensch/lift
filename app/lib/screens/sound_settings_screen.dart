import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/audio.dart';
import '../providers/sound_provider.dart';

class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final soundProvider = context.watch<SoundProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final presets = getPresets();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PICK SOUND',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ),
      body: ListView.separated(
        itemCount: presets.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colorScheme.outline),
        itemBuilder: (context, index) {
          final entry = presets[index];
          final isSelected = entry.key == soundProvider.currentPreset;

          return ListTile(
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? colorScheme.primary : colorScheme.tertiary,
            ),
            title: Text(
              entry.value.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
