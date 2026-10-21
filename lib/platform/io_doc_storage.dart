import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/doc_storage.dart';
import '../core/pdf_backend.dart';

/// Copies imported files into the app's private documents folder so they keep
/// working if the original is moved or deleted.
class IoDocStorage implements DocStorage {
  Directory? _dir;

  Future<Directory> _library() async {
    final existing = _dir;
    if (existing != null) return existing;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}library');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  static String _safe(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

  @override
  Future<String> save({
    required String name,
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    final dir = await _library();
    final key = '${DateTime.now().microsecondsSinceEpoch}-${_safe(name)}';
    final target = File('${dir.path}${Platform.pathSeparator}$key');
    if (sourcePath != null) {
      await File(sourcePath).copy(target.path);
    } else if (bytes != null) {
      await target.writeAsBytes(bytes, flush: true);
    } else {
      throw ArgumentError('Need sourcePath or bytes');
    }
    return key;
  }

  @override
  Future<DocSource?> open(String key) async {
    final dir = await _library();
    final f = File('${dir.path}${Platform.pathSeparator}$key');
    return await f.exists() ? DocSource.file(f.path, id: key) : null;
  }

  @override
  Future<void> delete(String key) async {
    final dir = await _library();
    final f = File('${dir.path}${Platform.pathSeparator}$key');
    if (await f.exists()) await f.delete();
  }
}
