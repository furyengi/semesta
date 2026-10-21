import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Icons a collection can use, keyed by a stable string for persistence.
abstract final class CollectionIcons {
  static const Map<String, IconData> all = {
    'folder': Icons.folder_outlined,
    'bolt': Icons.bolt_rounded,
    'book': Icons.menu_book_outlined,
    'coffee': Icons.coffee_outlined,
    'flight': Icons.flight_rounded,
    'heart': Icons.favorite_border_rounded,
    'star': Icons.star_border_rounded,
    'movie': Icons.movie_outlined,
    'music': Icons.music_note_rounded,
    'code': Icons.code_rounded,
    'shopping': Icons.shopping_bag_outlined,
    'work': Icons.work_outline_rounded,
  };

  static IconData resolve(String key) => all[key] ?? Icons.folder_outlined;
}

class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.iconKey,
    required this.createdAt,
    this.parentId,
  });

  static const unsortedId = 'unsorted';

  final String id;
  final String name;
  final int colorIndex;
  final String iconKey;
  final DateTime createdAt;
  final String? parentId;

  bool get isUnsorted => id == unsortedId;
  Color get color =>
      CollectionPalette.colors[colorIndex % CollectionPalette.colors.length];
  IconData get icon => CollectionIcons.resolve(iconKey);

  /// Collections created in the last few days get a "NEW" badge.
  bool get isNew =>
      !isUnsorted && DateTime.now().difference(createdAt).inDays < 3;

  Collection copyWith({String? name, int? colorIndex, String? iconKey}) =>
      Collection(
        id: id,
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
        iconKey: iconKey ?? this.iconKey,
        createdAt: createdAt,
        parentId: parentId,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'iconKey': iconKey,
    'createdAt': createdAt.toIso8601String(),
    'parentId': parentId,
  };

  factory Collection.fromJson(Map<String, dynamic> j) => Collection(
    id: j['id'] as String,
    name: j['name'] as String,
    colorIndex: j['colorIndex'] as int,
    iconKey: j['iconKey'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    parentId: j['parentId'] as String?,
  );
}

class LinkItem {
  const LinkItem({
    required this.id,
    required this.url,
    required this.title,
    required this.collectionId,
    required this.createdAt,
  });

  final String id;
  final String url;
  final String title;
  final String collectionId;
  final DateTime createdAt;

  String get host {
    final h = Uri.tryParse(url)?.host ?? url;
    return h.startsWith('www.') ? h.substring(4) : h;
  }

  LinkItem copyWith({String? collectionId, String? title}) => LinkItem(
    id: id,
    url: url,
    title: title ?? this.title,
    collectionId: collectionId ?? this.collectionId,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'collectionId': collectionId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LinkItem.fromJson(Map<String, dynamic> j) => LinkItem(
    id: j['id'] as String,
    url: j['url'] as String,
    title: j['title'] as String,
    collectionId: j['collectionId'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

/// Turns pasted text into a normalised http(s) URL, or null if it isn't one.
String? normalizeUrl(String input) {
  var s = input.trim();
  if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
  if (!s.contains('://')) s = 'https://$s';
  final uri = Uri.tryParse(s);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }
  if (uri.host.isEmpty || !uri.host.contains('.')) return null;
  return uri.toString();
}

/// Builds a readable title offline from the URL path ("Some post title"),
/// falling back to the host when the path has nothing readable.
String titleFromUrl(String url) {
  final uri = Uri.parse(url);
  final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return host;
  var last = Uri.decodeComponent(segs.last)
      .replaceAll(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), '')
      .replaceAll(RegExp(r'[-_+]+'), ' ')
      .trim();
  if (last.isEmpty) return host;
  last = last[0].toUpperCase() + last.substring(1);
  return last;
}
