import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/core/library_service.dart';
import 'package:semesta/data/models.dart';

import 'support/fakes.dart';

void main() {
  test('imports valid PDFs and reports unreadable ones', () async {
    final env = await TestEnv.create(pages: 30);
    final result = await env.library.importFiles([
      PickedFile(name: 'linear_algebra.pdf', readBytes: () async => pdfBytes()),
      PickedFile(name: 'broken.pdf', readBytes: () async => Uint8List(0)),
      const PickedFile(name: 'nothing.pdf'),
    ]);
    expect(result.added.single.title, 'Linear algebra');
    expect(result.added.single.pageCount, 30);
    expect(result.failed, ['broken.pdf', 'nothing.pdf']);
    expect(env.store.docs, hasLength(1));
    // Failed imports don't leave files behind.
    expect(env.storage.count, 1);
  });

  test('delete removes the entry and its file', () async {
    final env = await TestEnv.create();
    await env.addDoc('a.pdf');
    final doc = env.store.docs.single;
    await env.library.delete(doc);
    expect(env.store.docs, isEmpty);
    expect(env.storage.count, 0);
  });

  test('deleteAll clears everything', () async {
    final env = await TestEnv.create();
    await env.addDoc('a.pdf');
    await env.addDoc('b.pdf');
    await env.library.deleteAll();
    expect(env.store.docs, isEmpty);
    expect(env.storage.count, 0);
  });

  test('pruneMissing drops entries whose file is gone', () async {
    final env = await TestEnv.create();
    await env.addDoc('a.pdf');
    await env.addDoc('b.pdf');
    await env.storage.delete(env.store.docs.first.storageKey);
    await env.library.pruneMissing();
    expect(env.store.docs, hasLength(1));
  });

  test('seeds the sample guide once', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final env = await TestEnv.create();
    await env.library.seedIfNeeded();
    final doc = env.store.docs.single;
    expect(doc.title, 'Getting started with Semesta');
    expect(doc.category, DocCategory.notes);

    await env.library.deleteAll();
    await env.library.seedIfNeeded(); // already seeded: stays empty
    expect(env.store.docs, isEmpty);
    await env.library.seedIfNeeded(whenEmpty: true); // web: reseed when empty
    expect(env.store.docs, hasLength(1));
  });
}
