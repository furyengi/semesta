import 'package:flutter/foundation.dart';

/// Records what happens while the app starts, so a failure in one background
/// step (PDF engine, notifications, widgets) is visible instead of silent.
///
/// Messages are also written to the system log with a `SEMESTA boot:` prefix.
class StartupLog extends ChangeNotifier {
  StartupLog._();

  static final StartupLog instance = StartupLog._();

  final List<String> _problems = [];

  /// Things that went wrong, oldest first.
  List<String> get problems => List.unmodifiable(_problems);

  void note(String message) => debugPrint('SEMESTA boot: $message');

  void problem(String step, Object error, [StackTrace? stack]) {
    final first = (stack?.toString().split('\n').first ?? '').trim();
    final text = '$step: $error${first.isEmpty ? '' : '\n  at $first'}';
    debugPrint('SEMESTA boot: PROBLEM $text');
    if (_problems.length < 30) _problems.add(text);
    notifyListeners();
  }

  void clear() {
    _problems.clear();
    notifyListeners();
  }
}
