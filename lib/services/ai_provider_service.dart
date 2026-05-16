import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/ai_provider.dart';

class AIProviderService {
  final Logger _logger = Logger();
  
  Future<String?> summarizeArticle({
    required AIProvider provider,
    required String title,
    required String content,
  }) async {
    try {
      final prompt = provider.summaryPrompt
          .replaceAll('{title}', title)
          .replaceAll('{content}', content.substring(0, content.length > 4000 ? 4000 : content.length));

      final body = provider.type == 'ollama'
          ? {
              'model': provider.model,
              'prompt': prompt,
              'stream': false,
            }
          : {
              'model': provider.model,
              'messages': [
                {'role': 'system', 'content': 'You are a helpful assistant that summarizes articles.'},
                {'role': 'user', 'content': prompt},
              ],
              'stream': false,
            };

      final endpoint = provider.type == 'ollama'
          ? '${provider.baseUrl}/api/generate'
          : '${provider.baseUrl}/chat/completions';

      final headers = {
        'Content-Type': 'application/json',
        if (provider.apiKey.isNotEmpty) 'Authorization': 'Bearer ${provider.apiKey}',
      };

      _logger.d('Sending request to $endpoint with model ${provider.model}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (provider.type == 'ollama') {
          return data['response'];
        } else {
          return data['choices']?[0]?['message']?['content'];
        }
      }
      
      _logger.e('AI API error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e, stackTrace) {
      _logger.e('AI Service error', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<String?> translateArticle({
    required AIProvider provider,
    required String content,
    required String targetLanguage,
  }) async {
    try {
      final prompt = 'Translate the following text to $targetLanguage:\n\n$content';

      final body = provider.type == 'ollama'
          ? {
              'model': provider.model,
              'prompt': prompt,
              'stream': false,
            }
          : {
              'model': provider.model,
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
              'stream': false,
            };

      final endpoint = provider.type == 'ollama'
          ? '${provider.baseUrl}/api/generate'
          : '${provider.baseUrl}/chat/completions';

      final headers = {
        'Content-Type': 'application/json',
        if (provider.apiKey.isNotEmpty) 'Authorization': 'Bearer ${provider.apiKey}',
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (provider.type == 'ollama') {
          return data['response'];
        } else {
          return data['choices']?[0]?['message']?['content'];
        }
      }
      
      return null;
    } catch (e) {
      _logger.e('Translation error', error: e);
      return null;
    }
  }
}
