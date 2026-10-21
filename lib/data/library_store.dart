import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// In-memory library state, persisted as JSON in shared preferences.
class LibraryStore extends ChangeNotifier {
  LibraryStore._(this._prefs);

  static const _docsKey = 'semesta.library.v1';
  static const _themeKey = 'semesta.themeMode';
  static const _dynamicKey = 'semesta.dynamicColor';
  static const _nightKey = 'semesta.nightReading';
  static const _seededKey = 'semesta.seeded';

  final SharedPreferences _prefs;
  final List<Doc> _docs = [];

  /// Fires only when a setting changes, so the app shell doesn't rebuild on
  /// every page turn.
  final settingsChanges = _SettingsNotifier();
  ThemeMode _themeMode = ThemeMode.dark;
  bool _useDynamicColor = false;
  bool _nightReading = false;
  int _idCounter = 0;

  static Future<LibraryStore> load([SharedPreferences? prefs]) async {
    final store = LibraryStore._(
      prefs ?? await SharedPreferences.getInstance(),
    );
    store._restore();
    return store;
  }

  // ---- settings -----------------------------------------------------------

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;

  /// Invert page colours in the reader (for reading in the dark).
  bool get nightReading => _nightReading;

  set themeMode(ThemeMode m) {
    _themeMode = m;
    _prefs.setString(_themeKey, m.name);
    _settingChanged();
  }

  set useDynamicColor(bool v) {
    _useDynamicColor = v;
    _prefs.setBool(_dynamicKey, v);
    _settingChanged();
  }

  set nightReading(bool v) {
    _nightReading = v;
    _prefs.setBool(_nightKey, v);
    _settingChanged();
  }

  void _settingChanged() {
    settingsChanges.ping();
    notifyListeners();
  }

  bool get seeded => _prefs.getBool(_seededKey) ?? false;
  void markSeeded() => _prefs.setBool(_seededKey, true);

  // ---- queries ------------------------------------------------------------

  List<Doc> get docs => List.unmodifiable(_docs);

  Doc? doc(String id) {
    for (final d in _docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Most recently opened first, then newest additions.
  List<Doc> docsSorted([DocCategory? category]) {
    final list = _docs.where((d) => category == null || d.category == category);
    return list.toList()..sort((a, b) {
      final ao = a.lastOpenedAt, bo = b.lastOpenedAt;
      if (ao != null && bo != null) return bo.compareTo(ao);
      if (ao != null) return -1;
      if (bo != null) return 1;
      return b.addedAt.compareTo(a.addedAt);
    });
  }

  /// The document to offer under "Continue reading".
  Doc? get continueReading {
    Doc? best;
    for (final d in _docs) {
      if (d.lastOpenedAt == null || d.finished) continue;
      if (best == null || d.lastOpenedAt!.isAfter(best.lastOpenedAt!)) best = d;
    }
    return best;
  }

  /// Categories that have at least one document, in enum order.
  List<DocCategory> get usedCategories => [
    for (final c in DocCategory.values)
      if (_docs.any((d) => d.category == c)) c,
  ];

  List<Doc> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return docsSorted()
        .where(
          (d) =>
              d.title.toLowerCase().contains(q) ||
              d.category.label.toLowerCase().contains(q),
        )
        .toList();
  }

  // ---- mutations ----------------------------------------------------------

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  Doc addDoc({
    required String title,
    required String storageKey,
    required int pageCount,
    DocCategory category = DocCategory.other,
  }) {
    final d = Doc(
      id: _newId(),
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      storageKey: storageKey,
      category: category,
      addedAt: DateTime.now(),
      pageCount: pageCount,
    );
    _docs.add(d);
    _commit();
    return d;
  }

  void updateDoc(String id, {String? title, DocCategory? category}) {
    _replace(
      id,
      (d) => d.copyWith(
        title: (title?.trim().isEmpty ?? true) ? null : title!.trim(),
        category: category,
      ),
    );
  }

  /// Removes the document and returns it so the caller can delete its file.
  Doc? removeDoc(String id) {
    final d = doc(id);
    if (d == null) return null;
    _docs.removeWhere((x) => x.id == id);
    _commit();
    return d;
  }

  /// Removes everything and returns the removed documents.
  List<Doc> clearAll() {
    final removed = List<Doc>.of(_docs);
    _docs.clear();
    _commit();
    return removed;
  }

  void markOpened(String id) =>
      _replace(id, (d) => d.copyWith(lastOpenedAt: DateTime.now()));

  /// Saves the reading position. [pageCount] is stored too, since it's only
  /// known for sure once the viewer has loaded the document.
  void recordProgress(String id, {required int page, required int pageCount}) {
    _replace(
      id,
      (d) => d.copyWith(
        lastPage: page.clamp(1, pageCount < 1 ? 1 : pageCount),
        pageCount: pageCount,
        lastOpenedAt: DateTime.now(),
      ),
    );
  }

  /// Adds or removes a bookmark on [page]. Returns true if one was added.
  bool toggleBookmark(String id, int page) {
    var added = false;
    _replace(id, (d) {
      if (d.isBookmarked(page)) {
        return d.copyWith(
          bookmarks: d.bookmarks.where((b) => b.page != page).toList(),
        );
      }
      added = true;
      final next = [
        ...d.bookmarks,
        Bookmark(page: page, createdAt: DateTime.now()),
      ]..sort((a, b) => a.page.compareTo(b.page));
      return d.copyWith(bookmarks: next);
    });
    return added;
  }

  void _replace(String id, Doc Function(Doc) change) {
    final i = _docs.indexWhere((d) => d.id == id);
    if (i < 0) return;
    _docs[i] = change(_docs[i]);
    _commit();
  }

  // ---- persistence --------------------------------------------------------

  Timer? _saveTimer;

  /// Writes are coalesced so rapid page changes don't hammer storage.
  void _commit() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), flush);
  }

  /// Writes pending changes immediately.
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _prefs.setString(
      _docsKey,
      jsonEncode({'docs': _docs.map((d) => d.toJson()).toList()}),
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    settingsChanges.dispose();
    super.dispose();
  }

  void _restore() {
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_themeKey),
      orElse: () => ThemeMode.dark,
    );
    _useDynamicColor = _prefs.getBool(_dynamicKey) ?? false;
    _nightReading = _prefs.getBool(_nightKey) ?? false;

    final raw = _prefs.getString(_docsKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in j['docs'] as List) {
        _docs.add(Doc.fromJson(e as Map<String, dynamic>));
      }
    } catch (_) {
      _docs.clear();
    }
  }
}

class _SettingsNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
