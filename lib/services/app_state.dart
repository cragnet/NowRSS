import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed.dart';
import '../models/article.dart';
import '../models/feed_stats.dart';
import '../models/ai_provider.dart';
import 'feedbin_api.dart';
import 'ai_provider_service.dart';
import 'database_service.dart';
import 'file_cache_service.dart';
import 'log_service.dart';

enum ViewMode { feeds, unread, read, favorites, stats }
enum SortOrder { newest, oldest, hottest }

class AppState extends ChangeNotifier {
  FeedbinApiClient? _apiClient;
  final AIProviderService _aiService = AIProviderService();
  final DatabaseService _db = DatabaseService();
  final FileCacheService _fileCache = FileCacheService();
  final LogService _logger = LogService();

  List<Feed> _feeds = [];
  List<Article> _articles = [];
  Article? _selectedArticle;
  ViewMode _currentView = ViewMode.unread;
  String? _selectedFeedId;
  bool _isLoading = false;
  String? _error;
  double _progress = 0.0;
  String _progressLabel = '';

  List<AIProvider> _aiProviders = [];
  AIProvider? _defaultProvider;
  List<String> _filterKeywords = [];
  String _startupPage = 'unread';
  int _autoSyncMinutes = 15;
  bool _markReadOnScroll = true;
  bool _syncOnStartup = true;
  SortOrder _sortOrder = SortOrder.newest;
  int _readDaysLimit = 30;
  double _textZoom = 1.0;
  String? _feedbinUsername;
  String? _feedbinPassword;

  bool _isInitialized = false;
  Timer? _syncTimer;
  int _totalUnread = 0;
  int _totalRead = 0;
  int _totalStarred = 0;

  // Getters
  List<Feed> get feeds => _feeds;
  List<Article> get articles => _articles;
  Article? get selectedArticle => _selectedArticle;
  ViewMode get currentView => _currentView;
  String? get selectedFeedId => _selectedFeedId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get progress => _progress;
  String get progressLabel => _progressLabel;
  List<AIProvider> get aiProviders => _aiProviders;
  AIProvider? get defaultProvider => _defaultProvider;
  List<String> get filterKeywords => _filterKeywords;
  bool get isInitialized => _isInitialized;
  bool get hasFeedbinCredentials => _feedbinUsername != null && _feedbinPassword != null;
  bool get markReadOnScroll => _markReadOnScroll;
  bool get syncOnStartup => _syncOnStartup;
  int get autoSyncMinutes => _autoSyncMinutes;
  String get startupPage => _startupPage;
  SortOrder get sortOrder => _sortOrder;
  int get readDaysLimit => _readDaysLimit;
  double get textZoom => _textZoom;
  LogService get logger => _logger;
  String? get feedbinUsername => _feedbinUsername;
  String? get feedbinPassword => _feedbinPassword;

  // Counts
  int get unreadCount => _totalUnread;
  int get readCount => _totalRead;
  int get starredCount => _totalStarred;

  List<FeedStats> _feedStats = [];
  List<FeedStats> get feedStats => _feedStats;
  int get totalArticleCount => _totalUnread + _totalRead;
  Map<String, int> get feedUnreadCounts {
    final counts = <String, int>{};
    for (final article in _articles) {
      if (!article.isRead) {
        counts[article.feedId] = (counts[article.feedId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _updateCounts() async {
    _totalUnread = await _db.getTotalUnreadCount();
    _totalRead = await _db.getTotalReadCount();
    _totalStarred = await _db.getTotalStarredCount();
    notifyListeners();
  }

  Future<void> computeFeedStats() async {
    if (_feeds.isEmpty) return;
    final List<FeedStats> stats = [];
    for (final feed in _feeds) {
      final raw = await _db.getFeedStatsRaw(feed.id);
      if (raw.isEmpty) continue;
      final row = raw.first;

      final hourlyRaw = await _db.getHourlyDistribution(feed.id);
      final hourly = List<int>.filled(24, 0);
      for (final h in hourlyRaw) {
        final idx = (h['hour'] as num).toInt();
        if (idx >= 0 && idx < 24) hourly[idx] = (h['cnt'] as num).toInt();
      }

      final dailyRaw = await _db.getDailyDistribution(feed.id);
      final daily = List<int>.filled(7, 0);
      for (final d in dailyRaw) {
        final idx = (d['day'] as num).toInt();
        if (idx >= 0 && idx < 7) daily[idx] = (d['cnt'] as num).toInt();
      }
      // reverse so index 0 = today
      daily.reversed.toList();

      final total = (row['total'] as num).toInt();
      final last30 = (row['last_30d'] as num?)?.toInt() ?? 0;

      stats.add(FeedStats(
        feedId: feed.id,
        feedTitle: feed.title,
        folderName: feed.folderName,
        totalArticles: total,
        lastHour: (row['last_hour'] as num?)?.toInt() ?? 0,
        lastDay: (row['last_day'] as num?)?.toInt() ?? 0,
        last7Days: (row['last_7d'] as num?)?.toInt() ?? 0,
        last30Days: last30,
        unreadCount: (row['unread'] as num?)?.toInt() ?? 0,
        frequency: last30 / 30.0,
        hourlyDistribution: hourly,
        dailyDistribution: daily.reversed.toList(),
      ));
    }
    _feedStats = stats;
    notifyListeners();
  }

  AppState() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _logger.init();
    await _logger.info('AppState initializing...');
    await _loadSettings();
    await _loadCachedData();
    _isInitialized = true;
    notifyListeners();

    if (_syncOnStartup && hasFeedbinCredentials) {
      await _logger.info('Auto-sync on startup enabled — starting sync');
      await syncFeeds();
    }

    if (_autoSyncMinutes > 0) {
      startAutoSync();
    }
  }

  void setLoading(bool loading, {double? progress, String? label}) {
    _isLoading = loading;
    if (progress != null) _progress = progress;
    if (label != null) _progressLabel = label;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    _logger.error(error ?? 'Unknown error');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> setView(ViewMode view) async {
    _currentView = view;
    _selectedFeedId = null;
    await _loadArticlesForView();
    notifyListeners();
  }

  Future<void> selectFeed(String? feedId) async {
    _selectedFeedId = feedId;
    await _loadArticlesForView();
    notifyListeners();
  }

  void selectArticle(Article? article) {
    // If mark-read-on-scroll is enabled and we're leaving an unread article, mark it read
    if (_markReadOnScroll && _selectedArticle != null && !_selectedArticle!.isRead) {
      markArticleRead(_selectedArticle!.id, true);
    }
    _selectedArticle = article;
    notifyListeners();
  }

  Future<void> _loadCachedData() async {
    _feeds = await _db.getFeeds();
    await _updateCounts();
    await _loadArticlesForView();
    notifyListeners();
  }

  Future<void> _loadArticlesForView() async {
    final feedId = _selectedFeedId;
    switch (_currentView) {
      case ViewMode.unread:
        _articles = await _db.getArticles(isRead: false, feedId: feedId);
        break;
      case ViewMode.read:
        _articles = await _db.getArticles(isRead: true, feedId: feedId);
        break;
      case ViewMode.favorites:
        _articles = await _db.getArticles(isStarred: true, feedId: feedId);
        break;
      case ViewMode.feeds:
        _articles = await _db.getArticles(feedId: feedId);
        break;
      case ViewMode.stats:
        _articles = [];
        break;
    }
    _applySort();
  }

  void _applySort() {
    switch (_sortOrder) {
      case SortOrder.newest:
        _articles.sort((a, b) => (b.publishedAt ?? DateTime(1970)).compareTo(a.publishedAt ?? DateTime(1970)));
        break;
      case SortOrder.oldest:
        _articles.sort((a, b) => (a.publishedAt ?? DateTime(1970)).compareTo(b.publishedAt ?? DateTime(1970)));
        break;
      case SortOrder.hottest:
        _articles.sort((a, b) => _hotScore(b).compareTo(_hotScore(a)));
        break;
    }
  }

  double _hotScore(Article article) {
    // Hottest = unread + starred*2 + recency bonus
    double score = 0;
    if (!article.isRead) score += 5;
    if (article.isStarred) score += 10;
    final age = DateTime.now().difference(article.publishedAt ?? DateTime(1970)).inHours;
    if (age < 1) score += 20;
    else if (age < 24) score += 10;
    else if (age < 168) score += 5;
    return score;
  }

  Future<void> setFeedbinCredentials(String username, String password) async {
    _feedbinUsername = username;
    _feedbinPassword = password;
    _apiClient = FeedbinApiClient(username: username, password: password);
    await _logger.info('Feedbin credentials set for user: $username');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feedbinUsername', username);
    await prefs.setString('feedbinPassword', base64Encode(utf8.encode(password)));

    notifyListeners();
  }

  /// Test Feedbin credentials without performing a full sync
  Future<bool> testFeedbinConnection() async {
    if (_apiClient == null) {
      setError('No credentials set');
      return false;
    }
    setLoading(true, label: 'Testing connection...');
    try {
      final ok = await _apiClient!.testConnection();
      setLoading(false);
      if (!ok) {
        setError('Authentication failed — check your username (email) and password');
        await _logger.error('Feedbin connection test failed (401)');
      } else {
        clearError();
        await _logger.info('Feedbin connection test succeeded');
      }
      return ok;
    } catch (e, st) {
      setLoading(false);
      setError('Connection test error: $e');
      await _logger.error('Feedbin connection test error', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> syncFeeds() async {
    if (_apiClient == null) {
      final msg = 'Feedbin credentials not configured';
      await _logger.warning(msg);
      setError(msg);
      return;
    }

    clearError();
    setLoading(true, label: 'Syncing feeds...', progress: 0.1);
    await _logger.syncStart('full');

    try {
      // Fetch feeds
      setLoading(true, label: 'Fetching feeds...', progress: 0.2);
      final feeds = await _apiClient!.getFeeds();
      
      // Fetch taggings (folders)
      setLoading(true, label: 'Fetching folders...', progress: 0.22);
      final taggings = await _apiClient!.getTaggings();
      for (final feed in feeds) {
        // Match by subscription id or feed_id
        feed.folderName = _findTagForFeed(taggings, feed.id);
        if (feed.folderName == null || feed.folderName!.isEmpty) {
          feed.folderName = 'Uncategorized';
        }
      }
      
      // Fetch feed metadata (last updated, frequency)
      setLoading(true, label: 'Fetching feed stats...', progress: 0.25);
      final feedMetadata = await _apiClient!.getAllFeedMetadata();
      for (final feed in feeds) {
        final meta = feedMetadata[int.tryParse(feed.id)];
        if (meta != null) {
          feed.lastUpdatedAt = meta['last_published_entry'] != null
              ? DateTime.parse(meta['last_published_entry'])
              : null;
          // Feedbin doesn't directly provide frequency, but we can infer from recent articles
          feed.updateFrequency = _inferFrequency(meta);
        }
      }
      
      await _db.insertFeeds(feeds);
      _feeds = feeds;
      await _logger.info('Fetched ${feeds.length} feeds with metadata');

      // Fetch unread entries (Feedbin returns full entries with isRead=false)
      setLoading(true, label: 'Fetching unread articles...', progress: 0.4);
      final unreadArticles = await _apiClient!.getUnreadEntries();
      await _logger.info('Fetched ${unreadArticles.length} unread articles');

      // Fetch starred entries (Feedbin returns full entries with correct read/starred flags)
      setLoading(true, label: 'Fetching starred articles...', progress: 0.55);
      final starredArticles = await _apiClient!.getStarredEntries();
      await _logger.info('Fetched ${starredArticles.length} starred articles');

      // Build merged set of IDs to keep
      final idsToKeep = <String>{...unreadArticles.map((a) => a.id), ...starredArticles.map((a) => a.id)};

      // Mark any articles in DB that are NOT in the unread list as read
      // (they were previously unread but have been read on Feedbin)
      await _db.markArticlesReadExcept(idsToKeep.toList());

      // Merge: Feedbin authoritative read/starred flags
      final mergedMap = <String, Article>{};
      for (final a in unreadArticles) {
        mergedMap[a.id] = a;
      }
      for (final a in starredArticles) {
        if (!mergedMap.containsKey(a.id)) {
          mergedMap[a.id] = a;
        } else {
          mergedMap[a.id]!.isStarred = true;
        }
      }
      final articles = mergedMap.values.toList();

      // Apply keyword filters
      setLoading(true, label: 'Applying filters...', progress: 0.7);
      final filteredArticles = _applyKeywordFilters(articles);

      // Preserve locally cached HTML / summaries
      await _preserveCachedFields(filteredArticles);

      // Save to database
      await _db.insertArticles(filteredArticles);

      final totalCached = await _db.getTotalArticleCount();
      await _logger.info('Total cached articles: $totalCached');

      // Push pending local operations to Feedbin
      setLoading(true, label: 'Syncing local changes...', progress: 0.85);
      await _pushPendingOperations();

      // Update unread counts per feed
      final feedUnreadCounts = await _db.getAllFeedCounts();
      for (final feed in _feeds) {
        feed.unreadCount = feedUnreadCounts[feed.id] ?? 0;
        await _db.updateFeedUnreadCount(feed.id, feed.unreadCount);
      }

      // Compute statistics
      await computeFeedStats();

      await _db.completeSync(0, articles.length);
      await _logger.syncComplete('full', articles.length);
      await _loadArticlesForView();

      setLoading(false);
      notifyListeners();
    } catch (e, st) {
      setLoading(false);
      final msg = 'Sync failed: $e';
      await _logger.syncComplete('full', 0, error: msg);
      await _logger.error('Feedbin sync failed', error: e, stackTrace: st);
      setError(msg);
    }
  }

  Future<void> syncFavorites() async {
    if (_apiClient == null) return;

    setLoading(true, label: 'Syncing favorites...', progress: 0.3);
    await _logger.syncStart('favorites');

    try {
      final starred = await _apiClient!.getStarredEntries();
      for (final article in starred) {
        await _db.starArticle(article.id, true);
      }
      await _logger.syncComplete('favorites', starred.length);
      await _loadArticlesForView();
      setLoading(false);
      notifyListeners();
    } catch (e, st) {
      setLoading(false);
      await _logger.syncComplete('favorites', 0, error: e.toString());
      setError('Failed to sync favorites: $e');
    }
  }

  List<Article> _applyKeywordFilters(List<Article> articles) {
    if (_filterKeywords.isEmpty) return articles;

    for (final article in articles) {
      final text = '${article.title} ${article.contentText ?? ''}'.toLowerCase();
      for (final keyword in _filterKeywords) {
        if (text.contains(keyword.toLowerCase())) {
          article.isRead = true;
          break;
        }
      }
    }
    return articles;
  }

  String? _findTagForFeed(Map<String, List<String>> taggings, String feedId) {
    for (final entry in taggings.entries) {
      if (entry.value.contains(feedId)) {
        return entry.key;
      }
    }
    return null;
  }

  String? _inferFrequency(Map<String, dynamic> meta) {
    final count = meta['entries_count'] as int?;
    final lastPublished = meta['last_published_entry'];
    if (count == null || lastPublished == null) return 'Unknown';
    if (count > 50) return 'Very frequent';
    if (count > 20) return 'Frequent';
    if (count > 5) return 'Regular';
    return 'Infrequent';
  }

  /// Preserve locally-cached fields (HTML, original HTML, summary) so they aren't overwritten on sync.
  Future<void> _preserveCachedFields(List<Article> articles) async {
    for (final article in articles) {
      final cached = await _fileCache.loadArticleHtml(article.id);
      if (cached != null && cached.isNotEmpty) {
        // cached_html is no longer on Article model; cache stays on disk
      }
      final summary = await _fileCache.loadSummary(article.id);
      if (summary != null && summary.isNotEmpty) {
        article.summary = summary;
      }
    }
  }

  Future<void> saveCachedHtml(String articleId, String? html) async {
    if (html == null || html.isEmpty) return;
    await _fileCache.saveArticleHtml(articleId, html);
  }

  Future<void> saveCachedOriginalHtml(String articleId, String? html) async {
    if (html == null || html.isEmpty) return;
    await _fileCache.saveOriginalHtml(articleId, html);
  }

  Future<void> saveSummary(String articleId, String? summary) async {
    if (summary == null || summary.isEmpty) return;
    await _fileCache.saveSummary(articleId, summary);
  }

  Future<void> markArticleRead(String articleId, bool read) async {
    await _db.markArticleRead(articleId, read);
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index != -1) {
      _articles[index].isRead = read;
    }
    if (_selectedArticle?.id == articleId) {
      _selectedArticle?.isRead = read;
    }
    if (read) {
      await _db.queueOperation(articleId, 'mark_read');
      await _logger.info('Queued mark_read for article $articleId');
    }
    await _updateCounts();
    notifyListeners();
  }

  Future<void> toggleStar(String articleId) async {
    final article = _articles.firstWhere((a) => a.id == articleId);
    final newStarred = !article.isStarred;
    await _db.starArticle(articleId, newStarred);
    article.isStarred = newStarred;
    if (_selectedArticle?.id == articleId) {
      _selectedArticle?.isStarred = newStarred;
    }
    await _db.queueOperation(articleId, newStarred ? 'star' : 'unstar');
    await _logger.info('Queued ${newStarred ? 'star' : 'unstar'} for article $articleId');
    await _updateCounts();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    if (_articles.isEmpty) return;
    final unreadIds = _articles.where((a) => !a.isRead).map((a) => a.id).toList();
    if (unreadIds.isEmpty) return;

    setLoading(true, label: 'Marking all as read...', progress: 0.3);
    await _logger.info('Marking ${unreadIds.length} articles as read');

    await _db.markAllArticlesRead(unreadIds);
    for (final article in _articles) {
      article.isRead = true;
    }
    // Queue all for sync to Feedbin
    for (final id in unreadIds) {
      await _db.queueOperation(id, 'mark_read');
    }
    await _logger.info('Queued ${unreadIds.length} mark_read operations');
    setLoading(false);
    notifyListeners();
  }

  // Settings toggles
  void setMarkReadOnScroll(bool value) {
    _markReadOnScroll = value;
    saveSettings();
    notifyListeners();
  }

  void setSyncOnStartup(bool value) {
    _syncOnStartup = value;
    saveSettings();
    notifyListeners();
  }

  void setAutoSyncMinutes(int minutes) {
    _autoSyncMinutes = minutes;
    if (minutes > 0) {
      startAutoSync();
    } else {
      stopAutoSync();
    }
    saveSettings();
    notifyListeners();
  }

  void setStartupPage(String page) {
    _startupPage = page;
    saveSettings();
    notifyListeners();
  }

  void setSortOrder(SortOrder order) {
    _sortOrder = order;
    saveSettings();
    _applySort();
    notifyListeners();
  }

  void setReadDaysLimit(int days) {
    _readDaysLimit = days;
    saveSettings();
    notifyListeners();
  }

  void setTextZoom(double zoom) {
    _textZoom = zoom.clamp(0.5, 3.0);
    saveSettings();
    notifyListeners();
  }

  Future<void> _pushPendingOperations() async {
    if (_apiClient == null) return;
    
    final pending = await _db.getPendingOperations();
    if (pending.isEmpty) {
      await _logger.info('No pending operations to sync');
      return;
    }

    await _logger.info('Pushing ${pending.length} pending operations to Feedbin');
    final List<int> syncedIds = [];
    final List<String> readIds = [];
    final List<String> starIds = [];
    final List<String> unstarIds = [];

    for (final op in pending) {
      final articleId = op['article_id'] as String;
      final operation = op['operation'] as String;
      switch (operation) {
        case 'mark_read':
          readIds.add(articleId);
          break;
        case 'star':
          starIds.add(articleId);
          break;
        case 'unstar':
          unstarIds.add(articleId);
          break;
      }
      syncedIds.add(op['id'] as int);
    }

    // Batch operations
    try {
      if (readIds.isNotEmpty) {
        await _apiClient!.markAllAsRead(readIds);
        await _logger.info('Synced ${readIds.length} mark-reads');
      }
      if (starIds.isNotEmpty) {
        for (final id in starIds) {
          await _apiClient!.starEntry(id);
        }
        await _logger.info('Synced ${starIds.length} stars');
      }
      if (unstarIds.isNotEmpty) {
        for (final id in unstarIds) {
          await _apiClient!.unstarEntry(id);
        }
        await _logger.info('Synced ${unstarIds.length} unstars');
      }
      await _db.markOperationsSynced(syncedIds);
      await _db.clearOldSyncedOperations();
    } catch (e) {
      await _logger.error('Failed to push pending operations', error: e);
      // Leave them pending for next sync
    }
  }

  // Auto-sync timer
  void startAutoSync() {
    stopAutoSync();
    if (_autoSyncMinutes > 0) {
      _logger.info('Starting auto-sync timer: every $_autoSyncMinutes minutes');
      _syncTimer = Timer.periodic(
        Duration(minutes: _autoSyncMinutes),
        (_) => syncFeeds(),
      );
    }
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _feedbinUsername = prefs.getString('feedbinUsername');
    final encodedPassword = prefs.getString('feedbinPassword');
    if (encodedPassword != null && _feedbinUsername != null) {
      try {
        _feedbinPassword = utf8.decode(base64Decode(encodedPassword));
        _apiClient = FeedbinApiClient(
          username: _feedbinUsername!,
          password: _feedbinPassword!,
        );
        await _logger.info('Loaded Feedbin credentials for user: $_feedbinUsername');
      } catch (e) {
        await _logger.error('Failed to decode stored password', error: e);
      }
    }

    final providersJson = prefs.getString('aiProviders');
    if (providersJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(providersJson);
        _aiProviders = decoded.map((json) => AIProvider.fromJson(json)).toList();
      } catch (e) {
        await _logger.error('Failed to load AI providers', error: e);
      }
    }

    if (_aiProviders.isEmpty) {
      _aiProviders.add(AIProvider(
        id: 'default',
        name: 'Ollama Cloud',
        type: 'ollama',
        baseUrl: 'https://api.ollama.com/v1',
        model: 'llama3.2',
      ));
    }

    _defaultProvider = _aiProviders.firstWhere(
      (p) => p.id == prefs.getString('defaultProviderId'),
      orElse: () => _aiProviders.first,
    );

    _filterKeywords = prefs.getStringList('filterKeywords') ?? [];
    _startupPage = prefs.getString('startupPage') ?? 'unread';
    _autoSyncMinutes = prefs.getInt('autoSyncMinutes') ?? 15;
    _markReadOnScroll = prefs.getBool('markReadOnScroll') ?? true;
    _syncOnStartup = prefs.getBool('syncOnStartup') ?? true;
    _sortOrder = SortOrder.values[prefs.getInt('sortOrder') ?? 0];
    _readDaysLimit = prefs.getInt('readDaysLimit') ?? 7;
    _textZoom = prefs.getDouble('textZoom') ?? 1.0;
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aiProviders', jsonEncode(_aiProviders.map((p) => p.toJson()).toList()));
    await prefs.setString('defaultProviderId', _defaultProvider?.id ?? '');
    await prefs.setStringList('filterKeywords', _filterKeywords);
    await prefs.setString('startupPage', _startupPage);
    await prefs.setInt('autoSyncMinutes', _autoSyncMinutes);
    await prefs.setBool('markReadOnScroll', _markReadOnScroll);
    await prefs.setBool('syncOnStartup', _syncOnStartup);
    await prefs.setInt('sortOrder', _sortOrder.index);
    await prefs.setInt('readDaysLimit', _readDaysLimit);
    await prefs.setDouble('textZoom', _textZoom);
    await _logger.info('Settings saved');
  }

  // AI Operations with logging
  Future<String?> summarizeArticle(Article article) async {
    if (_defaultProvider == null) return null;
    final provider = _defaultProvider!;

    setLoading(true, label: 'Generating summary...', progress: 0.3);
    await _logger.aiRequest(provider.name, provider.model, 'summarize');

    try {
      final result = await _aiService.summarizeArticle(
        provider: provider,
        title: article.title,
        content: article.contentText ?? article.contentHtml ?? '',
      );
      await _logger.aiResponse(provider.name, provider.model, 'summarize', success: result != null);
      setLoading(false);
      return result;
    } catch (e, st) {
      await _logger.aiResponse(provider.name, provider.model, 'summarize', success: false, error: e.toString());
      await _logger.error('AI summarization failed', error: e, stackTrace: st);
      setLoading(false);
      return null;
    }
  }

  Future<String?> translateArticle(Article article, String language) async {
    if (_defaultProvider == null) return null;
    final provider = _defaultProvider!;

    setLoading(true, label: 'Translating to $language...', progress: 0.3);
    await _logger.aiRequest(provider.name, provider.model, 'translate-$language');

    try {
      final result = await _aiService.translateArticle(
        provider: provider,
        content: article.contentText ?? article.contentHtml ?? '',
        targetLanguage: language,
      );
      await _logger.aiResponse(provider.name, provider.model, 'translate-$language', success: result != null);
      setLoading(false);
      return result;
    } catch (e, st) {
      await _logger.aiResponse(provider.name, provider.model, 'translate-$language', success: false, error: e.toString());
      setLoading(false);
      return null;
    }
  }

  /// Smart Topic: summarize multiple unread articles together
  Future<String?> summarizeMultipleArticles(List<Article> articles, {String? customPrompt}) async {
    if (_defaultProvider == null || articles.isEmpty) return null;
    final provider = _defaultProvider!;

    setLoading(true, label: 'Analyzing ${articles.length} articles...', progress: 0.1);
    await _logger.aiRequest(provider.name, provider.model, 'smart-topic-batch');

    try {
      // Build combined prompt
      final buffer = StringBuffer();
      buffer.writeln('Summarize the key themes and important points from the following ${articles.length} articles:');
      buffer.writeln();
      for (int i = 0; i < articles.length; i++) {
        buffer.writeln('--- Article ${i + 1}: ${articles[i].title} ---');
        buffer.writeln(articles[i].contentText ?? articles[i].contentHtml ?? '');
        buffer.writeln();
      }

      final combinedContent = buffer.toString().substring(0, buffer.length > 8000 ? 8000 : buffer.length);

      setLoading(true, label: 'Sending to AI...', progress: 0.5);

      final result = await _aiService.summarizeArticle(
        provider: provider,
        title: 'Summary of ${articles.length} articles',
        content: combinedContent,
      );

      await _logger.aiResponse(provider.name, provider.model, 'smart-topic-batch', success: result != null);
      setLoading(false);
      return result;
    } catch (e, st) {
      await _logger.aiResponse(provider.name, provider.model, 'smart-topic-batch', success: false, error: e.toString());
      await _logger.error('Smart topic summarization failed', error: e, stackTrace: st);
      setLoading(false);
      return null;
    }
  }

  void addFilterKeyword(String keyword) {
    if (!_filterKeywords.contains(keyword)) {
      _filterKeywords.add(keyword);
      saveSettings();
      notifyListeners();
    }
  }

  void removeFilterKeyword(String keyword) {
    _filterKeywords.remove(keyword);
    saveSettings();
    notifyListeners();
  }

  /// Export settings to a JSON file
  Future<File> exportSettingsToFile({bool includeApiKey = false}) async {
    final settings = exportSettings(includeApiKey: includeApiKey);
    final json = const JsonEncoder.withIndent('  ').convert(settings);

    final dir = await getApplicationSupportDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final fileName = 'nowrss_settings_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsString(json);
    await _logger.info('Settings exported to: ${file.path}');
    return file;
  }

  /// Import settings from a JSON file
  Future<void> importSettingsFromFile(File file) async {
    try {
      final json = await file.readAsString();
      final settings = jsonDecode(json);
      await importSettings(settings);
      await _logger.info('Settings imported from: ${file.path}');
    } catch (e) {
      await _logger.error('Failed to import settings from file', error: e);
      throw Exception('Invalid settings file: $e');
    }
  }

  Map<String, dynamic> exportSettings({bool includeApiKey = false}) {
    return {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'feedbinUsername': _feedbinUsername,
      'feedbinPassword': includeApiKey ? _feedbinPassword : '',
      'aiProviders': _aiProviders.map((p) {
        final json = p.toJson();
        if (!includeApiKey) {
          json['apiKey'] = '';
        }
        return json;
      }).toList(),
      'defaultProviderId': _defaultProvider?.id,
      'filterKeywords': _filterKeywords,
      'startupPage': _startupPage,
      'autoSyncMinutes': _autoSyncMinutes,
      'markReadOnScroll': _markReadOnScroll,
      'syncOnStartup': _syncOnStartup,
      'sortOrder': _sortOrder.name,
      'readDaysLimit': _readDaysLimit,
      'textZoom': _textZoom,
    };
  }

  Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings['feedbinUsername'] != null && settings['feedbinPassword'] != null) {
      _feedbinUsername = settings['feedbinUsername'];
      _feedbinPassword = settings['feedbinPassword'];
      if (_feedbinUsername != null && _feedbinPassword != null && _feedbinPassword!.isNotEmpty) {
        _apiClient = FeedbinApiClient(
          username: _feedbinUsername!,
          password: _feedbinPassword!,
        );
      }
    }

    if (settings['aiProviders'] != null) {
      _aiProviders = (settings['aiProviders'] as List)
          .map((json) => AIProvider.fromJson(json))
          .toList();
    }

    _filterKeywords = List<String>.from(settings['filterKeywords'] ?? []);
    _startupPage = settings['startupPage'] ?? 'unread';
    _autoSyncMinutes = settings['autoSyncMinutes'] ?? 15;
    _markReadOnScroll = settings['markReadOnScroll'] ?? true;
    _syncOnStartup = settings['syncOnStartup'] ?? true;
    _sortOrder = SortOrder.values.byName(settings['sortOrder'] ?? 'newest');
    _readDaysLimit = settings['readDaysLimit'] ?? 7;
    _textZoom = settings['textZoom']?.toDouble() ?? 1.0;

    await saveSettings();
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
