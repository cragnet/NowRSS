import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/app_state.dart';

class AiSummaryScreen extends StatefulWidget {
  final List<Article> articles;
  final String summaryMarkdown;

  const AiSummaryScreen({
    super.key,
    required this.articles,
    required this.summaryMarkdown,
  });

  @override
  State<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

class _AiSummaryScreenState extends State<AiSummaryScreen> {
  Article? _selectedArticle;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final zoom = appState.textZoom;

    if (_selectedArticle != null) {
      return _buildArticleReader(context, _selectedArticle!, zoom, appState);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Digest'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Html(
          data: _markdownToHtml(widget.summaryMarkdown, widget.articles),
          style: _htmlStyle(zoom),
          onLinkTap: (url, _, __) {
            if (url != null && url.startsWith('nowrss://article/')) {
              final index = int.tryParse(url.replaceFirst('nowrss://article/', ''));
              if (index != null && index >= 1 && index <= widget.articles.length) {
                setState(() => _selectedArticle = widget.articles[index - 1]);
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildArticleReader(BuildContext context, Article article, double zoom, AppState appState) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedArticle = null),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () {
              if (article.url != null) {
                // Open URL
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) * zoom,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.author ?? 'Unknown',
              style: TextStyle(color: Colors.grey[600], fontSize: 14 * zoom),
            ),
            const Divider(height: 32),
            SelectableText(
              article.contentText ?? '',
              style: TextStyle(fontSize: 16 * zoom, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  String _markdownToHtml(String markdown, List<Article> articles) {
    var html = markdown;

    // Convert [N] links to clickable nowrss://article/N links
    html = html.replaceAllMapped(
      RegExp(r'\[(\d+)\]'),
      (m) {
        final num = m[1]!;
        final idx = int.tryParse(num);
        if (idx != null && idx >= 1 && idx <= articles.length) {
          return '<a href="nowrss://article/$num" style="color:#1976d2;font-weight:bold;text-decoration:none;">[$num]</a>';
        }
        return '[$num]';
      },
    );

    // Convert URLs to clickable links
    html = html.replaceAllMapped(
      RegExp(r'(https?://[^\s\]\)]+)'),
      (m) => '<a href="${m[1]}" style="color:#1976d2;">${m[1]}</a>',
    );

    // Markdown to HTML
    html = html
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>')
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => '<em>${m[1]}</em>')
      .replaceAllMapped(RegExp(r'^#{1,6}\s+(.+)', multiLine: true), (m) => '<h3 style="margin-top:16px;margin-bottom:8px;">${m[1]}</h3>')
      .replaceAllMapped(RegExp(r'^\s*-\s+(.+)', multiLine: true), (m) => '<li>${m[1]}</li>')
      .replaceAllMapped(RegExp(r'^\s*\d+\.\s+(.+)', multiLine: true), (m) => '<li>${m[1]}</li>');

    // Wrap li in ul
    if (html.contains('<li>')) {
      html = html.replaceAllMapped(
        RegExp(r'(<li>.+?</li>\s*)+', dotAll: true),
        (m) => '<ul style="margin-bottom:12px;">${m[0]}</ul>',
      );
    }

    // Paragraphs
    final paragraphs = html.split('\n\n');
    html = paragraphs.map((p) {
      if (p.trim().startsWith('<h') || p.trim().startsWith('<ul') || p.trim().startsWith('<li')) return p;
      return '<p style="margin-bottom:12px;line-height:1.6;">$p</p>';
    }).join('\n');

    return '<div style="font-family:sans-serif;">$html</div>';
  }

  Map<String, Style> _htmlStyle(double zoom, {double baseSize = 16}) {
    final s = baseSize * zoom;
    return {
      "body": Style(fontSize: FontSize(s), lineHeight: LineHeight(1.6), margin: Margins.zero),
      "p": Style(margin: Margins.only(bottom: 12), lineHeight: LineHeight(1.6)),
      "div": Style(margin: Margins.only(bottom: 8)),
      "h3": Style(fontSize: FontSize(s * 1.3), fontWeight: FontWeight.bold, margin: Margins.only(top: 16, bottom: 8)),
      "ul": Style(margin: Margins.only(bottom: 12, left: 16)),
      "li": Style(margin: Margins.only(bottom: 4), lineHeight: LineHeight(1.5)),
      "a": Style(color: const Color(0xFF1976D2), textDecoration: TextDecoration.none),
      "strong": Style(fontWeight: FontWeight.bold),
      "em": Style(fontStyle: FontStyle.italic),
    };
  }
}
