import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/article.dart';
import '../models/feed.dart';
import 'batch_dialog.dart';
import 'package:intl/intl.dart';

class ArticleList extends StatelessWidget {
  final Function(Article) onArticleSelected;
  final VoidCallback onMarkAllRead;

  const ArticleList({
    super.key,
    required this.onArticleSelected,
    required this.onMarkAllRead,
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
        final sortOrder = appState.sortOrder;

        return Column(
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${articles.length} articles',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  // Sort order button
                  _buildSortButton(context, appState, sortOrder),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome),
                    tooltip: 'AI Summarize Unread Articles',
                    onPressed: () {
                      final unread = appState.articles.where((a) => !a.isRead).toList();
                      if (unread.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No unread articles to summarize')),
                        );
                        return;
                      }
                      showDialog(
                        context: context,
                        builder: (_) => BatchDialog(articles: unread),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.done_all, size: 20),
                    tooltip: 'Mark all as read',
                    onPressed: articles.isNotEmpty ? onMarkAllRead : null,
                  ),
                ],
              ),
            ),

            // Article list
            Expanded(
              child: articles.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: articles.length,
                      itemBuilder: (context, index) {
                        final article = articles[index];
                        return _ArticleCard(
                          article: article,
                          index: index,
                          formatDate: _formatDate,
                          onTap: () => onArticleSelected(article),
                          onMarkRead: () => appState.markArticleRead(article.id, !article.isRead),
                          onStar: () => appState.toggleStar(article.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSortButton(BuildContext context, AppState appState, SortOrder current) {
    final icon = switch (current) {
      SortOrder.newest => Icons.arrow_downward,
      SortOrder.oldest => Icons.arrow_upward,
      SortOrder.hottest => Icons.local_fire_department,
    };
    final label = switch (current) {
      SortOrder.newest => 'Newest',
      SortOrder.oldest => 'Oldest',
      SortOrder.hottest => 'Hottest',
    };

    return MenuAnchor(
      builder: (context, controller, child) {
        return InkWell(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_downward, size: 16),
          child: const Text('Newest first'),
          onPressed: () => appState.setSortOrder(SortOrder.newest),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_upward, size: 16),
          child: const Text('Oldest first'),
          onPressed: () => appState.setSortOrder(SortOrder.oldest),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.local_fire_department, size: 16),
          child: const Text('Hottest first'),
          onPressed: () => appState.setSortOrder(SortOrder.hottest),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
          SizedBox(height: 8),
          Text(
            'Configure Feedbin in Settings to sync',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatefulWidget {
  final Article article;
  final int index;
  final Function() onTap;
  final Function() onMarkRead;
  final Function() onStar;
  final String Function(DateTime?) formatDate;

  const _ArticleCard({
    required this.article,
    required this.index,
    required this.onTap,
    required this.onMarkRead,
    required this.onStar,
    required this.formatDate,
  });

  @override
  State<_ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<_ArticleCard> {
  final _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MenuAnchor(
          controller: _menuController,
          menuChildren: [
            MenuItemButton(
              leadingIcon: Icon(widget.article.isRead ? Icons.mark_email_unread : Icons.mark_email_read),
              child: Text(widget.article.isRead ? 'Mark as Unread' : 'Mark as Read'),
              onPressed: () {
                _menuController.close();
                widget.onMarkRead();
              },
            ),
            const Divider(height: 1),
            MenuItemButton(
              leadingIcon: const Icon(Icons.done_all),
              child: const Text('Mark this and all above as Read'),
              onPressed: () {
                _menuController.close();
                _markAbove(appState, widget.index, true);
              },
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.mark_email_unread),
              child: const Text('Mark this and all above as Unread'),
              onPressed: () {
                _menuController.close();
                _markAbove(appState, widget.index, false);
              },
            ),
            const Divider(height: 1),
            MenuItemButton(
              leadingIcon: Icon(widget.article.isStarred ? Icons.star_border : Icons.star, color: widget.article.isStarred ? null : Colors.amber),
              child: Text(widget.article.isStarred ? 'Unstar' : 'Star'),
              onPressed: () {
                _menuController.close();
                widget.onStar();
              },
            ),
          ],
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: InkWell(
              onTap: widget.onTap,
              onSecondaryTap: () {
                _menuController.open();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildFavicon(appState, widget.article.feedId, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.article.feedTitle ?? 'Unknown Feed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!widget.article.isRead)
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
                          widget.formatDate(widget.article.publishedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.article.isStarred)
                          const Padding(
                            padding: EdgeInsets.only(right: 6, top: 2),
                            child: Icon(Icons.star, color: Colors.amber, size: 16),
                          ),
                        Expanded(
                          child: Text(
                            widget.article.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: widget.article.isRead ? FontWeight.normal : FontWeight.bold,
                              color: widget.article.isRead ? Colors.grey[700] : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (widget.article.contentText != null)
                      Text(
                        widget.article.contentText!,
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
          ),
        );
      },
    );
  }

  Widget _buildFavicon(AppState appState, String feedId, {double size = 20}) {
    final url = _getFeedFaviconUrl(appState, feedId);
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.rss_feed, size: size * 0.6),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey[300],
          child: Icon(Icons.rss_feed, size: size * 0.6),
        ),
      ),
    );
  }

  String? _getFeedFaviconUrl(AppState appState, String feedId) {
    try {
      final feed = appState.feeds.firstWhere((f) => f.id == feedId);
      return feed.faviconUrl;
    } catch (_) {
      return null;
    }
  }

  String _getFeedTitle(AppState appState, String feedId) {
    try {
      final feed = appState.feeds.firstWhere((f) => f.id == feedId);
      return feed.title;
    } catch (_) {
      return 'Unknown Feed';
    }
  }

  void _markAbove(AppState appState, int currentIndex, bool read) {
    final articles = appState.articles;
    final toMark = articles.sublist(0, currentIndex + 1);
    for (final article in toMark) {
      appState.markArticleRead(article.id, read);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked ${toMark.length} articles as ${read ? "read" : "unread"}')),
    );
  }
}
