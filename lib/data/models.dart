import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// What kind of material a document is. Used for filtering and as the
/// accent colour when a cover isn't available.
enum DocCategory {
  textbook('Textbooks', Icons.menu_book_outlined, 7),
  lecture('Lectures', Icons.school_outlined, 5),
  novel('Novels', Icons.auto_stories_outlined, 6),
  manhwa('Manhwa', Icons.collections_bookmark_outlined, 4),
  notes('Notes', Icons.edit_note_rounded, 2),
  other('Other', Icons.description_outlined, 0);

  const DocCategory(this.label, this.icon, this._colorIndex);

  final String label;
  final IconData icon;
  final int _colorIndex;

  Color get color => AccentPalette.colors[_colorIndex];

  static DocCategory byName(String? name) => DocCategory.values.firstWhere(
    (c) => c.name == name,
    orElse: () => DocCategory.other,
  );
}

class Bookmark {
  const Bookmark({required this.page, required this.createdAt});

  /// 1-based page number.
  final int page;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'page': page,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
    page: j['page'] as int,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

/// A document in the library. The file itself lives in [DocStorage] under
/// [storageKey]; this is the metadata and reading state.
class Doc {
  const Doc({
    required this.id,
    required this.title,
    required this.storageKey,
    required this.category,
    required this.addedAt,
    this.pageCount = 0,
    this.lastPage = 1,
    this.lastOpenedAt,
    this.bookmarks = const [],
    this.courseId,
  });

  final String id;
  final String title;
  final String storageKey;
  final DocCategory category;
  final DateTime addedAt;
  final int pageCount;

  /// 1-based page the reader was last on.
  final int lastPage;
  final DateTime? lastOpenedAt;
  final List<Bookmark> bookmarks;

  /// The course this material belongs to, if any.
  final String? courseId;

  bool get hasStarted => lastOpenedAt != null && lastPage > 1;
  bool get finished => pageCount > 0 && lastPage >= pageCount;

  /// Fraction read, 0..1.
  double get progress {
    if (pageCount <= 1) return finished ? 1 : 0;
    return ((lastPage - 1) / (pageCount - 1)).clamp(0.0, 1.0);
  }

  bool isBookmarked(int page) => bookmarks.any((b) => b.page == page);

  Doc copyWith({
    String? title,
    DocCategory? category,
    int? pageCount,
    int? lastPage,
    DateTime? lastOpenedAt,
    List<Bookmark>? bookmarks,
    String? courseId,
    bool clearCourse = false,
  }) => Doc(
    id: id,
    title: title ?? this.title,
    storageKey: storageKey,
    category: category ?? this.category,
    addedAt: addedAt,
    pageCount: pageCount ?? this.pageCount,
    lastPage: lastPage ?? this.lastPage,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    bookmarks: bookmarks ?? this.bookmarks,
    courseId: clearCourse ? null : (courseId ?? this.courseId),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'storageKey': storageKey,
    'category': category.name,
    'addedAt': addedAt.toIso8601String(),
    'pageCount': pageCount,
    'lastPage': lastPage,
    'lastOpenedAt': lastOpenedAt?.toIso8601String(),
    'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
    'courseId': courseId,
  };

  factory Doc.fromJson(Map<String, dynamic> j) => Doc(
    id: j['id'] as String,
    title: j['title'] as String,
    storageKey: j['storageKey'] as String,
    category: DocCategory.byName(j['category'] as String?),
    addedAt: DateTime.parse(j['addedAt'] as String),
    pageCount: (j['pageCount'] as int?) ?? 0,
    lastPage: (j['lastPage'] as int?) ?? 1,
    lastOpenedAt: j['lastOpenedAt'] == null
        ? null
        : DateTime.parse(j['lastOpenedAt'] as String),
    bookmarks: [
      for (final b in (j['bookmarks'] as List? ?? const []))
        Bookmark.fromJson(b as Map<String, dynamic>),
    ],
    courseId: j['courseId'] as String?,
  );
}

/// "intro_to-algorithms_v2.pdf" -> "Intro to algorithms v2".
String titleFromFileName(String fileName) {
  var s = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  s = s
      .replaceAll(RegExp(r'[_\-+]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (s.isEmpty) return 'Untitled';
  return s[0].toUpperCase() + s.substring(1);
}
