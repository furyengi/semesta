import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/reminder_settings.dart';

import 'support/fakes.dart';

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

DateTime get _soon => DateTime.now().add(const Duration(hours: 3));

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Settings'));
  await tester.pumpAndSettle();
}

Finder get _master => find.widgetWithText(SwitchListTile, 'Reminders');

Future<void> _finish(WidgetTester tester, TestEnv env) async {
  await tester.pump(const Duration(milliseconds: 500));
  env.reminders.dispose();
}

void main() {
  testWidgets('turning reminders on asks permission and reveals the options', (
    tester,
  ) async {
    final env = await pumpApp(tester, startReminders: true);
    env.notifier.permission = false;
    await _openSettings(tester);
    await tester.scrollUntilVisible(_master, 200);
    expect(find.text('Send a test notification'), findsNothing);

    await tester.tap(_master);
    await tester.pumpAndSettle();
    expect(env.notifier.permissionRequests, 1);
    expect(env.store.reminders.enabled, isTrue);
    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('10 min before'), findsNWidgets(2)); // classes and study
    expect(find.text('Nothing to remind you about yet.'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('a refused permission keeps reminders off and explains', (
    tester,
  ) async {
    final env = await pumpApp(tester, startReminders: true);
    env.notifier
      ..permission = false
      ..grantOnRequest = false;
    await _openSettings(tester);
    await tester.scrollUntilVisible(_master, 200);
    await tester.tap(_master);
    await tester.pumpAndSettle();
    expect(env.store.reminders.enabled, isFalse);
    expect(find.textContaining('blocked for Semesta'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('lead times, per-type switches and the daily summary', (
    tester,
  ) async {
    final env = await pumpApp(
      tester,
      startReminders: true,
      setup: (e) async =>
          e.store.reminders = const ReminderSettings(enabled: true),
    );
    await _openSettings(tester);
    await tester.scrollUntilVisible(find.text('Classes'), 200);

    await tester.ensureVisible(find.text('30 min before').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min before').first);
    await tester.pumpAndSettle();
    expect(env.store.reminders.classLeadMin, 30);

    await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Classes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Classes'));
    await tester.pumpAndSettle();
    expect(env.store.reminders.classes, isFalse);
    expect(
      find.text('30 min before'),
      findsOneWidget,
    ); // only study's chips remain

    await tester.scrollUntilVisible(find.text('Daily summary'), 200);
    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Daily summary'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Daily summary'));
    await tester.pumpAndSettle();
    expect(env.store.reminders.digest, isTrue);
    expect(find.text('8:00 AM'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('the screen reports what is scheduled and can send a test', (
    tester,
  ) async {
    final env = await pumpApp(
      tester,
      startReminders: true,
      setup: (e) async {
        e.store.reminders = const ReminderSettings(enabled: true);
        e.store.addEvent(
          title: 'Lecture',
          kind: EventKind.lecture,
          start: _soon,
          durationMin: 60,
        );
      },
    );
    await _openSettings(tester);
    await tester.scrollUntilVisible(find.text('Send a test notification'), 300);
    expect(find.textContaining('1 reminders scheduled'), findsOneWidget);

    await tester.ensureVisible(find.text('Send a test notification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send a test notification'));
    await tester.pumpAndSettle();
    expect(env.notifier.shown.single.title, 'Reminders are on');
    await _finish(tester, env);
  });

  testWidgets(
    'blocked notifications show a warning while the switch stays on',
    (tester) async {
      final env = await pumpApp(
        tester,
        startReminders: true,
        setup: (e) async {
          e.store.reminders = const ReminderSettings(enabled: true);
          e.notifier.permission = false;
        },
      );
      await env.reminders.sync();
      await _openSettings(tester);
      await tester.scrollUntilVisible(_master, 200);
      await tester.pumpAndSettle();
      expect(find.textContaining('Notifications are blocked'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(_master).value, isTrue);
      await _finish(tester, env);
    },
  );

  testWidgets('platforms without notifications say so', (tester) async {
    final env = await TestEnv.create();
    env.notifier.supported = false;
    await pumpApp(tester, env: env, startReminders: true);
    await _openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Not available on this platform'),
      200,
    );
    expect(find.text('Not available on this platform'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets(
    'the tip appears once there is something to remind, and can be turned on',
    (tester) async {
      final env = await pumpApp(
        tester,
        reminderPrompt: true,
        startReminders: true,
        setup: (e) async => e.store.addEvent(
          title: 'Lecture',
          kind: EventKind.lecture,
          start: _soon,
          durationMin: 60,
        ),
      );
      await tester.tap(_nav('Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Never miss a class or session'), findsOneWidget);

      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(env.store.reminders.enabled, isTrue);
      expect(find.text('Never miss a class or session'), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(env.notifier.scheduled, hasLength(1));
      await _finish(tester, env);
    },
  );

  testWidgets('the tip can be dismissed and stays away', (tester) async {
    final env = await pumpApp(
      tester,
      reminderPrompt: true,
      setup: (e) async => e.store.addEvent(
        title: 'Lecture',
        kind: EventKind.lecture,
        start: _soon,
        durationMin: 60,
      ),
    );
    await tester.tap(_nav('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Never miss a class or session'), findsNothing);
    expect(env.store.reminderPromptDismissed, isTrue);
    expect(env.store.reminders.enabled, isFalse);
    await _finish(tester, env);
  });

  testWidgets('no tip on an empty timetable', (tester) async {
    final env = await pumpApp(tester, reminderPrompt: true);
    await tester.tap(_nav('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Never miss a class or session'), findsNothing);
    await _finish(tester, env);
  });

  testWidgets('tapping a reminder opens the right tab', (tester) async {
    final env = await pumpApp(tester, startReminders: true);
    env.notifier.tap('tab:3');
    await tester.pumpAndSettle();
    expect(find.text('Study planner'), findsOneWidget);
    env.notifier.tap('tab:2');
    await tester.pumpAndSettle();
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Study planner'), findsNothing);
    await _finish(tester, env);
  });

  testWidgets('tapping a class reminder opens its material at the page', (
    tester,
  ) async {
    final env = await pumpApp(
      tester,
      startReminders: true,
      setup: (e) async => e.addDoc('linear_algebra.pdf'),
    );
    final doc = env.store.docs.single;
    env.notifier.tap('doc:${doc.id}:7');
    await tester.pumpAndSettle();
    expect(find.text('viewer page 7'), findsOneWidget);

    // From inside the reader, another reminder takes you back to the shell.
    env.notifier.tap('tab:1');
    await tester.pumpAndSettle();
    expect(find.text('viewer page 7'), findsNothing);
    expect(find.text('No courses yet'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('a reminder that launched the app is handled on start', (
    tester,
  ) async {
    final env = await TestEnv.create();
    env.notifier.launch = 'tab:3';
    await pumpApp(tester, env: env, startReminders: true);
    await tester.pumpAndSettle();
    expect(find.text('Study planner'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('bad payloads and missing documents do nothing harmful', (
    tester,
  ) async {
    final env = await pumpApp(tester, startReminders: true);
    env.notifier.tap('garbage');
    env.notifier.tap('doc:nope:3');
    await tester.pumpAndSettle();
    expect(
      find.text('That material is no longer in your library'),
      findsOneWidget,
    );
    await _finish(tester, env);
  });
}
