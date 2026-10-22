import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/library_store.dart';
import 'package:semesta/data/reminder_planner.dart';
import 'package:semesta/data/reminder_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Monday 19 Oct 2026, 07:00.
final _now = DateTime(2026, 10, 19, 7);

Future<LibraryStore> _store([ReminderSettings? s]) async {
  SharedPreferences.setMockInitialValues({});
  final store = await LibraryStore.load();
  store.reminders = s ?? const ReminderSettings(enabled: true);
  return store;
}

List<ReminderSpec> _plan(
  LibraryStore s, {
  DateTime? now,
  bool use24h = false,
  int horizon = 14,
  int max = 120,
}) => planReminders(
  s,
  now ?? _now,
  use24h: use24h,
  horizonDays: horizon,
  maxCount: max,
);

void main() {
  group('ReminderSettings', () {
    test('defaults are off with sensible leads', () {
      const d = ReminderSettings();
      expect(d.enabled, isFalse);
      expect(
        (d.classLeadMin, d.studyLeadMin, d.examLeadHours, d.deadlineLeadHours),
        (10, 10, 24, 24),
      );
      expect(d.digest, isFalse);
    });

    test('round-trips through JSON and survives bad data', () {
      const s = ReminderSettings(
        enabled: true,
        classLeadMin: 30,
        digest: true,
        digestMinute: 7 * 60 + 30,
        exams: false,
      );
      expect(ReminderSettings.decode(s.encode()), s);
      expect(ReminderSettings.decode('not json'), const ReminderSettings());
      expect(ReminderSettings.decode(null), const ReminderSettings());
      expect(
        ReminderSettings.fromJson({'enabled': true}).classLeadMin,
        10,
      ); // missing keys fall back
    });

    test('the store persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = await LibraryStore.load(prefs);
      a.reminders = const ReminderSettings(enabled: true, studyLeadMin: 30);
      final b = await LibraryStore.load(prefs);
      expect(b.reminders.enabled, isTrue);
      expect(b.reminders.studyLeadMin, 30);
    });
  });

  group('payloads and ids', () {
    test('parseReminderPayload', () {
      expect(parseReminderPayload('tab:3')!.tab, 3);
      final d = parseReminderPayload('doc:abc-1:12')!;
      expect((d.docId, d.page, d.tab), ('abc-1', 12, null));
      expect(parseReminderPayload('doc:abc:0')!.page, isNull); // saved position
      expect(parseReminderPayload('doc::5'), isNull);
      expect(parseReminderPayload('tab:x'), isNull);
      expect(parseReminderPayload('nonsense'), isNull);
      expect(parseReminderPayload(null), isNull);
    });

    test('reminderId is stable, positive and varies with the key', () {
      expect(reminderId('a'), reminderId('a'));
      expect(reminderId('a'), isNot(reminderId('b')));
      for (final k in [
        'x',
        'class:1@2',
        'a much longer key with spaces 12345',
      ]) {
        expect(reminderId(k), inInclusiveRange(0, 0x7fffffff));
      }
    });
  });

  group('planReminders', () {
    test('nothing when reminders are off', () async {
      final s = await _store(const ReminderSettings());
      s.addEvent(
        title: 'L',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 60,
      );
      expect(_plan(s), isEmpty);
    });

    test(
      'a class reminder comes the chosen number of minutes before',
      () async {
        final s = await _store(
          const ReminderSettings(enabled: true, classLeadMin: 15),
        );
        final c = s.addCourse(
          name: 'Algorithms',
          colorIndex: 1,
          iconKey: 'code',
        );
        s.addEvent(
          title: 'Algorithms Lecture',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 19, 9, 30),
          durationMin: 60,
          courseId: c.id,
          location: 'Hall B',
        );
        final r = _plan(s).single;
        expect(r.when, DateTime(2026, 10, 19, 9, 15));
        expect(r.title, 'Algorithms Lecture in 15 min');
        expect(r.body, '9:30 AM · Hall B');
        expect(r.kind, ReminderKind.classStart);
        expect(r.payload, 'tab:2');
      },
    );

    test('a class with linked material opens it when tapped', () async {
      final s = await _store();
      final doc = s.addDoc(title: 'Slides', storageKey: 'k', pageCount: 10);
      s.addEvent(
        title: 'Lecture',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 60,
        link: MaterialLink(docId: doc.id, page: 7),
      );
      final r = _plan(s).single;
      expect(r.payload, 'doc:${doc.id}:7');
      expect(r.body, contains('Tap to open Slides, p. 7'));
    });

    test('a link to a deleted document falls back to the calendar', () async {
      final s = await _store();
      s.addEvent(
        title: 'Lecture',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 60,
        link: const MaterialLink(docId: 'gone', page: 7),
      );
      expect(_plan(s).single.payload, 'tab:2');
    });

    test(
      'weekly classes get a reminder for every occurrence in the window',
      () async {
        final s = await _store();
        s.addEvent(
          title: 'Lecture',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 19, 9),
          durationMin: 60,
          weekly: true,
        );
        final r = _plan(s, horizon: 14);
        expect(
          r.map((x) => x.when.day),
          [19, 26, 2], // 19 Oct, 26 Oct, 2 Nov
        );
        expect(r.length, 3);
        expect(r.map((x) => x.id).toSet().length, 3); // distinct ids
      },
    );

    test('reminders that would already have fired are skipped', () async {
      final s = await _store();
      // Starts in 5 minutes but the lead is 10: already past.
      s.addEvent(
        title: 'Soon',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 7, 5),
        durationMin: 30,
      );
      s.addEvent(
        title: 'Later',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 7, 30),
        durationMin: 30,
      );
      expect(_plan(s).map((r) => r.title), ['Later in 10 min']);
    });

    test(
      'exams use their own lead and wording; turning them off hides them',
      () async {
        final s = await _store(
          const ReminderSettings(enabled: true, examLeadHours: 24),
        );
        s.addEvent(
          title: 'Midterm',
          kind: EventKind.exam,
          start: DateTime(2026, 10, 22, 10),
          durationMin: 120,
          location: 'Hall A',
        );
        final r = _plan(s).single;
        expect(r.when, DateTime(2026, 10, 21, 10));
        expect(r.title, 'Exam tomorrow: Midterm');
        expect(r.body, '10:00 AM–12:00 PM · Hall A');
        s.reminders = s.reminders.copyWith(exams: false);
        expect(_plan(s), isEmpty);
      },
    );

    test('study sessions: reminded before, skipped when done', () async {
      final s = await _store(
        const ReminderSettings(enabled: true, studyLeadMin: 5),
      );
      final a = s.addSession(
        title: 'Revise graphs',
        start: DateTime(2026, 10, 19, 18),
        durationMin: 60,
      );
      final b = s.addSession(
        title: 'Revise trees',
        start: DateTime(2026, 10, 20, 18),
        durationMin: 45,
      );
      s.toggleSession(b.id);
      final r = _plan(s).single;
      expect(r.when, DateTime(2026, 10, 19, 17, 55));
      expect(r.title, 'Study time in 5 min');
      expect(r.body, 'Revise graphs · 6:00 PM–7:00 PM');
      expect(r.payload, 'tab:3');
      expect(r.id, isNot(reminderId('x')));
      expect(a.id, isNotEmpty);
    });

    test(
      'deadlines: before the due time, not for finished or past ones',
      () async {
        final s = await _store(
          const ReminderSettings(enabled: true, deadlineLeadHours: 12),
        );
        final c = s.addCourse(name: 'Algo', colorIndex: 1, iconKey: 'code');
        s.addAssignment(
          courseId: c.id,
          title: 'PS3',
          due: DateTime(2026, 10, 20, 23, 59),
        );
        final done = s.addAssignment(
          courseId: c.id,
          title: 'PS2',
          due: DateTime(2026, 10, 21, 12),
        );
        s.toggleAssignment(done.id);
        s.addAssignment(
          courseId: c.id,
          title: 'Old',
          due: DateTime(2026, 10, 1),
        ); // long past
        s.addAssignment(
          courseId: c.id,
          title: 'Far',
          due: DateTime(2027, 6, 1),
        ); // outside the window
        final r = _plan(s).single;
        expect(r.when, DateTime(2026, 10, 20, 11, 59));
        expect(r.title, startsWith('Due '));
        expect(r.title, endsWith('PS3'));
        expect(r.body, '11:59 PM · Algo');
        expect(r.kind, ReminderKind.deadline);
        expect(r.payload, 'tab:1');
      },
    );

    test('24-hour times', () async {
      final s = await _store();
      s.addEvent(
        title: 'L',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 14, 5),
        durationMin: 60,
      );
      expect(_plan(s, use24h: true).single.body, '14:05');
      expect(_plan(s).single.body, '2:05 PM');
    });

    test('the daily summary counts the day and skips empty days', () async {
      final s = await _store(
        const ReminderSettings(
          enabled: true,
          digest: true,
          classes: false,
          exams: false,
          study: false,
          deadlines: false,
        ),
      );
      s.addEvent(
        title: 'Algo',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 20, 9),
        durationMin: 60,
      );
      s.addEvent(
        title: 'Chem',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 20, 11),
        durationMin: 60,
      );
      s.addEvent(
        title: 'Midterm',
        kind: EventKind.exam,
        start: DateTime(2026, 10, 20, 14),
        durationMin: 60,
      );
      s.addSession(
        title: 'Study',
        start: DateTime(2026, 10, 20, 18),
        durationMin: 30,
      );
      final c = s.addCourse(name: 'A', colorIndex: 1, iconKey: 'code');
      s.addAssignment(
        courseId: c.id,
        title: 'PS',
        due: DateTime(2026, 10, 20, 23, 59),
      );
      final r = _plan(s).single; // only Tuesday has anything
      expect(r.when, DateTime(2026, 10, 20, 8));
      expect(r.kind, ReminderKind.digest);
      expect(r.title, 'Today: 1 exam, 2 classes, 1 study session, 1 due');
      expect(r.body, '2:00 PM Midterm · 9:00 AM Algo · 11:00 AM Chem');
    });

    test('the daily summary skips a day whose time has passed', () async {
      final s = await _store(
        const ReminderSettings(
          enabled: true,
          digest: true,
          classes: false,
          exams: false,
          study: false,
          deadlines: false,
        ),
      );
      s.addEvent(
        title: 'Algo',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 60,
      );
      expect(
        _plan(s, now: DateTime(2026, 10, 19, 9)),
        isEmpty,
      ); // 08:00 already gone
      expect(_plan(s, now: DateTime(2026, 10, 19, 6)), hasLength(1));
    });

    test('sorted soonest first and capped', () async {
      final s = await _store();
      for (var i = 0; i < 10; i++) {
        s.addEvent(
          title: 'E$i',
          kind: EventKind.lecture,
          start: DateTime(2026, 10, 19, 20 - i),
          durationMin: 30,
        );
      }
      final all = _plan(s);
      expect(
        all.map((r) => r.when).toList(),
        [...all.map((r) => r.when)]..sort(),
      );
      final capped = _plan(s, max: 3);
      expect(capped.map((r) => r.id), all.take(3).map((r) => r.id));
    });

    test('signatures change when the content changes', () async {
      final s = await _store();
      final e = s.addEvent(
        title: 'L',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 60,
      );
      final before = _plan(s).single.signature;
      s.replaceEvent(e.copyWith(location: 'Room 9'));
      expect(_plan(s).single.signature, isNot(before));
      expect(_plan(s).single.signature, _plan(s).single.signature);
    });

    test('deleting an item removes its reminder', () async {
      final s = await _store();
      final e = s.addEvent(
        title: 'L',
        kind: EventKind.lecture,
        start: DateTime(2026, 10, 19, 9),
        durationMin: 60,
      );
      expect(_plan(s), hasLength(1));
      s.removeEvent(e.id);
      expect(_plan(s), isEmpty);
    });
  });
}
