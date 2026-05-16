class Feed {
  final String id;
  final String title;
  final String? url;
  final String? siteUrl;
  final String? folderName;
  final String? faviconUrl;
  int unreadCount;
  bool isExpanded;

  Feed({
    required this.id,
    required this.title,
    this.url,
    this.siteUrl,
    this.folderName,
    this.faviconUrl,
    this.unreadCount = 0,
    this.isExpanded = true,
  });

  factory Feed.fromJson(Map<String, dynamic> json) {
    return Feed(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled Feed',
      url: json['feed_url'],
      siteUrl: json['site_url'],
      faviconUrl: json['icon_url'],
    );
  }
}
