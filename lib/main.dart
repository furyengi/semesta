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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = await LibraryStore.load();
  // Browsers have no private file system, so the web build keeps files in
  // memory for the session. Everywhere else files are copied on-device.
  final DocStorage storage = kIsWeb ? MemoryDocStorage() : IoDocStorage();
  const backend = PdfrxBackend();
  final library = LibraryService(
    store: store,
    storage: storage,
    backend: backend,
  );
  await library.pruneMissing();
  await library.seedIfNeeded(whenEmpty: kIsWeb);
  if (kDemoData) seedDemoSemester(store);

  // Scheduled notifications are set up for Android; elsewhere reminders are
  // simply unavailable.
  final Notifier notifier =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? LocalNotifier()
      : (kDemoData ? DemoNotifier() : NoopNotifier());
  final reminders = ReminderService(store: store, notifier: notifier);
  await reminders.start();

  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final WidgetBackend widgetBackend = isAndroid
      ? ChannelWidgetBackend()
      : (kDemoData ? DemoWidgetBackend() : NoopWidgetBackend());
  final widgets = WidgetService(store: store, backend: widgetBackend);
  await widgets.start();

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
}
