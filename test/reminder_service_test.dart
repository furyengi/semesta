import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/reminder_settings.dart';

import 'support/fakes.dart';

/// Lets the store's debounced save and the service's timers finish.
Future<void> _finish(WidgetTester tester, TestEnv env) async {
  await tester.pump(const Duration(milliseconds: 500));
  env.reminders.dispose();
}

DateTime get _soon => DateTime.now().add(const Duration(hours: 3));

void main() {
  testWidgets('starting with reminders off clears anything left scheduled', (
    tester,
  ) async {
    final env = await TestEnv.create();
    await env.reminders.start();
    expect(env.notifier.replaceCalls, 1);
    expect(env.notifier.scheduled, isEmpty);

    await _finish(tester, env);
  });

  testWidgets(
    'enabling asks for permission, turns reminders on and schedules',
    (tester) async {
      final env = await TestEnv.create();
      env.notifier.permission = false;
      env.store.addEvent(
        title: 'Lecture',
        kind: EventKind.lecture,
        start: _soon,
        durationMin: 60,
      );
      await env.reminders.start();

      expect(await env.reminders.enable(), isTrue);
      expect(env.notifier.permissionRequests, 1);
      expect(env.store.reminders.enabled, isTrue);
      await tester.pump(const Duration(milliseconds: 100)); // debounce
      expect(env.notifier.scheduled, hasLength(1));
      expect(env.notifier.scheduled.single.title, startsWith('Lecture in'));
      expect(env.reminders.scheduled, hasLength(1));

      await _finish(tester, env);
    },
  );

  testWidgets('a refused permission leaves reminders off', (tester) async {
    final env = await TestEnv.create();
    env.notifier
      ..permission = false
      ..grantOnRequest = false;
    await env.reminders.start();
    expect(await env.reminders.enable(), isFalse);
    expect(env.store.reminders.enabled, isFalse);
    expect(env.reminders.permissionGranted, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.notifier.scheduled, isEmpty);

    await _finish(tester, env);
  });

  testWidgets('unrelated changes do not reschedule', (tester) async {
    final env = await TestEnv.create();
    env.store.reminders = const ReminderSettings(enabled: true);
    env.store.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: _soon,
      durationMin: 60,
    );
    await env.reminders.start();
    final calls = env.notifier.replaceCalls;

    await env.addDoc('a.pdf'); // a library change, not a timetable one
    env.store.recordProgress(env.store.docs.single.id, page: 3, pageCount: 12);
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.notifier.replaceCalls, calls);
    await _finish(tester, env);
  });

  testWidgets('adding, editing and deleting items keeps the schedule right', (
    tester,
  ) async {
    final env = await TestEnv.create();
    env.store.reminders = const ReminderSettings(enabled: true);
    await env.reminders.start();
    expect(env.notifier.scheduled, isEmpty);

    final e = env.store.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: _soon,
      durationMin: 60,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.notifier.scheduled, hasLength(1));

    env.store.replaceEvent(e.copyWith(location: 'Room 9'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.notifier.scheduled.single.body, contains('Room 9'));

    final s = env.store.addSession(
      title: 'Revise',
      start: _soon.add(const Duration(hours: 1)),
      durationMin: 30,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.notifier.scheduled, hasLength(2));
    env.store.toggleSession(s.id); // done -> no longer reminded
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.notifier.scheduled, hasLength(1));

    env.store.removeEvent(e.id);
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.notifier.scheduled, isEmpty);
    await _finish(tester, env);
  });

  testWidgets('turning reminders off cancels everything', (tester) async {
    final env = await TestEnv.create();
    env.store.reminders = const ReminderSettings(enabled: true);
    env.store.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: _soon,
      durationMin: 60,
    );
    await env.reminders.start();
    expect(env.notifier.scheduled, hasLength(1));
    env.reminders.disable();
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.notifier.scheduled, isEmpty);

    await _finish(tester, env);
  });

  testWidgets('changing a lead time moves the reminder', (tester) async {
    final env = await TestEnv.create();
    env.store.reminders = const ReminderSettings(
      enabled: true,
      classLeadMin: 10,
    );
    final start = DateTime.now().add(const Duration(hours: 5));
    env.store.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: start,
      durationMin: 60,
    );
    await env.reminders.start();
    final first = env.notifier.scheduled.single.when;
    env.store.reminders = env.store.reminders.copyWith(classLeadMin: 30);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      first.difference(env.notifier.scheduled.single.when),
      const Duration(minutes: 20),
    );

    await _finish(tester, env);
  });

  testWidgets('revoked permission stops scheduling and is noticed', (
    tester,
  ) async {
    final env = await TestEnv.create();
    env.store.reminders = const ReminderSettings(enabled: true);
    env.store.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: _soon,
      durationMin: 60,
    );
    await env.reminders.start();
    expect(env.notifier.scheduled, hasLength(1));

    env.notifier.permission =
        false; // user blocks notifications in system settings
    await env.reminders.sync();
    expect(env.notifier.scheduled, isEmpty);
    expect(env.reminders.permissionGranted, isFalse);
    expect(env.store.reminders.enabled, isTrue); // their choice is kept

    env.notifier.permission = true;
    await env.reminders.sync();
    expect(env.notifier.scheduled, hasLength(1));

    await _finish(tester, env);
  });

  testWidgets('an unsupported platform never schedules', (tester) async {
    final env = await TestEnv.create();
    env.notifier.supported = false;
    env.store.reminders = const ReminderSettings(enabled: true);
    env.store.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: _soon,
      durationMin: 60,
    );
    await env.reminders.start();
    expect(env.reminders.supported, isFalse);
    expect(await env.reminders.enable(), isFalse);
    expect(env.notifier.scheduled, isEmpty);

    await _finish(tester, env);
  });

  testWidgets('the test notification and launch payload', (tester) async {
    final env = await TestEnv.create();
    env.notifier.launch = 'tab:3';
    await env.reminders.start();
    await env.reminders.sendTest();
    expect(env.notifier.shown.single.title, 'Reminders are on');
    expect(await env.reminders.takeLaunchPayload(), 'tab:3');
    expect(await env.reminders.takeLaunchPayload(), isNull); // only once

    await _finish(tester, env);
  });

  testWidgets('overlapping syncs end in the latest state', (tester) async {
    final env = await TestEnv.create();
    env.store.reminders = const ReminderSettings(enabled: true);
    await env.reminders.start();
    env.store.addEvent(
      title: 'A',
      kind: EventKind.lecture,
      start: _soon,
      durationMin: 60,
    );
    final a = env.reminders.sync();
    env.store.addEvent(
      title: 'B',
      kind: EventKind.lecture,
      start: _soon.add(const Duration(hours: 1)),
      durationMin: 60,
    );
    final b = env.reminders.sync();
    await Future.wait([a, b]);
    expect(env.notifier.scheduled, hasLength(2));
    await _finish(tester, env);
  });
}
