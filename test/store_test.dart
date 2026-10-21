import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/library_store.dart';
import 'package:semesta/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LibraryStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return LibraryStore.load();
}

Doc _add(LibraryStore s, String title, {int pages = 10, DocCategory? c}) =>
    s.addDoc(
      title: title,
      storageKey: 'k-$title',
      pageCount: pages,
      category: c ?? DocCategory.other,
    );

void main() {
  test('titleFromFileName prettifies file names', () {
    expect(
      titleFromFileName('intro_to-algorithms_v2.PDF'),
      'Intro to algorithms v2',
    );
    expect(titleFromFileName('.pdf'), 'Untitled');
  });

  group('Doc progress', () {
    test('is 0 on the first page and 1 on the last', () {
      final d = Doc(
        id: 'a',
        title: 'A',
        storageKey: 'k',
        category: DocCategory.other,
        addedAt: _epoch,
        pageCount: 11,
      );
      expect(d.progress, 0);
      expect(d.copyWith(lastPage: 6).progress, closeTo(.5, 1e-9));
      expect(d.copyWith(lastPage: 11).progress, 1);
      expect(d.copyWith(lastPage: 11).finished, isTrue);
    });
  });

  group('LibraryStore', () {
    test('starts empty with dark theme by default', () async {
      final s = await _store();
      expect(s.docs, isEmpty);
      expect(s.themeMode, ThemeMode.dark);
      expect(s.continueReading, isNull);
    });

    test('records progress and clamps the page', () async {
      final s = await _store();
      final d = _add(s, 'Book');
      s.recordProgress(d.id, page: 4, pageCount: 10);
      expect(s.doc(d.id)!.lastPage, 4);
      expect(s.doc(d.id)!.lastOpenedAt, isNotNull);
      s.recordProgress(d.id, page: 99, pageCount: 10);
      expect(s.doc(d.id)!.lastPage, 10);
    });

    test('continueReading is the latest opened, unfinished document', () async {
      final s = await _store();
      final a = _add(s, 'A');
      final b = _add(s, 'B');
      s.recordProgress(a.id, page: 3, pageCount: 10);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      s.recordProgress(b.id, page: 2, pageCount: 10);
      expect(s.continueReading!.id, b.id);

      s.recordProgress(b.id, page: 10, pageCount: 10); // finished
      expect(s.continueReading!.id, a.id);
    });

    test('docsSorted puts recently opened first', () async {
      final s = await _store();
      final a = _add(s, 'A');
      final b = _add(s, 'B');
      expect(s.docsSorted().map((d) => d.id), [
        b.id,
        a.id,
      ]); // newest added first
      s.markOpened(a.id);
      expect(s.docsSorted().first.id, a.id);
    });

    test('filters by category and lists used categories', () async {
      final s = await _store();
      _add(s, 'T', c: DocCategory.textbook);
      _add(s, 'N', c: DocCategory.novel);
      expect(s.usedCategories, [DocCategory.textbook, DocCategory.novel]);
      expect(s.docsSorted(DocCategory.novel).single.title, 'N');
    });

    test('toggles bookmarks and keeps them sorted', () async {
      final s = await _store();
      final d = _add(s, 'Book');
      expect(s.toggleBookmark(d.id, 7), isTrue);
      expect(s.toggleBookmark(d.id, 2), isTrue);
      expect(s.doc(d.id)!.bookmarks.map((b) => b.page), [2, 7]);
      expect(s.toggleBookmark(d.id, 7), isFalse);
      expect(s.doc(d.id)!.bookmarks.map((b) => b.page), [2]);
    });

    test('updates title and category, ignoring blank titles', () async {
      final s = await _store();
      final d = _add(s, 'Old');
      s.updateDoc(d.id, title: 'New', category: DocCategory.lecture);
      expect(s.doc(d.id)!.title, 'New');
      expect(s.doc(d.id)!.category, DocCategory.lecture);
      s.updateDoc(d.id, title: '   ');
      expect(s.doc(d.id)!.title, 'New');
    });

    test('searches title and category', () async {
      final s = await _store();
      _add(s, 'Linear Algebra', c: DocCategory.textbook);
      _add(s, 'Solo Leveling', c: DocCategory.manhwa);
      expect(s.search('algebra').single.title, 'Linear Algebra');
      expect(s.search('manhwa').single.title, 'Solo Leveling');
      expect(s.search('  '), isEmpty);
    });

    test('removeDoc and clearAll return what they removed', () async {
      final s = await _store();
      final a = _add(s, 'A');
      _add(s, 'B');
      expect(s.removeDoc(a.id)!.title, 'A');
      expect(s.removeDoc(a.id), isNull);
      expect(s.clearAll().map((d) => d.title), ['B']);
      expect(s.docs, isEmpty);
    });

    test('persists docs and settings across loads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = await LibraryStore.load(prefs);
      final d = _add(a, 'Keep');
      a.recordProgress(d.id, page: 5, pageCount: 10);
      a.toggleBookmark(d.id, 5);
      a.themeMode = ThemeMode.light;
      a.nightReading = true;
      await a.flush();

      final b = await LibraryStore.load(prefs);
      final back = b.docs.single;
      expect(back.title, 'Keep');
      expect(back.lastPage, 5);
      expect(back.bookmarks.single.page, 5);
      expect(b.themeMode, ThemeMode.light);
      expect(b.nightReading, isTrue);
    });

    test(
      'settings changes notify settingsChanges, doc changes do not',
      () async {
        final s = await _store();
        var settings = 0;
        s.settingsChanges.addListener(() => settings++);
        final d = _add(s, 'A');
        s.recordProgress(d.id, page: 2, pageCount: 10);
        expect(settings, 0);
        s.nightReading = true;
        expect(settings, 1);
      },
    );
  });
}

final _epoch = DateTime.utc(2026);
