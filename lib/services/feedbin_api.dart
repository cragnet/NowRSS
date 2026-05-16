import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/feed.dart';
import '../models/article.dart';
import 'log_service.dart';

class FeedbinApiClient {
  final String username;
  final String password;
  final String baseUrl;
  final LogService _logger = LogService();

  FeedbinApiClient({
    required this.username,
    required this.password,
    this.baseUrl = 'https://api.feedbin.com',
  });

  Map<String, String> get _headers => {
    'Authorization': 'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    'Content-Type': 'application/json',
  };

  // === SUBSCRIPTIONS (FEEDS) ===

  Future<List<Feed>> getFeeds() async {
    final url = '$baseUrl/v2/subscriptions.json';
    await _logger.apiRequest('GET', url);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );
      await _logger.apiResponse('GET', url, response.statusCode,
          bodyPreview: response.body.substring(0, response.body.length > 200 ? 200 : response.body.length));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Feed(
          id: json['feed_id'].toString(),
          title: json['title'] ?? 'Untitled',
          url: json['feed_url'],
          siteUrl: json['site_url'],
          faviconUrl: json['icon_url'],
        )).toList();
      }
      throw Exception('Failed to load feeds: ${response.statusCode}');
    } catch (e, st) {
      await _logger.error('Feedbin getFeeds failed', error: e, stackTrace: st);
      throw Exception('Feedbin API error: $e');
    }
  }

  // === ENTRIES (ARTICLES) ===

  Future<List<Article>> getUnreadEntries() async {
    // First get unread entry IDs, then fetch the entries
    final idsUrl = '$baseUrl/v2/unread_entries.json';
    await _logger.apiRequest('GET', idsUrl);
    
    try {
      final idsResponse = await http.get(
        Uri.parse(idsUrl),
        headers: _headers,
      );
      await _logger.apiResponse('GET', idsUrl, idsResponse.statusCode,
          bodyPreview: idsResponse.body.substring(0, idsResponse.body.length > 100 ? 100 : idsResponse.body.length));

      if (idsResponse.statusCode != 200) {
        throw Exception('Failed to get unread entry IDs: ${idsResponse.statusCode}');
      }

      final List<dynamic> entryIds = jsonDecode(idsResponse.body);
      if (entryIds.isEmpty) return [];

      // Fetch entries in batches
      return await _getEntriesByIds(entryIds.map((id) => id.toString()).toList());
    } catch (e, st) {
      await _logger.error('Feedbin getUnreadEntries failed', error: e, stackTrace: st);
      throw Exception('Feedbin API error: $e');
    }
  }

  Future<List<Article>> getStarredEntries() async {
    // First get starred entry IDs, then fetch the entries
    final idsUrl = '$baseUrl/v2/starred_entries.json';
    await _logger.apiRequest('GET', idsUrl);
    
    try {
      final idsResponse = await http.get(
        Uri.parse(idsUrl),
        headers: _headers,
      );
      await _logger.apiResponse('GET', idsUrl, idsResponse.statusCode,
          bodyPreview: idsResponse.body.substring(0, idsResponse.body.length > 100 ? 100 : idsResponse.body.length));

      if (idsResponse.statusCode != 200) {
        throw Exception('Failed to get starred entry IDs: ${idsResponse.statusCode}');
      }

      final List<dynamic> entryIds = jsonDecode(idsResponse.body);
      if (entryIds.isEmpty) return [];

      return await _getEntriesByIds(entryIds.map((id) => id.toString()).toList());
    } catch (e, st) {
      await _logger.error('Feedbin getStarredEntries failed', error: e, stackTrace: st);
      throw Exception('Feedbin API error: $e');
    }
  }

  Future<List<Article>> _getEntriesByIds(List<String> ids) async {
    final url = '$baseUrl/v2/entries.json?ids=${ids.join(",")}&per_page=100';
    await _logger.apiRequest('GET', url);
    
    final response = await http.get(
      Uri.parse(url),
      headers: _headers,
    );
    await _logger.apiResponse('GET', url, response.statusCode,
        bodyPreview: response.body.substring(0, response.body.length > 200 ? 200 : response.body.length));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Article.fromFeedbinJson(json)).toList();
    }
    throw Exception('Failed to load entries: ${response.statusCode}');
  }

  // === MARK READ / STAR ===

  Future<void> markAsRead(String entryId) async {
    final url = '$baseUrl/v2/reads.json';
    final body = {'entries': [int.parse(entryId)]};
    await _logger.apiRequest('POST', url, body: body);

    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(body),
    );

    await _logger.apiResponse('POST', url, response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to mark as read: ${response.statusCode}');
    }
  }

  Future<void> markAllAsRead(List<String> entryIds) async {
    final url = '$baseUrl/v2/reads.json';
    final body = {'entries': entryIds.map((id) => int.parse(id)).toList()};
    await _logger.apiRequest('POST', url, body: body);

    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(body),
    );

    await _logger.apiResponse('POST', url, response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to mark all as read: ${response.statusCode}');
    }
  }

  Future<void> starEntry(String entryId) async {
    final url = '$baseUrl/v2/starred_entries.json';
    final body = {'entries': [int.parse(entryId)]};
    await _logger.apiRequest('POST', url, body: body);

    final response = await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(body),
    );

    await _logger.apiResponse('POST', url, response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to star: ${response.statusCode}');
    }
  }

  Future<void> unstarEntry(String entryId) async {
    final url = '$baseUrl/v2/starred_entries.json';
    final body = {'entries': [int.parse(entryId)]};
    await _logger.apiRequest('DELETE', url, body: body);

    final response = await http.delete(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(body),
    );

    await _logger.apiResponse('DELETE', url, response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to unstar: ${response.statusCode}');
    }
  }
}