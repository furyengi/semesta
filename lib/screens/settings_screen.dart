import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../widgets/brutal.dart';
import 'home_screen.dart' show contentGutter;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clear(BuildContext context) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined),
        title: const Text('Delete everything?'),
        content: const Text(
          'All collections and saved links on this device will be removed. '
          'This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok == true) {
      store.clearAll();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('All data deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = contentGutter(context);

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 12),
      child: Text(s, style: text.titleMedium),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Settings')),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter + 4, 40),
            sliver: SliverList.list(
              children: [
                label('Appearance'),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {store.themeMode},
                    onSelectionChanged: (s) => store.themeMode = s.first,
                  ),
                ),
                const SizedBox(height: 20),
                BrutalBox(
                  offset: const Offset(3, 4),
                  child: SwitchListTile(
                    title: Text('Dynamic color', style: text.titleSmall),
                    subtitle: const Text(
                      'Match your wallpaper on Android 12 and up',
                    ),
                    value: store.useDynamicColor,
                    onChanged: (v) => store.useDynamicColor = v,
                  ),
                ),
                const SizedBox(height: 12),
                label('Data'),
                BrutalBox(
                  offset: const Offset(3, 4),
                  onTap: () => _clear(context),
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error,
                    ),
                    title: Text(
                      'Delete all saved links',
                      style: text.titleSmall?.copyWith(color: scheme.error),
                    ),
                    subtitle: const Text('Everything is stored on this device'),
                  ),
                ),
                const SizedBox(height: 12),
                label('About'),
                BrutalBox(
                  offset: const Offset(3, 4),
                  child: ListTile(
                    leading: const Icon(Icons.bookmark_border_rounded),
                    title: Text('Semesta', style: text.titleSmall),
                    subtitle: const Text('Save now. Find anytime. · v0.1.0'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
