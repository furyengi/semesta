import 'dart:typed_data';

import 'pdf_backend.dart';

/// Where imported files are kept.
abstract class DocStorage {
  /// Stores a file, from [sourcePath] when given (copied, not moved), else
  /// from [bytes]. Returns the key to open or delete it with.
  Future<String> save({
    required String name,
    String? sourcePath,
    Uint8List? bytes,
  });

  Future<DocSource?> open(String key);
  Future<void> delete(String key);
}

/// Keeps files in memory. Used on the web (no file system) and in tests.
class MemoryDocStorage implements DocStorage {
  final Map<String, Uint8List> _files = {};
  int _n = 0;

  @override
  Future<String> save({
    required String name,
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    if (bytes == null) {
      throw ArgumentError('MemoryDocStorage needs bytes');
    }
    final key = '${_n++}-$name';
    _files[key] = bytes;
    return key;
  }

  @override
  Future<DocSource?> open(String key) async {
    final b = _files[key];
    return b == null ? null : DocSource.memory(b, id: key);
  }

  @override
  Future<void> delete(String key) async => _files.remove(key);

  int get count => _files.length;
}
