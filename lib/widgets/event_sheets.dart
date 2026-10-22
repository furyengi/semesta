import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/store_scope.dart';
import 'format.dart';
import 'material_link.dart';
import 'pickers.dart';

/// Read-only details with edit/delete, shown when you tap an event.
Future<void> showEventDetails(BuildContext context, Occurrence occurrence) {
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final e = occurrence.event;
      final course = store.course(e.courseId);
      final text = Theme.of(sheetContext).textTheme;
      final scheme = Theme.of(sheetContext).colorScheme;
      final label = materialLabel(store, e.link);
      final repeat = !e.weekly
          ? null
          : 'Repeats every ${weekdayLong[e.start.weekday - 1]}'
                '${e.until == null ? '' : ' until ${formatShortDate(e.until!)}'}';
      Widget row(IconData icon, String value) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(child: Text(value, style: text.bodyLarge)),
          ],
        ),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(e.kind.icon, color: course?.color ?? scheme.primary),
                const SizedBox(width: 8),
                Text(e.kind.label.toUpperCase(), style: text.labelSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(e.title, style: text.headlineSmall),
            row(
              Icons.schedule_rounded,
              '${weekdayLong[occurrence.start.weekday - 1]} ${occurrence.start.day} '
              '${monthNames[occurrence.start.month - 1]}, '
              '${formatTimeRange(sheetContext, occurrence.start, occurrence.end)}',
            ),
            if (repeat != null) row(Icons.repeat_rounded, repeat),
            if (course != null) row(Icons.school_outlined, course.name),
            if (e.location.isNotEmpty) row(Icons.place_outlined, e.location),
            if (label != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    openMaterial(context, e.link!);
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(
                    'Open $label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: sheetContext,
                      builder: (context) => AlertDialog(
                        title: Text(
                          e.weekly
                              ? 'Delete this class?'
                              : 'Delete this event?',
                        ),
                        content: Text(
                          e.weekly
                              ? 'Every weekly occurrence of "${e.title}" will be removed.'
                              : '"${e.title}" will be removed.',
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
                      store.removeEvent(e.id);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showEventEditor(context, existing: e);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Add a new event on [day], or edit [existing].
Future<void> showEventEditor(
  BuildContext context, {
  ScheduleEvent? existing,
  DateTime? day,
  String? courseId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _EventEditor(existing: existing, day: day, courseId: courseId),
  );
}

class _EventEditor extends StatefulWidget {
  const _EventEditor({this.existing, this.day, this.courseId});

  final ScheduleEvent? existing;
  final DateTime? day;
  final String? courseId;

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  )..addListener(() => setState(() {}));
  late final TextEditingController _location = TextEditingController(
    text: widget.existing?.location ?? '',
  );
  late EventKind _kind = widget.existing?.kind ?? EventKind.lecture;
  late String? _courseId = widget.existing?.courseId ?? widget.courseId;
  late DateTime _start = widget.existing?.start ?? _defaultStart();
  late DateTime _end = _start.add(
    Duration(minutes: widget.existing?.durationMin ?? 60),
  );
  late bool _weekly = widget.existing?.weekly ?? false;
  late DateTime? _until = widget.existing?.until;
  late MaterialLink? _link = widget.existing?.link;

  DateTime _defaultStart() {
    final d = widget.day ?? DateTime.now();
    final now = DateTime.now();
    final hour = sameDay(d, now) ? (now.hour + 1).clamp(7, 21) : 9;
    return DateTime(d.year, d.month, d.day, hour);
  }

  bool get _editing => widget.existing != null;
  bool get _timesOk => _end.isAfter(_start);
  bool get _valid =>
      (_title.text.trim().isNotEmpty || _courseId != null) && _timesOk;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  void _setStart(DateTime s) {
    final length = _end.difference(_start);
    setState(() {
      _start = s;
      _end = s.add(length);
    });
  }

  void _save() {
    if (!_valid) return;
    final store = StoreScope.read(context);
    final course = store.course(_courseId);
    final title = _title.text.trim().isEmpty
        ? '${course?.name ?? ''} ${_kind.label}'.trim()
        : _title.text.trim();
    final minutes = _end.difference(_start).inMinutes;
    if (_editing) {
      store.replaceEvent(
        widget.existing!.copyWith(
          title: title,
          kind: _kind,
          courseId: _courseId,
          clearCourse: _courseId == null,
          start: _start,
          durationMin: minutes,
          weekly: _weekly,
          until: _weekly ? _until : null,
          clearUntil: !_weekly || _until == null,
          location: _location.text.trim(),
          link: _link,
          clearLink: _link == null,
        ),
      );
    } else {
      store.addEvent(
        title: title,
        kind: _kind,
        start: _start,
        durationMin: minutes,
        courseId: _courseId,
        weekly: _weekly,
        until: _until,
        location: _location.text,
        link: _link,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final courses = store.courses;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_editing ? 'Edit event' : 'New event', style: text.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in EventKind.values)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(k.icon, size: 18),
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: _courseId == null
                    ? null
                    : 'Defaults to the course name',
                border: const OutlineInputBorder(),
              ),
            ),
            if (courses.isNotEmpty) ...[
              const SizedBox(height: 16),
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
                  for (final c in courses)
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
            const SizedBox(height: 16),
            Text('When', style: text.labelLarge),
            const SizedBox(height: 8),
            DatePickerButton(value: _start, onChanged: _setStart),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TimePickerButton(value: _start, onChanged: _setStart),
                Text('to', style: text.bodyMedium),
                TimePickerButton(
                  value: _end,
                  onChanged: (t) => setState(
                    () => _end = DateTime(
                      _start.year,
                      _start.month,
                      _start.day,
                      t.hour,
                      t.minute,
                    ),
                  ),
                ),
              ],
            ),
            if (!_timesOk)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'The end time must be after the start time.',
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Repeat every ${weekdayLong[_start.weekday - 1]}'),
              value: _weekly,
              onChanged: (v) => setState(() => _weekly = v),
            ),
            if (_weekly)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    DatePickerButton(
                      label: 'Until',
                      value: _until ?? addDays(_start, 7 * 12),
                      onChanged: (d) => setState(() => _until = d),
                    ),
                    if (_until != null)
                      TextButton(
                        onPressed: () => setState(() => _until = null),
                        child: const Text('No end date'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Material for this event', style: text.labelLarge),
            const SizedBox(height: 8),
            MaterialLinkField(
              value: _link,
              preferredCourseId: _courseId,
              onChanged: (l) => setState(() => _link = l),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid ? _save : null,
                child: Text(_editing ? 'Save' : 'Add to calendar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
