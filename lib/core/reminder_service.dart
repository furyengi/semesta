import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/library_store.dart';
import '../data/reminder_planner.dart';
import 'notifier.dart';

/// Keeps the scheduled notifications in step with the library store.
///
/// Every change to classes, sessions, assignments or reminder settings (and
/// every app resume, so the window rolls forward) rebuilds the plan. The
/// schedule is only pushed to the system when it actually changed.
class ReminderService extends ChangeNotifier {
  ReminderService({
    required this.store,
    required this.notifier,
    DateTime Function()? clock,
    this.debounce = const Duration(seconds: 1),
    bool Function()? use24h,
  }) : _clock = clock ?? DateTime.now,
       _use24h =
           use24h ?? (() => PlatformDispatcher.instance.alwaysUse24HourFormat);

  final LibraryStore store;
  final Notifier notifier;
  final Duration debounce;
  final DateTime Function() _clock;
  final bool Function() _use24h;

  List<ReminderSpec> _scheduled = const [];
  String? _lastSignature;
  bool? _permission;
  Timer? _timer;
  bool _syncing = false;
  bool _again = false;
  bool _started = false;

  bool get supported => notifier.supported;

  /// What is currently scheduled, soonest first.
  List<ReminderSpec> get scheduled => _scheduled;

  /// Whether the system lets us post notifications (null until checked).
  bool? get permissionGranted => _permission;

  Stream<String> get taps => notifier.taps;

  bool _launchTaken = false;

  /// The payload of the notification that started the app; returned once.
  Future<String?> takeLaunchPayload() async {
    if (_launchTaken) return null;
    _launchTaken = true;
    return notifier.takeLaunchPayload();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await notifier.init();
    _permission = supported ? await notifier.areEnabled() : false;
    store.addListener(_onStoreChanged);
    await sync();
  }

  void _onStoreChanged() {
    _timer?.cancel();
    _timer = Timer(debounce, sync);
  }

  /// Recomputes and, if needed, reschedules. Safe to call at any time.
  Future<void> sync() async {
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce() async {
    var specs = const <ReminderSpec>[];
    if (supported && store.reminders.enabled) {
      // The user can revoke permission in system settings at any time.
      final granted = await notifier.areEnabled();
      if (granted != _permission) {
        _permission = granted;
        notifyListeners();
      }
      if (granted) {
        specs = planReminders(store, _clock(), use24h: _use24h());
      }
    }
    final signature = specs.map((s) => s.signature).join('\n');
    if (signature == _lastSignature) return;
    await notifier.replaceAll(specs);
    _lastSignature = signature;
    _scheduled = specs;
    notifyListeners();
  }

  /// Asks for permission and, if granted, turns reminders on.
  Future<bool> enable() async {
    if (!supported) return false;
    bool granted;
    try {
      granted = await notifier.requestPermission();
    } catch (_) {
      granted = false;
    }
    _permission = granted;
    if (granted) {
      store.reminders = store.reminders.copyWith(enabled: true);
    }
    notifyListeners();
    return granted;
  }

  void disable() {
    store.reminders = store.reminders.copyWith(enabled: false);
  }

  Future<void> sendTest() => notifier.showNow(
    title: 'Reminders are on',
    body: 'You’ll get notifications like this before classes, study sessions and deadlines.',
    payload: 'tab:${ReminderTabs.library}',
  );

  @override
  void dispose() {
    _timer?.cancel();
    if (_started) store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
