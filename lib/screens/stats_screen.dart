import 'dart:async';
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
          return const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No stats available yet', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 8),
              Text('Sync feeds to load statistics', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ));
        }

        // Sort by total volume (busiest first)
        final sorted = List<FeedStats>.from(stats)..sort((a, b) => b.last30Days.compareTo(a.last30Days));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Feed Statistics'),
            actions: [
              TextButton.icon(
                onPressed: () => appState.setView(ViewMode.unread),
                icon: const Icon(Icons.close),
                label: const Text('Close Stats'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) => _FeedStatsCard(stats: sorted[index]),
          ),
        );
      },
    );
  }
}

class _FeedStatsCard extends StatelessWidget {
  final FeedStats stats;
  const _FeedStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxDaily = stats.dailyDistribution.isEmpty ? 1 : stats.dailyDistribution.reduce((a, b) => a > b ? a : b);
    final maxHourly = stats.hourlyDistribution.isEmpty ? 1 : stats.hourlyDistribution.reduce((a, b) => a > b ? a : b);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + folder + unread badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.feedTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stats.folderName != null)
                        Text(
                          stats.folderName!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                if (stats.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${stats.unreadCount} unread',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Time-window counts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CountBadge(label: '1h', count: stats.lastHour, color: Colors.red),
                _CountBadge(label: '24h', count: stats.lastDay, color: Colors.orange),
                _CountBadge(label: '7d', count: stats.last7Days, color: Colors.blue),
                _CountBadge(label: '30d', count: stats.last30Days, color: Colors.green),
                _CountBadge(label: 'Total', count: stats.totalArticles, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),

            // Frequency text
            Text(
              '${stats.frequency.toStringAsFixed(1)} articles/day · ${stats.frequency > 5 ? "Very busy" : stats.frequency > 1 ? "Busy" : stats.frequency > 0.3 ? "Regular" : "Quiet"}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // Mini sparkline: last 7 days
            if (stats.dailyDistribution.isNotEmpty) ...[
              Text('Last 7 days', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              _MiniBarChart(data: stats.dailyDistribution, maxValue: maxDaily, barColor: Colors.blue),
              const SizedBox(height: 12),
            ],

            // Mini sparkline: hourly pattern (last 24h)
            if (stats.hourlyDistribution.isNotEmpty) ...[
              Text('Hourly pattern (24h)', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              _MiniBarChart(data: stats.hourlyDistribution, maxValue: maxHourly, barColor: Colors.teal, barWidth: 3),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<int> data;
  final int maxValue;
  final Color barColor;
  final double barWidth;
  final double height;

  const _MiniBarChart({
    required this.data,
    required this.maxValue,
    required this.barColor,
    this.barWidth = 6,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((value) {
          final h = maxValue <= 0 ? 0.0 : (value / maxValue) * height;
          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Tooltip(
              message: '$value',
              child: Container(
                width: barWidth,
                height: h,
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.7 + (value / maxValue.clamp(1, 99999)) * 0.3),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(2), topRight: Radius.circular(2)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
