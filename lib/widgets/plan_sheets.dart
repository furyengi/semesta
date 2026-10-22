import 'package:flutter/material.dart';

import '../data/academic_models.dart';
import '../data/plan_generator.dart';
import '../data/store_scope.dart';
import 'format.dart';
import 'material_link.dart';
import 'pickers.dart';

/// Create a study plan, optionally for a known exam or deadline.
/// Returns the new goal, or null if cancelled.
Future<StudyGoal?> showPlanWizard(BuildContext context, {PlanTarget? target}) {
  return showModalBottomSheet<StudyGoal>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PlanWizard(target: target),
  );
}

class _PlanWizard extends StatefulWidget {
  const _PlanWizard({this.target});

  final PlanTarget? target;

  @override
  State<_PlanWizard> createState() => _PlanWizardState();
}

class _PlanWizardState extends State<_PlanWizard> {
  static const _lengths = [30, 45, 60, 90, 120];

  late final TextEditingController _title = TextEditingController(
    text: widget.target?.title ?? '',
  )..addListener(() => setState(() {}));
  final _lastPage = TextEditingController();

  PlanTarget? _picked;
  late String? _courseId = widget.target?.courseId;
  late DateTime _date =
      widget.target?.date ??
      (() {
        final d = addDays(dateOnly(DateTime.now()), 14);
        return DateTime(d.year, d.month, d.day, 9);
      })();
  double _hours = 6;
  int _session = 60;
  Set<int> _days = {1, 2, 3, 4, 5};
  DateTime _startTime = DateTime(2000, 1, 1, 18);
  MaterialLink? _link;

  @override
  void initState() {
    super.initState();
    _picked = widget.target;
  }

  @override
  void dispose() {
    _title.dispose();
    _lastPage.dispose();
    super.dispose();
  }

  int get _startMinute => _startTime.hour * 60 + _startTime.minute;
  int? get _last => int.tryParse(_lastPage.text);

  List<PlannedSession> _preview() {
    final store = StoreScope.read(context);
    return store.previewPlan(
      title: _title.text.trim().isEmpty ? 'Study' : _title.text.trim(),
      target: _date,
      totalMinutes: (_hours * 60).round(),
      sessionMinutes: _session,
      weekdays: _days,
      startMinute: _startMinute,
      firstPage: _link?.page,
      lastPage: _link == null ? null : _last,
    );
  }

  bool get _valid => _title.text.trim().isNotEmpty && _days.isNotEmpty;

  void _pick(PlanTarget? t) {
    setState(() {
      _picked = t;
      if (t != null) {
        _title.text = t.title;
        _courseId = t.courseId;
        _date = t.date;
      }
    });
  }

  void _create(List<PlannedSession> preview) {
    if (!_valid) return;
    final store = StoreScope.read(context);
    final goal = store.createPlan(
      title: _title.text,
      target: _date,
      totalMinutes: (_hours * 60).round(),
      sessionMinutes: _session,
      weekdays: _days,
      startMinute: _startMinute,
      courseId: _courseId,
      sourceId: _picked?.sourceId,
      docId: _link?.docId,
      firstPage: _link?.page,
      lastPage: _link == null ? null : _last,
    );
    Navigator.pop(context, goal);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final targets = store.unplannedTargets(DateTime.now(), withinDays: 60);
    final preview = _valid ? _preview() : const <PlannedSession>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New study plan', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Semesta spreads your revision over the days before the date, around your classes.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text('What are you preparing for?', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in targets)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      t.isExam ? Icons.quiz_outlined : Icons.flag_outlined,
                      size: 18,
                    ),
                    label: Text('${t.title} · ${formatShortDate(t.date)}'),
                    selected:
                        _picked?.sourceId == t.sourceId && _picked != null,
                    onSelected: (_) => _pick(t),
                  ),
                ChoiceChip(
                  showCheckmark: false,
                  avatar: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Something else'),
                  selected: _picked == null,
                  onSelected: (_) => _pick(null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Plan name',
                border: OutlineInputBorder(),
              ),
            ),
            if (store.courses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('No course'),
                    selected: _courseId == null,
                    onSelected: (_) => setState(() => _courseId = null),
                  ),
                  for (final c in store.courses)
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
            Text('Date of the exam or deadline', style: text.labelLarge),
            const SizedBox(height: 8),
            DatePickerButton(
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text('Total study time', style: text.labelLarge),
                ),
                Text(formatHoursValue(_hours), style: text.titleSmall),
              ],
            ),
            Slider(
              min: 1,
              max: 40,
              divisions: 39,
              value: _hours,
              label: formatHoursValue(_hours),
              onChanged: (v) => setState(() => _hours = v),
            ),
            Text('Session length', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _lengths)
                  ChoiceChip(
                    label: Text(formatDuration(m)),
                    selected: _session == m,
                    onSelected: (_) => setState(() => _session = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Study on', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(weekdayShort[d - 1]),
                    selected: _days.contains(d),
                    onSelected: (v) => setState(() {
                      _days = {..._days};
                      v ? _days.add(d) : _days.remove(d);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('Start around', style: text.bodyMedium),
                TimePickerButton(
                  value: _startTime,
                  onChanged: (t) => setState(() => _startTime = t),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Reading to cover (optional)', style: text.labelLarge),
            const SizedBox(height: 8),
            MaterialLinkField(
              value: _link,
              preferredCourseId: _courseId,
              onChanged: (l) => setState(() => _link = l),
            ),
            if (_link != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Enter the first page above and the last page here; each session gets its own share.',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _lastPage,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Last page',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            _PreviewBox(preview: preview, valid: _valid),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid ? () => _create(preview) : null,
                child: const Text('Create plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatHoursValue(double hours) => '${hours.round()} h';

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.preview, required this.valid});

  final List<PlannedSession> preview;
  final bool valid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final String message;
    final bool warn;
    if (!valid) {
      message = 'Name your plan and pick at least one day.';
      warn = false;
    } else if (preview.isEmpty) {
      message = 'No available day before that date. Move the date later or allow more days.';
      warn = true;
    } else {
      final first = preview.first.start, last = preview.last.start;
      message =
          '${preview.length} ${preview.length == 1 ? 'session' : 'sessions'}, '
          '${formatShortDate(first)} to ${formatShortDate(last)}';
      warn = false;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: warn ? scheme.errorContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              warn ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
              size: 20,
              color: warn ? scheme.onErrorContainer : scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: warn ? scheme.onErrorContainer : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add a session to a plan (or on its own), or reschedule [existing].
Future<void> showSessionEditor(
  BuildContext context, {
  StudySession? existing,
  String? goalId,
  DateTime? day,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _SessionEditor(existing: existing, goalId: goalId, day: day),
  );
}

class _SessionEditor extends StatefulWidget {
  const _SessionEditor({this.existing, this.goalId, this.day});

  final StudySession? existing;
  final String? goalId;
  final DateTime? day;

  @override
  State<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<_SessionEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  )..addListener(() => setState(() {}));
  late DateTime _start = widget.existing?.start ?? _defaultStart();
  late int _minutes = widget.existing?.durationMin ?? 60;
  late MaterialLink? _link = widget.existing?.link;

  DateTime _defaultStart() {
    final d = widget.day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, 18);
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
      store.replaceSession(
        widget.existing!.copyWith(
          title: _title.text.trim(),
          start: _start,
          durationMin: _minutes,
          link: _link,
          clearLink: _link == null,
        ),
      );
    } else {
      store.addSession(
        title: _title.text,
        start: _start,
        durationMin: _minutes,
        goalId: widget.goalId,
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
              _editing ? 'Edit session' : 'New session',
              style: text.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What will you study?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('When', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DatePickerButton(
                  value: _start,
                  onChanged: (d) => setState(() => _start = d),
                ),
                TimePickerButton(
                  value: _start,
                  onChanged: (d) => setState(() => _start = d),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Length', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in const [15, 30, 45, 60, 90, 120])
                  ChoiceChip(
                    label: Text(formatDuration(m)),
                    selected: _minutes == m,
                    onSelected: (_) => setState(() => _minutes = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Material', style: text.labelLarge),
            const SizedBox(height: 8),
            MaterialLinkField(
              value: _link,
              preferredCourseId:
                  widget.existing?.courseId ??
                  StoreScope.read(context).goal(widget.goalId)?.courseId,
              onChanged: (l) => setState(() => _link = l),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid ? _save : null,
                child: Text(_editing ? 'Save' : 'Add session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
