import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/article.dart';
import 'ai_summary_screen.dart';

class BatchDialog extends StatefulWidget {
  final List<Article> articles;

  const BatchDialog({super.key, required this.articles});

  @override
  State<BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<BatchDialog> {
  bool _isRunning = false;
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startBatch() async {
    setState(() {
      _isRunning = true;
      _error = null;
    });

    final appState = context.read<AppState>();
    final batchSize = appState.aiBatchSize;
    final toSummarize = widget.articles.where((a) => !a.isRead).take(batchSize).toList();

    if (toSummarize.isEmpty) {
      setState(() {
        _isRunning = false;
        _error = 'No unread articles to summarize';
      });
      return;
    }

    try {
      final result = await appState.summarizeMultipleArticles(toSummarize);
      if (mounted) {
        setState(() {
          _isRunning = false;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final batchSize = appState.aiBatchSize;
    final toSummarize = widget.articles.where((a) => !a.isRead).take(batchSize).toList();
    final totalUnread = widget.articles.where((a) => !a.isRead).length;

    // If we have a result, show it directly in the dialog with a View Full button
    if (_result != null && _result!.isNotEmpty) {
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('AI Digest Ready'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              _result!,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiSummaryScreen(
                    articles: toSummarize,
                    summaryMarkdown: _result!,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.fullscreen),
            label: const Text('Open Full View'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('AI Summarize Articles'),
      content: SizedBox(
        width: 400,
        child: _isRunning
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Analyzing ${toSummarize.length} articles...'),
                  const SizedBox(height: 8),
                  Text(
                    'This may take a moment',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summarize up to $batchSize articles from your unread list.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have $totalUnread unread articles. ${toSummarize.length} will be summarized.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        if (!_isRunning)
          ElevatedButton.icon(
            onPressed: _startBatch,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('GENERATE DIGEST'),
          ),
      ],
    );
  }
}
