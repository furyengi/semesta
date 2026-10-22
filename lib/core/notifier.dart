import '../data/reminder_planner.dart';

/// Schedules and shows system notifications. The real implementation wraps a
/// plugin; tests use a recording fake.
abstract class Notifier {
  /// False where notifications can't be scheduled (web, desktop).
  bool get supported;

  Future<void> init();

  /// Whether the app is currently allowed to post notifications.
  Future<bool> areEnabled();

  /// Asks the user for permission (a no-op prompt where it isn't needed).
  Future<bool> requestPermission();

  /// Cancels everything scheduled and schedules exactly [specs].
  Future<void> replaceAll(List<ReminderSpec> specs);

  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  });

  /// Payloads of notifications the user taps while the app is running.
  Stream<String> get taps;

  /// The payload of the notification that launched the app, once.
  Future<String?> takeLaunchPayload();
}

/// Used where notifications aren't available.
class NoopNotifier implements Notifier {
  @override
  bool get supported => false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> areEnabled() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<ReminderSpec> specs) async {}

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<String?> takeLaunchPayload() async => null;
}
