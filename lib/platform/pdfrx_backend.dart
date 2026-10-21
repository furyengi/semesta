import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/pdf_backend.dart';

/// PDF engine backed by pdfrx (PDFium).
class PdfrxBackend implements PdfBackend {
  const PdfrxBackend();

  PdfDocumentRef _ref(DocSource s) => s.path != null
      ? PdfDocumentRefFile(s.path!)
      : PdfDocumentRefData(s.bytes!, sourceName: s.id);

  @override
  Future<int?> pageCount(DocSource source) async {
    PdfDocument? doc;
    try {
      doc = source.path != null
          ? await PdfDocument.openFile(source.path!)
          : await PdfDocument.openData(source.bytes!, sourceName: source.id);
      return doc.pages.length;
    } catch (_) {
      return null;
    } finally {
      await doc?.dispose();
    }
  }

  @override
  Widget buildViewer({
    required DocSource source,
    required int initialPage,
    required ReaderHandle handle,
    required ValueChanged<ReaderPosition> onPosition,
    required VoidCallback onTap,
    required Color background,
  }) {
    return _PdfrxView(
      ref: _ref(source),
      initialPage: initialPage,
      handle: handle,
      onPosition: onPosition,
      onTap: onTap,
      background: background,
    );
  }

  @override
  Widget buildCover(DocSource source) {
    return PdfDocumentViewBuilder(
      documentRef: _ref(source),
      builder: (context, document) {
        if (document == null || document.pages.isEmpty) {
          return const SizedBox.expand();
        }
        // Fill the cover edge to edge (cropping the page bottom) instead of
        // letterboxing it.
        final page = document.pages.first;
        return FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: page.width,
            height: page.height,
            child: PdfPageView(
              document: document,
              pageNumber: 1,
              decoration: const BoxDecoration(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

class _PdfrxView extends StatefulWidget {
  const _PdfrxView({
    required this.ref,
    required this.initialPage,
    required this.handle,
    required this.onPosition,
    required this.onTap,
    required this.background,
  });

  final PdfDocumentRef ref;
  final int initialPage;
  final ReaderHandle handle;
  final ValueChanged<ReaderPosition> onPosition;
  final VoidCallback onTap;
  final Color background;

  @override
  State<_PdfrxView> createState() => _PdfrxViewState();
}

class _PdfrxViewState extends State<_PdfrxView> {
  final _controller = PdfViewerController();

  @override
  void dispose() {
    widget.handle.detach();
    super.dispose();
  }

  void _report() {
    if (!_controller.isReady) return;
    final page = _controller.pageNumber;
    if (page == null) return;
    widget.onPosition(
      ReaderPosition(page: page, pageCount: _controller.pageCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewer(
      widget.ref,
      controller: _controller,
      initialPageNumber: widget.initialPage,
      params: PdfViewerParams(
        backgroundColor: widget.background,
        margin: 10,
        pageDropShadow: const BoxShadow(
          color: Colors.black45,
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
        onViewerReady: (document, controller) {
          widget.handle.attach(
            (page) => controller.goToPage(
              pageNumber: page,
              anchor: PdfPageAnchor.top,
              duration: const Duration(milliseconds: 300),
            ),
          );
          _report();
        },
        onPageChanged: (_) => _report(),
        onGeneralTap: (context, controller, details) {
          if (details.type != PdfViewerGeneralTapType.tap) return false;
          widget.onTap();
          return true;
        },
      ),
    );
  }
}
