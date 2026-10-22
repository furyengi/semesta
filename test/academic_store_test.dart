import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/library_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LibraryStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LibraryStore.load();
}

Course _course(LibraryStore s, [String name = 'Algorithms']) =>
    s.addCourse(name: name, colorIndex: 1, iconKey: 'code');

// A Monday, so weekday maths in the tests is easy to read.
final _mon = DateTime(2026, 10, 19);

void main() {
  test('date helpers', () {
    expect(startOfWeek(DateTime(2026, 10, 22, 15)), _mon); // Thursday -> Monday
    expect(startOfWeek(_mon), _mon);
    expect(startOfWeek(DateTime(2026, 10, 25)), _mon); // Sunday -> Monday
    expect(addDays(DateTime(2026, 10, 31), 1), DateTime(2026, 11, 1));
    expect(sameDay(DateTime(2026, 1, 1, 5), DateTime(2026, 1, 1, 23)), isTrue);
  });

  group('courses', () {
    test('add, update and find', () async {
      final s = await _store();
      final c = _course(s);
      s.updateCourse(c.id, name: 'Algorithms II', code: 'CS201', notes: 'hi');
      final back = s.course(c.id)!;
      expect(back.name, 'Algorithms II');
      expect(back.code, 'CS201');
      expect(back.notes, 'hi');
      s.updateCourse(c.id, name: '  '); // blank names are ignored
      expect(s.course(c.id)!.name, 'Algorithms II');
      expect(s.course('missing'), isNull);
      expect(s.course(null), isNull);
    });

    test(
      'removing a course drops its schedule and unlinks documents',
      () async {
        final s = await _store();
        final c = _course(s);
        final other = _course(s, 'Biology');
        final doc = s.addDoc(title: 'Book', storageKey: 'k', pageCount: 10);
        s.setDocCourse(doc.id, c.id);
        s.addEvent(
          title: 'L',
          kind: EventKind.lecture,
          start: _mon.add(const Duration(hours: 9)),
          durationMin: 60,
          courseId: c.id,
        );
        s.addEvent(
          title: 'Bio',
          kind: EventKind.lecture,
          start: _mon.add(const Duration(hours: 9)),
          durationMin: 60,
          courseId: other.id,
        );
        s.addAssignment(courseId: c.id, title: 'PS1', due: _mon);

        s.removeCourse(c.id);
        expect(s.course(c.id), isNull);
        expect(s.events.map((e) => e.title), ['Bio']);
        expect(s.assignments, isEmpty);
        expect(s.doc(doc.id), isNotNull);
        expect(s.doc(doc.id)!.courseId, isNull);
      },
    );

    test('docsForCourse and setDocCourse', () async {
      final s = await _store();
      final c = _course(s);
      final a = s.addDoc(title: 'A', storageKey: 'a', pageCount: 1);
      s.addDoc(title: 'B', storageKey: 'b', pageCount: 1);
      s.setDocCourse(a.id, c.id);
      expect(s.docsForCourse(c.id).map((d) => d.title), ['A']);
      s.setDocCourse(a.id, null);
      expect(s.docsForCourse(c.id), isEmpty);
    });
  });

  group('timetable', () {
    test('a one-off event occurs only on its day', () async {
      final s = await _store();
      s.addEvent(
        title: 'Exam',
        kind: EventKind.exam,
        start: DateTime(2026, 10, 22, 14),
        durationMin: 120,
      );
      expect(
        s.occurrencesOn(DateTime(2026, 10, 22)).single.start,
        DateTime(2026, 10, 22, 14),
      );
      expect(
        s.occurrencesOn(DateTime(2026, 10, 22)).single.end,
        DateTime(2026, 10, 22, 16),
      );
      expect(s.occurrencesOn(DateTime(2026, 10, 29)), isEmpty);
      expect(s.occurrencesOn(DateTime(2026, 10, 21)), isEmpty);
    });

    test('a weekly class repeats on its weekday from its start date', () async {
      final s = await _store();
      s.addEvent(
        title: 'Lecture',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9, 30), // Monday
        durationMin: 90,
        weekly: true,
      );
      expect(
        s.occurrencesOn(DateTime(2026, 10, 12)),
        isEmpty,
      ); // before the start
      expect(s.occurrencesOn(DateTime(2026, 10, 19)), hasLength(1));
      expect(s.occurrencesOn(DateTime(2026, 10, 20)), isEmpty); // Tuesday
      final later = s.occurrencesOn(DateTime(2026, 11, 2)).single;
      expect(later.start, DateTime(2026, 11, 2, 9, 30));
      expect(later.end, DateTime(2026, 11, 2, 11));
    });

    test('weekly classes stop after the until date (inclusive)', () async {
      final s = await _store();
      s.addEvent(
        title: 'Lecture',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 60,
        weekly: true,
        until: DateTime(2026, 11, 2, 18),
      );
      expect(s.occurrencesOn(DateTime(2026, 11, 2)), hasLength(1));
      expect(s.occurrencesOn(DateTime(2026, 11, 9)), isEmpty);
    });

    test('occurrences are sorted by start time', () async {
      final s = await _store();
      s.addEvent(
        title: 'Late',
        kind: EventKind.other,
        start: DateTime(2026, 10, 19, 15),
        durationMin: 30,
      );
      s.addEvent(
        title: 'Early',
        kind: EventKind.other,
        start: DateTime(2026, 10, 19, 8),
        durationMin: 30,
      );
      expect(s.occurrencesOn(_mon).map((o) => o.event.title), [
        'Early',
        'Late',
      ]);
    });

    test('upcoming skips finished events and can filter by course', () async {
      final s = await _store();
      final a = _course(s, 'A');
      final b = _course(s, 'B');
      s.addEvent(
        title: 'A-lec',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 60,
        courseId: a.id,
        weekly: true,
      );
      s.addEvent(
        title: 'B-lec',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 20, 9),
        durationMin: 60,
        courseId: b.id,
        weekly: true,
      );

      // Monday 10:00: Monday's lecture is over.
      final from = DateTime(2026, 10, 19, 10);
      expect(s.upcoming(from, count: 3).map((o) => o.event.title), [
        'B-lec',
        'A-lec',
        'B-lec',
      ]);
      expect(s.upcoming(from, count: 2, courseId: a.id).map((o) => o.start), [
        DateTime(2026, 10, 26, 9),
        DateTime(2026, 11, 2, 9),
      ]);
      // During the lecture it still counts as upcoming/ongoing.
      expect(
        s.upcoming(DateTime(2026, 10, 19, 9, 30), count: 1).single.event.title,
        'A-lec',
      );
    });

    test('daysWithEvents', () async {
      final s = await _store();
      s.addEvent(
        title: 'X',
        kind: EventKind.other,
        start: DateTime(2026, 10, 21, 9),
        durationMin: 30,
      );
      s.addEvent(
        title: 'Y',
        kind: EventKind.other,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 30,
        weekly: true,
      );
      expect(s.daysWithEvents(DateTime(2026, 10, 19), DateTime(2026, 10, 27)), {
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 26),
      });
    });

    test('replaceEvent edits and removeEvent deletes', () async {
      final s = await _store();
      final e = s.addEvent(
        title: 'T',
        kind: EventKind.other,
        start: _mon,
        durationMin: 30,
      );
      s.replaceEvent(
        e.copyWith(
          title: 'T2',
          location: 'Room 4',
          link: const MaterialLink(docId: 'd', page: 3),
        ),
      );
      expect(s.event(e.id)!.title, 'T2');
      expect(s.event(e.id)!.link!.page, 3);
      s.replaceEvent(s.event(e.id)!.copyWith(clearLink: true));
      expect(s.event(e.id)!.link, isNull);
      s.removeEvent(e.id);
      expect(s.events, isEmpty);
    });
  });

  group('assignments', () {
    test(
      'open ones sort first by due date; toggling moves them last',
      () async {
        final s = await _store();
        final c = _course(s);
        final late = s.addAssignment(
          courseId: c.id,
          title: 'Late',
          due: DateTime(2026, 11, 1),
        );
        final soon = s.addAssignment(
          courseId: c.id,
          title: 'Soon',
          due: DateTime(2026, 10, 25),
        );
        expect(s.assignmentsFor(c.id).map((a) => a.title), ['Soon', 'Late']);
        s.toggleAssignment(soon.id);
        expect(s.assignmentsFor(c.id).map((a) => a.title), ['Late', 'Soon']);
        expect(s.openAssignmentCount(c.id), 1);
        expect(s.assignmentsDueOn(DateTime(2026, 11, 1, 5)).single.id, late.id);
      },
    );

    test('openAssignmentsFrom ignores done and past ones', () async {
      final s = await _store();
      final c = _course(s);
      s.addAssignment(
        courseId: c.id,
        title: 'Past',
        due: DateTime(2026, 10, 1),
      );
      final done = s.addAssignment(
        courseId: c.id,
        title: 'Done',
        due: DateTime(2026, 10, 26),
      );
      s.addAssignment(
        courseId: c.id,
        title: 'Next',
        due: DateTime(2026, 10, 28),
      );
      s.toggleAssignment(done.id);
      expect(
        s.openAssignmentsFrom(DateTime(2026, 10, 20)).map((a) => a.title),
        ['Next'],
      );
    });
  });

  test('courses, schedule and assignments persist across loads', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = await LibraryStore.load(prefs);
    final c = _course(a);
    a.updateCourse(c.id, notes: 'remember');
    a.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: DateTime(2026, 10, 19, 9),
      durationMin: 60,
      courseId: c.id,
      weekly: true,
      until: DateTime(2026, 12, 1),
      location: 'Hall 2',
      link: const MaterialLink(docId: 'doc', page: 12),
    );
    a.addAssignment(
      courseId: c.id,
      title: 'PS1',
      due: DateTime(2026, 10, 30, 23, 59),
    );
    await a.flush();

    final b = await LibraryStore.load(prefs);
    expect(b.courses.single.notes, 'remember');
    final e = b.events.single;
    expect(e.weekly, isTrue);
    expect(e.until, DateTime(2026, 12, 1));
    expect(e.location, 'Hall 2');
    expect(e.link!.docId, 'doc');
    expect(e.link!.page, 12);
    expect(b.assignments.single.title, 'PS1');
  });

  test('clearAcademicData removes everything and unlinks documents', () async {
    final s = await _store();
    final c = _course(s);
    final d = s.addDoc(title: 'D', storageKey: 'd', pageCount: 3);
    s.setDocCourse(d.id, c.id);
    s.addAssignment(courseId: c.id, title: 'x', due: _mon);
    s.clearAcademicData();
    expect(s.courses, isEmpty);
    expect(s.assignments, isEmpty);
    expect(s.doc(d.id)!.courseId, isNull);
  });
}
