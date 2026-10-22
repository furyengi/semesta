import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'core/doc_storage.dart';
import 'core/library_service.dart';
import 'core/notifier.dart';
import 'core/reminder_service.dart';
import 'core/services.dart';
import 'core/widget_backend.dart';
import 'core/widget_service.dart';
import 'data/library_store.dart';
import 'demo_data.dart';
import 'platform/channel_widget_backend.dart';
import 'platform/io_doc_storage.dart';
import 'platform/local_notifier.dart';
import 'platform/pdfrx_backend.dart';
import 'startup_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = StartupLog.instance;
  log.note('start');

  FlutterError.onError = (details) {
    log.problem('framework', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.problem('uncaught', error, stack);
    return true;
  };

  try {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (e, s) {
    log.problem('system ui', e, s);
  }

  // The only thing the first screen truly needs is the saved library.
  final LibraryStore store;
  try {
    store = await LibraryStore.load().timeout(const Duration(seconds: 15));
  } catch (e, s) {
    log.problem('loading saved data', e, s);
    runApp(_StartupFailure(error: '$e'));
    return;
  }
  log.note('data loaded');

  // Browsers have no private file system, so the web build keeps files in
  // memory for the session. Everywhere else files are copied on-device.
  final DocStorage storage = kIsWeb ? MemoryDocStorage() : IoDocStorage();
  const backend = PdfrxBackend();
  final library = LibraryService(
    store: store,
    storage: storage,
    backend: backend,
  );

  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  // Scheduled notifications are set up for Android; elsewhere reminders are
  // simply unavailable.
  final Notifier notifier = isAndroid
      ? LocalNotifier()
      : (kDemoData ? DemoNotifier() : NoopNotifier());
  final reminders = ReminderService(store: store, notifier: notifier);
  final WidgetBackend widgetBackend = isAndroid
      ? ChannelWidgetBackend()
      : (kDemoData ? DemoWidgetBackend() : NoopWidgetBackend());
  final widgets = WidgetService(store: store, backend: widgetBackend);

  // Show the app right away; everything else happens behind it, so a slow or
  // failing step can never leave the user on the splash screen.
  runApp(
    SemestaApp(
      store: store,
      services: Services(
        library: library,
        storage: storage,
        backend: backend,
        reminders: reminders,
        widgets: widgets,
      ),
    ),
  );
  log.note('ui shown');

  unawaited(_finishStartup(store, library, reminders, widgets));
}

/// Runs the slower start-up work, each step on its own so one failure
/// doesn't stop the rest.
Future<void> _finishStartup(
  LibraryStore store,
  LibraryService library,
  ReminderService reminders,
  WidgetService widgets,
) async {
  final log = StartupLog.instance;

  Future<void> step(String name, FutureOr<void> Function() body) async {
    try {
      await Future<void>.sync(body).timeout(const Duration(seconds: 20));
      log.note('$name ok');
    } on TimeoutException {
      log.problem(name, 'did not finish within 20 seconds');
    } catch (e, s) {
      log.problem(name, e, s);
    }
  }

  await step('pdf engine', pdfrxFlutterInitialize);
  await step('library check', library.pruneMissing);
  await step('sample document', () => library.seedIfNeeded(whenEmpty: kIsWeb));
  if (kDemoData) await step('demo data', () => seedDemoSemester(store));
  await step('reminders', reminders.start);
  await step('widgets', widgets.start);
  log.note('ready');
}

/// Shown only if the saved data can't even be read.
class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Semesta couldn’t start',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please send this message to whoever is helping you:',
                ),
                const SizedBox(height: 12),
                SelectableText(error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
