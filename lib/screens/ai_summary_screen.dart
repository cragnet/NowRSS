import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/app_state.dart';
import 'reading_pane.dart';

class AiSummaryScreen extends StatefulWidget {
  final List<Article> articles;
  final String summaryMarkdown;
  final VoidCallback? onMarkAllRead;

  const AiSummaryScreen({
    super.key,
    required this.articles,
    required this.summaryMarkdown,
    this.onMarkAllRead,
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

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        title: const Text('AI Digest'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.onMarkAllRead != null)
            TextButton.icon(
              onPressed: () {
                widget.onMarkAllRead!();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marked all digest articles as read')),
                );
              },
              icon: const Icon(Icons.done_all, size: 20),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: TextStyle(color: colorScheme.onSurface),
          child: Html(
            data: _markdownToHtml(widget.summaryMarkdown, widget.articles),
            style: _htmlStyle(context, zoom),
            onLinkTap: (url, _, __) {
              if (url == null) return;
              if (url.startsWith('nowrss://article/')) {
                final index = int.tryParse(url.replaceFirst('nowrss://article/', ''));
                if (index != null && index >= 1 && index <= widget.articles.length) {
                  setState(() => _selectedArticle = widget.articles[index - 1]);
                }
              } else if (url.startsWith('http://') || url.startsWith('https://')) {
                // External URLs — handled by flutter_html / let user decide
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildArticleReader(BuildContext context, Article article, double zoom, AppState appState) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerHighest,
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
      body: ReadingPane(article: article),
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
          return '<a href="nowrss://article/$num">[$num]</a>';
        }
        return '[$num]';
      },
    );

    // Convert URLs to clickable links
    html = html.replaceAllMapped(
      RegExp(r'(https?://[^\s\]\)]+)'),
      (m) => '<a href="${m[1]}">${m[1]}</a>',
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

  Map<String, Style> _htmlStyle(BuildContext context, double zoom, {double baseSize = 16}) {
    final s = baseSize * zoom;
    final colorScheme = Theme.of(context).colorScheme;
    final linkColor = colorScheme.brightness == Brightness.dark
        ? colorScheme.primary
        : const Color(0xFF1976D2);
    return {
      "body": Style(
          fontSize: FontSize(s),
          lineHeight: LineHeight(1.6),
          margin: Margins.zero,
          color: colorScheme.onSurface),
      "p": Style(
          margin: Margins.only(bottom: 12),
          lineHeight: LineHeight(1.6),
          color: colorScheme.onSurface),
      "div": Style(
          margin: Margins.only(bottom: 8),
          color: colorScheme.onSurface),
      "h3": Style(
          fontSize: FontSize(s * 1.3),
          fontWeight: FontWeight.bold,
          margin: Margins.only(top: 16, bottom: 8),
          color: colorScheme.onSurface),
      "ul": Style(
          margin: Margins.only(bottom: 12, left: 16),
          color: colorScheme.onSurface),
      "li": Style(
          margin: Margins.only(bottom: 4),
          lineHeight: LineHeight(1.5),
          color: colorScheme.onSurface),
      "a": Style(
          color: linkColor,
          textDecoration: TextDecoration.none),
      "strong": Style(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface),
      "em": Style(
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurface),
    };
  }
}
