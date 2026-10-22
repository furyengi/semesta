import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/core/widget_service.dart';
import 'package:semesta/data/academic_models.dart';
import 'package:semesta/data/widget_data.dart';

import 'support/fakes.dart';

Future<void> _finish(WidgetTester tester, TestEnv env) async {
  await tester.pump(const Duration(milliseconds: 500));
  env.widgets.dispose();
}

List<dynamic> _json(TestEnv env, String key) =>
    jsonDecode(env.widgetBackend.published[key]!) as List<dynamic>;

void main() {
  testWidgets('an unsupported platform does nothing', (tester) async {
    final env = await TestEnv.create();
    env.widgetBackend.supported = false;
    await env.widgets.start();
    env.store.addEvent(
      title: 'L',
      kind: EventKind.lecture,
      start: DateTime.now().add(const Duration(hours: 2)),
      durationMin: 60,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.widgets.supported, isFalse);
    expect(env.widgetBackend.publishCalls, 0);
    expect(await env.widgets.takeLaunchPayload(), isNull);
    await _finish(tester, env);
  });

  testWidgets('starting publishes the current data once', (tester) async {
    final env = await TestEnv.create();
    env.store.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: DateTime.now().add(const Duration(hours: 2)),
      durationMin: 60,
    );
    await env.widgets.start();
    expect(env.widgetBackend.publishCalls, 1);
    expect(env.widgets.canPin, isTrue);
    expect(_json(env, WidgetKeys.nextUp), hasLength(1));
    expect(env.widgets.data, env.widgetBackend.published);
    await env.widgets.start(); // idempotent
    expect(env.widgetBackend.publishCalls, 1);
    await _finish(tester, env);
  });

  testWidgets('only changes the widgets show cause a publish', (tester) async {
    final env = await TestEnv.create();
    await env.widgets.start();
    final calls = env.widgetBackend.publishCalls;

    env.store.themeMode = ThemeMode.light; // unrelated
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.widgetBackend.publishCalls, calls);

    env.store.addEvent(
      title: 'Lecture',
      kind: EventKind.lecture,
      start: DateTime.now().add(const Duration(hours: 2)),
      durationMin: 60,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.widgetBackend.publishCalls, calls + 1);
    expect(_json(env, WidgetKeys.nextUp), hasLength(1));
    await _finish(tester, env);
  });

  testWidgets('deadlines, study and reading progress flow through', (
    tester,
  ) async {
    final env = await TestEnv.create();
    await env.widgets.start();
    final c = env.store.addCourse(name: 'Algo', colorIndex: 1, iconKey: 'code');
    final a = env.store.addAssignment(
      courseId: c.id,
      title: 'PS3',
      due: DateTime.now().add(const Duration(days: 2)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(_json(env, WidgetKeys.deadlines).single['title'], 'PS3');

    env.store.toggleAssignment(a.id);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_json(env, WidgetKeys.deadlines), isEmpty);

    await env.addDoc('book.pdf');
    final doc = env.store.docs.single;
    env.store.recordProgress(doc.id, page: 6, pageCount: 12);
    await tester.pump(const Duration(milliseconds: 100));
    final cont = jsonDecode(
      env.widgetBackend.published[WidgetKeys.continueReading]!,
    ) as Map<String, dynamic>;
    expect(cont['subtitle'], 'Page 6 of 12');
    expect(cont['progress'], 45);
    await _finish(tester, env);
  });

  testWidgets('syncing later drops what has passed', (tester) async {
    final env = await TestEnv.create();
    var now = DateTime(2026, 10, 22, 10);
    final svc = WidgetService(
      store: env.store,
      backend: env.widgetBackend,
      clock: () => now,
      debounce: const Duration(milliseconds: 50),
      use24h: () => false,
    );
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
    await svc.start();
    expect(_json(env, WidgetKeys.nextUp).map((e) => (e as Map)['title']), [
      'Morning',
      'Afternoon',
    ]);

    now = DateTime(2026, 10, 22, 13);
    await svc.sync(); // app resumed
    expect(_json(env, WidgetKeys.nextUp).map((e) => (e as Map)['title']), [
      'Afternoon',
    ]);
    await tester.pump(const Duration(milliseconds: 500));
    svc.dispose();
    env.widgets.dispose();
  });

  testWidgets('taps, launch payload and pinning are passed along', (
    tester,
  ) async {
    final env = await TestEnv.create();
    env.widgetBackend.launch = 'tab:2';
    await env.widgets.start();

    final taps = <String>[];
    final sub = env.widgets.taps.listen(taps.add);
    env.widgetBackend.tap('doc:abc:7');
    await tester.pump();
    expect(taps, ['doc:abc:7']);
    sub.cancel(); // not awaited: a fake-async test can't wait on it

    expect(await env.widgets.takeLaunchPayload(), 'tab:2');
    expect(await env.widgets.takeLaunchPayload(), isNull); // once

    expect(await env.widgets.pin(WidgetKind.deadlines), isTrue);
    expect(env.widgetBackend.pinned, [WidgetKind.deadlines]);
    env.widgetBackend.pinSupported = false;
    expect(await env.widgets.pin(WidgetKind.today), isFalse);
    await _finish(tester, env);
  });

  testWidgets('overlapping syncs end with the latest data', (tester) async {
    final env = await TestEnv.create();
    await env.widgets.start();
    env.store.addEvent(
      title: 'A',
      kind: EventKind.lecture,
      start: DateTime.now().add(const Duration(hours: 2)),
      durationMin: 60,
    );
    final a = env.widgets.sync();
    env.store.addEvent(
      title: 'B',
      kind: EventKind.lecture,
      start: DateTime.now().add(const Duration(hours: 3)),
      durationMin: 60,
    );
    final b = env.widgets.sync();
    await Future.wait([a, b]);
    expect(_json(env, WidgetKeys.nextUp), hasLength(2));
    await _finish(tester, env);
  });
}
