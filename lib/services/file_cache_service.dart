import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileCacheService {
  Directory? _cacheDir;

  Future<Directory> get _htmlDir async {
    final base = _cacheDir ??= await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'cache', 'html'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get _originalDir async {
    final base = _cacheDir ??= await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'cache', 'original'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get _summaryDir async {
    final base = _cacheDir ??= await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'cache', 'summary'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _safeFilename(String articleId) {
    return articleId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '_');
  }

  Future<void> saveArticleHtml(String articleId, String html) async {
    final dir = await _htmlDir;
    final file = File(p.join(dir.path, '${_safeFilename(articleId)}.html'));
    await file.writeAsString(html, encoding: utf8);
  }

  Future<String?> loadArticleHtml(String articleId) async {
    final dir = await _htmlDir;
    final file = File(p.join(dir.path, '${_safeFilename(articleId)}.html'));
    if (!await file.exists()) return null;
    return file.readAsString(encoding: utf8);
  }

  Future<void> saveOriginalHtml(String articleId, String html) async {
    final dir = await _originalDir;
    final file = File(p.join(dir.path, '${_safeFilename(articleId)}.html'));
    await file.writeAsString(html, encoding: utf8);
  }

  Future<String?> loadOriginalHtml(String articleId) async {
    final dir = await _originalDir;
    final file = File(p.join(dir.path, '${_safeFilename(articleId)}.html'));
    if (!await file.exists()) return null;
    return file.readAsString(encoding: utf8);
  }

  Future<void> saveSummary(String articleId, String summary) async {
    final dir = await _summaryDir;
    final file = File(p.join(dir.path, '${_safeFilename(articleId)}.txt'));
    await file.writeAsString(summary, encoding: utf8);
  }

  Future<String?> loadSummary(String articleId) async {
    final dir = await _summaryDir;
    final file = File(p.join(dir.path, '${_safeFilename(articleId)}.txt'));
    if (!await file.exists()) return null;
    return file.readAsString(encoding: utf8);
  }

  Future<void> deleteArticle(String articleId) async {
    final safe = _safeFilename(articleId);
    for (final dir in [await _htmlDir, await _originalDir, await _summaryDir]) {
      for (final ext in ['.html', '.txt']) {
        final file = File(p.join(dir.path, '$safe$ext'));
        if (await file.exists()) await file.delete();
      }
    }
  }

  /// Purge files whose article IDs are NOT in the keep list. Call after DB cleanup.
  Future<void> purgeOrphans(List<String> keepArticleIds) async {
    final keepSet = keepArticleIds.map(_safeFilename).toSet();
    for (final dir in [await _htmlDir, await _originalDir, await _summaryDir]) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = p.basenameWithoutExtension(entity.path);
          if (!keepSet.contains(name)) {
            await entity.delete();
          }
        }
      }
    }
  }

  Future<void> clearAll() async {
    final base = _cacheDir ??= await getApplicationSupportDirectory();
    final cache = Directory(p.join(base.path, 'cache'));
    if (await cache.exists()) await cache.delete(recursive: true);
  }
}
