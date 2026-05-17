import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import '../models/feed.dart';
import '../models/article.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService _instance = DatabaseService._internal();
  
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    
    final Directory appDir = await getApplicationSupportDirectory();
    final String path = join(appDir.path, 'nowrss.db');
    
    // Use FFI factory directly without mutating global databaseFactory
    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE feeds (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        url TEXT,
        site_url TEXT,
        folder_name TEXT,
        favicon_url TEXT,
        unread_count INTEGER DEFAULT 0,
        last_synced_at INTEGER
      )
    ''');
    
    await db.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        feed_id TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT,
        author TEXT,
        content_html TEXT,
        content_text TEXT,
        summary TEXT,
        published_at INTEGER,
        fetched_at INTEGER,
        image_url TEXT,
        is_read INTEGER DEFAULT 0,
        is_starred INTEGER DEFAULT 0,
        read_at INTEGER,
        starred_at INTEGER
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_articles_feed ON articles(feed_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_articles_read ON articles(is_read)
    ''');
    await db.execute('''
      CREATE INDEX idx_articles_starred ON articles(is_starred)
    ''');
    await db.execute('''
      CREATE INDEX idx_articles_published ON articles(published_at DESC)
    ''');
    
    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_type TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        articles_fetched INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending'
      )
    ''');
    
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        article_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_sync_queue_pending ON sync_queue(status, operation)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          article_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          created_at INTEGER NOT NULL,
          synced_at INTEGER
        )
      ''');
      await db.execute('''
        CREATE INDEX idx_sync_queue_pending ON sync_queue(status, operation)
      ''');
    }
  }

  // Sync queue
  Future<void> queueOperation(String articleId, String operation) async {
    final db = await database;
    await db.insert('sync_queue', {
      'article_id': articleId,
      'operation': operation,
      'status': 'pending',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    final List<Map> maps = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => Map<String, dynamic>.from(map)).toList();
  }

  Future<void> markOperationsSynced(List<int> ids) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in ids) {
      batch.update(
        'sync_queue',
        {'status': 'synced', 'synced_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearOldSyncedOperations({int days = 7}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    await db.delete(
      'sync_queue',
      where: 'status = ? AND synced_at < ?',
      whereArgs: ['synced', cutoff],
    );
  }

  // Feeds
  Future<void> insertFeeds(List<Feed> feeds) async {
    final db = await database;
    final batch = db.batch();
    for (final feed in feeds) {
      batch.insert(
        'feeds',
        {
          'id': feed.id,
          'title': feed.title,
          'url': feed.url,
          'site_url': feed.siteUrl,
          'folder_name': feed.folderName,
          'favicon_url': feed.faviconUrl,
          'unread_count': feed.unreadCount,
          'last_synced_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Feed>> getFeeds() async {
    final db = await database;
    final List<Map> maps = await db.query('feeds', orderBy: 'folder_name, title');
    return maps.map((map) => Feed(
      id: map['id'] as String,
      title: map['title'] as String,
      url: map['url'] as String?,
      siteUrl: map['site_url'] as String?,
      folderName: map['folder_name'] as String?,
      faviconUrl: map['favicon_url'] as String?,
      unreadCount: map['unread_count'] as int? ?? 0,
    )).toList();
  }

  Future<void> updateFeedUnreadCount(String feedId, int count) async {
    final db = await database;
    await db.update('feeds', {'unread_count': count}, where: 'id = ?', whereArgs: [feedId]);
  }

  // Articles
  Future<void> insertArticles(List<Article> articles) async {
    final db = await database;
    final batch = db.batch();
    for (final article in articles) {
      batch.insert(
        'articles',
        {
          'id': article.id,
          'feed_id': article.feedId,
          'title': article.title,
          'url': article.url,
          'author': article.author,
          'content_html': article.contentHtml,
          'content_text': article.contentText,
          'summary': article.summary,
          'published_at': article.publishedAt?.millisecondsSinceEpoch,
          'fetched_at': DateTime.now().millisecondsSinceEpoch,
          'image_url': article.imageUrl,
          'is_read': article.isRead ? 1 : 0,
          'is_starred': article.isStarred ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Article>> getArticles({
    bool? isRead,
    bool? isStarred,
    String? feedId,
    List<String>? feedIds,
    int limit = 5000,
    int offset = 0,
  }) async {
    final db = await database;

    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (isRead != null) {
      where += ' AND a.is_read = ?';
      whereArgs.add(isRead ? 1 : 0);
    }
    if (isStarred != null) {
      where += ' AND a.is_starred = ?';
      whereArgs.add(isStarred ? 1 : 0);
    }
    if (feedId != null) {
      where += ' AND a.feed_id = ?';
      whereArgs.add(feedId);
    }
    if (feedIds != null && feedIds.isNotEmpty) {
      where += ' AND a.feed_id IN (${List.filled(feedIds.length, '?').join(',')})';
      whereArgs.addAll(feedIds);
    }

    final List<Map> maps = await db.rawQuery('''
      SELECT a.*, COALESCE(f.title, 'Unknown Feed') as feed_title
      FROM articles a
      LEFT JOIN feeds f ON a.feed_id = f.id
      WHERE $where
      ORDER BY a.published_at DESC
      LIMIT ? OFFSET ?
    ''', [...whereArgs, limit, offset]);
    return maps.map((map) => _mapToArticle(map)).toList();
  }

  Future<void> markArticleRead(String articleId, bool read) async {
    final db = await database;
    await db.update(
      'articles',
      {
        'is_read': read ? 1 : 0,
        'read_at': read ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [articleId],
    );
  }

  Future<void> markAllArticlesRead(List<String> articleIds) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final id in articleIds) {
      batch.update(
        'articles',
        {'is_read': 1, 'read_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> starArticle(String articleId, bool starred) async {
    final db = await database;
    await db.update(
      'articles',
      {
        'is_starred': starred ? 1 : 0,
        'starred_at': starred ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [articleId],
    );
  }

  Future<int> getUnreadCount(String feedId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM articles WHERE feed_id = ? AND is_read = 0',
      [feedId],
    );
    return result.first['count'] as int? ?? 0;
  }

  Future<int> getTotalUnreadCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM articles WHERE is_read = 0');
    return result.first['count'] as int? ?? 0;
  }

  Future<int> getTotalReadCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM articles WHERE is_read = 1');
    return result.first['count'] as int? ?? 0;
  }

  Future<int> getTotalStarredCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM articles WHERE is_starred = 1');
    return result.first['count'] as int? ?? 0;
  }

  Future<Map<String, int>> getFeedArticleCounts(String feedId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN is_read = 0 THEN 1 ELSE 0 END) as unread,
        SUM(CASE WHEN is_read = 1 THEN 1 ELSE 0 END) as read,
        SUM(CASE WHEN is_starred = 1 THEN 1 ELSE 0 END) as starred
      FROM articles WHERE feed_id = ?
    ''', [feedId]);
    final row = results.first;
    return {
      'unread': (row['unread'] as int?) ?? 0,
      'read': (row['read'] as int?) ?? 0,
      'starred': (row['starred'] as int?) ?? 0,
    };
  }

  Future<Map<String, int>> getAllFeedCounts() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        feed_id,
        SUM(CASE WHEN is_read = 0 THEN 1 ELSE 0 END) as unread
      FROM articles GROUP BY feed_id
    ''');
    final Map<String, int> counts = {};
    for (final row in results) {
      counts[row['feed_id'] as String] = (row['unread'] as int?) ?? 0;
    }
    return counts;
  }

  Future<Map<String, int>> getAllFeedReadCounts() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        feed_id,
        SUM(CASE WHEN is_read = 1 THEN 1 ELSE 0 END) as read
      FROM articles GROUP BY feed_id
    ''');
    final Map<String, int> counts = {};
    for (final row in results) {
      counts[row['feed_id'] as String] = (row['read'] as int?) ?? 0;
    }
    return counts;
  }

  Future<Map<String, int>> getAllFeedStarredCounts() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        feed_id,
        SUM(CASE WHEN is_starred = 1 THEN 1 ELSE 0 END) as starred
      FROM articles GROUP BY feed_id
    ''');
    final Map<String, int> counts = {};
    for (final row in results) {
      counts[row['feed_id'] as String] = (row['starred'] as int?) ?? 0;
    }
    return counts;
  }

  Future<List<Map<String, dynamic>>> getFeedStatsRaw(String feedId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hourAgo = now - 3600000;
    final dayAgo = now - 86400000;
    final weekAgo = now - 604800000;
    final monthAgo = now - 2592000000;

    return await db.rawQuery('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN published_at > ? THEN 1 ELSE 0 END) as last_hour,
        SUM(CASE WHEN published_at > ? THEN 1 ELSE 0 END) as last_day,
        SUM(CASE WHEN published_at > ? THEN 1 ELSE 0 END) as last_7d,
        SUM(CASE WHEN published_at > ? THEN 1 ELSE 0 END) as last_30d,
        SUM(CASE WHEN is_read = 0 THEN 1 ELSE 0 END) as unread
      FROM articles WHERE feed_id = ?
    ''', [hourAgo, dayAgo, weekAgo, monthAgo, feedId]);
  }

  Future<List<Map<String, dynamic>>> getHourlyDistribution(String feedId) async {
    final db = await database;
    final dayAgo = DateTime.now().millisecondsSinceEpoch - 86400000;
    return await db.rawQuery('''
      SELECT (published_at / 3600000 % 24) as hour, COUNT(*) as cnt
      FROM articles
      WHERE feed_id = ? AND published_at > ?
      GROUP BY hour
      ORDER BY hour
    ''', [feedId, dayAgo]);
  }

  Future<List<Map<String, dynamic>>> getDailyDistribution(String feedId) async {
    final db = await database;
    final weekAgo = DateTime.now().millisecondsSinceEpoch - 604800000;
    return await db.rawQuery('''
      SELECT CAST((? - published_at) / 86400000 AS INTEGER) as day, COUNT(*) as cnt
      FROM articles
      WHERE feed_id = ? AND published_at > ?
      GROUP BY day
      ORDER BY day
    ''', [DateTime.now().millisecondsSinceEpoch, feedId, weekAgo]);
  }

  Future<int> getTotalArticleCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM articles');
    return result.first['count'] as int? ?? 0;
  }

  Future<void> enforceArticleLimit(int limit) async {
    final db = await database;
    final total = await getTotalArticleCount();
    if (total <= limit) return;

    final toDelete = total - limit;
    // Keep unread, starred, and articles from last 90 days.
    // Delete oldest read articles first.
    await db.rawDelete('''
      DELETE FROM articles WHERE id IN (
        SELECT id FROM articles 
        WHERE is_read = 1 AND is_starred = 0
          AND published_at < ?
        ORDER BY published_at ASC, fetched_at ASC
        LIMIT ?
      )
    ''', [DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch, toDelete]);
  }

  // Sync log
  Future<int> startSync(String type) async {
    final db = await database;
    return await db.insert('sync_log', {
      'sync_type': type,
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'running',
    });
  }

  Future<void> completeSync(int logId, int articlesFetched, {String? error}) async {
    final db = await database;
    await db.update(
      'sync_log',
      {
        'completed_at': DateTime.now().millisecondsSinceEpoch,
        'articles_fetched': articlesFetched,
        'status': error != null ? 'error' : 'success',
      },
      where: 'id = ?',
      whereArgs: [logId],
    );
  }

  Article _mapToArticle(Map<dynamic, dynamic> map) {
    return Article(
      id: map['id'] as String,
      feedId: map['feed_id'] as String,
      title: map['title'] as String,
      url: map['url'] as String?,
      author: map['author'] as String?,
      contentHtml: map['content_html'] as String?,
      contentText: map['content_text'] as String?,
      summary: map['summary'] as String?,
      publishedAt: map['published_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['published_at'] as int)
          : null,
      fetchedAt: map['fetched_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['fetched_at'] as int)
          : null,
      imageUrl: map['image_url'] as String?,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      isStarred: (map['is_starred'] as int? ?? 0) == 1,
      feedTitle: map['feed_title'] as String?,
    );
  }

  Future<void> markArticlesReadExcept(List<String> keepIds) async {
    final db = await database;
    if (keepIds.isEmpty) {
      // Mark ALL articles as read
      await db.update('articles', {'is_read': 1, 'read_at': DateTime.now().millisecondsSinceEpoch});
      return;
    }
    final placeholders = List.filled(keepIds.length, '?').join(',');
    final updated = await db.rawUpdate(
      '''UPDATE articles SET is_read = 1, read_at = ?
         WHERE is_read = 0 AND id NOT IN ($placeholders)''',
      [DateTime.now().millisecondsSinceEpoch, ...keepIds],
    );
    if (updated > 0) {
      print('Marked $updated articles as read (no longer in Feedbin unread list)');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
