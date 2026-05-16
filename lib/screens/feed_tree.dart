import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/feed.dart';
import 'settings_screen.dart';

class FeedTree extends StatelessWidget {
  final Function(String?) onFeedSelected;
  final Function(ViewMode) onViewChanged;
  final Function(String, List<String>)? onFolderSelected;

  const FeedTree({
    super.key,
    required this.onFeedSelected,
    required this.onViewChanged,
    this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Group feeds by folder/tag
        final Map<String, List<Feed>> feedsByFolder = {};
        for (final feed in appState.feeds) {
          final folder = feed.folderName ?? 'Uncategorized';
          feedsByFolder.putIfAbsent(folder, () => []).add(feed);
        }
        // Sort folder names
        final sortedFolders = feedsByFolder.keys.toList()..sort();

        return Column(
          children: [
            // Header with action buttons
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'NowRSS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: () => appState.syncFeeds(),
                    tooltip: 'Sync feeds',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Quick filters with real counts
            _QuickFilterTile(
              icon: Icons.star,
              label: 'All Starred',
              count: appState.starredCount,
              onTap: () => onViewChanged(ViewMode.favorites),
              color: Colors.amber,
            ),
            _QuickFilterTile(
              icon: Icons.circle,
              label: 'All Unread',
              count: appState.unreadCount,
              onTap: () => onViewChanged(ViewMode.unread),
              color: Colors.blue,
            ),
            _QuickFilterTile(
              icon: Icons.check_circle,
              label: 'All Read',
              count: appState.readCount,
              onTap: () => onViewChanged(ViewMode.read),
              color: Colors.grey,
            ),
            _QuickFilterTile(
              icon: Icons.bar_chart,
              label: 'Statistics',
              count: appState.feedStats.length,
              onTap: () => onViewChanged(ViewMode.stats),
              color: Colors.purple,
            ),
            
            const Divider(height: 1),
            
            // Feed tree grouped by folder
            Expanded(
              child: ListView.builder(
                itemCount: sortedFolders.length,
                itemBuilder: (context, folderIndex) {
                  final folderName = sortedFolders[folderIndex];
                  final feeds = feedsByFolder[folderName]!;
                  final feedIds = feeds.map((f) => f.id).toList();
                  final isSelected = appState.selectedFolderName == folderName;
                  
                  // Calculate folder totals
                  int folderUnread = 0, folderRead = 0, folderStarred = 0;
                  for (final feed in feeds) {
                    folderUnread += feed.unreadCount;
                    folderRead += feed.readCount;
                    folderStarred += feed.starredCount;
                  }

                  // Build counts from articles for each feed
                  for (final feed in feeds) {
                    int read = 0, starred = 0;
                    for (final a in appState.articles) {
                      if (a.feedId == feed.id) {
                        if (a.isRead) read++;
                        if (a.isStarred) starred++;
                      }
                    }
                    feed.readCount = read;
                    feed.starredCount = starred;
                  }

                  return _FolderTile(
                    folderName: folderName,
                    feeds: feeds,
                    feedIds: feedIds,
                    unread: folderUnread,
                    read: folderRead,
                    starred: folderStarred,
                    isSelected: isSelected,
                    isExpanded: feeds.any((f) => f.isExpanded),
                    onFolderTap: () {
                      if (onFolderSelected != null) {
                        onFolderSelected!(folderName, feedIds);
                      }
                    },
                    onFeedTap: (feedId) => onFeedSelected(feedId),
                    onToggleExpand: () {
                      for (final f in feeds) {
                        f.isExpanded = !f.isExpanded;
                      }
                      // Force rebuild
                      (context as Element).markNeedsBuild();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day}/${date.month}/${date.year}';
}

class _FolderTile extends StatelessWidget {
  final String folderName;
  final List<Feed> feeds;
  final List<String> feedIds;
  final int unread;
  final int read;
  final int starred;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onFolderTap;
  final Function(String) onFeedTap;
  final VoidCallback onToggleExpand;

  const _FolderTile({
    required this.folderName,
    required this.feeds,
    required this.feedIds,
    required this.unread,
    required this.read,
    required this.starred,
    required this.isSelected,
    required this.isExpanded,
    required this.onFolderTap,
    required this.onFeedTap,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isSelected
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(40),
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
              ),
            )
          : null,
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: (_) => onToggleExpand(),
        leading: GestureDetector(
          onTap: onFolderTap,
          child: Icon(
            isExpanded ? Icons.folder_open : Icons.folder,
            size: 20,
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.blueGrey,
          ),
        ),
        title: GestureDetector(
          onTap: onFolderTap,
          child: Text(
            folderName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FeedCountChip(
              count: read,
              color: Colors.grey[600]!,
              icon: Icons.check,
              tooltip: 'Read',
            ),
            const SizedBox(width: 4),
            _FeedCountChip(
              count: starred,
              color: Colors.amber,
              icon: Icons.star,
              tooltip: 'Favorites',
            ),
            const SizedBox(width: 4),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unread',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        children: feeds.map((feed) => _buildFeedTile(context, feed)).toList(),
      ),
    );
  }

  Widget _buildFeedTile(BuildContext context, Feed feed) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      leading: _buildFavicon(feed.faviconUrl, size: 18),
      title: Text(
        feed.title,
        style: const TextStyle(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feed.lastUpdatedAt != null)
            Text(
              'Updated ${_formatDate(feed.lastUpdatedAt!)} \u00b7 ${feed.updateFrequency ?? 'Unknown'}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FeedCountChip(
            count: feed.readCount,
            color: Colors.grey[600]!,
            icon: Icons.check,
            tooltip: 'Read',
          ),
          const SizedBox(width: 4),
          _FeedCountChip(
            count: feed.starredCount,
            color: Colors.amber,
            icon: Icons.star,
            tooltip: 'Favorites',
          ),
          const SizedBox(width: 4),
          if (feed.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${feed.unreadCount}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      dense: true,
      onTap: () => onFeedTap(feed.id),
    );
  }

  Widget _buildFavicon(String? url, {double size = 18}) {
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.rss_feed, size: size * 0.6, color: Colors.blueGrey),
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
          child: Icon(Icons.rss_feed, size: size * 0.6, color: Colors.blueGrey),
        ),
      ),
    );
  }
}

class _FeedCountChip extends StatelessWidget {
  final int count;
  final Color color;
  final IconData icon;
  final String tooltip;

  const _FeedCountChip({
    required this.count,
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Tooltip(
      message: '$tooltip: $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final Color color;

  const _QuickFilterTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        '$count',
        style: TextStyle(
          color: count > 0 ? color : Colors.grey,
          fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}
