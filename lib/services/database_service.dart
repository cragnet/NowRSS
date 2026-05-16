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
    // Initialize FFI for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    final Directory appDir = await getApplicationSupportDirectory();
    final String path = join(appDir.path, 'nowrss.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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
      CREATE INDEX idx_articles_feed ON articles(feed_id)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_articles_read ON articles(is_read)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_articles_starred ON articles(is_starred)
    ''');
  }

  // Feed operations
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
    await db.update(
      'feeds',
      {'unread_count': count},
      where: 'id = ?',
      whereArgs: [feedId],
    );
  }

  // Article operations
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
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    
    String where = '1=1';
    List<dynamic> whereArgs = [];
    
    if (isRead != null) {
      where += ' AND is_read = ?';
      whereArgs.add(isRead ? 1 : 0);
    }
    
    if (isStarred != null) {
      where += ' AND is_starred = ?';
      whereArgs.add(isStarred ? 1 : 0);
    }
    
    if (feedId != null) {
      where += ' AND feed_id = ?';
      whereArgs.add(feedId);
    }
    
    final List<Map> maps = await db.query(
      'articles',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'published_at DESC',
      limit: limit,
      offset: offset,
    );
    
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
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM articles WHERE is_read = 0',
    );
    return result.first['count'] as int? ?? 0;
  }

  Future<int> getTotalStarredCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM articles WHERE is_starred = 1',
    );
    return result.first['count'] as int? ?? 0;
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
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
