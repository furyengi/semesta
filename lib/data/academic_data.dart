import 'package:flutter/foundation.dart';

import 'academic_models.dart';
import 'plan_generator.dart';

/// Courses, timetable and assignments. Mixed into the library store so one
/// store (and one persistence path) serves the whole app.
mixin AcademicData on ChangeNotifier {
  final List<Course> _courses = [];
  final List<ScheduleEvent> _events = [];
  final List<Assignment> _assignments = [];
  final List<StudyGoal> _goals = [];
  final List<StudySession> _sessions = [];
  int _academicIds = 0;

  /// Called after any change so the host can notify and persist.
  @protected
  void commit();

  /// Called when a course is deleted so documents can drop their link.
  @protected
  void onCourseRemoved(String courseId);

  String _aid() =>
      '${DateTime.now().microsecondsSinceEpoch}-a${_academicIds++}';

  // ---- courses ------------------------------------------------------------

  List<Course> get courses => List.unmodifiable(_courses);

  Course? course(String? id) {
    if (id == null) return null;
    for (final c in _courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Course addCourse({
    required String name,
    required int colorIndex,
    required String iconKey,
    String code = '',
    String instructor = '',
  }) {
    final c = Course(
      id: _aid(),
      name: name.trim(),
      code: code.trim(),
      instructor: instructor.trim(),
      colorIndex: colorIndex,
      iconKey: iconKey,
      createdAt: DateTime.now(),
    );
    _courses.add(c);
    commit();
    return c;
  }

  void updateCourse(
    String id, {
    String? name,
    String? code,
    String? instructor,
    String? notes,
    int? colorIndex,
    String? iconKey,
  }) {
    final i = _courses.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _courses[i] = _courses[i].copyWith(
      name: (name?.trim().isEmpty ?? true) ? null : name!.trim(),
      code: code?.trim(),
      instructor: instructor?.trim(),
      notes: notes,
      colorIndex: colorIndex,
      iconKey: iconKey,
    );
    commit();
  }

  /// Removes the course with its events and assignments. Documents stay in
  /// the library, just unlinked.
  void removeCourse(String id) {
    if (course(id) == null) return;
    _courses.removeWhere((c) => c.id == id);
    _events.removeWhere((e) => e.courseId == id);
    _assignments.removeWhere((a) => a.courseId == id);
    final goalIds = _goals
        .where((g) => g.courseId == id)
        .map((g) => g.id)
        .toSet();
    _goals.removeWhere((g) => g.courseId == id);
    _sessions.removeWhere(
      (s) => goalIds.contains(s.goalId) || s.courseId == id,
    );
    onCourseRemoved(id);
    commit();
  }

  // ---- events -------------------------------------------------------------

  List<ScheduleEvent> get events => List.unmodifiable(_events);

  ScheduleEvent? event(String id) {
    for (final e in _events) {
      if (e.id == id) return e;
    }
    return null;
  }

  ScheduleEvent addEvent({
    required String title,
    required EventKind kind,
    required DateTime start,
    required int durationMin,
    String? courseId,
    bool weekly = false,
    DateTime? until,
    String location = '',
    MaterialLink? link,
  }) {
    final e = ScheduleEvent(
      id: _aid(),
      title: title.trim(),
      kind: kind,
      start: start,
      durationMin: durationMin < 1 ? 1 : durationMin,
      courseId: courseId,
      weekly: weekly,
      until: weekly && until != null ? dateOnly(until) : null,
      location: location.trim(),
      link: link,
    );
    _events.add(e);
    commit();
    return e;
  }

  void replaceEvent(ScheduleEvent updated) {
    final i = _events.indexWhere((e) => e.id == updated.id);
    if (i < 0) return;
    _events[i] = updated;
    commit();
  }

  void removeEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    commit();
  }

  /// Whether [e] happens on the calendar day [day].
  bool _occursOn(ScheduleEvent e, DateTime day) {
    final d = dateOnly(day);
    final first = dateOnly(e.start);
    if (!e.weekly) return sameDay(first, d);
    if (d.isBefore(first)) return false;
    if (e.until != null && d.isAfter(dateOnly(e.until!))) return false;
    return d.weekday == first.weekday;
  }

  Occurrence _at(ScheduleEvent e, DateTime day) => Occurrence(
    e,
    DateTime(day.year, day.month, day.day, e.start.hour, e.start.minute),
  );

  /// Everything happening on [day], earliest first.
  List<Occurrence> occurrencesOn(DateTime day) =>
      [
        for (final e in _events)
          if (_occursOn(e, day)) _at(e, day),
      ]..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : a.event.title.compareTo(b.event.title);
      });

  /// Days in [from]..[to] (inclusive) that have at least one occurrence.
  Set<DateTime> daysWithEvents(DateTime from, DateTime to) {
    final out = <DateTime>{};
    for (var d = dateOnly(from); !d.isAfter(to); d = addDays(d, 1)) {
      if (_events.any((e) => _occursOn(e, d))) out.add(d);
    }
    return out;
  }

  /// The next [count] occurrences starting at or after [from].
  List<Occurrence> upcoming(
    DateTime from, {
    int count = 3,
    String? courseId,
    int lookaheadDays = 90,
  }) {
    final out = <Occurrence>[];
    for (var i = 0; i <= lookaheadDays && out.length < count; i++) {
      final day = addDays(dateOnly(from), i);
      for (final o in occurrencesOn(day)) {
        if (courseId != null && o.event.courseId != courseId) continue;
        // Keep events that haven't finished yet.
        if (o.end.isAfter(from)) out.add(o);
        if (out.length == count) break;
      }
    }
    return out;
  }

  // ---- assignments --------------------------------------------------------

  List<Assignment> get assignments => List.unmodifiable(_assignments);

  /// Open assignments first (soonest due), then finished ones.
  List<Assignment> assignmentsFor(String courseId) =>
      _assignments.where((a) => a.courseId == courseId).toList()..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return a.due.compareTo(b.due);
      });

  List<Assignment> assignmentsDueOn(DateTime day) =>
      _assignments.where((a) => sameDay(a.due, day)).toList()
        ..sort((a, b) => a.due.compareTo(b.due));

  /// Not-yet-done assignments due from [from] on, soonest first.
  List<Assignment> openAssignmentsFrom(DateTime from, {int? count}) {
    final list =
        _assignments.where((a) => !a.done && !a.due.isBefore(from)).toList()
          ..sort((a, b) => a.due.compareTo(b.due));
    return count == null ? list : list.take(count).toList();
  }

  int openAssignmentCount(String courseId) =>
      _assignments.where((a) => a.courseId == courseId && !a.done).length;

  Assignment addAssignment({
    required String courseId,
    required String title,
    required DateTime due,
    MaterialLink? link,
  }) {
    final a = Assignment(
      id: _aid(),
      courseId: courseId,
      title: title.trim(),
      due: due,
      link: link,
    );
    _assignments.add(a);
    commit();
    return a;
  }

  void replaceAssignment(Assignment updated) {
    final i = _assignments.indexWhere((a) => a.id == updated.id);
    if (i < 0) return;
    _assignments[i] = updated;
    commit();
  }

  /// Puts an assignment back (used to undo a delete).
  void replaceAssignmentOrAdd(Assignment a) {
    final i = _assignments.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      _assignments[i] = a;
    } else {
      _assignments.add(a);
    }
    commit();
  }

  void toggleAssignment(String id) {
    final i = _assignments.indexWhere((a) => a.id == id);
    if (i < 0) return;
    _assignments[i] = _assignments[i].copyWith(done: !_assignments[i].done);
    commit();
  }

  void removeAssignment(String id) {
    _assignments.removeWhere((a) => a.id == id);
    commit();
  }

  // ---- study plans --------------------------------------------------------

  List<StudyGoal> get goals => List.unmodifiable(_goals);
  List<StudySession> get sessions => List.unmodifiable(_sessions);

  StudyGoal? goal(String? id) {
    if (id == null) return null;
    for (final g in _goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Plans that haven't passed their date yet first (soonest), then the rest.
  List<StudyGoal> goalsSorted(DateTime now) => _goals.toList()
    ..sort((a, b) {
      final ap = a.target.isBefore(now), bp = b.target.isBefore(now);
      if (ap != bp) return ap ? 1 : -1;
      return a.target.compareTo(b.target);
    });

  List<StudySession> sessionsFor(String goalId) =>
      _sessions.where((s) => s.goalId == goalId).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  List<StudySession> sessionsOn(DateTime day) =>
      _sessions.where((s) => sameDay(s.start, day)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  /// Past sessions that were never marked done, oldest first.
  List<StudySession> overdueSessions(DateTime now) =>
      _sessions.where((s) => !s.done && s.end.isBefore(now)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  PlanProgress planProgress(String goalId) {
    final list = sessionsFor(goalId);
    return PlanProgress(
      doneMinutes: list
          .where((s) => s.done)
          .fold(0, (a, s) => a + s.durationMin),
      plannedMinutes: list.fold(0, (a, s) => a + s.durationMin),
      doneCount: list.where((s) => s.done).length,
      count: list.length,
    );
  }

  PlanStatus planStatus(String goalId, DateTime now) {
    final list = sessionsFor(goalId);
    if (list.isNotEmpty && list.every((s) => s.done)) {
      return PlanStatus.complete;
    }
    final g = goal(goalId);
    if (g != null && g.target.isBefore(now)) return PlanStatus.past;
    return list.any((s) => !s.done && s.end.isBefore(now))
        ? PlanStatus.behind
        : PlanStatus.onTrack;
  }

  /// Minutes of finished study in the week starting [monday].
  int studiedMinutesInWeek(DateTime monday) {
    final end = addDays(monday, 7);
    return _sessions
        .where(
          (s) => s.done && !s.start.isBefore(monday) && s.start.isBefore(end),
        )
        .fold(0, (a, s) => a + s.durationMin);
  }

  /// (done, total) sessions in the week starting [monday].
  (int, int) sessionsInWeek(DateTime monday) {
    final end = addDays(monday, 7);
    final list = _sessions.where(
      (s) => !s.start.isBefore(monday) && s.start.isBefore(end),
    );
    return (list.where((s) => s.done).length, list.length);
  }

  /// Upcoming exams and open assignments within [withinDays] that have no
  /// plan yet, soonest first.
  List<PlanTarget> unplannedTargets(DateTime now, {int withinDays = 21}) {
    final planned = {for (final g in _goals) ?g.sourceId};
    final out = <PlanTarget>[];

    final horizon = addDays(dateOnly(now), withinDays);
    for (final e in _events) {
      if (e.kind != EventKind.exam || planned.contains(e.id)) continue;
      // Exams can repeat in theory; plan for the next occurrence.
      final next = upcoming(
        now,
        count: 50,
        lookaheadDays: withinDays,
      ).where((o) => o.event.id == e.id).firstOrNull;
      if (next == null || next.start.isAfter(horizon)) continue;
      out.add(
        PlanTarget(
          title: e.title,
          date: next.start,
          isExam: true,
          courseId: e.courseId,
          sourceId: e.id,
        ),
      );
    }
    for (final a in _assignments) {
      if (a.done || planned.contains(a.id)) continue;
      if (a.due.isBefore(now) || a.due.isAfter(horizon)) continue;
      out.add(
        PlanTarget(
          title: a.title,
          date: a.due,
          isExam: false,
          courseId: a.courseId,
          sourceId: a.id,
        ),
      );
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  bool _busy(DateTime start, DateTime end) {
    for (
      var d = dateOnly(start);
      !d.isAfter(dateOnly(end));
      d = addDays(d, 1)
    ) {
      for (final o in occurrencesOn(d)) {
        if (o.start.isBefore(end) && start.isBefore(o.end)) return true;
      }
    }
    for (final s in _sessions) {
      if (s.start.isBefore(end) && start.isBefore(s.end)) return true;
    }
    return false;
  }

  /// Creates a plan and the sessions that fill it. Sessions avoid classes,
  /// exams and other planned study. Returns the goal even if no day was
  /// available (it then has no sessions).
  StudyGoal createPlan({
    required String title,
    required DateTime target,
    required int totalMinutes,
    required int sessionMinutes,
    required Set<int> weekdays,
    required int startMinute,
    String? courseId,
    String? sourceId,
    String? docId,
    int? firstPage,
    int? lastPage,
    DateTime? now,
  }) {
    final goal = StudyGoal(
      id: _aid(),
      title: title.trim(),
      courseId: courseId,
      target: target,
      createdAt: now ?? DateTime.now(),
      sourceId: sourceId,
      totalMinutes: totalMinutes,
      sessionMinutes: sessionMinutes,
      weekdays: (weekdays.toList()..sort()),
      startMinute: startMinute,
      docId: docId,
      firstPage: firstPage,
      lastPage: lastPage,
    );
    _goals.add(goal);
    _fillPlan(goal, totalMinutes, firstPage, now ?? DateTime.now());
    commit();
    return goal;
  }

  /// What a plan for these settings would look like, without saving it.
  List<PlannedSession> previewPlan({
    required String title,
    required DateTime target,
    required int totalMinutes,
    required int sessionMinutes,
    required Set<int> weekdays,
    required int startMinute,
    int? firstPage,
    int? lastPage,
    DateTime? now,
  }) => generatePlan(
    PlanRequest(
      now: now ?? DateTime.now(),
      target: target,
      totalMinutes: totalMinutes,
      sessionMinutes: sessionMinutes,
      weekdays: weekdays,
      startMinute: startMinute,
      baseTitle: title,
      firstPage: firstPage,
      lastPage: lastPage,
      isBusy: _busy,
    ),
  );

  void _fillPlan(StudyGoal goal, int minutes, int? firstPage, DateTime now) {
    final planned = previewPlan(
      title: goal.title,
      target: goal.target,
      totalMinutes: minutes,
      sessionMinutes: goal.sessionMinutes,
      weekdays: goal.weekdays.toSet(),
      startMinute: goal.startMinute,
      firstPage: goal.docId == null ? null : firstPage,
      lastPage: goal.docId == null ? null : goal.lastPage,
      now: now,
    );
    // Added one by one so later sessions see earlier ones as busy.
    for (final p in planned) {
      _sessions.add(
        StudySession(
          id: _aid(),
          title: p.title,
          goalId: goal.id,
          courseId: goal.courseId,
          start: p.start,
          durationMin: p.durationMin,
          link: goal.docId == null
              ? null
              : MaterialLink(docId: goal.docId!, page: p.page),
          pageEnd: p.pageEnd,
        ),
      );
    }
  }

  /// Drops sessions that are still to do and plans the remaining time again
  /// from now on (after a missed day or a changed date). Finished sessions
  /// stay, and any reading range continues after the last page covered.
  void replanGoal(String id, {DateTime? now, DateTime? newTarget}) {
    final i = _goals.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final when = now ?? DateTime.now();
    if (newTarget != null) _goals[i] = _goals[i].copyWith(target: newTarget);
    final goal = _goals[i];

    final kept = _sessions.where((s) => s.goalId == id && s.done).toList();
    _sessions.removeWhere((s) => s.goalId == id && !s.done);
    final doneMinutes = kept.fold(0, (a, s) => a + s.durationMin);
    final remaining = goal.totalMinutes - doneMinutes;

    int? nextPage = goal.firstPage;
    final covered = kept.map((s) => s.pageEnd).nonNulls;
    if (covered.isNotEmpty) {
      nextPage = covered.reduce((a, b) => a > b ? a : b) + 1;
    }
    final pagesLeft =
        goal.lastPage != null && nextPage != null && nextPage <= goal.lastPage!;
    if (remaining > 0) {
      _fillPlan(goal, remaining, pagesLeft ? nextPage : null, when);
    }
    commit();
  }

  void updateGoal(String id, {String? title}) {
    final i = _goals.indexWhere((g) => g.id == id);
    if (i < 0) return;
    _goals[i] = _goals[i].copyWith(
      title: (title?.trim().isEmpty ?? true) ? null : title!.trim(),
    );
    commit();
  }

  void removeGoal(String id) {
    _goals.removeWhere((g) => g.id == id);
    _sessions.removeWhere((s) => s.goalId == id);
    commit();
  }

  StudySession addSession({
    required String title,
    required DateTime start,
    required int durationMin,
    String? goalId,
    String? courseId,
    MaterialLink? link,
  }) {
    final s = StudySession(
      id: _aid(),
      title: title.trim(),
      goalId: goalId,
      courseId: courseId ?? goal(goalId)?.courseId,
      start: start,
      durationMin: durationMin < 1 ? 1 : durationMin,
      link: link,
    );
    _sessions.add(s);
    commit();
    return s;
  }

  void replaceSession(StudySession updated) {
    final i = _sessions.indexWhere((s) => s.id == updated.id);
    if (i < 0) return;
    _sessions[i] = updated;
    commit();
  }

  /// Puts a session back (used to undo a delete).
  void restoreSession(StudySession s) {
    if (_sessions.any((x) => x.id == s.id)) return;
    _sessions.add(s);
    commit();
  }

  void toggleSession(String id) {
    final i = _sessions.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _sessions[i] = _sessions[i].copyWith(done: !_sessions[i].done);
    commit();
  }

  void removeSession(String id) {
    _sessions.removeWhere((s) => s.id == id);
    commit();
  }

  // ---- persistence --------------------------------------------------------

  @protected
  Map<String, dynamic> academicToJson() => {
    'courses': _courses.map((c) => c.toJson()).toList(),
    'events': _events.map((e) => e.toJson()).toList(),
    'assignments': _assignments.map((a) => a.toJson()).toList(),
    'goals': _goals.map((g) => g.toJson()).toList(),
    'sessions': _sessions.map((s) => s.toJson()).toList(),
  };

  @protected
  void academicFromJson(Map<String, dynamic> j) {
    _courses
      ..clear()
      ..addAll([
        for (final e in (j['courses'] as List? ?? const []))
          Course.fromJson(e as Map<String, dynamic>),
      ]);
    _events
      ..clear()
      ..addAll([
        for (final e in (j['events'] as List? ?? const []))
          ScheduleEvent.fromJson(e as Map<String, dynamic>),
      ]);
    _assignments
      ..clear()
      ..addAll([
        for (final e in (j['assignments'] as List? ?? const []))
          Assignment.fromJson(e as Map<String, dynamic>),
      ]);
    _goals
      ..clear()
      ..addAll([
        for (final e in (j['goals'] as List? ?? const []))
          StudyGoal.fromJson(e as Map<String, dynamic>),
      ]);
    _sessions
      ..clear()
      ..addAll([
        for (final e in (j['sessions'] as List? ?? const []))
          StudySession.fromJson(e as Map<String, dynamic>),
      ]);
  }

  @protected
  void clearAcademic() {
    _courses.clear();
    _events.clear();
    _assignments.clear();
    _goals.clear();
    _sessions.clear();
  }
}
