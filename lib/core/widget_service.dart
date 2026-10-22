import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/library_store.dart';
import '../data/widget_data.dart';
import 'widget_backend.dart';

/// Keeps the home-screen widgets showing current data.
///
/// Rebuilds the widget data whenever the store changes (debounced) and when
/// the app resumes, and only talks to the platform when something the
/// widgets show actually changed.
class WidgetService extends ChangeNotifier {
  WidgetService({
    required this.store,
    required this.backend,
    DateTime Function()? clock,
    this.debounce = const Duration(seconds: 1),
    bool Function()? use24h,
  }) : _clock = clock ?? DateTime.now,
       _use24h =
           use24h ?? (() => PlatformDispatcher.instance.alwaysUse24HourFormat);

  final LibraryStore store;
  final WidgetBackend backend;
  final Duration debounce;
  final DateTime Function() _clock;
  final bool Function() _use24h;

  Map<String, String> _data = const {};
  String? _signature;
  Timer? _timer;
  bool _started = false;
  bool _syncing = false;
  bool _again = false;
  bool _launchTaken = false;
  bool? _canPin;

  bool get supported => backend.supported;

  /// What the widgets were last given.
  Map<String, String> get data => _data;

  Stream<String> get taps => backend.taps;

  /// Whether the launcher lets the app add widgets directly (cached).
  bool? get canPin => _canPin;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!supported) return;
    _canPin = await backend.canPin();
    store.addListener(_onStoreChanged);
    await sync();
  }

  void _onStoreChanged() {
    _timer?.cancel();
    _timer = Timer(debounce, sync);
  }

  /// Rebuilds the data and pushes it if it changed.
  Future<void> sync() async {
    if (!supported) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        final data = buildWidgetData(store, _clock(), use24h: _use24h());
        final signature = data.entries
            .map((e) => '${e.key}=${e.value}')
            .join('\n');
        if (signature == _signature) continue;
        await backend.publish(data);
        _signature = signature;
        _data = data;
        notifyListeners();
      } while (_again);
    } finally {
      _syncing = false;
    }
  }

  Future<bool> pin(WidgetKind kind) => backend.pin(kind);

  /// The widget tap that started the app; returned once.
  Future<String?> takeLaunchPayload() async {
    if (_launchTaken || !supported) return null;
    _launchTaken = true;
    return backend.takeLaunchPayload();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_started && supported) store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
