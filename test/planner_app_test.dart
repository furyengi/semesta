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

/// A session that is "today" and not over at any time of day.
StudySession _allDaySession(
  TestEnv e, {
  String title = 'Revise graphs',
  String? goalId,
}) => e.store.addSession(
  title: title,
  start: _today,
  durationMin: 1439,
  goalId: goalId,
);

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Plan tab starts empty and offers a new plan', (
    tester,
  ) async {
    await pumpApp(tester);
    await _goTo(tester, 'Plan');
    expect(find.text('Study planner'), findsOneWidget);
    expect(find.text('No study plans yet'), findsOneWidget);
    expect(find.text('No study sessions today.'), findsOneWidget);
    expect(find.text('New plan'), findsWidgets);
    expect(find.text('Add PDF'), findsNothing);
    expect(find.text('Read. Learn.\nProgress.'), findsNothing);
  });

  testWidgets('creating a custom plan schedules sessions and opens it', (
    tester,
  ) async {
    final env = await pumpApp(tester);
    await _goTo(tester, 'Plan');
    await tester.tap(find.widgetWithText(FloatingActionButton, 'New plan'));
    await tester.pumpAndSettle();

    expect(find.text('New study plan'), findsOneWidget);
    // Nothing yet: needs a name.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create plan'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Plan name'),
      'Revise databases',
    );
    await tester.pump();
    expect(
      find.textContaining('6 sessions'),
      findsOneWidget,
    ); // 6 h in 1 h sessions

    await _tap(tester, find.widgetWithText(FilledButton, 'Create plan'));

    final g = env.store.goals.single;
    expect(g.title, 'Revise databases');
    expect(env.store.sessionsFor(g.id), hasLength(6));
    // Opened on the plan.
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('0 of 6 sessions done'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('an exam without a plan is offered one, pre-filled', (
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
        e.store.addEvent(
          title: 'Midterm',
          kind: EventKind.exam,
          start: _today.add(const Duration(days: 10, hours: 10)),
          durationMin: 120,
          courseId: c.id,
        );
      },
    );
    await _goTo(tester, 'Plan');
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('No study plan yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Plan'));
    await tester.pumpAndSettle();
    expect(find.text('New study plan'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Midterm'),
      findsOneWidget,
    ); // pre-filled name
    expect(find.textContaining('sessions'), findsWidgets);

    await _tap(tester, find.widgetWithText(FilledButton, 'Create plan'));
    final g = env.store.goals.single;
    expect(g.sourceId, env.store.events.single.id);
    expect(g.courseId, env.store.courses.single.id);
    expect(g.target, env.store.events.single.start);

    // Back on the tab, the exam is no longer flagged.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('No study plan yet'), findsNothing);
    expect(find.text('Midterm'), findsOneWidget); // the plan card
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('with no study days selected the plan cannot be created', (
    tester,
  ) async {
    await pumpApp(tester);
    await _goTo(tester, 'Plan');
    await tester.tap(find.widgetWithText(FloatingActionButton, 'New plan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Plan name'), 'X');
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      await _tap(tester, find.widgetWithText(FilterChip, d));
    }
    expect(
      find.text('Name your plan and pick at least one day.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create plan'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('ticking sessions off updates the plan', (tester) async {
    final env = await pumpApp(
      tester,
      setup: (e) async {
        e.store.createPlan(
          title: 'Finals',
          target: _today.add(const Duration(days: 12, hours: 9)),
          totalMinutes: 240,
          sessionMinutes: 60,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          startMinute: 18 * 60,
        );
      },
    );
    await _goTo(tester, 'Plan');
    expect(find.text('Finals'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.textContaining('0 of 4 sessions'), findsOneWidget);

    await tester.tap(find.text('Finals'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 4 sessions done'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 of 4 sessions done'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget); // studied so far
    expect(env.store.planProgress(env.store.goals.single.id).doneCount, 1);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'missed sessions show up under Needs attention and can be moved',
    (tester) async {
      final env = await pumpApp(
        tester,
        setup: (e) async {
          e.store.addSession(
            title: 'Chapter 4 problems',
            start: _today
                .subtract(const Duration(days: 2))
                .add(const Duration(hours: 18)),
            durationMin: 60,
          );
        },
      );
      await _goTo(tester, 'Plan');
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Chapter 4 problems'), findsOneWidget);
      expect(find.textContaining('Missed'), findsOneWidget);

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to today'));
      await tester.pumpAndSettle();
      expect(sameDay(env.store.sessions.single.start, _today), isTrue);
      expect(env.store.sessions.single.start.hour, 18);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('deleting a session can be undone', (tester) async {
    final env = await pumpApp(tester, setup: (e) async => _allDaySession(e));
    await _goTo(tester, 'Plan');
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(env.store.sessions, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(env.store.sessions, hasLength(1));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a plan screen can add a session, re-plan and delete the plan', (
    tester,
  ) async {
    final env = await pumpApp(
      tester,
      setup: (e) async {
        e.store.createPlan(
          title: 'Finals',
          target: _today.add(const Duration(days: 12, hours: 9)),
          totalMinutes: 120,
          sessionMinutes: 60,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          startMinute: 18 * 60,
        );
      },
    );
    final id = env.store.goals.single.id;
    await _goTo(tester, 'Plan');
    await tester.tap(find.text('Finals'));
    await tester.pumpAndSettle();

    // Add a session.
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What will you study?'),
      'Extra practice',
    );
    await tester.pump();
    await _tap(tester, find.widgetWithText(FilledButton, 'Add session'));
    expect(env.store.sessionsFor(id), hasLength(3));
    expect(find.text('Extra practice'), findsOneWidget);

    // Re-plan keeps the plan and refills it.
    await tester.tap(find.byTooltip('More options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Re-plan remaining'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Re-plan'));
    await tester.pumpAndSettle();
    expect(find.text('Plan updated'), findsOneWidget);
    expect(env.store.sessionsFor(id).fold(0, (a, s) => a + s.durationMin), 120);

    // Delete.
    await tester.tap(find.byTooltip('More options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(env.store.goals, isEmpty);
    expect(env.store.sessions, isEmpty);
    expect(find.text('No study plans yet'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('study sessions appear on the calendar', (tester) async {
    final env = await pumpApp(
      tester,
      setup: (e) async => _allDaySession(e, title: 'Revise graphs'),
    );
    await _goTo(tester, 'Calendar');
    expect(find.text('Revise graphs'), findsOneWidget); // week view
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(env.store.sessions.single.done, isTrue);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('Revise graphs'), findsOneWidget); // timeline block
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
    'the Library shows today’s study sessions and a way into the material',
    (tester) async {
      await pumpApp(
        tester,
        setup: (e) async {
          await e.addDoc('linear_algebra.pdf');
          final doc = e.store.docs.single;
          e.store.addSession(
            title: 'Read chapter',
            start: _today,
            durationMin: 1439,
            link: MaterialLink(docId: doc.id, page: 5),
          );
        },
      );
      expect(find.textContaining('1 study session today'), findsOneWidget);
      await tester.tap(find.byTooltip('Open Linear algebra · p. 5'));
      await tester.pumpAndSettle();
      expect(find.text('viewer page 5'), findsOneWidget);
    },
  );
}
