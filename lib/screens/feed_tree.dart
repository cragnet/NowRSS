import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'settings_screen.dart';

class FeedTree extends StatelessWidget {
  final Function(String?) onFeedSelected;
  final Function(ViewMode) onViewChanged;

  const FeedTree({
    super.key,
    required this.onFeedSelected,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
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
            
            // Quick filters
            _QuickFilterTile(
              icon: Icons.star,
              label: 'All Starred',
              count: 0,
              onTap: () => onViewChanged(ViewMode.favorites),
              color: Colors.amber,
            ),
            _QuickFilterTile(
              icon: Icons.circle,
              label: 'All Unread',
              count: 0,
              onTap: () => onViewChanged(ViewMode.unread),
              color: Colors.blue,
            ),
            _QuickFilterTile(
              icon: Icons.check_circle,
              label: 'All Read',
              count: 0,
              onTap: () => onViewChanged(ViewMode.read),
              color: Colors.grey,
            ),
            
            const Divider(height: 1),
            
            // Feed list
            Expanded(
              child: ListView.builder(
                itemCount: appState.feeds.length,
                itemBuilder: (context, index) {
                  final feed = appState.feeds[index];
                  return ListTile(
                    leading: const Icon(Icons.rss_feed, size: 20),
                    title: Text(
                      feed.title,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: feed.unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${feed.unreadCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    dense: true,
                    onTap: () => onFeedSelected(feed.id),
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
      trailing: count > 0
          ? Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            )
          : null,
      dense: true,
      onTap: onTap,
    );
  }
}
