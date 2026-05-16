import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/feed.dart';
import '../models/article.dart';

class FeedbinApiClient {
  final String username;
  final String password;
  final String baseUrl;
  
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
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v2/feeds.json'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Feed.fromJson(json)).toList();
      }
      throw Exception('Failed to load feeds: ${response.statusCode}');
    } catch (e) {
      throw Exception('Feedbin API error: $e');
    }
  }

  Future<List<Article>> getUnreadEntries() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v2/entries.json?unread=true&per_page=100'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Article.fromFeedbinJson(json)).toList();
      }
      throw Exception('Failed to load entries: ${response.statusCode}');
    } catch (e) {
      throw Exception('Feedbin API error: $e');
    }
  }

  Future<List<Article>> getStarredEntries() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v2/entries.json?starred=true&per_page=100'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Article.fromFeedbinJson(json)).toList();
      }
      throw Exception('Failed to load starred entries: ${response.statusCode}');
    } catch (e) {
      throw Exception('Feedbin API error: $e');
    }
  }

  Future<void> markAsRead(String entryId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v2/reads.json'),
      headers: _headers,
      body: jsonEncode({'entries': [int.parse(entryId)]}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to mark as read: ${response.statusCode}');
    }
  }

  Future<void> markAllAsRead(List<String> entryIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v2/reads.json'),
      headers: _headers,
      body: jsonEncode({
        'entries': entryIds.map((id) => int.parse(id)).toList(),
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to mark all as read: ${response.statusCode}');
    }
  }

  Future<void> starEntry(String entryId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v2/starred_entries.json'),
      headers: _headers,
      body: jsonEncode({'entries': [int.parse(entryId)]}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to star: ${response.statusCode}');
    }
  }

  Future<void> unstarEntry(String entryId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/v2/starred_entries.json'),
      headers: _headers,
      body: jsonEncode({'entries': [int.parse(entryId)]}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to unstar: ${response.statusCode}');
    }
  }
}
