import 'dart:convert';

import 'academic_models.dart';
import 'library_store.dart';
import 'reminder_planner.dart' show ReminderTabs;

/// The home-screen widgets Semesta offers.
enum WidgetKind {
  nextUp(
    'nextUp',
    'Next up',
    'Your next class or exam, with a tap into its material.',
  ),
  today('today', 'Today', 'Classes, study sessions and deadlines for today.'),
  deadlines('deadlines', 'Deadlines', 'Your next assignment deadlines.'),
  continueReading(
    'continueReading',
    'Continue reading',
    'Jump back into what you were reading.',
  );

  const WidgetKind(this.id, this.label, this.description);

  /// Stable name shared with the Android side.
  final String id;
  final String label;
  final String description;
}

/// Keys of the values handed to the Android widgets (each a JSON string).
abstract final class WidgetKeys {
  static const nextUp = 'nextup';
  static const today = 'today';
  static const deadlines = 'deadlines';
  static const continueReading = 'continue';
}

String _time(DateTime t, bool use24h) {
  final m = t.minute.toString().padLeft(2, '0');
  if (use24h) return '${t.hour.toString().padLeft(2, '0')}:$m';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Thu 22 Oct". Absolute, so it never goes stale on the home screen.
String _date(DateTime d) =>
    '${weekdayShort[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1].substring(0, 3)}';

String _docPayload(MaterialLink l) => 'doc:${l.docId}:${l.page ?? 0}';

/// Builds everything the widgets show, from [now].
///
/// Widgets can't run Dart, and the app may not be opened for hours, so this
/// hands over a *timeline* (several upcoming entries with start and end
/// times). The Android side picks the entry that is current whenever it
/// redraws. All text is formatted here, using absolute dates and times.
Map<String, String> buildWidgetData(
  LibraryStore store,
  DateTime now, {
  bool use24h = false,
}) {
  String? material(MaterialLink? l) {
    if (l == null) return null;
    final doc = store.doc(l.docId);
    if (doc == null) return null;
    return doc.title;
  }

  String payloadFor(MaterialLink? l, int fallbackTab) =>
      l != null && store.doc(l.docId) != null
      ? _docPayload(l)
      : 'tab:$fallbackTab';

  // Next up: classes and exams.
  final nextUp = [
    for (final o in store.upcoming(now, count: 12, lookaheadDays: 14))
      () {
        final e = o.event;
        final course = store.course(e.courseId);
        return {
          'title': e.title,
          'subtitle': [
            ?course?.name,
            if (e.location.isNotEmpty) e.location,
            ?material(e.link),
          ].join(' · '),
          'when':
              '${_date(o.start)} · ${_time(o.start, use24h)}–${_time(o.end, use24h)}',
          'kind': e.kind == EventKind.exam ? 'exam' : 'class',
          'startMs': o.start.millisecondsSinceEpoch,
          'endMs': o.end.millisecondsSinceEpoch,
          'payload': payloadFor(e.link, ReminderTabs.calendar),
        };
      }(),
  ];

  // Today: three days of items; the widget shows whichever day it is when it
  // redraws, so it stays right across midnight.
  final today = <Map<String, Object>>[];
  final first = dateOnly(now);
  for (var i = 0; i < 3; i++) {
    final day = addDays(first, i);
    final items = <(DateTime, Map<String, Object>)>[];
    for (final o in store.occurrencesOn(day)) {
      items.add((
        o.start,
        {
          'title': o.event.title,
          'time': _time(o.start, use24h),
          'kind': o.event.kind == EventKind.exam ? 'exam' : 'class',
          'startMs': o.start.millisecondsSinceEpoch,
          'endMs': o.end.millisecondsSinceEpoch,
          'payload': payloadFor(o.event.link, ReminderTabs.calendar),
        },
      ));
    }
    for (final s in store.sessionsOn(day)) {
      if (s.done) continue;
      items.add((
        s.start,
        {
          'title': s.title,
          'time': _time(s.start, use24h),
          'kind': 'study',
          'startMs': s.start.millisecondsSinceEpoch,
          'endMs': s.end.millisecondsSinceEpoch,
          'payload': payloadFor(s.link, ReminderTabs.plan),
        },
      ));
    }
    for (final a in store.assignmentsDueOn(day)) {
      if (a.done) continue;
      items.add((
        a.due,
        {
          'title': a.title,
          'time': _time(a.due, use24h),
          'kind': 'due',
          'startMs': a.due.millisecondsSinceEpoch,
          'endMs': a.due.millisecondsSinceEpoch,
          'payload': payloadFor(a.link, ReminderTabs.courses),
        },
      ));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    today.addAll(items.take(12).map((e) => e.$2));
  }

  // Deadlines.
  final deadlines = [
    for (final a in store.openAssignmentsFrom(
      now.subtract(const Duration(days: 1)),
      count: 8,
    ))
      {
        'title': a.title,
        'subtitle': store.course(a.courseId)?.name ?? '',
        'when': '${_date(a.due)} · ${_time(a.due, use24h)}',
        'dueMs': a.due.millisecondsSinceEpoch,
        'payload': payloadFor(a.link, ReminderTabs.courses),
      },
  ];

  // Continue reading.
  final doc = store.continueReading;
  final cont = doc == null
      ? <String, Object>{}
      : {
          'title': doc.title,
          'subtitle': 'Page ${doc.lastPage} of ${doc.pageCount}',
          'progress': (doc.progress * 100).round(),
          'payload': 'doc:${doc.id}:0',
        };

  return {
    WidgetKeys.nextUp: jsonEncode(nextUp),
    WidgetKeys.today: jsonEncode(today),
    WidgetKeys.deadlines: jsonEncode(deadlines),
    WidgetKeys.continueReading: jsonEncode(cont),
  };
}

// ---- reading the data back ---------------------------------------------------
//
// The Android widgets apply these same rules in Kotlin (WidgetData.kt) each
// time they redraw. The in-app previews use these Dart versions.

List<Map<String, dynamic>> _entries(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic>) e,
    ];
  } catch (_) {
    return const [];
  }
}

/// The first next-up entry that hasn't finished by [nowMs], or null.
Map<String, dynamic>? currentNextUp(Map<String, String> data, int nowMs) {
  for (final e in _entries(data[WidgetKeys.nextUp])) {
    final end = e['endMs'];
    if (end is int && end > nowMs) return e;
  }
  return null;
}

/// Entries for the calendar day that contains [now], in time order.
List<Map<String, dynamic>> todayEntries(
  Map<String, String> data,
  DateTime now,
) {
  final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final end = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
  return [
    for (final e in _entries(data[WidgetKeys.today]))
      if (e['startMs'] is int &&
          (e['startMs'] as int) >= start &&
          (e['startMs'] as int) < end)
        e,
  ];
}

/// Up to [max] deadlines. Each has an `overdue` flag relative to [nowMs].
List<Map<String, dynamic>> deadlineEntries(
  Map<String, String> data,
  int nowMs, {
  int max = 4,
}) {
  final out = <Map<String, dynamic>>[];
  for (final e in _entries(data[WidgetKeys.deadlines])) {
    final due = e['dueMs'];
    if (due is! int) continue;
    out.add({...e, 'overdue': due < nowMs});
    if (out.length == max) break;
  }
  return out;
}

/// The continue-reading entry, or null when there is nothing to continue.
Map<String, dynamic>? continueEntry(Map<String, String> data) {
  final json = data[WidgetKeys.continueReading];
  if (json == null || json.isEmpty) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic> && decoded.isNotEmpty) return decoded;
  } catch (_) {}
  return null;
}
