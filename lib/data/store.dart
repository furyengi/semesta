import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum AddLinkResult { added, invalid, duplicate }

/// In-memory app state, persisted as JSON in shared preferences.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  static const _dataKey = 'semesta.data.v1';
  static const _themeKey = 'semesta.themeMode';
  static const _dynamicKey = 'semesta.dynamicColor';

  final SharedPreferences _prefs;
  final List<Collection> _collections = [];
  final List<LinkItem> _links = [];
  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = true;
  int _idCounter = 0;

  static Future<AppStore> load([SharedPreferences? prefs]) async {
    final store = AppStore._(prefs ?? await SharedPreferences.getInstance());
    store._restore();
    return store;
  }

  // ---- settings -----------------------------------------------------------

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;

  set themeMode(ThemeMode m) {
    _themeMode = m;
    _prefs.setString(_themeKey, m.name);
    notifyListeners();
  }

  set useDynamicColor(bool v) {
    _useDynamicColor = v;
    _prefs.setBool(_dynamicKey, v);
    notifyListeners();
  }

  // ---- queries ------------------------------------------------------------

  List<Collection> get rootCollections =>
      _collections.where((c) => c.parentId == null).toList(growable: false);

  List<Collection> get allCollections => List.unmodifiable(_collections);

  Collection? collection(String id) {
    for (final c in _collections) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Collection> children(String id) =>
      _collections.where((c) => c.parentId == id).toList(growable: false);

  List<LinkItem> linksIn(String id) =>
      _links.where((l) => l.collectionId == id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Iterable<String> _descendantIds(String id) sync* {
    yield id;
    for (final c in children(id)) {
      yield* _descendantIds(c.id);
    }
  }

  /// Links in a collection and everything nested under it.
  int linkCount(String id) {
    final ids = _descendantIds(id).toSet();
    return _links.where((l) => ids.contains(l.collectionId)).length;
  }

  int folderCount(String id) => children(id).length;

  List<LinkItem> recentLinks(int n) =>
      (_links.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .take(n)
          .toList();

  List<LinkItem> searchLinks(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _links
        .where(
          (l) =>
              l.title.toLowerCase().contains(q) ||
              l.url.toLowerCase().contains(q),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Collection> searchCollections(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _collections.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  /// Every collection in depth-first order with its nesting depth.
  List<(Collection, int)> tree() {
    final out = <(Collection, int)>[];
    void walk(Collection c, int depth) {
      out.add((c, depth));
      for (final child in children(c.id)) {
        walk(child, depth + 1);
      }
    }

    for (final c in rootCollections) {
      walk(c, 0);
    }
    return out;
  }

  /// Names of the ancestors of [id], root first, excluding [id] itself.
  List<Collection> ancestors(String id) {
    final out = <Collection>[];
    var cur = collection(id)?.parentId;
    while (cur != null) {
      final c = collection(cur);
      if (c == null) break;
      out.insert(0, c);
      cur = c.parentId;
    }
    return out;
  }

  // ---- mutations ----------------------------------------------------------

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  AddLinkResult addLink(
    String raw, {
    String collectionId = Collection.unsortedId,
  }) {
    final url = normalizeUrl(raw);
    if (url == null) return AddLinkResult.invalid;
    if (_links.any((l) => l.url == url && l.collectionId == collectionId)) {
      return AddLinkResult.duplicate;
    }
    _lastAdded = LinkItem(
      id: _newId(),
      url: url,
      title: titleFromUrl(url),
      collectionId: collectionId,
      createdAt: DateTime.now(),
    );
    _links.add(_lastAdded!);
    _commit();
    return AddLinkResult.added;
  }

  LinkItem? _lastAdded;

  /// The link created by the most recent successful [addLink].
  LinkItem? get lastAdded => _lastAdded;

  void moveLink(String linkId, String collectionId) {
    final i = _links.indexWhere((l) => l.id == linkId);
    if (i < 0) return;
    _links[i] = _links[i].copyWith(collectionId: collectionId);
    _commit();
  }

  void renameLink(String linkId, String title) {
    final i = _links.indexWhere((l) => l.id == linkId);
    if (i < 0 || title.trim().isEmpty) return;
    _links[i] = _links[i].copyWith(title: title.trim());
    _commit();
  }

  void deleteLink(String linkId) {
    _links.removeWhere((l) => l.id == linkId);
    _commit();
  }

  void restoreLink(LinkItem link) {
    if (_links.any((l) => l.id == link.id)) return;
    _links.add(link);
    _commit();
  }

  Collection addCollection({
    required String name,
    required int colorIndex,
    required String iconKey,
    String? parentId,
  }) {
    final c = Collection(
      id: _newId(),
      name: name.trim(),
      colorIndex: colorIndex,
      iconKey: iconKey,
      createdAt: DateTime.now(),
      parentId: parentId,
    );
    _collections.add(c);
    _commit();
    return c;
  }

  void updateCollection(
    String id, {
    String? name,
    int? colorIndex,
    String? iconKey,
  }) {
    final i = _collections.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _collections[i] = _collections[i].copyWith(
      name: name?.trim().isEmpty ?? true ? null : name!.trim(),
      colorIndex: colorIndex,
      iconKey: iconKey,
    );
    _commit();
  }

  /// Deletes a collection and its sub-folders; their links fall back to
  /// Unsorted so nothing the user saved is lost.
  void deleteCollection(String id) {
    if (id == Collection.unsortedId) return;
    final ids = _descendantIds(id).toSet();
    for (var i = 0; i < _links.length; i++) {
      if (ids.contains(_links[i].collectionId)) {
        _links[i] = _links[i].copyWith(collectionId: Collection.unsortedId);
      }
    }
    _collections.removeWhere((c) => ids.contains(c.id));
    _commit();
  }

  /// Wipes everything the user saved, leaving only an empty Unsorted.
  void clearAll() {
    _collections
      ..clear()
      ..add(_unsorted());
    _links.clear();
    _commit();
  }

  // ---- persistence --------------------------------------------------------

  void _commit() {
    _prefs.setString(
      _dataKey,
      jsonEncode({
        'collections': _collections.map((c) => c.toJson()).toList(),
        'links': _links.map((l) => l.toJson()).toList(),
      }),
    );
    notifyListeners();
  }

  void _restore() {
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_themeKey),
      orElse: () => ThemeMode.system,
    );
    _useDynamicColor = _prefs.getBool(_dynamicKey) ?? true;

    final raw = _prefs.getString(_dataKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _collections.addAll(
          (j['collections'] as List).map(
            (e) => Collection.fromJson(e as Map<String, dynamic>),
          ),
        );
        _links.addAll(
          (j['links'] as List).map(
            (e) => LinkItem.fromJson(e as Map<String, dynamic>),
          ),
        );
      } catch (_) {
        _collections.clear();
        _links.clear();
      }
    }
    if (!_collections.any((c) => c.isUnsorted)) {
      if (raw == null) {
        _seed();
      } else {
        _collections.insert(0, _unsorted());
      }
      _commit();
    }
  }

  Collection _unsorted() => Collection(
    id: Collection.unsortedId,
    name: 'Unsorted',
    colorIndex: 0,
    iconKey: 'folder',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// First-run starter content so the home screen isn't empty.
  void _seed() {
    final now = DateTime.now();
    _collections.add(_unsorted());

    Collection add(String name, int color, String icon, {int daysAgo = 30}) {
      final c = Collection(
        id: _newId(),
        name: name,
        colorIndex: color,
        iconKey: icon,
        createdAt: now.subtract(Duration(days: daysAgo)),
      );
      _collections.add(c);
      return c;
    }

    void link(Collection c, String url, int minutesAgo) {
      _links.add(
        LinkItem(
          id: _newId(),
          url: url,
          title: titleFromUrl(url),
          collectionId: c.id,
          createdAt: now.subtract(Duration(minutes: minutesAgo)),
        ),
      );
    }

    final watch = add('Must watch', 1, 'bolt');
    final learn = add('Learning & Research', 2, 'book');
    final coffee = add('Coffee & Chill Spots', 3, 'coffee');
    final travel = add('Travel plan', 4, 'flight');
    final recipes = add('Weekend Recipes', 5, 'heart', daysAgo: 1);

    final design = Collection(
      id: _newId(),
      name: 'Design',
      colorIndex: 2,
      iconKey: 'star',
      createdAt: now.subtract(const Duration(days: 30)),
      parentId: learn.id,
    );
    final dev = Collection(
      id: _newId(),
      name: 'Development',
      colorIndex: 7,
      iconKey: 'code',
      createdAt: now.subtract(const Duration(days: 30)),
      parentId: learn.id,
    );
    _collections.addAll([design, dev]);

    link(
      _collections.first,
      'https://m3.material.io/blog/building-with-m3-expressive',
      4,
    );
    link(watch, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 60);
    link(watch, 'https://vimeo.com/channels/staffpicks', 300);
    link(design, 'https://m3.material.io/styles/motion/overview', 1500);
    link(
      design,
      'https://www.nngroup.com/articles/ten-usability-heuristics',
      2000,
    );
    link(dev, 'https://docs.flutter.dev/ui/animations', 2500);
    link(learn, 'https://web.dev/learn', 3000);
    link(coffee, 'https://www.google.com/maps/search/coffee+near+me', 4000);
    link(travel, 'https://www.skyscanner.com/flights', 5000);
    link(travel, 'https://www.tripadvisor.com/Tourism', 5100);
    link(recipes, 'https://www.seriouseats.com/best-pancake-recipe', 800);
    link(recipes, 'https://smittenkitchen.com/recipes', 900);
  }
}
