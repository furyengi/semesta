import 'package:flutter/foundation.dart';

import 'academic_models.dart';

/// Courses, timetable and assignments. Mixed into the library store so one
/// store (and one persistence path) serves the whole app.
mixin AcademicData on ChangeNotifier {
  final List<Course> _courses = [];
  final List<ScheduleEvent> _events = [];
  final List<Assignment> _assignments = [];
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

  // ---- persistence --------------------------------------------------------

  @protected
  Map<String, dynamic> academicToJson() => {
    'courses': _courses.map((c) => c.toJson()).toList(),
    'events': _events.map((e) => e.toJson()).toList(),
    'assignments': _assignments.map((a) => a.toJson()).toList(),
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
  }

  @protected
  void clearAcademic() {
    _courses.clear();
    _events.clear();
    _assignments.clear();
  }
}
