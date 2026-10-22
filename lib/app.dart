import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/services.dart';
import 'data/library_store.dart';
import 'data/store_scope.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';

class SemestaApp extends StatefulWidget {
  const SemestaApp({
    super.key,
    required this.store,
    required this.services,
    this.systemAccent,
  });

  final LibraryStore store;
  final Services services;

  /// Overrides the system accent lookup (used by tests).
  final Future<Color?>? systemAccent;

  @override
  State<SemestaApp> createState() => _SemestaAppState();
}

class _SemestaAppState extends State<SemestaApp> with WidgetsBindingObserver {
  Color? _accent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Roll the reminder window forward and pick up permission changes.
    if (state == AppLifecycleState.resumed) {
      widget.services.reminders.sync();
    }
  }

  Future<void> _loadAccent() async {
    Color? accent;
    try {
      accent =
          await (widget.systemAccent ?? DynamicColorPlugin.getAccentColor());
    } catch (_) {
      // No system accent on this platform; fall back to the brand palette.
    }
    if (mounted && accent != _accent) setState(() => _accent = accent);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ServicesScope(
      services: widget.services,
      child: StoreScope(
        store: store,
        // Only settings rebuild the shell, not every page turn.
        child: ListenableBuilder(
          listenable: store.settingsChanges,
          builder: (context, _) {
            final seed = store.useDynamicColor ? _accent : null;
            return MaterialApp(
              title: 'Semesta',
              debugShowCheckedModeBanner: false,
              themeMode: store.themeMode,
              theme: AppTheme.light(seed),
              darkTheme: AppTheme.dark(seed),
              themeAnimationDuration: Motion.medium2,
              themeAnimationCurve: Motion.emphasized,
              builder: (context, child) {
                final dark = Theme.of(context).brightness == Brightness.dark;
                final icons = dark ? Brightness.light : Brightness.dark;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: Colors.transparent,
                    systemNavigationBarContrastEnforced: false,
                    statusBarIconBrightness: icons,
                    systemNavigationBarIconBrightness: icons,
                  ),
                  child: child!,
                );
              },
              home: const AppShell(),
            );
          },
        ),
      ),
    );
  }
}
