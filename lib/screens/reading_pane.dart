import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article.dart';
import '../services/app_state.dart';

class ReadingPane extends StatefulWidget {
  final Article? article;

  const ReadingPane({
    super.key,
    this.article,
  });

  @override
  State<ReadingPane> createState() => _ReadingPaneState();
}

class _ReadingPaneState extends State<ReadingPane> {
  int _viewMode = 1; // 0=text, 1=text+images, 2=original
  String? _summary;
  String? _translation;
  bool _isLoading = false;

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
                  setState(() {
                    _viewMode = selected.first;
                  });
                },
              ),
              
              const Spacer(),
              
              // AI actions
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'AI Summarize',
                onPressed: () => _summarizeArticle(context, article),
              ),
              IconButton(
                icon: const Icon(Icons.translate),
                tooltip: 'Translate',
                onPressed: () => _translateArticle(context, article),
              ),
              
              const SizedBox(width: 8),
              
              // Article actions
              IconButton(
                icon: Icon(article.isStarred ? Icons.star : Icons.star_border),
                tooltip: article.isStarred ? 'Unstar' : 'Star',
                onPressed: () {
                  // TODO: Toggle star
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: () => _shareArticle(article),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser),
                tooltip: 'Open in browser',
                onPressed: () => _openInBrowser(article.url),
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
                      color: const Color(0xFFF5F0E8), // Beige/cream
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
                                // TODO: Copy to clipboard
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
                if (_viewMode == 0 || _viewMode == 1)
                  _buildContentView(article, _viewMode == 1)
                else
                  _buildWebView(article.url),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentView(Article article, bool showImages) {
    if (article.contentHtml == null && article.contentText == null) {
      return const Text('No content available');
    }

    if (article.contentHtml != null && showImages) {
      return Html(data: article.contentHtml!);
    }

    return Text(
      article.contentText ?? article.contentHtml ?? '',
      style: const TextStyle(fontSize: 16, height: 1.6),
    );
  }

  Widget _buildWebView(String? url) {
    if (url == null) {
      return const Center(child: Text('No URL available'));
    }
    
    // Note: webview_flutter doesn't support Linux directly
    // We'll use url_launcher for now
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.web, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Original article: $url'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openInBrowser(url),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Browser'),
          ),
        ],
      ),
    );
  }

  Future<void> _summarizeArticle(BuildContext context, Article article) async {
    setState(() {
      _isLoading = true;
      _summary = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);
    final result = await appState.summarizeArticle(article);

    if (mounted) {
      setState(() {
        _summary = result ?? 'Failed to generate summary';
        _isLoading = false;
      });
    }
  }

  Future<void> _translateArticle(BuildContext context, Article article) async {
    setState(() {
      _isLoading = true;
      _translation = null;
    });

    final appState = Provider.of<AppState>(context, listen: false);
    final result = await appState.translateArticle(article, 'English');

    if (mounted) {
      setState(() {
        _translation = result ?? 'Failed to translate';
        _isLoading = false;
      });
    }
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
