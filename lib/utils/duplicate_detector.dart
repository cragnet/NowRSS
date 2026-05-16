import 'dart:async';
import 'dart:math' as math;

class DuplicateDetector {
  /// Fuzzy string similarity using Levenshtein distance
  static double similarity(String s1, String s2) {
    if (s1.isEmpty && s2.isEmpty) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final len1 = s1.length;
    final len2 = s2.length;
    final maxLen = math.max(len1, len2);
    
    final distance = _levenshtein(s1.toLowerCase(), s2.toLowerCase());
    return 1.0 - (distance / maxLen);
  }

  static int _levenshtein(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;
    
    final List<List<int>> dp = List.generate(
      m + 1,
      (i) => List.filled(n + 1, 0),
    );
    
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;
    
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (s1[i - 1] == s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + math.min(
            dp[i - 1][j],
            math.min(dp[i][j - 1], dp[i - 1][j - 1]),
          );
        }
      }
    }
    
    return dp[m][n];
  }

  /// Find duplicate article groups within the same feed
  static Map<String, String> findDuplicates(
    List<Map<String, dynamic>> articles, {
    double threshold = 0.85,
  }) {
    final duplicates = <String, String>{};
    final seen = <Map<String, dynamic>>[];
    
    for (final article in articles) {
      final id = article['id'] as String;
      final title = article['title'] as String? ?? '';
      final feedId = article['feed_id'] as String?;
      
      // Only compare within same feed
      var found = false;
      for (final seenArticle in seen.where((a) => a['feed_id'] == feedId)) {
        final seenTitle = seenArticle['title'] as String? ?? '';
        final sim = similarity(title, seenTitle);
        
        if (sim >= threshold) {
          duplicates[id] = seenArticle['id'] as String;
          found = true;
          break;
        }
      }
      
      if (!found) {
        seen.add(article);
      }
    }
    
    return duplicates;
  }
}
