import 'package:flutter/services.dart';

import '../data/library_store.dart';
import '../data/models.dart';
import 'doc_storage.dart';
import 'pdf_backend.dart';

/// A file chosen by the user, independent of the picker plugin.
class PickedFile {
  const PickedFile({required this.name, this.path, this.readBytes});

  final String name;
  final String? path;
  final Future<Uint8List> Function()? readBytes;
}

class ImportResult {
  const ImportResult({this.added = const [], this.failed = const []});

  final List<Doc> added;
  final List<String> failed;
}

/// Imports, seeds and deletes documents, keeping the store and file storage
/// in step.
class LibraryService {
  LibraryService({
    required this.store,
    required this.storage,
    required this.backend,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  static const sampleAsset = 'assets/samples/getting-started.pdf';

  final LibraryStore store;
  final DocStorage storage;
  final PdfBackend backend;
  final AssetBundle _bundle;

  Future<ImportResult> importFiles(List<PickedFile> files) async {
    final added = <Doc>[];
    final failed = <String>[];
    for (final f in files) {
      final doc = await _importOne(f);
      if (doc == null) {
        failed.add(f.name);
      } else {
        added.add(doc);
      }
    }
    return ImportResult(added: added, failed: failed);
  }

  Future<Doc?> _importOne(PickedFile f, {DocCategory? category}) async {
    String? key;
    try {
      Uint8List? bytes;
      if (f.path == null) bytes = await f.readBytes?.call();
      if (f.path == null && bytes == null) return null;
      key = await storage.save(name: f.name, sourcePath: f.path, bytes: bytes);
      final source = await storage.open(key);
      final pages = source == null ? null : await backend.pageCount(source);
      if (pages == null || pages < 1) {
        await storage.delete(key);
        return null;
      }
      return store.addDoc(
        title: titleFromFileName(f.name),
        storageKey: key,
        pageCount: pages,
        category: category ?? DocCategory.other,
      );
    } catch (_) {
      if (key != null) await storage.delete(key);
      return null;
    }
  }

  /// Adds the bundled getting-started guide on first launch.
  Future<void> seedIfNeeded({bool whenEmpty = false}) async {
    final skip = whenEmpty ? store.docs.isNotEmpty : store.seeded;
    if (skip) return;
    store.markSeeded();
    try {
      final data = await _bundle.load(sampleAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await _importOne(
        PickedFile(
          name: 'Getting started with Semesta.pdf',
          readBytes: () async => bytes,
        ),
        category: DocCategory.notes,
      );
    } catch (_) {
      // The sample is a nicety; the library works without it.
    }
  }

  /// Drops library entries whose file has gone missing (cleared storage, a
  /// fresh browser session) so they don't show as broken cards.
  Future<void> pruneMissing() async {
    for (final d in store.docs) {
      if (await storage.open(d.storageKey) == null) store.removeDoc(d.id);
    }
  }

  Future<void> delete(Doc doc) async {
    store.removeDoc(doc.id);
    await storage.delete(doc.storageKey);
  }

  Future<void> deleteAll() async {
    for (final d in store.clearAll()) {
      await storage.delete(d.storageKey);
    }
  }
}
