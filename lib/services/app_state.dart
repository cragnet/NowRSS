import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed.dart';
import '../models/article.dart';
import '../models/ai_provider.dart';
import 'feedbin_api.dart';
import 'ai_provider_service.dart';
import 'database_service.dart';
import 'log_service.dart';

enum ViewMode { feeds, unread, read, favorites }

class AppState extends ChangeNotifier {
  FeedbinApiClient? _apiClient;
  final AIProviderService _aiService = AIProviderService();
  final DatabaseService _db = DatabaseService();
  final LogService _logger = LogService();

  List<Feed> _feeds = [];
  List<Article> _articles = [];
  Article? _selectedArticle;
  ViewMode _currentView = ViewMode.unread;
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
  String? _feedbinUsername;
  String? _feedbinPassword;

  bool _isInitialized = false;
  Timer? _syncTimer;

  // Getters
  List<Feed> get feeds => _feeds;
  List<Article> get articles => _articles;
  Article? get selectedArticle => _selectedArticle;
  ViewMode get currentView => _currentView;
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
  LogService get logger => _logger;

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

  void setView(ViewMode view) {
    _currentView = view;
    _loadArticlesForView();
    notifyListeners();
  }

  void selectArticle(Article? article) {
    _selectedArticle = article;
    if (article != null && !article.isRead && _markReadOnScroll) {
      markArticleRead(article.id, true);
    }
    notifyListeners();
  }

  Future<void> _loadCachedData() async {
    _feeds = await _db.getFeeds();
    await _loadArticlesForView();
    notifyListeners();
  }

  Future<void> _loadArticlesForView() async {
    switch (_currentView) {
      case ViewMode.unread:
        _articles = await _db.getArticles(isRead: false);
        break;
      case ViewMode.read:
        _articles = await _db.getArticles(isRead: true);
        break;
      case ViewMode.favorites:
        _articles = await _db.getArticles(isStarred: true);
        break;
      case ViewMode.feeds:
        _articles = await _db.getArticles();
        break;
    }
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

    // Immediately test by syncing
    await syncFeeds();
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
      await _db.insertFeeds(feeds);
      _feeds = feeds;
      await _logger.info('Fetched ${feeds.length} feeds');

      // Fetch unread entries
      setLoading(true, label: 'Fetching articles...', progress: 0.5);
      final articles = await _apiClient!.getUnreadEntries();
      await _logger.info('Fetched ${articles.length} unread articles');

      // Apply keyword filters
      setLoading(true, label: 'Applying filters...', progress: 0.8);
      final filteredArticles = _applyKeywordFilters(articles);
      final autoMarked = articles.length - filteredArticles.where((a) => !a.isRead).length;
      if (autoMarked > 0) {
        await _logger.info('Auto-marked $autoMarked articles as read via keyword filters');
      }

      // Cache articles
      await _db.insertArticles(filteredArticles);

      // Update unread counts per feed
      for (final feed in _feeds) {
        final count = await _db.getUnreadCount(feed.id);
        feed.unreadCount = count;
        await _db.updateFeedUnreadCount(feed.id, count);
      }

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

  Future<void> markArticleRead(String articleId, bool read) async {
    await _db.markArticleRead(articleId, read);
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index != -1) {
      _articles[index].isRead = read;
    }
    if (_selectedArticle?.id == articleId) {
      _selectedArticle?.isRead = read;
    }
    if (_apiClient != null && read) {
      try {
        await _apiClient!.markAsRead(articleId);
      } catch (e) {
        await _logger.warning('Failed to sync mark-as-read to Feedbin: $e');
      }
    }
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
    if (_apiClient != null) {
      try {
        await _apiClient!.markAllAsRead(unreadIds);
      } catch (e) {
        await _logger.warning('Failed to sync mark-all-read to Feedbin: $e');
      }
    }
    setLoading(false);
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
    if (_apiClient != null) {
      try {
        if (newStarred) {
          await _apiClient!.starEntry(articleId);
        } else {
          await _apiClient!.unstarEntry(articleId);
        }
      } catch (e) {
        await _logger.warning('Failed to sync star to Feedbin: $e');
      }
    }
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

    await saveSettings();
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
