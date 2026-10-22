import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/widget_data.dart';
import 'package:semesta/widgets/widget_settings_section.dart';

import 'support/fakes.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Settings'));
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester, TestEnv env) async {
  await tester.pump(const Duration(milliseconds: 500));
  env.widgets.dispose();
}

DateTime get _soon => DateTime.now().add(const Duration(hours: 3));

void main() {
  testWidgets('settings shows a preview of each widget with live data', (
    tester,
  ) async {
    final env = await pumpApp(
      tester,
      startWidgets: true,
      setup: (e) async {
        final c = e.store.addCourse(
          name: 'Algorithms',
          colorIndex: 1,
          iconKey: 'code',
        );
        e.store.addEvent(
          title: 'Lecture 4',
          kind: EventKind.lecture,
          start: _soon,
          durationMin: 60,
          courseId: c.id,
          location: 'Hall B',
        );
        e.store.addAssignment(
          courseId: c.id,
          title: 'Problem set 3',
          due: DateTime.now().add(const Duration(days: 2)),
        );
        await e.addDoc('linear_algebra.pdf');
        e.store.recordProgress(e.store.docs.single.id, page: 4, pageCount: 12);
      },
    );
    await env.widgets.sync();
    await _openSettings(tester);
    await tester.scrollUntilVisible(find.text('NEXT UP'), 300);
    expect(find.text('Lecture 4'), findsWidgets);
    expect(find.textContaining('Algorithms · Hall B'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('DEADLINES'), 300);
    expect(find.text('Problem set 3'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('CONTINUE READING'), 300);
    expect(find.text('Page 4 of 12'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('empty previews explain themselves', (tester) async {
    final env = await pumpApp(tester, startWidgets: true);
    await _openSettings(tester);
    await tester.scrollUntilVisible(find.text(WidgetTexts.emptyNextUp), 300);
    expect(find.text(WidgetTexts.emptyToday), findsOneWidget);
    await tester.scrollUntilVisible(find.text(WidgetTexts.emptyContinue), 300);
    expect(find.text(WidgetTexts.emptyDeadlines), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('each widget can be added from the app', (tester) async {
    final env = await pumpApp(tester, startWidgets: true);
    await _openSettings(tester);
    final add = find.byTooltip('Add deadlines widget');
    await tester.scrollUntilVisible(add, 300);
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(env.widgetBackend.pinned, [WidgetKind.deadlines]);
    expect(find.textContaining('Confirm in your launcher'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('a launcher that refuses gets a fallback hint', (tester) async {
    final env = await TestEnv.create();
    await pumpApp(tester, env: env, startWidgets: true);
    env.widgetBackend.pinSupported = true;
    await _openSettings(tester);
    final add = find.byTooltip('Add today widget');
    await tester.scrollUntilVisible(add, 300);
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    env.widgetBackend.pinSupported = false; // refuses at tap time
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.textContaining('Long-press the home screen'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('without in-app pinning the section explains how to add one', (
    tester,
  ) async {
    final env = await TestEnv.create();
    env.widgetBackend.pinSupported = false;
    await pumpApp(tester, env: env, startWidgets: true);
    await _openSettings(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Long-press your home screen'),
      300,
    );
    expect(find.byTooltip('Add next up widget'), findsNothing);
    await _finish(tester, env);
  });

  testWidgets('platforms without widgets say so', (tester) async {
    final env = await TestEnv.create();
    env.widgetBackend.supported = false;
    await pumpApp(tester, env: env, startWidgets: true);
    await _openSettings(tester);
    await tester.scrollUntilVisible(find.text('Home screen widgets').last, 300);
    expect(find.text('Not available on this platform'), findsWidgets);
    await _finish(tester, env);
  });

  testWidgets('a widget tap opens the right tab or document', (tester) async {
    final env = await pumpApp(
      tester,
      startWidgets: true,
      setup: (e) async => e.addDoc('linear_algebra.pdf'),
    );
    env.widgetBackend.tap('tab:3');
    await tester.pumpAndSettle();
    expect(find.text('Study planner'), findsOneWidget);

    env.widgetBackend.tap('doc:${env.store.docs.single.id}:9');
    await tester.pumpAndSettle();
    expect(find.text('viewer page 9'), findsOneWidget);

    env.widgetBackend.tap('tab:1');
    await tester.pumpAndSettle();
    expect(find.text('viewer page 9'), findsNothing);
    expect(find.text('No courses yet'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('a widget tap that launched the app is handled on start', (
    tester,
  ) async {
    final env = await TestEnv.create();
    env.widgetBackend.launch = 'tab:2';
    await pumpApp(tester, env: env, startWidgets: true);
    await tester.pumpAndSettle();
    expect(find.text('Add event'), findsOneWidget); // the Calendar tab's button
    await _finish(tester, env);
  });

  testWidgets('returning to the app refreshes the widgets right away', (
    tester,
  ) async {
    final env = await pumpApp(tester, startWidgets: true);
    final before = env.widgetBackend.publishCalls;
    env.store.addEvent(
      title: 'Seminar',
      kind: EventKind.lecture,
      start: _soon,
      durationMin: 60,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(env.widgetBackend.publishCalls, greaterThan(before));
    expect(env.widgetBackend.published[WidgetKeys.nextUp], contains('Seminar'));
    await _finish(tester, env);
  });

  testWidgets('WidgetPreview follows the clock for next up and today', (
    tester,
  ) async {
    final env = await TestEnv.create();
    env.store.addEvent(
      title: 'Morning',
      kind: EventKind.lecture,
      start: DateTime(2026, 10, 22, 11),
      durationMin: 60,
    );
    env.store.addEvent(
      title: 'Afternoon',
      kind: EventKind.lecture,
      start: DateTime(2026, 10, 22, 15),
      durationMin: 60,
    );
    final data = buildWidgetData(env.store, DateTime(2026, 10, 22, 10));
    Future<void> show(WidgetKind k, DateTime at) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WidgetPreview(kind: k, data: data, now: at),
        ),
      ),
    );

    await show(WidgetKind.nextUp, DateTime(2026, 10, 22, 10));
    expect(find.text('NEXT UP'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);

    await show(WidgetKind.nextUp, DateTime(2026, 10, 22, 11, 30));
    expect(find.text('HAPPENING NOW'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);

    await show(WidgetKind.nextUp, DateTime(2026, 10, 22, 12));
    expect(find.text('Afternoon'), findsOneWidget);

    await show(WidgetKind.nextUp, DateTime(2026, 10, 22, 17));
    expect(find.text(WidgetTexts.emptyNextUp), findsOneWidget);

    await show(WidgetKind.today, DateTime(2026, 10, 22, 12));
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    await show(WidgetKind.today, DateTime(2026, 10, 23, 8));
    expect(find.text(WidgetTexts.emptyToday), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    env.reminders.dispose();
  });
}
