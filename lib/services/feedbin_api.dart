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

  Future<List<Feed>> getFeeds() async {
    final url = '$baseUrl/v2/feeds.json';
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
        return data.map((json) => Feed.fromJson(json)).toList();
      }
      throw Exception('Failed to load feeds: ${response.statusCode}');
    } catch (e, st) {
      await _logger.error('Feedbin getFeeds failed', error: e, stackTrace: st);
      throw Exception('Feedbin API error: $e');
    }
  }

  Future<List<Article>> getUnreadEntries() async {
    final url = '$baseUrl/v2/entries.json?unread=true&per_page=100';
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
        return data.map((json) => Article.fromFeedbinJson(json)).toList();
      }
      throw Exception('Failed to load entries: ${response.statusCode}');
    } catch (e, st) {
      await _logger.error('Feedbin getUnreadEntries failed', error: e, stackTrace: st);
      throw Exception('Feedbin API error: $e');
    }
  }

  Future<List<Article>> getStarredEntries() async {
    final url = '$baseUrl/v2/entries.json?starred=true&per_page=100';
    await _logger.apiRequest('GET', url);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );
      await _logger.apiResponse('GET', url, response.statusCode);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Article.fromFeedbinJson(json)).toList();
      }
      throw Exception('Failed to load starred entries: ${response.statusCode}');
    } catch (e, st) {
      await _logger.error('Feedbin getStarredEntries failed', error: e, stackTrace: st);
      throw Exception('Feedbin API error: $e');
    }
  }

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