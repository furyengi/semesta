import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:semesta/app.dart';
import 'package:semesta/core/doc_storage.dart';
import 'package:semesta/core/library_service.dart';
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
  TestEnv(this.store, this.storage, this.backend, this.library);

  final LibraryStore store;
  final MemoryDocStorage storage;
  final FakeBackend backend;
  final LibraryService library;

  Services get services =>
      Services(library: library, storage: storage, backend: backend);

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
    return TestEnv(store, storage, backend, library);
  }

  Future<void> addDoc(String fileName, {int pages = 12}) => library.importFiles(
    [PickedFile(name: fileName, readBytes: () async => pdfBytes())],
  );
}

Future<TestEnv> pumpApp(
  WidgetTester tester, {
  TestEnv? env,
  Future<void> Function(TestEnv env)? setup,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final e = env ?? await TestEnv.create();
  if (setup != null) await setup(e);
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
