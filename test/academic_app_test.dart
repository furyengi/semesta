import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';

import 'support/fakes.dart';

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _goTo(WidgetTester tester, String tab) async {
  await tester.tap(_nav(tab));
  await tester.pumpAndSettle();
}

DateTime get _today => dateOnly(DateTime.now());

/// One course, one linked document and a lecture today.
Future<void> _seed(TestEnv e) async {
  await e.addDoc('linear_algebra.pdf');
  final doc = e.store.docs.single;
  final c = e.store.addCourse(
    name: 'Algorithms',
    colorIndex: 1,
    iconKey: 'code',
    code: 'CS101',
  );
  e.store.setDocCourse(doc.id, c.id);
  e.store.addEvent(
    title: 'Lecture 3',
    kind: EventKind.lecture,
    start: _today.add(const Duration(hours: 10)),
    durationMin: 60,
    courseId: c.id,
    weekly: true, // always has an occurrence today and a next one later
    location: 'Hall B',
    link: MaterialLink(docId: doc.id, page: 7),
  );
}

void main() {
  testWidgets('bottom navigation switches tabs and the add button changes', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Add PDF'), findsOneWidget);

    await _goTo(tester, 'Courses');
    // The hidden Library tab must not be painted (or hit) behind this one.
    expect(find.text('Read. Learn.\nProgress.'), findsNothing);
    expect(find.text('No courses yet'), findsOneWidget);
    expect(find.text('Add course'), findsOneWidget);
    expect(find.text('Add PDF'), findsNothing);

    await _goTo(tester, 'Calendar');
    expect(find.text('Your\ncourses.'), findsNothing);
    expect(find.text('Add event'), findsOneWidget);
    expect(find.text('Calendar'), findsWidgets);

    await _goTo(tester, 'Library');
    expect(find.text('Add PDF'), findsOneWidget);
  });

  testWidgets('creating a course adds a card', (tester) async {
    final env = await pumpApp(tester);
    await _goTo(tester, 'Courses');
    await tester.tap(find.text('Add course'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Course name'),
      'Organic Chemistry',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'CHEM2');
    await tester.tap(find.text('Create course'));
    await tester.pumpAndSettle();

    expect(env.store.courses.single.name, 'Organic Chemistry');
    expect(env.store.courses.single.code, 'CHEM2');
    expect(find.text('Organic Chemistry'), findsOneWidget);
    expect(find.text('No courses yet'), findsNothing);
  });

  testWidgets(
    'a course space shows schedule, materials, assignments and notes',
    (tester) async {
      final env = await pumpApp(tester, setup: _seed);
      await _goTo(tester, 'Courses');
      await tester.tap(find.text('Algorithms'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Lecture 3'), findsWidgets);
      expect(find.text('Linear algebra'), findsOneWidget); // material

      // Add an assignment.
      await tester.scrollUntilVisible(
        find.text('Nothing due. Add assignments to see them on your calendar.'),
        200,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Add').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Problem set 1',
      );
      await tester.pump(); // enable the button
      await tester.tap(find.text('Add assignment'));
      await tester.pumpAndSettle();
      final a = env.store.assignments.single;
      expect(a.title, 'Problem set 1');
      expect(a.done, isFalse);

      // Tick it off.
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(env.store.assignments.single.done, isTrue);

      // Notes save after a pause.
      final notes = find.widgetWithText(
        TextField,
        'Key points, exam tips, questions for the lecturer…',
      );
      await tester.scrollUntilVisible(
        notes,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(notes, 'Dijkstra needs non-negative weights');
      await tester.pump(const Duration(seconds: 1));
      expect(
        env.store.courses.single.notes,
        'Dijkstra needs non-negative weights',
      );
    },
  );

  testWidgets('attaching and removing materials', (tester) async {
    final env = await pumpApp(
      tester,
      setup: (e) async {
        await e.addDoc('cell_reader.pdf');
        e.store.addCourse(name: 'Biology', colorIndex: 2, iconKey: 'biotech');
      },
    );
    await _goTo(tester, 'Courses');
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cell reader'));
    await tester.pumpAndSettle();
    expect(env.store.docs.single.courseId, env.store.courses.single.id);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove from course'));
    await tester.pumpAndSettle();
    expect(env.store.docs.single.courseId, isNull);
    await tester.pump(
      const Duration(milliseconds: 400),
    ); // let the save timer fire
  });

  testWidgets('deleting a course removes it and unlinks its documents', (
    tester,
  ) async {
    final env = await pumpApp(tester, setup: _seed);
    await _goTo(tester, 'Courses');
    await tester.tap(find.text('Algorithms'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(env.store.courses, isEmpty);
    expect(env.store.events, isEmpty);
    expect(env.store.docs.single.courseId, isNull);
    expect(find.text('No courses yet'), findsOneWidget);
  });

  testWidgets(
    'the week view lists today’s class and its book button opens the page',
    (tester) async {
      await pumpApp(tester, setup: _seed);
      await _goTo(tester, 'Calendar');
      expect(find.text('Lecture 3'), findsOneWidget);
      expect(find.textContaining('Hall B'), findsOneWidget);

      await tester.tap(find.byTooltip('Open Linear algebra · p. 7'));
      await tester.pumpAndSettle();
      expect(find.text('viewer page 7'), findsOneWidget);
    },
  );

  testWidgets('event details open the linked material', (tester) async {
    await pumpApp(tester, setup: _seed);
    await _goTo(tester, 'Calendar');
    await tester.tap(find.text('Lecture 3'));
    await tester.pumpAndSettle();
    expect(find.text('LECTURE'), findsOneWidget);
    expect(find.text('Hall B'), findsWidgets);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Open Linear algebra · p. 7'),
    );
    await tester.pumpAndSettle();
    expect(find.text('viewer page 7'), findsOneWidget);
  });

  testWidgets('adding an event from the calendar', (tester) async {
    final env = await pumpApp(
      tester,
      setup: (e) async {
        e.store.addCourse(name: 'Algorithms', colorIndex: 1, iconKey: 'code');
      },
    );
    await _goTo(tester, 'Calendar');
    await tester.tap(find.text('Add event'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Algorithms'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Practical'));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.ensureVisible(find.text('Add to calendar'));
    await tester.tap(find.text('Add to calendar'));
    await tester.pumpAndSettle();

    final e = env.store.events.single;
    expect(e.title, 'Algorithms Practical'); // defaults from course + kind
    expect(e.kind, EventKind.practical);
    expect(e.weekly, isTrue);
    expect(e.durationMin, 60);
    expect(sameDay(e.start, _today), isTrue);
  });

  testWidgets('a new event is valid by default (one hour long)', (
    tester,
  ) async {
    await pumpApp(tester);
    await _goTo(tester, 'Calendar');
    await tester.tap(find.text('Add event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Quiz');
    await tester.pump();
    // Nothing wrong yet: the default is one hour long.
    expect(
      find.text('The end time must be after the start time.'),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add to calendar'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('month view marks days and lists the selected day', (
    tester,
  ) async {
    await pumpApp(tester, setup: _seed);
    await _goTo(tester, 'Calendar');
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets); // agenda heading
    expect(find.text('Lecture 3'), findsOneWidget);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('Lecture 3'), findsOneWidget); // timeline block
  });

  testWidgets('assignments appear on their due day and can be ticked off', (
    tester,
  ) async {
    final env = await pumpApp(
      tester,
      setup: (e) async {
        final c = e.store.addCourse(
          name: 'Algorithms',
          colorIndex: 1,
          iconKey: 'code',
        );
        e.store.addAssignment(
          courseId: c.id,
          title: 'Problem set 2',
          due: _today.add(const Duration(hours: 23, minutes: 59)),
        );
      },
    );
    await _goTo(tester, 'Calendar');
    expect(find.text('Problem set 2'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(env.store.assignments.single.done, isTrue);
  });

  testWidgets('Library shows Next up with a button to the linked page', (
    tester,
  ) async {
    final now = DateTime.now();
    // Starts in an hour so it is always "next" regardless of the time of day.
    await pumpApp(
      tester,
      setup: (e) async {
        await e.addDoc('linear_algebra.pdf');
        final doc = e.store.docs.single;
        e.store.addEvent(
          title: 'Seminar',
          kind: EventKind.lecture,
          start: now.add(const Duration(hours: 1)),
          durationMin: 45,
          link: MaterialLink(docId: doc.id, page: 4),
        );
      },
    );
    expect(find.textContaining('NEXT UP'), findsOneWidget);
    expect(find.text('Seminar'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Linear algebra · p. 4'),
    );
    await tester.pumpAndSettle();
    expect(find.text('viewer page 4'), findsOneWidget);
  });

  testWidgets('a deleted document leaves a friendly message, not a crash', (
    tester,
  ) async {
    final env = await pumpApp(tester, setup: _seed);
    final doc = env.store.docs.single;
    await _goTo(tester, 'Calendar');
    await env.library.delete(doc);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open Linear algebra · p. 7'), findsNothing);
    expect(find.text('Lecture 3'), findsOneWidget);
  });

  testWidgets('document details can assign a course', (tester) async {
    final env = await pumpApp(
      tester,
      setup: (e) async {
        await e.addDoc('cell_reader.pdf');
        e.store.addCourse(name: 'Biology', colorIndex: 2, iconKey: 'biotech');
      },
    );
    await tester.longPress(find.text('Cell reader'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Biology'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(env.store.docs.single.courseId, env.store.courses.single.id);
  });
}
