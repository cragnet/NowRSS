class AIProvider {
  final String id;
  final String name;
  final String type; // 'ollama' or 'openai'
  final String baseUrl;
  final String apiKey;
  final String model;
  final String summaryPrompt;
  final String articleSummaryPrompt;
  final String batchSummaryPrompt;

  AIProvider({
    required this.id,
    required this.name,
    this.type = 'ollama',
    required this.baseUrl,
    this.apiKey = '',
    required this.model,
    this.summaryPrompt = '''You are a helpful assistant. Summarize the following article concisely.
Focus on the key points, main arguments, and any actionable takeaways.
Keep it under 150 words.

Title: {title}
Content: {content}

Summary:''',
    this.articleSummaryPrompt = '''You are an expert news summarizer. Create a comprehensive yet concise summary of the following article.

REQUIREMENTS:
- Provide 5 or more bullet points covering the main topics and key facts
- Each bullet should be a complete, informative sentence
- Include any data, names, dates, or statistics mentioned
- Add a "Synopsis Overview" section at the end (2-3 sentences capturing the essence)
- Format using Markdown: bullet points with dashes, bold headings

Title: {title}
Author: {author}
Content: {content}

Summary:''',
    this.batchSummaryPrompt = '''You are a news digest curator. Summarize a collection of articles for a busy reader.

INPUT FORMAT:
You will receive multiple articles drawn from full article text. For each article provide:
1. Title with source
2. One substantive sentence capturing the main point (NOT a generic RSS teaser)
3. A numbered link reference [N]

GROUPING:
- Group articles by similar theme/topic under bold headings
- If an article stands alone, list it individually

OUTPUT FORMAT:
## Themed Groups
**Theme Name**
- [1] Article Title — One sentence summary
- [2] Another Title — One sentence summary

## Individual Articles
- [3] Standalone Title — One sentence summary

## Overview Synopsis
A concise, opinionated analysis (200+ words) covering:
- The overarching narrative and key themes across articles
- Notable trends or surprising developments
- Potential implications or critical questions raised
- A brief, balanced editorial perspective on the collection's significance

Articles:
{articles}

Digest:''',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'summaryPrompt': summaryPrompt,
    'articleSummaryPrompt': articleSummaryPrompt,
    'batchSummaryPrompt': batchSummaryPrompt,
  };

  factory AIProvider.fromJson(Map<String, dynamic> json) {
    return AIProvider(
      id: json['id'],
      name: json['name'],
      type: json['type'] ?? 'ollama',
      baseUrl: json['baseUrl'],
      apiKey: json['apiKey'] ?? '',
      model: json['model'],
      summaryPrompt: json['summaryPrompt'] ?? '',
      articleSummaryPrompt: json['articleSummaryPrompt'] ?? '',
      batchSummaryPrompt: json['batchSummaryPrompt'] ?? '',
    );
  }
}
