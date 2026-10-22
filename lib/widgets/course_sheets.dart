import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/store_scope.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import 'material_link.dart';
import 'pickers.dart';

/// Create or edit a course.
Future<Course?> showCourseEditor(BuildContext context, {Course? existing}) {
  return showModalBottomSheet<Course>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CourseEditor(existing: existing),
  );
}

class _CourseEditor extends StatefulWidget {
  const _CourseEditor({this.existing});

  final Course? existing;

  @override
  State<_CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<_CourseEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  )..addListener(() => setState(() {}));
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _instructor = TextEditingController(
    text: widget.existing?.instructor ?? '',
  );
  late int _color = widget.existing?.colorIndex ?? 1;
  late String _icon = widget.existing?.iconKey ?? 'school';

  bool get _editing => widget.existing != null;
  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _instructor.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    final store = StoreScope.read(context);
    final Course result;
    if (_editing) {
      store.updateCourse(
        widget.existing!.id,
        name: _name.text,
        code: _code.text,
        instructor: _instructor.text,
        colorIndex: _color,
        iconKey: _icon,
      );
      result = store.course(widget.existing!.id)!;
    } else {
      result = store.addCourse(
        name: _name.text,
        code: _code.text,
        instructor: _instructor.text,
        colorIndex: _color,
        iconKey: _icon,
      );
    }
    Navigator.pop(context, result);
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
            Text(
              _editing ? 'Edit course' : 'New course',
              style: text.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Course name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _instructor,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Instructor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Colour', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 1; i < AccentPalette.colors.length; i++)
                  _Swatch(
                    color: AccentPalette.colors[i],
                    selected: _color == i,
                    label: 'Colour $i',
                    onTap: () => setState(() => _color = i),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Icon', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in CourseIcons.all.entries)
                  ChoiceChip(
                    showCheckmark: false,
                    label: Icon(e.value, size: 22),
                    selected: _icon == e.key,
                    selectedColor: AccentPalette.colors[_color],
                    labelStyle: TextStyle(
                      color: _icon == e.key
                          ? AccentPalette.on(AccentPalette.colors[_color])
                          : scheme.onSurface,
                    ),
                    onSelected: (_) => setState(() => _icon = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid ? _save : null,
                child: Text(_editing ? 'Save' : 'Create course'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.label,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.short4),
          curve: Motion.emphasized,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.onSurface : Colors.transparent,
              width: 3,
            ),
          ),
          child: AnimatedScale(
            scale: selected ? 1 : 0,
            duration: Motion.of(context, Motion.short4),
            curve: Motion.emphasized,
            child: Icon(Icons.check_rounded, color: AccentPalette.on(color)),
          ),
        ),
      ),
    );
  }
}

/// Create or edit an assignment for [courseId].
Future<void> showAssignmentEditor(
  BuildContext context, {
  required String courseId,
  Assignment? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AssignmentEditor(courseId: courseId, existing: existing),
  );
}

class _AssignmentEditor extends StatefulWidget {
  const _AssignmentEditor({required this.courseId, this.existing});

  final String courseId;
  final Assignment? existing;

  @override
  State<_AssignmentEditor> createState() => _AssignmentEditorState();
}

class _AssignmentEditorState extends State<_AssignmentEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  )..addListener(() => setState(() {}));
  late DateTime _due = widget.existing?.due ?? _defaultDue();
  late MaterialLink? _link = widget.existing?.link;

  static DateTime _defaultDue() {
    final t = addDays(dateOnly(DateTime.now()), 7);
    return DateTime(t.year, t.month, t.day, 23, 59);
  }

  bool get _editing => widget.existing != null;
  bool get _valid => _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    final store = StoreScope.read(context);
    if (_editing) {
      store.replaceAssignment(
        widget.existing!.copyWith(
          title: _title.text.trim(),
          due: _due,
          link: _link,
          clearLink: _link == null,
        ),
      );
    } else {
      store.addAssignment(
        courseId: widget.courseId,
        title: _title.text,
        due: _due,
        link: _link,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _editing ? 'Edit assignment' : 'New assignment',
              style: text.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Due', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DatePickerButton(
                  value: _due,
                  onChanged: (d) => setState(() => _due = d),
                ),
                TimePickerButton(
                  value: _due,
                  onChanged: (d) => setState(() => _due = d),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Related material', style: text.labelLarge),
            const SizedBox(height: 8),
            MaterialLinkField(
              value: _link,
              preferredCourseId: widget.courseId,
              onChanged: (l) => setState(() => _link = l),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid ? _save : null,
                child: Text(_editing ? 'Save' : 'Add assignment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Choose which library documents belong to [course].
Future<void> showCourseMaterialsPicker(BuildContext context, Course course) {
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .65,
      minChildSize: .4,
      maxChildSize: .92,
      builder: (context, controller) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final docs = store.docsSorted();
          final text = Theme.of(context).textTheme;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Materials for ${course.name}',
                    style: text.titleLarge,
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
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final here = d.courseId == course.id;
                          final other = store.course(d.courseId);
                          return CheckboxListTile(
                            value: here,
                            controlAffinity: ListTileControlAffinity.trailing,
                            secondary: Icon(d.category.icon),
                            title: Text(
                              d.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: other != null && !here
                                ? Text('Currently in ${other.name}')
                                : Text(d.category.label),
                            onChanged: (v) => store.setDocCourse(
                              d.id,
                              v == true ? course.id : null,
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
