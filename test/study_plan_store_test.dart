import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LibraryStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LibraryStore.load();
}

// Monday 19 Oct 2026, 08:00.
final _now = DateTime(2026, 10, 19, 8);
final _exam = DateTime(2026, 10, 30, 10);

StudyGoal _plan(
  LibraryStore s, {
  String? courseId,
  String? sourceId,
  int total = 240,
  DateTime? now,
  String? docId,
  int? first,
  int? last,
}) => s.createPlan(
  title: 'Midterm',
  target: _exam,
  totalMinutes: total,
  sessionMinutes: 60,
  weekdays: {1, 2, 3, 4, 5},
  startMinute: 18 * 60,
  courseId: courseId,
  sourceId: sourceId,
  docId: docId,
  firstPage: first,
  lastPage: last,
  now: now ?? _now,
);

void main() {
  test('createPlan makes a goal with sessions that add up', () async {
    final s = await _store();
    final c = s.addCourse(name: 'Algo', colorIndex: 1, iconKey: 'code');
    final g = _plan(s, courseId: c.id);
    final sessions = s.sessionsFor(g.id);
    expect(sessions, hasLength(4));
    expect(sessions.fold(0, (a, x) => a + x.durationMin), 240);
    expect(sessions.every((x) => x.courseId == c.id && !x.done), isTrue);
    final p = s.planProgress(g.id);
    expect((p.doneCount, p.count, p.plannedMinutes), (0, 4, 240));
  });

  test('sessions avoid classes and other plans', () async {
    final s = await _store();
    // A class every weekday evening at 18:00.
    for (var d = 0; d < 5; d++) {
      s.addEvent(
        title: 'Evening class',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19 + d, 18),
        durationMin: 60,
        weekly: true,
      );
    }
    final g = _plan(s);
    for (final x in s.sessionsFor(g.id)) {
      final clash = s
          .occurrencesOn(x.start)
          .any((o) => o.start.isBefore(x.end) && x.start.isBefore(o.end));
      expect(clash, isFalse, reason: '${x.start}');
    }
    // A second plan doesn't land on the first plan's sessions either.
    final g2 = _plan(s);
    final all = [...s.sessionsFor(g.id), ...s.sessionsFor(g2.id)];
    for (final a in all) {
      for (final b in all) {
        if (a.id == b.id) continue;
        expect(a.start.isBefore(b.end) && b.start.isBefore(a.end), isFalse);
      }
    }
  });

  test('toggling sessions updates progress and status', () async {
    final s = await _store();
    final g = _plan(s);
    final list = s.sessionsFor(g.id);
    expect(s.planStatus(g.id, _now), PlanStatus.onTrack);

    s.toggleSession(list[0].id);
    expect(s.planProgress(g.id).doneMinutes, 60);
    expect(s.planProgress(g.id).fraction, closeTo(.25, 1e-9));

    // After the second session's time with it not done: behind.
    final later = list[1].end.add(const Duration(minutes: 1));
    expect(s.planStatus(g.id, later), PlanStatus.behind);
    expect(s.overdueSessions(later).map((x) => x.id), [list[1].id]);

    for (final x in s.sessionsFor(g.id)) {
      if (!x.done) s.toggleSession(x.id);
    }
    expect(s.planStatus(g.id, later), PlanStatus.complete);
    expect(
      s.planStatus(g.id, _exam.add(const Duration(days: 1))),
      PlanStatus.complete,
    );
  });

  test('a plan whose date has passed is "past" unless complete', () async {
    final s = await _store();
    final g = _plan(s);
    expect(
      s.planStatus(g.id, _exam.add(const Duration(days: 1))),
      PlanStatus.past,
    );
  });

  test('weekly study totals', () async {
    final s = await _store();
    final g = _plan(s);
    final list = s.sessionsFor(g.id);
    s.toggleSession(list[0].id);
    s.toggleSession(list[1].id);
    final monday = DateTime(2026, 10, 19);
    final (done, total) = s.sessionsInWeek(monday);
    expect(total, greaterThanOrEqualTo(2));
    expect(done, 2);
    expect(
      s.studiedMinutesInWeek(monday) +
          s.studiedMinutesInWeek(DateTime(2026, 10, 26)),
      120,
    );
  });

  test('unplannedTargets lists exams and assignments without a plan', () async {
    final s = await _store();
    final c = s.addCourse(name: 'Algo', colorIndex: 1, iconKey: 'code');
    final exam = s.addEvent(
      title: 'Midterm',
      kind: EventKind.exam,
      start: _exam,
      durationMin: 120,
      courseId: c.id,
    );
    s.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: _exam,
      durationMin: 60,
    ); // not an exam
    final a = s.addAssignment(
      courseId: c.id,
      title: 'PS5',
      due: DateTime(2026, 10, 25, 23, 59),
    );
    final far = s.addAssignment(
      courseId: c.id,
      title: 'Far away',
      due: DateTime(2027, 3, 1),
    );
    final past = s.addAssignment(
      courseId: c.id,
      title: 'Past',
      due: DateTime(2026, 10, 1),
    );

    var t = s.unplannedTargets(_now);
    expect(t.map((x) => x.title), ['PS5', 'Midterm']);
    expect(t.last.isExam, isTrue);
    expect(t.map((x) => x.sourceId), isNot(contains(far.id)));
    expect(t.map((x) => x.sourceId), isNot(contains(past.id)));

    _plan(s, sourceId: exam.id);
    t = s.unplannedTargets(_now);
    expect(t.map((x) => x.title), ['PS5']);
    s.toggleAssignment(a.id); // done assignments need no plan
    expect(s.unplannedTargets(_now), isEmpty);
  });

  test('replan keeps finished sessions and re-spreads what is left', () async {
    final s = await _store();
    final g = _plan(s, total: 360);
    final list = s.sessionsFor(g.id);
    s.toggleSession(list[0].id);
    s.toggleSession(list[1].id);

    // A week later, three sessions were missed.
    final later = DateTime(2026, 10, 26, 8);
    s.replanGoal(g.id, now: later);
    final after = s.sessionsFor(g.id);
    expect(after.where((x) => x.done), hasLength(2));
    final todo = after.where((x) => !x.done).toList();
    expect(todo.fold(0, (a, x) => a + x.durationMin), 240); // 360 - 120 done
    expect(todo.every((x) => x.start.isAfter(later)), isTrue);
    expect(todo.every((x) => x.start.isBefore(DateTime(2026, 10, 30))), isTrue);
  });

  test('replan can move the date', () async {
    final s = await _store();
    final g = _plan(s);
    s.replanGoal(g.id, now: _now, newTarget: DateTime(2026, 11, 6, 10));
    expect(s.goal(g.id)!.target, DateTime(2026, 11, 6, 10));
    expect(
      s.sessionsFor(g.id).last.start.isAfter(DateTime(2026, 10, 30)),
      isTrue,
    );
  });

  test('a reading range continues after the last page finished', () async {
    final s = await _store();
    final doc = s.addDoc(title: 'Book', storageKey: 'k', pageCount: 100);
    final g = _plan(s, total: 240, docId: doc.id, first: 1, last: 80);
    final list = s.sessionsFor(g.id);
    expect(list.map((x) => (x.link!.page, x.pageEnd)), [
      (1, 20),
      (21, 40),
      (41, 60),
      (61, 80),
    ]);

    s.toggleSession(list[0].id);
    s.toggleSession(list[1].id);
    s.replanGoal(g.id, now: DateTime(2026, 10, 22, 8));
    final todo = s.sessionsFor(g.id).where((x) => !x.done).toList();
    expect(todo.first.link!.page, 41);
    expect(todo.last.pageEnd, 80);
  });

  test('removing a goal or a course removes its sessions', () async {
    final s = await _store();
    final c = s.addCourse(name: 'Algo', colorIndex: 1, iconKey: 'code');
    final g1 = _plan(s, courseId: c.id);
    final g2 = _plan(s);
    s.removeGoal(g2.id);
    expect(s.sessionsFor(g2.id), isEmpty);
    expect(s.goal(g1.id), isNotNull);
    s.removeCourse(c.id);
    expect(s.goals, isEmpty);
    expect(s.sessions, isEmpty);
  });

  test('manual sessions: add, move, delete and restore', () async {
    final s = await _store();
    final g = _plan(s, total: 60);
    final x = s.addSession(
      title: 'Extra',
      start: DateTime(2026, 10, 21, 20),
      durationMin: 45,
      goalId: g.id,
    );
    expect(
      s.sessionsOn(DateTime(2026, 10, 21)).any((e) => e.id == x.id),
      isTrue,
    );
    s.replaceSession(x.copyWith(start: DateTime(2026, 10, 22, 9)));
    expect(
      s.sessionsOn(DateTime(2026, 10, 22)).any((e) => e.id == x.id),
      isTrue,
    );
    s.removeSession(x.id);
    expect(s.sessions.any((e) => e.id == x.id), isFalse);
    s.restoreSession(x);
    s.restoreSession(x); // no duplicate
    expect(s.sessions.where((e) => e.id == x.id), hasLength(1));
  });

  test(
    'plans persist across loads and clearAcademicData removes them',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = await LibraryStore.load(prefs);
      final g = _plan(a);
      a.toggleSession(a.sessionsFor(g.id).first.id);
      await a.flush();

      final b = await LibraryStore.load(prefs);
      expect(b.goals.single.title, 'Midterm');
      expect(b.goals.single.weekdays, [1, 2, 3, 4, 5]);
      expect(b.sessions, hasLength(4));
      expect(b.sessions.where((x) => x.done), hasLength(1));

      b.clearAcademicData();
      expect(b.goals, isEmpty);
      expect(b.sessions, isEmpty);
    },
  );

  test('goalsSorted puts upcoming plans first by date', () async {
    final s = await _store();
    final later = s.createPlan(
      title: 'Later',
      target: DateTime(2026, 12, 1),
      totalMinutes: 60,
      sessionMinutes: 60,
      weekdays: {1},
      startMinute: 600,
      now: _now,
    );
    final soon = s.createPlan(
      title: 'Soon',
      target: DateTime(2026, 10, 28),
      totalMinutes: 60,
      sessionMinutes: 60,
      weekdays: {1, 2, 3},
      startMinute: 600,
      now: _now,
    );
    final gone = s.createPlan(
      title: 'Gone',
      target: DateTime(2026, 10, 1),
      totalMinutes: 60,
      sessionMinutes: 60,
      weekdays: {1},
      startMinute: 600,
      now: _now,
    );
    expect(s.goalsSorted(_now).map((g) => g.id), [soon.id, later.id, gone.id]);
  });
}
