import 'academic_models.dart';
import 'library_store.dart';

/// The kinds of reminder, which also pick the notification channel.
enum ReminderKind {
  classStart('classes', 'Classes and exams'),
  study('study', 'Study sessions'),
  deadline('deadlines', 'Deadlines'),
  digest('digest', 'Daily summary');

  const ReminderKind(this.channelId, this.channelName);

  final String channelId;
  final String channelName;
}

/// One notification to schedule.
class ReminderSpec {
  const ReminderSpec({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
  });

  final int id;
  final ReminderKind kind;
  final String title;
  final String body;
  final DateTime when;

  /// What to open when tapped; see [parseReminderPayload].
  final String payload;

  /// Compact text used to tell whether the schedule changed.
  String get signature =>
      '$id|${when.millisecondsSinceEpoch}|$title|$body|$payload';
}

/// Where a tapped reminder should take the user.
class ReminderTarget {
  const ReminderTarget({this.tab, this.docId, this.page});

  /// Navigation tab: 0 Library, 1 Courses, 2 Calendar, 3 Plan.
  final int? tab;
  final String? docId;
  final int? page;
}

abstract final class ReminderTabs {
  static const library = 0;
  static const courses = 1;
  static const calendar = 2;
  static const plan = 3;
}

/// Parses `tab:2` or `doc:ID:PAGE` (page 0 means the saved position).
ReminderTarget? parseReminderPayload(String? payload) {
  if (payload == null) return null;
  final parts = payload.split(':');
  if (parts.length == 2 && parts[0] == 'tab') {
    final t = int.tryParse(parts[1]);
    return t == null ? null : ReminderTarget(tab: t);
  }
  if (parts.length >= 3 && parts[0] == 'doc') {
    // The id may contain ':'? Ours don't, but be safe: page is the last part.
    final page = int.tryParse(parts.last);
    final id = parts.sublist(1, parts.length - 1).join(':');
    if (id.isEmpty) return null;
    return ReminderTarget(
      docId: id,
      page: (page == null || page < 1) ? null : page,
    );
  }
  return null;
}

String _docPayload(MaterialLink l) => 'doc:${l.docId}:${l.page ?? 0}';

/// Stable positive 31-bit id for a reminder key (FNV-1a), so the same
/// occurrence always gets the same notification id.
int reminderId(String key) {
  var h = 0x811c9dc5;
  for (final c in key.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

String _time(DateTime t, bool use24h) {
  final m = t.minute.toString().padLeft(2, '0');
  if (use24h) return '${t.hour.toString().padLeft(2, '0')}:$m';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _day(DateTime d, DateTime now) {
  final diff = dateOnly(d).difference(dateOnly(now)).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  return '${weekdayLong[d.weekday - 1]} ${d.day} ${monthNames[d.month - 1].substring(0, 3)}';
}

String _lead(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  return h == 1 ? '1 hour' : '$h hours';
}

/// Works out every notification that should be scheduled from [now] over the
/// next [horizonDays], soonest first, at most [maxCount].
///
/// Reminders that would already have fired are left out. Reminders are
/// rebuilt from scratch whenever the data or settings change, so deleted or
/// finished items never fire.
List<ReminderSpec> planReminders(
  LibraryStore store,
  DateTime now, {
  int horizonDays = 14,
  int maxCount = 120,
  bool use24h = false,
}) {
  final s = store.reminders;
  if (!s.enabled) return const [];

  final out = <ReminderSpec>[];
  final cutoff = now.add(const Duration(minutes: 1));
  void add(ReminderSpec spec) {
    if (spec.when.isAfter(cutoff)) out.add(spec);
  }

  String? material(MaterialLink? l) {
    if (l == null) return null;
    final doc = store.doc(l.docId);
    if (doc == null) return null;
    return l.page == null ? doc.title : '${doc.title}, p. ${l.page}';
  }

  final today = dateOnly(now);
  final lastDay = addDays(today, horizonDays);

  for (var d = today; !d.isAfter(lastDay); d = addDays(d, 1)) {
    final occ = store.occurrencesOn(d);

    for (final o in occ) {
      final e = o.event;
      final course = store.course(e.courseId);
      final place = e.location.isEmpty ? null : e.location;
      final link = material(e.link);
      final key = '${e.id}@${o.start.millisecondsSinceEpoch}';

      if (e.kind == EventKind.exam) {
        if (!s.exams) continue;
        final when = o.start.subtract(Duration(hours: s.examLeadHours));
        add(
          ReminderSpec(
            id: reminderId('exam:$key'),
            kind: ReminderKind.classStart,
            title: 'Exam ${_day(o.start, when)}: ${e.title}',
            body: [
              '${_time(o.start, use24h)}–${_time(o.end, use24h)}',
              ?place,
              ?course?.name,
            ].join(' · '),
            when: when,
            payload: 'tab:${ReminderTabs.calendar}',
          ),
        );
      } else if (s.classes) {
        final when = o.start.subtract(Duration(minutes: s.classLeadMin));
        add(
          ReminderSpec(
            id: reminderId('class:$key'),
            kind: ReminderKind.classStart,
            title: '${e.title} in ${_lead(s.classLeadMin)}',
            body: [
              _time(o.start, use24h),
              ?place,
              if (link != null) 'Tap to open $link',
            ].join(' · '),
            when: when,
            payload: e.link != null && link != null
                ? _docPayload(e.link!)
                : 'tab:${ReminderTabs.calendar}',
          ),
        );
      }
    }

    if (s.study) {
      for (final x in store.sessionsOn(d)) {
        if (x.done) continue;
        final link = material(x.link);
        add(
          ReminderSpec(
            id: reminderId('study:${x.id}@${x.start.millisecondsSinceEpoch}'),
            kind: ReminderKind.study,
            title: 'Study time in ${_lead(s.studyLeadMin)}',
            body: [
              x.title,
              '${_time(x.start, use24h)}–${_time(x.end, use24h)}',
              ?link,
            ].join(' · '),
            when: x.start.subtract(Duration(minutes: s.studyLeadMin)),
            payload: x.link != null && link != null
                ? _docPayload(x.link!)
                : 'tab:${ReminderTabs.plan}',
          ),
        );
      }
    }

    if (s.digest) {
      final when = DateTime(
        d.year,
        d.month,
        d.day,
        s.digestMinute ~/ 60,
        s.digestMinute % 60,
      );
      final classes = occ.where((o) => o.event.kind != EventKind.exam).toList();
      final exams = occ.where((o) => o.event.kind == EventKind.exam).toList();
      final study = store.sessionsOn(d).where((x) => !x.done).toList();
      final due = store.assignmentsDueOn(d).where((a) => !a.done).toList();
      final parts = <String>[
        if (exams.isNotEmpty)
          '${exams.length} ${exams.length == 1 ? 'exam' : 'exams'}',
        if (classes.isNotEmpty)
          '${classes.length} ${classes.length == 1 ? 'class' : 'classes'}',
        if (study.isNotEmpty)
          '${study.length} study ${study.length == 1 ? 'session' : 'sessions'}',
        if (due.isNotEmpty) '${due.length} due',
      ];
      if (parts.isNotEmpty) {
        final first = [
          for (final o in [...exams, ...classes].take(3))
            '${_time(o.start, use24h)} ${o.event.title}',
        ];
        add(
          ReminderSpec(
            id: reminderId('digest:${d.millisecondsSinceEpoch}'),
            kind: ReminderKind.digest,
            title: 'Today: ${parts.join(', ')}',
            body: first.isEmpty
                ? 'Open Semesta to see your day.'
                : first.join(' · '),
            when: when,
            payload: 'tab:${ReminderTabs.calendar}',
          ),
        );
      }
    }
  }

  if (s.deadlines) {
    for (final a in store.assignments) {
      if (a.done) continue;
      if (a.due.isAfter(lastDay.add(Duration(hours: s.deadlineLeadHours)))) {
        continue;
      }
      final course = store.course(a.courseId);
      final link = material(a.link);
      add(
        ReminderSpec(
          id: reminderId('due:${a.id}@${a.due.millisecondsSinceEpoch}'),
          kind: ReminderKind.deadline,
          title:
              'Due ${_day(a.due, a.due.subtract(Duration(hours: s.deadlineLeadHours)))}: ${a.title}',
          body: [_time(a.due, use24h), ?course?.name, ?link].join(' · '),
          when: a.due.subtract(Duration(hours: s.deadlineLeadHours)),
          payload: a.link != null && link != null
              ? _docPayload(a.link!)
              : 'tab:${ReminderTabs.courses}',
        ),
      );
    }
  }

  out.sort((a, b) {
    final c = a.when.compareTo(b.when);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  // Same occurrence can't appear twice, but guard against id clashes.
  final seen = <int>{};
  final unique = [
    for (final r in out)
      if (seen.add(r.id)) r,
  ];
  return unique.length <= maxCount ? unique : unique.sublist(0, maxCount);
}
