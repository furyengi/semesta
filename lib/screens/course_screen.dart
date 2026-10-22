import 'dart:async';

import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/library_store.dart';
import '../data/store_scope.dart';
import '../widgets/course_card.dart' show plural;
import '../widgets/course_sheets.dart';
import '../widgets/doc_cover.dart';
import '../widgets/event_sheets.dart';
import '../widgets/schedule_tiles.dart';
import 'home_screen.dart' show contentGutter;
import 'reader_screen.dart';

enum _CourseMenu { edit, delete }

/// Everything for one course: next classes, materials, assignments, notes.
class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key, required this.courseId});

  final String courseId;

  Future<void> _delete(BuildContext context, Course c) async {
    final store = StoreScope.read(context);
    final nav = Navigator.of(context);
    final materials = store.docsForCourse(c.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text('Delete "${c.name}"?'),
        content: Text(
          'Its classes, assignments and notes will be removed. '
          '${materials == 0 ? '' : '${plural(materials, 'document')} stay in your library. '}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      nav.pop();
      store.removeCourse(c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = store.course(courseId);
    if (c == null) return const Scaffold(body: SizedBox.shrink());

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final gutter = contentGutter(context);
    final next = store.upcoming(DateTime.now(), count: 3, courseId: c.id);
    final docs = store.docsForCourse(c.id);
    final assignments = store.assignmentsFor(c.id);
    final subtitle = [
      if (c.code.isNotEmpty) c.code,
      if (c.instructor.isNotEmpty) c.instructor,
    ].join(' · ');

    Widget header(String title, {Widget? action}) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: text.titleLarge)),
          ?action,
        ],
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<_CourseMenu>(
                tooltip: 'More options',
                onSelected: (m) {
                  switch (m) {
                    case _CourseMenu.edit:
                      showCourseEditor(context, existing: c);
                    case _CourseMenu.delete:
                      _delete(context, c);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _CourseMenu.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit course'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _CourseMenu.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 48),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: c.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subtitle.isEmpty ? 'Course' : subtitle,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                header(
                  'Schedule',
                  action: TextButton.icon(
                    onPressed: () => showEventEditor(context, courseId: c.id),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add class'),
                  ),
                ),
                if (next.isEmpty)
                  const _Hint(
                    'No upcoming classes or exams. Add one and link its material.',
                  )
                else
                  for (final o in next)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OccurrenceTile(occurrence: o, showDate: true),
                    ),
                header(
                  'Materials',
                  action: TextButton.icon(
                    onPressed: () => showCourseMaterialsPicker(context, c),
                    icon: const Icon(Icons.library_add_outlined),
                    label: const Text('Add'),
                  ),
                ),
                if (docs.isEmpty)
                  const _Hint(
                    'Attach PDFs from your library: textbooks, lecture slides, notes.',
                  )
                else
                  for (final d in docs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MaterialTile(docId: d.id),
                    ),
                header(
                  'Assignments',
                  action: TextButton.icon(
                    onPressed: () =>
                        showAssignmentEditor(context, courseId: c.id),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ),
                if (assignments.isEmpty)
                  const _Hint(
                    'Nothing due. Add assignments to see them on your calendar.',
                  )
                else
                  for (final a in assignments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AssignmentTile(assignment: a),
                    ),
                header('Notes'),
                _NotesField(courseId: c.id, initial: c.notes),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.docId});

  final String docId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final d = store.doc(docId);
    if (d == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => ReaderScreen(docId: d.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 44, height: 60, child: DocCover(doc: d)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.hasStarted
                          ? 'Page ${d.lastPage} of ${d.pageCount}'
                          : d.category.label,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: d.progress),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from course',
                icon: const Icon(Icons.link_off_rounded),
                onPressed: () => store.setDocCourse(d.id, null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free-form notes saved shortly after you stop typing.
class _NotesField extends StatefulWidget {
  const _NotesField({required this.courseId, required this.initial});

  final String courseId;
  final String initial;

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  Timer? _timer;
  late final LibraryStore _store;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _store = StoreScope.read(context);
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    _store.updateCourse(widget.courseId, notes: _controller.text);
  }

  @override
  void dispose() {
    if (_timer != null) {
      final id = widget.courseId, notes = _controller.text, store = _store;
      // Notifying while the tree unmounts is unsafe, so defer it.
      scheduleMicrotask(() => store.updateCourse(id, notes: notes));
    }
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 4,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Key points, exam tips, questions for the lecturer…',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      onChanged: (_) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 600), _flush);
      },
    );
  }
}
