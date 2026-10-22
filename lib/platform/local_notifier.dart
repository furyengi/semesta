import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/notifier.dart';
import '../data/reminder_planner.dart';

/// Android notifications via flutter_local_notifications.
///
/// Reminders are scheduled with [AndroidScheduleMode.inexactAllowWhileIdle]:
/// that needs no special alarm permission, at the cost of arriving up to a
/// few minutes late when the phone is dozing.
class LocalNotifier implements Notifier {
  LocalNotifier() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<String>.broadcast();
  bool _ready = false;

  static const _icon = 'ic_stat_semesta';

  @override
  bool get supported => true;

  @override
  Stream<String> get taps => _taps.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init() async {
    if (_ready) return;
    // Only the instant matters for scheduling, so UTC is enough here.
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload;
        if (p != null) _taps.add(p);
      },
    );
    _ready = true;
  }

  @override
  Future<bool> areEnabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android == null) return false;
    if (await android.areNotificationsEnabled() ?? false) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  NotificationDetails _details(ReminderKind kind, String body) {
    final urgent =
        kind == ReminderKind.classStart || kind == ReminderKind.deadline;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        kind.channelId,
        kind.channelName,
        channelDescription: 'Reminders for ${kind.channelName.toLowerCase()}',
        importance: urgent ? Importance.high : Importance.defaultImportance,
        priority: urgent ? Priority.high : Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        icon: _icon,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
  }

  @override
  Future<void> replaceAll(List<ReminderSpec> specs) async {
    await _plugin.cancelAll();
    for (final spec in specs) {
      try {
        await _plugin.zonedSchedule(
          id: spec.id,
          title: spec.title,
          body: spec.body,
          scheduledDate: tz.TZDateTime.from(spec.when, tz.UTC),
          notificationDetails: _details(spec.kind, spec.body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: spec.payload,
        );
      } catch (_) {
        // One bad reminder (e.g. a time that just passed) shouldn't stop the rest.
      }
    }
  }

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) => _plugin.show(
    id: 1,
    title: title,
    body: body,
    notificationDetails: _details(ReminderKind.digest, body),
    payload: payload,
  );

  @override
  Future<String?> takeLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }
}
