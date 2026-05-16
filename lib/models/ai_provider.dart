class AIProvider {
  final String id;
  final String name;
  final String type; // 'ollama' or 'openai'
  final String baseUrl;
  final String apiKey;
  final String model;
  final String summaryPrompt;

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
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'summaryPrompt': summaryPrompt,
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
    );
  }
}
