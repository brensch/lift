import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/audio.dart';
import '../providers/sound_provider.dart';

class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final soundProvider = context.watch<SoundProvider>();
    final presets = getPresets();

    return Scaffold(
      appBar: AppBar(title: const Text('Rest Timer Sound')),
      body: ListView.builder(
        itemCount: presets.length,
        itemBuilder: (context, index) {
          final entry = presets[index];
          final isSelected = entry.key == soundProvider.currentPreset;

          return ListTile(
            leading: isSelected
                ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                : const Icon(Icons.circle_outlined),
            title: Text(entry.value.name),
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
