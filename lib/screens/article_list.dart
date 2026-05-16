import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/article.dart';
import 'package:intl/intl.dart';

class ArticleList extends StatelessWidget {
  final Function(Article) onArticleSelected;

  const ArticleList({
    super.key,
    required this.onArticleSelected,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final articles = appState.articles;
        
        if (articles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No articles yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final article = articles[index];
            return _ArticleCard(
              article: article,
              formatDate: _formatDate,
              onTap: () => onArticleSelected(article),
            );
          },
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  final Function() onTap;
  final String Function(DateTime?) formatDate;

  const _ArticleCard({
    required this.article,
    required this.onTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source and timestamp row
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.rss_feed, size: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Feed ${article.feedId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!article.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    formatDate(article.publishedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Title
              Text(
                article.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: article.isRead ? FontWeight.normal : FontWeight.bold,
                  color: article.isRead ? Colors.grey[700] : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Excerpt
              if (article.contentText != null)
                Text(
                  article.contentText!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
