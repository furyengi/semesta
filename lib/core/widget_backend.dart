import '../data/widget_data.dart';

/// Talks to the platform's home-screen widgets. The Android implementation
/// uses a method channel; tests use a recording fake.
abstract class WidgetBackend {
  /// False where there are no home-screen widgets (web, desktop, iOS for now).
  bool get supported;

  /// Stores [data] for the widgets to read and asks them to redraw.
  Future<void> publish(Map<String, String> data);

  /// Whether the launcher can offer to pin a widget from inside the app.
  Future<bool> canPin();

  /// Asks the launcher to add a widget of [kind]. False if it can't.
  Future<bool> pin(WidgetKind kind);

  /// Payloads of widget taps while the app is running ("tab:2", "doc:ID:7").
  Stream<String> get taps;

  /// The payload of the widget tap that started the app, once.
  Future<String?> takeLaunchPayload();
}

/// Used where widgets aren't available.
class NoopWidgetBackend implements WidgetBackend {
  @override
  bool get supported => false;

  @override
  Future<void> publish(Map<String, String> data) async {}

  @override
  Future<bool> canPin() async => false;

  @override
  Future<bool> pin(WidgetKind kind) async => false;

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<String?> takeLaunchPayload() async => null;
}
