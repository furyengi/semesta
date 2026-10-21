import 'package:flutter/material.dart';

import '../core/services.dart';
import '../data/store_scope.dart';
import 'home_screen.dart' show contentGutter;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _clear(BuildContext context) async {
    final library = ServicesScope.of(context).library;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined),
        title: const Text('Delete the whole library?'),
        content: const Text(
          'All documents, reading progress and bookmarks on this device will '
          'be removed. Your original files are not touched.',
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
      await library.deleteAll();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Library deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = contentGutter(context);

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: Text(s, style: text.titleSmall?.copyWith(color: scheme.primary)),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Settings')),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 40),
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
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dynamic color'),
                  subtitle: const Text(
                    'Match your wallpaper on Android 12 and up',
                  ),
                  value: store.useDynamicColor,
                  onChanged: (v) => store.useDynamicColor = v,
                ),
                label('Reading'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Night reading'),
                  subtitle: const Text('Invert page colours in the reader'),
                  value: store.nightReading,
                  onChanged: (v) => store.nightReading = v,
                ),
                label('Library'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.error,
                  ),
                  title: Text(
                    'Delete the whole library',
                    style: TextStyle(color: scheme.error),
                  ),
                  subtitle: const Text(
                    'Documents are stored privately on this device',
                  ),
                  onTap: () => _clear(context),
                ),
                label('About'),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_stories_outlined),
                  title: Text('Semesta'),
                  subtitle: Text(
                    'Read. Organize. Understand. Progress. · v0.2.0',
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
