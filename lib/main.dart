import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'core/doc_storage.dart';
import 'core/library_service.dart';
import 'core/services.dart';
import 'data/library_store.dart';
import 'demo_data.dart';
import 'platform/io_doc_storage.dart';
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

  runApp(
    SemestaApp(
      store: store,
      services: Services(library: library, storage: storage, backend: backend),
    ),
  );
}
