import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:semesta/data/models.dart';
import 'package:semesta/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore.load();
}

void main() {
  group('normalizeUrl', () {
    test('adds https and keeps valid urls', () {
      expect(normalizeUrl('example.com/a'), 'https://example.com/a');
      expect(normalizeUrl('  http://example.com  '), 'http://example.com');
    });

    test('rejects non-links', () {
      expect(normalizeUrl(''), isNull);
      expect(normalizeUrl('hello world'), isNull);
      expect(normalizeUrl('localhost'), isNull);
      expect(normalizeUrl('ftp://example.com'), isNull);
    });
  });

  test('titleFromUrl builds a readable offline title', () {
    expect(
      titleFromUrl('https://www.seriouseats.com/best-pancake-recipe'),
      'Best pancake recipe',
    );
    expect(titleFromUrl('https://example.com/'), 'example.com');
  });

  group('AppStore', () {
    test('seeds starter collections with Unsorted first', () async {
      final store = await _store();
      expect(store.rootCollections.first.isUnsorted, isTrue);
      expect(store.rootCollections.length, greaterThan(1));
    });

    test('adds, dedupes and validates links', () async {
      final store = await _store();
      final before = store.linkCount(Collection.unsortedId);
      expect(store.addLink('nope nope'), AddLinkResult.invalid);
      expect(store.addLink('example.com/x'), AddLinkResult.added);
      expect(store.addLink('https://example.com/x'), AddLinkResult.duplicate);
      expect(store.linkCount(Collection.unsortedId), before + 1);
    });

    test('moves, deletes and restores a link', () async {
      final store = await _store();
      store.addLink('example.com/m');
      final link = store.lastAdded!;
      final target = store.rootCollections[1];
      store.moveLink(link.id, target.id);
      expect(store.linksIn(target.id).any((l) => l.id == link.id), isTrue);
      store.deleteLink(link.id);
      expect(store.linksIn(target.id).any((l) => l.id == link.id), isFalse);
      store.restoreLink(link.copyWith(collectionId: target.id));
      expect(store.linksIn(target.id).any((l) => l.id == link.id), isTrue);
    });

    test('deleting a collection moves its links to Unsorted', () async {
      final store = await _store();
      final c = store.addCollection(
        name: 'Temp',
        colorIndex: 1,
        iconKey: 'star',
      );
      final sub = store.addCollection(
        name: 'Sub',
        colorIndex: 2,
        iconKey: 'star',
        parentId: c.id,
      );
      store.addLink('example.com/a', collectionId: c.id);
      store.addLink('example.com/b', collectionId: sub.id);
      expect(store.linkCount(c.id), 2);
      expect(store.folderCount(c.id), 1);

      final unsorted = store.linkCount(Collection.unsortedId);
      store.deleteCollection(c.id);
      expect(store.collection(c.id), isNull);
      expect(store.collection(sub.id), isNull);
      expect(store.linkCount(Collection.unsortedId), unsorted + 2);
    });

    test('Unsorted cannot be deleted', () async {
      final store = await _store();
      store.deleteCollection(Collection.unsortedId);
      expect(store.collection(Collection.unsortedId), isNotNull);
    });

    test('persists across loads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = await AppStore.load(prefs);
      a.addLink('example.com/persist');
      a.themeMode = ThemeMode.dark;
      final b = await AppStore.load(prefs);
      expect(b.searchLinks('persist').map((l) => l.url), [
        'https://example.com/persist',
      ]);
      expect(b.themeMode, ThemeMode.dark);
    });

    test('search matches title, url and collection name', () async {
      final store = await _store();
      expect(store.searchLinks('flutter'), isNotEmpty);
      expect(store.searchCollections('coffee').single.name, contains('Coffee'));
      expect(store.searchLinks('   '), isEmpty);
    });
  });
}
