import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'data/store_scope.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';

class SemestaApp extends StatefulWidget {
  const SemestaApp({super.key, required this.store, this.systemAccent});

  final AppStore store;

  /// Overrides the system accent lookup (used by tests).
  final Future<Color?>? systemAccent;

  @override
  State<SemestaApp> createState() => _SemestaAppState();
}

class _SemestaAppState extends State<SemestaApp> {
  Color? _accent;

  @override
  void initState() {
    super.initState();
    _loadAccent();
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
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
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
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
