import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feed.dart';
import '../models/article.dart';
import '../models/ai_provider.dart';
import 'feedbin_api.dart';
import 'ai_provider_service.dart';

enum ViewMode { feeds, unread, read, favorites }

class AppState extends ChangeNotifier {
  final FeedbinApiClient? _apiClient;
  final AIProviderService _aiService = AIProviderService();
  
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

  AppState() : _apiClient = null {
    _loadSettings();
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
    notifyListeners();
  }

  void selectArticle(Article? article) {
    _selectedArticle = article;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
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
    
    notifyListeners();
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

  Future<void> syncFeeds() async {
    // Placeholder for actual sync
    setLoading(true, label: 'Syncing feeds...');
    await Future.delayed(const Duration(seconds: 1));
    setLoading(false);
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
}
