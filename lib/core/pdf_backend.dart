import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Where a document's bytes come from: a file on disk, or memory (web).
class DocSource {
  const DocSource.file(String this.path, {required this.id}) : bytes = null;
  const DocSource.memory(Uint8List this.bytes, {required this.id})
    : path = null;

  final String id;
  final String? path;
  final Uint8List? bytes;
}

/// Page position reported by a reader view.
class ReaderPosition {
  const ReaderPosition({required this.page, required this.pageCount});

  /// 1-based.
  final int page;
  final int pageCount;
}

/// Lets the reader screen drive a view it doesn't own.
class ReaderHandle {
  Future<void> Function(int page)? _goTo;

  /// Called by the view once it can navigate.
  void attach(Future<void> Function(int page) goTo) => _goTo = goTo;
  void detach() => _goTo = null;

  Future<void> goToPage(int page) async => _goTo?.call(page);
}

/// Everything the app needs from a PDF engine, so screens and tests don't
/// depend on the engine directly.
abstract class PdfBackend {
  /// Number of pages, or null if the file can't be read as a PDF.
  Future<int?> pageCount(DocSource source);

  /// A scrolling, zoomable viewer.
  Widget buildViewer({
    required DocSource source,
    required int initialPage,
    required ReaderHandle handle,
    required ValueChanged<ReaderPosition> onPosition,
    required VoidCallback onTap,
    required Color background,
  });

  /// First-page thumbnail that fills its parent.
  Widget buildCover(DocSource source);
}
