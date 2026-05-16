import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed.dart';
import '../models/article.dart';
import '../models/ai_provider.dart';
import 'feedbin_api.dart';
import 'ai_provider_service.dart';
import 'database_service.dart';

enum ViewMode { feeds, unread, read, favorites }

class AppState extends ChangeNotifier {
  FeedbinApiClient? _apiClient;
  final AIProviderService _aiService = AIProviderService();
  final DatabaseService _db = DatabaseService();
  
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
  String? _feedbinUsername;
  String? _feedbinPassword;
  
  bool _isInitialized = false;
  
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

  AppState() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadSettings();
    await _loadCachedData();
    _isInitialized = true;
    notifyListeners();
    
    // Auto-sync at startup if configured
    if (_startupPage != 'feeds' && hasFeedbinCredentials) {
      await syncFeeds();
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
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feedbinUsername', username);
    await prefs.setString('feedbinPassword', base64Encode(utf8.encode(password)));
    
    notifyListeners();
  }

  Future<void> syncFeeds() async {
    if (_apiClient == null) {
      setError('Feedbin credentials not configured');
      return;
    }

    clearError();
    setLoading(true, label: 'Syncing feeds...', progress: 0.1);
    
    try {
      // Start sync log
      final syncId = await _db.startSync('full');
      
      // Fetch feeds
      setLoading(true, label: 'Fetching feeds...', progress: 0.2);
      final feeds = await _apiClient!.getFeeds();
      await _db.insertFeeds(feeds);
      _feeds = feeds;
      
      // Fetch unread entries
      setLoading(true, label: 'Fetching articles...', progress: 0.5);
      final articles = await _apiClient!.getUnreadEntries();
      
      // Apply keyword filters
      setLoading(true, label: 'Applying filters...', progress: 0.8);
      final filteredArticles = _applyKeywordFilters(articles);
      
      // Cache articles
      await _db.insertArticles(filteredArticles);
      
      // Update unread counts
      for (final feed in _feeds) {
        final count = await _db.getUnreadCount(feed.id);
        feed.unreadCount = count;
        await _db.updateFeedUnreadCount(feed.id, count);
      }
      
      await _db.completeSync(syncId, articles.length);
      await _loadArticlesForView();
      
      setLoading(false);
      notifyListeners();
    } catch (e) {
      setLoading(false);
      setError('Sync failed: $e');
    }
  }

  Future<void> syncFavorites() async {
    if (_apiClient == null) return;
    
    setLoading(true, label: 'Syncing favorites...', progress: 0.3);
    
    try {
      final starred = await _apiClient!.getStarredEntries();
      
      // Mark as starred in local DB
      for (final article in starred) {
        await _db.starArticle(article.id, true);
      }
      
      await _loadArticlesForView();
      setLoading(false);
      notifyListeners();
    } catch (e) {
      setLoading(false);
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
    
    // Update in-memory
    final index = _articles.indexWhere((a) => a.id == articleId);
    if (index != -1) {
      _articles[index].isRead = read;
    }
    
    if (_selectedArticle?.id == articleId) {
      _selectedArticle?.isRead = read;
    }
    
    // Sync to Feedbin
    if (_apiClient != null && read) {
      try {
        await _apiClient!.markAsRead(articleId);
      } catch (e) {
        // Local mark succeeded, sync failed — will retry next sync
      }
    }
    
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    if (_articles.isEmpty) return;
    
    final unreadIds = _articles.where((a) => !a.isRead).map((a) => a.id).toList();
    if (unreadIds.isEmpty) return;
    
    setLoading(true, label: 'Marking all as read...', progress: 0.3);
    
    await _db.markAllArticlesRead(unreadIds);
    
    for (final article in _articles) {
      article.isRead = true;
    }
    
    if (_apiClient != null) {
      try {
        await _apiClient!.markAllAsRead(unreadIds);
      } catch (e) {
        // Local succeeded
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
        // Local succeeded
      }
    }
    
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Feedbin credentials
    _feedbinUsername = prefs.getString('feedbinUsername');
    final encodedPassword = prefs.getString('feedbinPassword');
    if (encodedPassword != null) {
      _feedbinPassword = utf8.decode(base64Decode(encodedPassword));
      _apiClient = FeedbinApiClient(
        username: _feedbinUsername!,
        password: _feedbinPassword!,
      );
    }
    
    // AI providers
    final providersJson = prefs.getString('aiProviders');
    if (providersJson != null) {
      final List<dynamic> decoded = jsonDecode(providersJson);
      _aiProviders = decoded.map((json) => AIProvider.fromJson(json)).toList();
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
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('aiProviders', jsonEncode(_aiProviders.map((p) => p.toJson()).toList()));
    await prefs.setString('defaultProviderId', _defaultProvider?.id ?? '');
    await prefs.setStringList('filterKeywords', _filterKeywords);
    await prefs.setString('startupPage', _startupPage);
    await prefs.setInt('autoSyncMinutes', _autoSyncMinutes);
    await prefs.setBool('markReadOnScroll', _markReadOnScroll);
  }

  Future<String?> summarizeArticle(Article article) async {
    if (_defaultProvider == null) return null;
    
    setLoading(true, label: 'Generating summary...', progress: 0.3);
    
    final result = await _aiService.summarizeArticle(
      provider: _defaultProvider!,
      title: article.title,
      content: article.contentText ?? article.contentHtml ?? '',
    );
    
    setLoading(false);
    return result;
  }

  Future<String?> translateArticle(Article article, String language) async {
    if (_defaultProvider == null) return null;
    
    setLoading(true, label: 'Translating...', progress: 0.3);
    
    final result = await _aiService.translateArticle(
      provider: _defaultProvider!,
      content: article.contentText ?? article.contentHtml ?? '',
      targetLanguage: language,
    );
    
    setLoading(false);
    return result;
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

  Map<String, dynamic> exportSettings({bool includeApiKey = false}) {
    return {
      'version': '1.0',
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
    };
  }

  Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings['feedbinUsername'] != null && settings['feedbinPassword'] != null) {
      _feedbinUsername = settings['feedbinUsername'];
      _feedbinPassword = settings['feedbinPassword'];
      if (_feedbinUsername != null && _feedbinPassword != null) {
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
    
    await saveSettings();
    notifyListeners();
  }

  // Auto-sync timer
  Timer? _syncTimer;

  void startAutoSync() {
    _syncTimer?.cancel();
    if (_autoSyncMinutes > 0) {
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

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
