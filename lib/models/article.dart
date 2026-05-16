class Article {
  final String id;
  final String feedId;
  final String title;
  final String? url;
  final String? author;
  final String? contentHtml;
  final String? contentText;
  final String? summary;
  final DateTime? publishedAt;
  final DateTime? fetchedAt;
  final String? imageUrl;
  bool isRead;
  bool isStarred;

  Article({
    required this.id,
    required this.feedId,
    required this.title,
    this.url,
    this.author,
    this.contentHtml,
    this.contentText,
    this.summary,
    this.publishedAt,
    this.fetchedAt,
    this.imageUrl,
    this.isRead = false,
    this.isStarred = false,
  });

  factory Article.fromFeedbinJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'].toString(),
      feedId: json['feed_id']?.toString() ?? '0',
      title: json['title'] ?? 'Untitled',
      url: json['url'],
      author: json['author'],
      contentHtml: json['content'],
      contentText: _extractText(json['content']),
      publishedAt: json['published'] != null 
          ? DateTime.parse(json['published']) 
          : null,
      imageUrl: _extractImage(json['content']),
      isRead: json['read'] ?? false,
      isStarred: json['starred'] ?? false,
    );
  }

  static String? _extractText(String? html) {
    if (html == null) return null;
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
  }

  static String? _extractImage(String? html) {
    if (html == null) return null;
    final match = RegExp(r"""<img[^>]+src=["']([^"']+)["']""").firstMatch(html);
    return match?.group(1);
  }
}
