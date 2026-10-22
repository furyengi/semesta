import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/library_store.dart';
import '../data/store_scope.dart';
import '../screens/reader_screen.dart';

/// "Linear algebra · p. 12", or null when the document is gone.
String? materialLabel(LibraryStore store, MaterialLink? link) {
  if (link == null) return null;
  final doc = store.doc(link.docId);
  if (doc == null) return null;
  return link.page == null ? doc.title : '${doc.title} · p. ${link.page}';
}

/// Opens the linked document (at the linked page). Explains if it's gone.
void openMaterial(BuildContext context, MaterialLink link) {
  final store = StoreScope.read(context);
  if (store.doc(link.docId) == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('That material is no longer in your library'),
        ),
      );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(docId: link.docId, initialPage: link.page),
    ),
  );
}

/// Chip-style row that links a document and page to an event or assignment.
class MaterialLinkField extends StatelessWidget {
  const MaterialLinkField({
    super.key,
    required this.value,
    required this.onChanged,
    this.preferredCourseId,
  });

  final MaterialLink? value;
  final ValueChanged<MaterialLink?> onChanged;

  /// Documents from this course are listed first when picking.
  final String? preferredCourseId;

  Future<void> _pick(BuildContext context) async {
    final store = StoreScope.read(context);
    final docs = store.docsSorted()
      ..sort((a, b) {
        final ap = a.courseId == preferredCourseId ? 0 : 1;
        final bp = b.courseId == preferredCourseId ? 0 : 1;
        return ap.compareTo(bp);
      });
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .6,
        maxChildSize: .9,
        minChildSize: .4,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Link a document',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text('Add a PDF to your library first.'),
                    )
                  : ListView.builder(
                      controller: controller,
                      itemCount: docs.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: Icon(docs[i].category.icon),
                        title: Text(
                          docs[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          store.course(docs[i].courseId)?.name ??
                              docs[i].category.label,
                        ),
                        selected: docs[i].id == value?.docId,
                        onTap: () => Navigator.pop(sheetContext, docs[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      onChanged(
        MaterialLink(
          docId: picked,
          page: value?.docId == picked ? value?.page : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final doc = value == null ? null : store.doc(value!.docId);

    if (doc == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.link_rounded),
          label: const Text('Link a document'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pick(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: TextFormField(
            key: ValueKey('page-${value!.docId}'),
            initialValue: value!.page?.toString() ?? '',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Page',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              onChanged(
                MaterialLink(
                  docId: value!.docId,
                  page: n != null && n > 0 ? n : null,
                ),
              );
            },
          ),
        ),
        IconButton(
          tooltip: 'Remove link',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => onChanged(null),
        ),
      ],
    );
  }
}
