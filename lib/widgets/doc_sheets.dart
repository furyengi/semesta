import 'package:flutter/material.dart';

import '../core/services.dart';
import '../data/models.dart';
import '../data/store_scope.dart';

/// Rename, re-categorise or delete a document.
Future<void> showDocEditor(BuildContext context, Doc doc) {
  final services = ServicesScope.of(context);
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _DocEditor(
      doc: doc,
      onSave: (title, category, courseId) => store.updateDoc(
        doc.id,
        title: title,
        category: category,
        courseId: courseId,
        clearCourse: courseId == null,
      ),
      onDelete: () async {
        final ok = await showDialog<bool>(
          context: sheetContext,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.delete_outline_rounded),
            title: Text('Remove "${doc.title}"?'),
            content: const Text(
              'The file, your reading progress and bookmarks will be removed '
              'from Semesta. The original file is not touched.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await services.library.delete(doc);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        }
      },
    ),
  );
}

class _DocEditor extends StatefulWidget {
  const _DocEditor({
    required this.doc,
    required this.onSave,
    required this.onDelete,
  });

  final Doc doc;
  final void Function(String title, DocCategory category, String? courseId)
  onSave;
  final Future<void> Function() onDelete;

  @override
  State<_DocEditor> createState() => _DocEditorState();
}

class _DocEditorState extends State<_DocEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.doc.title,
  )..addListener(() => setState(() {}));
  late DocCategory _category = widget.doc.category;
  late String? _courseId = widget.doc.courseId;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _valid => _title.text.trim().isNotEmpty;

  void _save() {
    if (!_valid) return;
    widget.onSave(_title.text, _category, _courseId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Document details', style: text.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('Category', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in DocCategory.values)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            if (StoreScope.of(context).courses.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Course', style: text.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('None'),
                    selected: _courseId == null,
                    onSelected: (_) => setState(() => _courseId = null),
                  ),
                  for (final c in StoreScope.of(context).courses)
                    ChoiceChip(
                      showCheckmark: false,
                      avatar: CircleAvatar(backgroundColor: c.color, radius: 7),
                      label: Text(c.name),
                      selected: _courseId == c.id,
                      onSelected: (_) => setState(() => _courseId = c.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _valid ? _save : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bookmarked pages for [doc]; tapping one calls [onGoTo].
Future<void> showBookmarksSheet(
  BuildContext context, {
  required String docId,
  required int currentPage,
  required void Function(int page) onGoTo,
}) {
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final doc = store.doc(docId);
        final marks = doc?.bookmarks ?? const <Bookmark>[];
        final text = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        final here = doc?.isBookmarked(currentPage) ?? false;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .55,
          minChildSize: .35,
          maxChildSize: .9,
          builder: (context, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('Bookmarks', style: text.titleLarge)),
                    FilledButton.tonalIcon(
                      onPressed: () => store.toggleBookmark(docId, currentPage),
                      icon: Icon(
                        here
                            ? Icons.bookmark_remove_outlined
                            : Icons.bookmark_add_outlined,
                      ),
                      label: Text(
                        here ? 'Remove p. $currentPage' : 'Add p. $currentPage',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: marks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No bookmarks yet. Tap the bookmark icon while '
                            'reading to save a page.',
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: marks.length,
                        itemBuilder: (context, i) {
                          final m = marks[i];
                          return ListTile(
                            leading: Icon(
                              Icons.bookmark_rounded,
                              color: scheme.primary,
                            ),
                            title: Text('Page ${m.page}'),
                            subtitle: Text(_date(m.createdAt)),
                            trailing: IconButton(
                              tooltip: 'Remove bookmark',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () =>
                                  store.toggleBookmark(docId, m.page),
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onGoTo(m.page);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

String _date(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Saved ${d.day} ${months[d.month - 1]}';
}
