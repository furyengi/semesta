import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:semesta/app.dart';
import 'package:semesta/core/doc_storage.dart';
import 'package:semesta/core/library_service.dart';
import 'package:semesta/core/notifier.dart';
import 'package:semesta/core/reminder_service.dart';
import 'package:semesta/core/widget_backend.dart';
import 'package:semesta/core/widget_service.dart';
import 'package:semesta/data/widget_data.dart';
import 'package:semesta/data/reminder_planner.dart';
import 'package:semesta/core/pdf_backend.dart';
import 'package:semesta/core/services.dart';
import 'package:semesta/data/library_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in PDF engine: files of 0 bytes are "not a PDF"; everything else
/// has [pages] pages. The viewer is a few buttons that drive the callbacks.
class FakeBackend implements PdfBackend {
  FakeBackend({this.pages = 12});

  final int pages;

  @override
  Future<int?> pageCount(DocSource source) async {
    final length = source.bytes?.length ?? 1;
    return length == 0 ? null : pages;
  }

  @override
  Widget buildViewer({
    required DocSource source,
    required int initialPage,
    required ReaderHandle handle,
    required ValueChanged<ReaderPosition> onPosition,
    required VoidCallback onTap,
    required Color background,
  }) => _FakeViewer(
    initialPage: initialPage,
    pages: pages,
    handle: handle,
    onPosition: onPosition,
    onTap: onTap,
  );

  @override
  Widget buildCover(DocSource source) => const SizedBox.expand();
}

class _FakeViewer extends StatefulWidget {
  const _FakeViewer({
    required this.initialPage,
    required this.pages,
    required this.handle,
    required this.onPosition,
    required this.onTap,
  });

  final int initialPage;
  final int pages;
  final ReaderHandle handle;
  final ValueChanged<ReaderPosition> onPosition;
  final VoidCallback onTap;

  @override
  State<_FakeViewer> createState() => _FakeViewerState();
}

class _FakeViewerState extends State<_FakeViewer> {
  late int page = widget.initialPage;

  @override
  void initState() {
    super.initState();
    widget.handle.attach((p) async => _set(p));
    WidgetsBinding.instance.addPostFrameCallback((_) => _set(page));
  }

  void _set(int p) {
    if (!mounted) return;
    setState(() => page = p);
    widget.onPosition(ReaderPosition(page: p, pageCount: widget.pages));
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('viewer page $page', key: const Key('viewer-page')),
        TextButton(
          key: const Key('next-page'),
          onPressed: () => _set(page + 1),
          child: const Text('next'),
        ),
        TextButton(
          key: const Key('tap-page'),
          onPressed: widget.onTap,
          child: const Text('tap'),
        ),
      ],
    ),
  );
}

Uint8List pdfBytes([int n = 8]) => Uint8List.fromList(List.filled(n, 1));

class TestEnv {
  TestEnv(
    this.store,
    this.storage,
    this.backend,
    this.library,
    this.notifier,
    this.reminders,
    this.widgetBackend,
    this.widgets,
  );

  final LibraryStore store;
  final MemoryDocStorage storage;
  final FakeBackend backend;
  final LibraryService library;
  final FakeNotifier notifier;
  final ReminderService reminders;
  final FakeWidgetBackend widgetBackend;
  final WidgetService widgets;

  Services get services => Services(
    library: library,
    storage: storage,
    backend: backend,
    reminders: reminders,
    widgets: widgets,
  );

  static Future<TestEnv> create({int pages = 12}) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LibraryStore.load();
    final storage = MemoryDocStorage();
    final backend = FakeBackend(pages: pages);
    final library = LibraryService(
      store: store,
      storage: storage,
      backend: backend,
    );
    final notifier = FakeNotifier();
    final reminders = ReminderService(
      store: store,
      notifier: notifier,
      debounce: const Duration(milliseconds: 50),
      use24h: () => false,
    );
    final widgetBackend = FakeWidgetBackend();
    final widgets = WidgetService(
      store: store,
      backend: widgetBackend,
      debounce: const Duration(milliseconds: 50),
      use24h: () => false,
    );
    return TestEnv(
      store,
      storage,
      backend,
      library,
      notifier,
      reminders,
      widgetBackend,
      widgets,
    );
  }

  Future<void> addDoc(String fileName, {int pages = 12}) => library.importFiles(
    [PickedFile(name: fileName, readBytes: () async => pdfBytes())],
  );
}

Future<TestEnv> pumpApp(
  WidgetTester tester, {
  TestEnv? env,
  Future<void> Function(TestEnv env)? setup,

  /// Leave the "turn on reminders" tip visible (other tests hide it so it
  /// doesn't push content around).
  bool reminderPrompt = false,
  bool startReminders = false,
  bool startWidgets = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final e = env ?? await TestEnv.create();
  if (!reminderPrompt) e.store.dismissReminderPrompt();
  if (setup != null) await setup(e);
  if (startReminders) await e.reminders.start();
  if (startWidgets) await e.widgets.start();
  await tester.pumpWidget(
    SemestaApp(
      store: e.store,
      services: e.services,
      systemAccent: Future.value(null),
    ),
  );
  await tester.pumpAndSettle();
  return e;
}

/// Records what would be scheduled, and lets tests tap notifications.
class FakeNotifier implements Notifier {
  FakeNotifier({
    this.supported = true,
    this.permission = true,
    this.grantOnRequest = true,
  });

  /// Whether the system currently allows notifications.
  bool permission;

  /// Whether the next permission request is granted.
  bool grantOnRequest;

  List<ReminderSpec> scheduled = const [];
  int replaceCalls = 0;
  int permissionRequests = 0;
  final shown = <({String title, String body, String? payload})>[];
  String? launch;
  final _taps = StreamController<String>.broadcast();

  void tap(String payload) => _taps.add(payload);

  @override
  bool supported;

  @override
  Future<void> init() async {}

  @override
  Future<bool> areEnabled() async => permission;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grantOnRequest) permission = true;
    return permission;
  }

  @override
  Future<void> replaceAll(List<ReminderSpec> specs) async {
    replaceCalls++;
    scheduled = specs;
  }

  @override
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async => shown.add((title: title, body: body, payload: payload));

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchPayload() async {
    final p = launch;
    launch = null;
    return p;
  }
}

/// Records what the widgets would be given, and lets tests tap them.
class FakeWidgetBackend implements WidgetBackend {
  FakeWidgetBackend({this.supported = true, this.pinSupported = true});

  @override
  bool supported;

  bool pinSupported;
  Map<String, String> published = const {};
  int publishCalls = 0;
  final pinned = <WidgetKind>[];
  String? launch;
  final _taps = StreamController<String>.broadcast();

  void tap(String payload) => _taps.add(payload);

  @override
  Future<void> publish(Map<String, String> data) async {
    publishCalls++;
    published = data;
  }

  @override
  Future<bool> canPin() async => pinSupported;

  @override
  Future<bool> pin(WidgetKind kind) async {
    if (!pinSupported) return false;
    pinned.add(kind);
    return true;
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchPayload() async {
    final p = launch;
    launch = null;
    return p;
  }
}
