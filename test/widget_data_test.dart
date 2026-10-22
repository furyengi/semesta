import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/library_store.dart';
import 'package:semesta/data/widget_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Thursday 22 Oct 2026, 10:00.
final _now = DateTime(2026, 10, 22, 10);

Future<LibraryStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LibraryStore.load();
}

List<dynamic> _list(Map<String, String> d, String key) =>
    jsonDecode(d[key]!) as List<dynamic>;

void main() {
  _readBackTests();
  test('everything is empty for an empty app', () async {
    final s = await _store();
    final d = buildWidgetData(s, _now);
    expect(_list(d, WidgetKeys.nextUp), isEmpty);
    expect(_list(d, WidgetKeys.today), isEmpty);
    expect(_list(d, WidgetKeys.deadlines), isEmpty);
    expect(jsonDecode(d[WidgetKeys.continueReading]!), isEmpty);
    expect(d.keys.toSet(), {'nextup', 'today', 'deadlines', 'continue'});
  });

  test('widget kinds have unique ids', () {
    expect(
      WidgetKind.values.map((k) => k.id).toSet().length,
      WidgetKind.values.length,
    );
  });

  group('next up', () {
    test('lists upcoming classes with absolute, preformatted text', () async {
      final s = await _store();
      final c = s.addCourse(name: 'Algorithms', colorIndex: 1, iconKey: 'code');
      s.addEvent(
        title: 'Lecture 4',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 22, 14, 30),
        durationMin: 90,
        courseId: c.id,
        location: 'Hall B',
      );
      final e =
          _list(buildWidgetData(s, _now), WidgetKeys.nextUp).single
              as Map<String, dynamic>;
      expect(e['title'], 'Lecture 4');
      expect(e['subtitle'], 'Algorithms · Hall B');
      expect(e['when'], 'Thu 22 Oct · 2:30 PM–4:00 PM');
      expect(e['kind'], 'class');
      expect(
        e['startMs'],
        DateTime(2026, 10, 22, 14, 30).millisecondsSinceEpoch,
      );
      expect(e['endMs'], DateTime(2026, 10, 22, 16).millisecondsSinceEpoch);
      expect(e['payload'], 'tab:2');
    });

    test(
      'skips finished events, keeps order, flags exams, uses 24-hour time',
      () async {
        final s = await _store();
        s.addEvent(
          title: 'Over',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 22, 8),
          durationMin: 60,
        );
        s.addEvent(
          title: 'Exam',
          kind: EventKind.exam,
          start: DateTime(2026, 10, 23, 9),
          durationMin: 120,
        );
        s.addEvent(
          title: 'Later',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 22, 16),
          durationMin: 60,
        );
        final list = _list(
          buildWidgetData(s, _now, use24h: true),
          WidgetKeys.nextUp,
        ).cast<Map<String, dynamic>>();
        expect(list.map((e) => e['title']), ['Later', 'Exam']);
        expect(list.last['kind'], 'exam');
        expect(list.first['when'], 'Thu 22 Oct · 16:00–17:00');
      },
    );

    test('an ongoing class is still listed', () async {
      final s = await _store();
      s.addEvent(
        title: 'Now',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 22, 9, 30),
        durationMin: 60,
      );
      expect(_list(buildWidgetData(s, _now), WidgetKeys.nextUp), hasLength(1));
    });

    test(
      'opens the linked material when there is one and it still exists',
      () async {
        final s = await _store();
        final doc = s.addDoc(title: 'Slides', storageKey: 'k', pageCount: 30);
        s.addEvent(
          title: 'Lecture',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 22, 14),
          durationMin: 60,
          link: MaterialLink(docId: doc.id, page: 12),
        );
        var e =
            _list(buildWidgetData(s, _now), WidgetKeys.nextUp).single
                as Map<String, dynamic>;
        expect(e['payload'], 'doc:${doc.id}:12');
        expect(e['subtitle'], 'Slides');

        s.removeDoc(doc.id);
        e =
            _list(buildWidgetData(s, _now), WidgetKeys.nextUp).single
                as Map<String, dynamic>;
        expect(e['payload'], 'tab:2'); // falls back instead of a dead link
      },
    );

    test('is limited to a dozen entries', () async {
      final s = await _store();
      s.addEvent(
        title: 'Daily',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 22, 14),
        durationMin: 30,
        weekly: true,
      );
      s.addEvent(
        title: 'Other',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 22, 15),
        durationMin: 30,
        weekly: true,
      );
      expect(
        _list(buildWidgetData(s, _now), WidgetKeys.nextUp).length,
        lessThanOrEqualTo(12),
      );
    });
  });

  group('today', () {
    test(
      'mixes classes, study sessions and due assignments in time order',
      () async {
        final s = await _store();
        final c = s.addCourse(name: 'A', colorIndex: 1, iconKey: 'code');
        s.addEvent(
          title: 'Lecture',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 22, 14),
          durationMin: 60,
        );
        s.addSession(
          title: 'Revise',
          start: DateTime(2026, 10, 22, 18),
          durationMin: 45,
        );
        s.addAssignment(
          courseId: c.id,
          title: 'PS3',
          due: DateTime(2026, 10, 22, 23, 59),
        );
        s.addSession(
          title: 'Done one',
          start: DateTime(2026, 10, 22, 19),
          durationMin: 30,
        );
        s.toggleSession(s.sessions.last.id);

        final l = _list(
          buildWidgetData(s, _now),
          WidgetKeys.today,
        ).cast<Map<String, dynamic>>();
        expect(l.map((e) => (e['kind'], e['title'], e['time'])), [
          ('class', 'Lecture', '2:00 PM'),
          ('study', 'Revise', '6:00 PM'),
          ('due', 'PS3', '11:59 PM'),
        ]);
        expect(l[1]['payload'], 'tab:3'); // study with no material -> Plan tab
        expect(l[2]['payload'], 'tab:1');
      },
    );

    test(
      'includes the next two days so it stays right past midnight',
      () async {
        final s = await _store();
        s.addEvent(
          title: 'Tomorrow',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 23, 9),
          durationMin: 60,
        );
        s.addEvent(
          title: 'In 3 days',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 25, 9),
          durationMin: 60,
        );
        final l = _list(
          buildWidgetData(s, _now),
          WidgetKeys.today,
        ).cast<Map<String, dynamic>>();
        expect(l.map((e) => e['title']), ['Tomorrow']);
      },
    );

    test('study sessions link to their material', () async {
      final s = await _store();
      final doc = s.addDoc(title: 'Book', storageKey: 'k', pageCount: 100);
      s.addSession(
        title: 'Read',
        start: DateTime(2026, 10, 22, 18),
        durationMin: 60,
        link: MaterialLink(docId: doc.id, page: 41),
      );
      final e =
          _list(buildWidgetData(s, _now), WidgetKeys.today).single
              as Map<String, dynamic>;
      expect(e['payload'], 'doc:${doc.id}:41');
    });
  });

  group('deadlines', () {
    test(
      'soonest open ones first, with course and absolute due text',
      () async {
        final s = await _store();
        final c = s.addCourse(
          name: 'Algorithms',
          colorIndex: 1,
          iconKey: 'code',
        );
        s.addAssignment(
          courseId: c.id,
          title: 'Later',
          due: DateTime(2026, 10, 30, 12),
        );
        s.addAssignment(
          courseId: c.id,
          title: 'Soon',
          due: DateTime(2026, 10, 23, 23, 59),
        );
        final done = s.addAssignment(
          courseId: c.id,
          title: 'Done',
          due: DateTime(2026, 10, 24),
        );
        s.toggleAssignment(done.id);
        final l = _list(
          buildWidgetData(s, _now),
          WidgetKeys.deadlines,
        ).cast<Map<String, dynamic>>();
        expect(l.map((e) => e['title']), ['Soon', 'Later']);
        expect(l.first['subtitle'], 'Algorithms');
        expect(l.first['when'], 'Fri 23 Oct · 11:59 PM');
        expect(
          l.first['dueMs'],
          DateTime(2026, 10, 23, 23, 59).millisecondsSinceEpoch,
        );
      },
    );

    test(
      'keeps something that just became overdue, drops old ones, caps at eight',
      () async {
        final s = await _store();
        final c = s.addCourse(name: 'A', colorIndex: 1, iconKey: 'code');
        s.addAssignment(
          courseId: c.id,
          title: 'Just late',
          due: DateTime(2026, 10, 22, 8),
        );
        s.addAssignment(
          courseId: c.id,
          title: 'Ancient',
          due: DateTime(2026, 9, 1),
        );
        for (var i = 0; i < 10; i++) {
          s.addAssignment(
            courseId: c.id,
            title: 'T$i',
            due: DateTime(2026, 11, 1 + i),
          );
        }
        final l = _list(
          buildWidgetData(s, _now),
          WidgetKeys.deadlines,
        ).cast<Map<String, dynamic>>();
        expect(l.first['title'], 'Just late');
        expect(l.map((e) => e['title']), isNot(contains('Ancient')));
        expect(l.length, 8);
      },
    );
  });

  group('continue reading', () {
    test('describes the document being read', () async {
      final s = await _store();
      final d = s.addDoc(
        title: 'Linear algebra',
        storageKey: 'k',
        pageCount: 101,
      );
      s.recordProgress(d.id, page: 51, pageCount: 101);
      final c = jsonDecode(
        buildWidgetData(s, _now)[WidgetKeys.continueReading]!,
      ) as Map<String, dynamic>;
      expect(c['title'], 'Linear algebra');
      expect(c['subtitle'], 'Page 51 of 101');
      expect(c['progress'], 50);
      expect(c['payload'], 'doc:${d.id}:0');
    });

    test('is empty when nothing is in progress or it is finished', () async {
      final s = await _store();
      final d = s.addDoc(title: 'Book', storageKey: 'k', pageCount: 10);
      expect(
        jsonDecode(buildWidgetData(s, _now)[WidgetKeys.continueReading]!),
        isEmpty,
      );
      s.recordProgress(d.id, page: 10, pageCount: 10);
      expect(
        jsonDecode(buildWidgetData(s, _now)[WidgetKeys.continueReading]!),
        isEmpty,
      );
    });
  });

  test('the output is deterministic for the same state', () async {
    final s = await _store();
    s.addEvent(
      title: 'L',
      kind: EventKind.lecture,
      start: DateTime(2026, 10, 22, 14),
      durationMin: 60,
    );
    expect(buildWidgetData(s, _now), buildWidgetData(s, _now));
  });
}

void _readBackTests() {
  group('reading the data back', () {
    test(
      'currentNextUp picks the first entry not yet finished, as time passes',
      () async {
        final s = await _store();
        s.addEvent(
          title: 'A',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 22, 11),
          durationMin: 60,
        );
        s.addEvent(
          title: 'B',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 22, 14),
          durationMin: 60,
        );
        final d = buildWidgetData(s, _now);
        int at(int h, [int m = 0]) =>
            DateTime(2026, 10, 22, h, m).millisecondsSinceEpoch;
        expect(currentNextUp(d, at(10))!['title'], 'A');
        expect(currentNextUp(d, at(11, 30))!['title'], 'A'); // ongoing
        expect(currentNextUp(d, at(12))!['title'], 'B'); // A has ended
        expect(currentNextUp(d, at(15)), isNull);
      },
    );

    test('todayEntries follows the clock across midnight', () async {
      final s = await _store();
      s.addEvent(
        title: 'Today',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 22, 14),
        durationMin: 60,
      );
      s.addEvent(
        title: 'Tomorrow',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 23, 9),
        durationMin: 60,
      );
      final d = buildWidgetData(s, _now);
      expect(
        todayEntries(d, DateTime(2026, 10, 22, 12)).map((e) => e['title']),
        ['Today'],
      );
      expect(
        todayEntries(d, DateTime(2026, 10, 23, 0, 5)).map((e) => e['title']),
        ['Tomorrow'],
      );
      expect(todayEntries(d, DateTime(2026, 10, 24, 8)), isEmpty);
    });

    test('deadlineEntries flags overdue ones and caps the list', () async {
      final s = await _store();
      final c = s.addCourse(name: 'A', colorIndex: 1, iconKey: 'code');
      s.addAssignment(
        courseId: c.id,
        title: 'Late',
        due: DateTime(2026, 10, 22, 8),
      );
      for (var i = 0; i < 6; i++) {
        s.addAssignment(
          courseId: c.id,
          title: 'T$i',
          due: DateTime(2026, 11, 1 + i),
        );
      }
      final d = buildWidgetData(s, _now);
      final l = deadlineEntries(d, _now.millisecondsSinceEpoch);
      expect(l.length, 4);
      expect(l.first['title'], 'Late');
      expect(l.first['overdue'], isTrue);
      expect(l[1]['overdue'], isFalse);
      expect(
        deadlineEntries(d, _now.millisecondsSinceEpoch, max: 2),
        hasLength(2),
      );
    });

    test('bad or missing data reads as empty', () {
      expect(currentNextUp(const {}, 0), isNull);
      expect(todayEntries({'today': 'not json'}, _now), isEmpty);
      expect(deadlineEntries({'deadlines': '{}'}, 0), isEmpty);
      expect(continueEntry({'continue': '{}'}), isNull);
      expect(continueEntry({'continue': 'oops'}), isNull);
      expect(continueEntry({'continue': '{"title":"X"}'})!['title'], 'X');
    });
  });
}
