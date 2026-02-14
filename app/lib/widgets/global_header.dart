import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/multiplayer_modal.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Lift',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (auth.username != null)
                  Text(
                    auth.username!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Progress'),
            onTap: () {
              Navigator.pop(context);
              context.go('/progress');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History'),
            onTap: () {
              Navigator.pop(context);
              context.go('/history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Multiplayer'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const MultiplayerModal(),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Rest Timer Sound'),
            onTap: () {
              Navigator.pop(context);
              context.go('/sound-settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              Navigator.pop(context);
              final wp = context.read<WorkoutProvider>();
              wp.clear();
              await auth.logout();
            },
          ),
        ],
      ),
    );
  }
}
