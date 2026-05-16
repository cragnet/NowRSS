class FeedStats {
  final String feedId;
  final String feedTitle;
  final String? folderName;

  // Total articles ever seen
  final int totalArticles;

  // Articles in sliding windows
  final int lastHour;
  final int lastDay;
  final int last7Days;
  final int last30Days;

  // How many articles behind the user is (Feedbin unread count)
  final int unreadCount;

  // Average articles per day over last 30 days
  final double frequency;

  // Hourly distribution for mini sparkline (24 buckets: 0-23)
  final List<int> hourlyDistribution;

  // Daily distribution for last 7 days (7 buckets)
  final List<int> dailyDistribution;

  FeedStats({
    required this.feedId,
    required this.feedTitle,
    this.folderName,
    required this.totalArticles,
    required this.lastHour,
    required this.lastDay,
    required this.last7Days,
    required this.last30Days,
    required this.unreadCount,
    required this.frequency,
    required this.hourlyDistribution,
    required this.dailyDistribution,
  });
}
