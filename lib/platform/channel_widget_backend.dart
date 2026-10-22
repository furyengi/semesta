import 'dart:async';

import 'package:flutter/services.dart';

import '../core/widget_backend.dart';
import '../data/widget_data.dart';

/// Android home-screen widgets, driven through a method channel handled by
/// `WidgetChannel.kt`.
class ChannelWidgetBackend implements WidgetBackend {
  ChannelWidgetBackend() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetTap') {
        final payload = call.arguments;
        if (payload is String) _taps.add(payload);
      }
      return null;
    });
  }

  static const _channel = MethodChannel('com.semesta.semesta/widgets');
  final _taps = StreamController<String>.broadcast();

  @override
  bool get supported => true;

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<void> publish(Map<String, String> data) async {
    try {
      await _channel.invokeMethod<void>('publish', data);
    } on PlatformException {
      // Widgets are a nicety; never let them break the app.
    } on MissingPluginException {
      // Running without the native side (e.g. in tests).
    }
  }

  @override
  Future<bool> canPin() async {
    try {
      return await _channel.invokeMethod<bool>('canPin') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> pin(WidgetKind kind) async {
    try {
      return await _channel.invokeMethod<bool>('pin', kind.id) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<String?> takeLaunchPayload() async {
    try {
      return await _channel.invokeMethod<String>('launchPayload');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
