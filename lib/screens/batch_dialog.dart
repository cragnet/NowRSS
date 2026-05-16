import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/article.dart';

class BatchDialog extends StatefulWidget {
  final List<Article> articles;

  const BatchDialog({super.key, required this.articles});

  @override
  State<BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<BatchDialog> {
  int _current = 0;
  final List<String> _summaries = [];
  String? _currentSummary;
  bool _isRunning = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startBatch();
  }

  Future<void> _startBatch() async {
    setState(() => _isRunning = true);
    final appState = context.read<AppState>();
    final unread = widget.articles.where((a) => !a.isRead).toList();

    for (int i = 0; i < unread.length; i++) {
      if (!mounted) return;
      setState(() => _current = i + 1);
      
      final summary = await appState.summarizeArticle(unread[i]);
      if (summary != null) {
        _summaries.add('**${unread[i].title}**\n$summary');
      }
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
        _isComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.articles.where((a) => !a.isRead).length;
    
    return AlertDialog(
      title: const Text('Summarize All Unread'),
      content: SizedBox(
        width: 600,
        child: _isComplete
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Summarized $_current of $unreadCount articles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ..._summaries.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0E8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s),
                      ),
                    )),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Processing $_current of $unreadCount unread articles...'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: unreadCount > 0 ? _current / unreadCount : null,
                  ),
                  if (_currentSummary != null) ...[
                    const SizedBox(height: 16),
                    Text(_currentSummary!, maxLines: 3),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: _isComplete ? const Text('CLOSE') : const Text('CANCEL'),
        ),
      ],
    );
  }
}
