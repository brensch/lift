/// Health-permission and heart-rate help dialogs.
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';

Future<void> showHealthPermissionDialog(BuildContext context) async {
  final isAndroid = Platform.isAndroid;
  final storeName = isAndroid ? 'Health Connect' : 'Apple Health';
  final steps = isAndroid
      ? 'Open Settings > Apps > Schlift > Health Connect, then enable workout permissions.'
      : 'Open Settings > Health > Data Access > Schlift, then enable workout permissions.';

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Sync Workouts',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Text(
        'Schlift can save workouts to $storeName so they appear in your fitness apps.\n\n$steps',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

/// Instructions for enabling live heart rate, tailored to the current OS. Shown
/// when the user taps the heart rate readout in the workout bar.
Future<void> showHeartRateHelpDialog(BuildContext context) async {
  final isAndroid = Platform.isAndroid;
  final watchName = isAndroid ? 'Wear OS watch' : 'Apple Watch';

  final steps = isAndroid
      ? const <String>[
          'Pair your Wear OS watch and install the Schlift watch app on it.',
          'Open Schlift on your watch and keep it running on your wrist during the workout.',
          'Tap Allow when the watch asks for Body Sensors / Heart Rate access.',
        ]
      : const <String>[
          'Pair your Apple Watch and install the Schlift watch app on it.',
          'Start the workout from your iPhone — the watch app launches automatically.',
          'Tap Allow on the Health permission sheet, making sure Heart Rate is turned on.',
        ];

  final fixes = isAndroid
      ? const <String>[
          'On the watch: Settings → Apps → Schlift → Permissions → Body sensors → Allow.',
          'Make sure the watch app is open and the workout is running.',
          'Wear the watch snugly, just above your wrist bone.',
        ]
      : const <String>[
          'Health app → tap your photo (top-right) → Privacy → Apps → Schlift → turn on Heart Rate.',
          'Or iPhone Settings → Privacy & Security → Health → Schlift → enable Heart Rate.',
          'Wear the watch snugly, just above your wrist bone.',
        ];

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.favorite, size: 20, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text('Heart rate', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live heart rate is measured by your $watchName during a workout. '
                'To see your BPM here:',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < steps.length; i++)
                HeartRateStep(leading: '${i + 1}.', text: steps[i]),
              const SizedBox(height: 6),
              Text(
                'STILL NOT SHOWING?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 10),
              for (final fix in fixes) HeartRateStep(leading: '•', text: fix),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}

class HeartRateStep extends StatelessWidget {
  final String leading;
  final String text;
  const HeartRateStep({super.key, required this.leading, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              leading,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
                height: 1.4,
              ),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
