import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/feed_stats.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final stats = appState.feedStats;
        if (stats.isEmpty) {
          return _buildEmpty(context, appState);
        }

        // Sort by 7-day volume (busiest first)
        final sorted = List<FeedStats>.from(stats)
          ..sort((a, b) => b.last7Days.compareTo(a.last7Days));

        return Scaffold(
          body: Column(
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    Text('Feed Statistics', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${sorted.length} feeds', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => appState.setView(ViewMode.unread),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                  ],
                ),
              ),
              // Scrollable table
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowHeight: 40,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 40,
                      horizontalMargin: 12,
                      columnSpacing: 16,
                      dividerThickness: 0.5,
                      sortColumnIndex: 4,
                      sortAscending: false,
                      columns: const [
                        DataColumn(label: Text('Feed')),
                        DataColumn(label: Text('Folder'), numeric: false),
                        DataColumn(label: Text('1h'), numeric: true),
                        DataColumn(label: Text('24h'), numeric: true),
                        DataColumn(label: Text('7d'), numeric: true),
                        DataColumn(label: Text('30d'), numeric: true),
                        DataColumn(label: Text('Total'), numeric: true),
                        DataColumn(label: Text('Freq/day'), numeric: true),
                        DataColumn(label: Text('Unread'), numeric: true),
                        DataColumn(label: Text('7d Sparkline'), numeric: false),
                      ],
                      rows: sorted.map((s) => DataRow(
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                s.feedTitle,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(
                                s.folderName ?? '-',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(Text('${s.lastHour}', style: TextStyle(color: s.lastHour > 0 ? Colors.red : Colors.grey))),
                          DataCell(Text('${s.lastDay}', style: TextStyle(color: s.lastDay > 0 ? Colors.orange : Colors.grey))),
                          DataCell(Text('${s.last7Days}', style: TextStyle(color: s.last7Days > 0 ? Colors.blue : Colors.grey, fontWeight: FontWeight.bold))),
                          DataCell(Text('${s.last30Days}')),
                          DataCell(Text('${s.totalArticles}')),
                          DataCell(Text(s.frequency.toStringAsFixed(1))),
                          DataCell(
                            s.unreadCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                                  child: Text('${s.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                )
                              : const Text('0', style: TextStyle(color: Colors.grey)),
                          ),
                          DataCell(_Sparkline(data: s.dailyDistribution, width: 60, height: 20)),
                        ],
                      )).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context, AppState appState) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No statistics available', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Sync feeds to generate statistics', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => appState.syncFeeds(),
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => appState.setView(ViewMode.unread),
              child: const Text('Back to Reader'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List<int> data;
  final double width;
  final double height;
  const _Sparkline({required this.data, this.width = 80, this.height = 24});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.reduce((a, b) => max(a, b));
    if (maxVal <= 0) return const SizedBox.shrink();

    return SizedBox(
      width: width,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((v) {
          final h = (v / maxVal) * height;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              height: h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5 + (v / maxVal.clamp(1, 99999)) * 0.5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
