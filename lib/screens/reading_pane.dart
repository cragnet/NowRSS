import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article.dart';
import '../services/app_state.dart';

class ReadingPane extends StatefulWidget {
  final Article? article;

  const ReadingPane({super.key, this.article});

  @override
  State<ReadingPane> createState() => _ReadingPaneState();
}

class _ReadingPaneState extends State<ReadingPane> {
  int _viewMode = 1;
  String? _summary;
  String? _translation;

  @override
  void didUpdateWidget(ReadingPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.article?.id != oldWidget.article?.id) {
      _summary = null;
      _translation = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    if (article == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select an article to read',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyM): () => appState.markArticleRead(article.id, !article.isRead),
            const SingleActivator(LogicalKeyboardKey.keyS): () => appState.toggleStar(article.id),
            const SingleActivator(LogicalKeyboardKey.keyO): () => _openInBrowser(article.url),
          },
          child: Focus(
            autofocus: true,
            child: Column(
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
                      // View mode toggle
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            label: Text('Text'),
                            icon: Icon(Icons.text_fields, size: 16),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text('Text+Img'),
                            icon: Icon(Icons.image, size: 16),
                          ),
                          ButtonSegment(
                            value: 2,
                            label: Text('Original'),
                            icon: Icon(Icons.web, size: 16),
                          ),
                        ],
                        selected: {_viewMode},
                        onSelectionChanged: (selected) {
                          setState(() => _viewMode = selected.first);
                        },
                      ),
                      const Spacer(),
                      // AI actions
                      IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        tooltip: 'AI Summarize (Shift+S)',
                        onPressed: () => _summarizeArticle(context, article),
                      ),
                      IconButton(
                        icon: const Icon(Icons.translate),
                        tooltip: 'Translate (Shift+T)',
                        onPressed: () => _showTranslateDialog(context, article),
                      ),
                      const SizedBox(width: 8),
                      // Article actions
                      IconButton(
                        icon: Icon(article.isStarred ? Icons.star : Icons.star_border, color: article.isStarred ? Colors.amber : null),
                        tooltip: article.isStarred ? 'Unstar (S)' : 'Star (S)',
                        onPressed: () => appState.toggleStar(article.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: 'Share',
                        onPressed: () => _shareArticle(article),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_browser),
                        tooltip: 'Open in browser (O)',
                        onPressed: () => _openInBrowser(article.url),
                      ),
                      IconButton(
                        icon: Icon(article.isRead ? Icons.mark_email_unread : Icons.mark_email_read),
                        tooltip: article.isRead ? 'Mark unread (M)' : 'Mark read (M)',
                        onPressed: () => appState.markArticleRead(article.id, !article.isRead),
                      ),
                    ],
                  ),
                ),
                // Article content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          article.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Meta info
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              article.author ?? 'Unknown',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              article.publishedAt != null
                                  ? DateFormat('MMM d, yyyy').format(article.publishedAt!)
                                  : 'Unknown date',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        // AI Summary card
                        if (_summary != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F0E8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE0D5C0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Text(
                                      'AI Summary',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: _summary!));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Summary copied')),
                                        );
                                      },
                                      tooltip: 'Copy summary',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(_summary!),
                              ],
                            ),
                          ),
                        // Translation
                        if (_translation != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFC0D5E0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.translate, size: 16, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Translation',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(_translation!),
                              ],
                            ),
                          ),
                        // Article body
                        _buildContent(article),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(Article article) {
    if (_viewMode == 0 || _viewMode == 1) {
      if (article.contentText == null && article.contentHtml == null) {
        return const Text('No content available');
      }
      if (_viewMode == 1 && article.contentHtml != null) {
        // For Text+Img mode, we could use flutter_html but it can be heavy.
        // For now, strip tags and show text; images handled separately if needed.
        return Text(
          article.contentText ?? article.contentHtml!,
          style: const TextStyle(fontSize: 16, height: 1.6),
        );
      }
      return Text(
        article.contentText ?? article.contentHtml ?? '',
        style: const TextStyle(fontSize: 16, height: 1.6),
      );
    } else {
      if (article.url == null) {
        return const Center(child: Text('No URL available'));
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.web, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(article.url!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openInBrowser(article.url),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in Browser'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _summarizeArticle(BuildContext context, Article article) async {
    setState(() => _summary = null);
    final appState = Provider.of<AppState>(context, listen: false);
    final result = await appState.summarizeArticle(article);
    if (mounted) {
      setState(() => _summary = result ?? 'Failed to generate summary');
    }
  }

  void _showTranslateDialog(BuildContext context, Article article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Translate to'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              'English', 'Spanish', 'French', 'German', 'Chinese', 'Japanese', 'Korean'
            ].map((lang) => ListTile(
              title: Text(lang),
              onTap: () async {
                Navigator.pop(context);
                final appState = Provider.of<AppState>(context, listen: false);
                final result = await appState.translateArticle(article, lang);
                if (mounted) {
                  setState(() => _translation = result ?? 'Translation failed');
                }
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _shareArticle(Article article) {
    if (article.url != null) {
      Share.share(article.url!, subject: article.title);
    }
  }

  Future<void> _openInBrowser(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
