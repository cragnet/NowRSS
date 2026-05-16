class Feed {
  final String id;
  final String title;
  final String? url;
  final String? siteUrl;
  String? folderName;
  final String? faviconUrl;
  int unreadCount;
  int readCount;
  int starredCount;
  DateTime? lastUpdatedAt;
  String? updateFrequency;
  bool isExpanded;

  Feed({
    required this.id,
    required this.title,
    this.url,
    this.siteUrl,
    this.folderName,
    this.faviconUrl,
    this.unreadCount = 0,
    this.readCount = 0,
    this.starredCount = 0,
    this.lastUpdatedAt,
    this.updateFrequency,
    this.isExpanded = true,
  });

  factory Feed.fromJson(Map<String, dynamic> json) {
    return Feed(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled Feed',
      url: json['feed_url'],
      siteUrl: json['site_url'],
      faviconUrl: json['icon_url'],
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_updated_at'])
          : null,
      updateFrequency: json['update_frequency'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'feed_url': url,
      'site_url': siteUrl,
      'folder_name': folderName,
      'icon_url': faviconUrl,
      'unread_count': unreadCount,
      'read_count': readCount,
      'starred_count': starredCount,
      'last_updated_at': lastUpdatedAt?.millisecondsSinceEpoch,
      'update_frequency': updateFrequency,
    };
  }
}
