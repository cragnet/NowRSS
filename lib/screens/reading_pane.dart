import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../models/article.dart';
import '../services/app_state.dart';
import '../services/file_cache_service.dart';

class ReadingPane extends StatefulWidget {
  final Article? article;
  const ReadingPane({super.key, this.article});
  @override
  State<ReadingPane> createState() => _ReadingPaneState();
}

class _ReadingPaneState extends State<ReadingPane> {
  int _viewMode = 0;
  String? _summary;
  String? _translation;
  String? _articleHtml;
  String? _originalHtml;
  bool _loadingArticle = false;
  bool _loadingOriginal = false;
  Timer? _readTimer;
  final _fileCache = FileCacheService();

  @override
  void didUpdateWidget(covariant ReadingPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.article?.id != oldWidget.article?.id) {
      _readTimer?.cancel();
      if (oldWidget.article != null && !oldWidget.article!.isRead) {
        Provider.of<AppState>(context, listen: false).markArticleRead(oldWidget.article!.id, true);
      }
      _summary = null;
      _translation = null;
      _articleHtml = null;
      _originalHtml = null;
      _viewMode = 0;
      _startReadTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    _startReadTimer();
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  void _startReadTimer() {
    if (widget.article != null && !widget.article!.isRead) {
      _readTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && widget.article != null) {
          Provider.of<AppState>(context, listen: false).markArticleRead(widget.article!.id, true);
        }
      });
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
            Text('Select an article to read', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final zoom = appState.textZoom;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyM): () => appState.markArticleRead(article.id, !article.isRead),
            const SingleActivator(LogicalKeyboardKey.keyS): () => appState.toggleStar(article.id),
            const SingleActivator(LogicalKeyboardKey.keyO): () => _openInBrowser(article.url),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildToolbar(context, appState, article),
                    Expanded(child: _buildContent(article, zoom)),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          tooltip: 'Zoom out',
                          onPressed: () => appState.setTextZoom((zoom - 0.1).clamp(0.5, 2.0)),
                        ),
                        Text('${(zoom * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          tooltip: 'Zoom in',
                          onPressed: () => appState.setTextZoom((zoom + 0.1).clamp(0.5, 2.0)),
                        ),
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

  Widget _buildToolbar(BuildContext context, AppState appState, Article article) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Summary'), icon: Icon(Icons.short_text, size: 16)),
              ButtonSegment(value: 1, label: Text('Article'), icon: Icon(Icons.article, size: 16)),
              ButtonSegment(value: 2, label: Text('Original'), icon: Icon(Icons.web, size: 16)),
            ],
            selected: {_viewMode},
            onSelectionChanged: (s) => setState(() => _viewMode = s.first),
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.auto_awesome), tooltip: 'AI Summarize', onPressed: () => _summarizeArticle(context, article)),
          IconButton(icon: const Icon(Icons.translate), tooltip: 'Translate', onPressed: () => _showTranslateDialog(context, article)),
          const SizedBox(width: 8),
          IconButton(icon: Icon(article.isStarred ? Icons.star : Icons.star_border, color: article.isStarred ? Colors.amber : null), tooltip: 'Star', onPressed: () => appState.toggleStar(article.id)),
          IconButton(icon: const Icon(Icons.share), tooltip: 'Share', onPressed: () => _shareArticle(article)),
          IconButton(icon: const Icon(Icons.open_in_browser), tooltip: 'Open in browser', onPressed: () => _openInBrowser(article.url)),
          IconButton(icon: Icon(article.isRead ? Icons.mark_email_unread : Icons.mark_email_read), tooltip: article.isRead ? 'Mark unread' : 'Mark read', onPressed: () => appState.markArticleRead(article.id, !article.isRead)),
        ],
      ),
    );
  }

  Widget _buildContent(Article article, double zoom) {
    switch (_viewMode) {
      case 0: return _buildSummaryView(article, zoom);
      case 1: return _buildArticleView(article, zoom);
      case 2: return _buildOriginalView(article, zoom);
      default: return _buildSummaryView(article, zoom);
    }
  }

  Widget _buildSummaryView(Article article, double zoom) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(article.title, zoom),
          const SizedBox(height: 8),
          _buildMetaRow(article, zoom),
          const Divider(height: 32),
          if (_summary != null || article.summary != null) _buildSummaryCard(article, zoom),
          _buildSummaryText(article, zoom),
        ],
      ),
    );
  }

  Widget _buildArticleView(Article article, double zoom) {
    if (_articleHtml == null && !_loadingArticle) {
      _loadingArticle = true;
      _fetchArticleContent(article);
    }

    if (_loadingArticle) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Fetching full article...')],
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(article.title, zoom),
          const SizedBox(height: 8),
          _buildMetaRow(article, zoom),
          const Divider(height: 32),
          if (_summary != null || article.summary != null) _buildSummaryCard(article, zoom),
          if (_articleHtml != null)
            Html(
              data: _articleHtml!,
              style: _htmlStyle(zoom),
            )
          else
            const Text('Failed to fetch full article'),
        ],
      ),
    );
  }

  Widget _buildOriginalView(Article article, double zoom) {
    if (article.url == null) return const Center(child: Text('No URL available'));

    if (_originalHtml == null && !_loadingOriginal) {
      _loadingOriginal = true;
      _fetchOriginalHtml(article.url!);
    }

    if (_loadingOriginal) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading original page...')],
      ));
    }

    if (_originalHtml == null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Could not load original page'),
          const SizedBox(height: 8),
          Text(article.url!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openInBrowser(article.url),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Browser'),
          ),
        ],
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: _originalHtml!,
        style: _htmlStyle(zoom, baseSize: 14),
      ),
    );
  }

  /// Zoom only affects font sizes — text naturally re-flows within pane width.
  Map<String, Style> _htmlStyle(double zoom, {double baseSize = 16}) {
    final s = baseSize * zoom;
    return {
      "body": Style(fontSize: FontSize(s), lineHeight: LineHeight(1.6), margin: Margins.zero),
      "p": Style(margin: Margins.only(bottom: 12), lineHeight: LineHeight(1.6)),
      "div": Style(margin: Margins.only(bottom: 8)),
      "h1": Style(fontSize: FontSize(s * 1.6), fontWeight: FontWeight.bold, margin: Margins.only(top: 16, bottom: 8)),
      "h2": Style(fontSize: FontSize(s * 1.4), fontWeight: FontWeight.bold, margin: Margins.only(top: 14, bottom: 6)),
      "h3": Style(fontSize: FontSize(s * 1.2), fontWeight: FontWeight.bold, margin: Margins.only(top: 12, bottom: 4)),
      "h4": Style(fontSize: FontSize(s * 1.1), fontWeight: FontWeight.bold, margin: Margins.only(top: 10, bottom: 4)),
      "h5": Style(fontSize: FontSize(s), fontWeight: FontWeight.bold, margin: Margins.only(top: 8, bottom: 2)),
      "h6": Style(fontSize: FontSize(s), fontWeight: FontWeight.bold, margin: Margins.only(top: 8, bottom: 2)),
      "img": Style(width: Width.auto(), height: Height.auto(), margin: Margins.symmetric(vertical: 8)),
      "blockquote": Style(
        margin: Margins.symmetric(vertical: 8, horizontal: 12),
        padding: HtmlPaddings.only(left: 12),
        border: const Border(left: BorderSide(color: Colors.grey, width: 3)),
      ),
      "ul": Style(margin: Margins.only(bottom: 12, left: 16)),
      "ol": Style(margin: Margins.only(bottom: 12, left: 16)),
      "li": Style(margin: Margins.only(bottom: 4), lineHeight: LineHeight(1.5)),
      "pre": Style(
        backgroundColor: Colors.grey[200],
        padding: HtmlPaddings.all(8),
        margin: Margins.only(bottom: 12),
      ),
      "code": Style(
        backgroundColor: Colors.grey[200],
        padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        fontFamily: 'monospace',
      ),
    };
  }

  /// Style used inside the summary card, explicitly using theme text colours.
  Map<String, Style> _summaryHtmlStyle(BuildContext context, double zoom, {double baseSize = 14}) {
    final s = baseSize * zoom;
    final cs = Theme.of(context).colorScheme;
    return {
      "body": Style(fontSize: FontSize(s), lineHeight: LineHeight(1.6), margin: Margins.zero, color: cs.onSecondaryContainer),
      "p": Style(margin: Margins.only(bottom: 12), lineHeight: LineHeight(1.6), color: cs.onSecondaryContainer),
      "div": Style(margin: Margins.only(bottom: 8), color: cs.onSecondaryContainer),
      "h1": Style(fontSize: FontSize(s * 1.6), fontWeight: FontWeight.bold, margin: Margins.only(top: 16, bottom: 8), color: cs.onSecondaryContainer),
      "h2": Style(fontSize: FontSize(s * 1.4), fontWeight: FontWeight.bold, margin: Margins.only(top: 14, bottom: 6), color: cs.onSecondaryContainer),
      "h3": Style(fontSize: FontSize(s * 1.2), fontWeight: FontWeight.bold, margin: Margins.only(top: 12, bottom: 4), color: cs.onSecondaryContainer),
      "h4": Style(fontSize: FontSize(s * 1.1), fontWeight: FontWeight.bold, margin: Margins.only(top: 10, bottom: 4), color: cs.onSecondaryContainer),
      "h5": Style(fontSize: FontSize(s), fontWeight: FontWeight.bold, margin: Margins.only(top: 8, bottom: 2), color: cs.onSecondaryContainer),
      "h6": Style(fontSize: FontSize(s), fontWeight: FontWeight.bold, margin: Margins.only(top: 8, bottom: 2), color: cs.onSecondaryContainer),
      "ul": Style(margin: Margins.only(bottom: 12, left: 16), color: cs.onSecondaryContainer),
      "ol": Style(margin: Margins.only(bottom: 12, left: 16), color: cs.onSecondaryContainer),
      "li": Style(margin: Margins.only(bottom: 4), lineHeight: LineHeight(1.5), color: cs.onSecondaryContainer),
      "a": Style(color: cs.primary, textDecoration: TextDecoration.none),
      "strong": Style(fontWeight: FontWeight.bold, color: cs.onSecondaryContainer),
      "em": Style(fontStyle: FontStyle.italic, color: cs.onSecondaryContainer),
    };
  }

  Widget _buildTitle(String title, double zoom) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) * zoom,
      ),
    );
  }

  Widget _buildMetaRow(Article article, double zoom) {
    return Row(children: [
      Icon(Icons.person, size: 16 * zoom, color: Colors.grey),
      const SizedBox(width: 4),
      Text(article.author ?? 'Unknown', style: TextStyle(color: Colors.grey[600], fontSize: 14 * zoom)),
      const SizedBox(width: 16),
      Icon(Icons.calendar_today, size: 16 * zoom, color: Colors.grey),
      const SizedBox(width: 4),
      Text(
        article.publishedAt != null ? DateFormat('MMM d, yyyy').format(article.publishedAt!) : 'Unknown date',
        style: TextStyle(color: Colors.grey[600], fontSize: 14 * zoom),
      ),
    ]);
  }

  Widget _buildSummaryCard(Article article, double zoom) {
    final text = _summary ?? article.summary;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final htmlContent = _markdownToHtml(text);
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: cs.onSecondaryContainer),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
            const SizedBox(width: 8),
            Text('AI Summary', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary copied')));
              },
              tooltip: 'Copy summary',
            ),
          ]),
          const SizedBox(height: 8),
          Html(
            data: htmlContent,
            style: _summaryHtmlStyle(context, zoom, baseSize: 14),
          ),
        ]),
      ),
    );
  }

  /// Convert basic Markdown to HTML for flutter_html rendering
  String _markdownToHtml(String markdown) {
    var html = markdown
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>')
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => '<em>${m[1]}</em>')
      .replaceAllMapped(RegExp(r'^#{1,6}\s+(.+)', multiLine: true), (m) => '<h3>${m[1]}</h3>')
      .replaceAllMapped(RegExp(r'^\s*-\s+(.+)', multiLine: true), (m) => '<li>${m[1]}</li>')
      .replaceAllMapped(RegExp(r'^\s*\d+\.\s+(.+)', multiLine: true), (m) => '<li>${m[1]}</li>');
    
    // Wrap bare li elements in ul
    if (html.contains('<li>')) {
      html = html.replaceAllMapped(
        RegExp(r'(<li>.+?</li>\s*)+', dotAll: true),
        (m) => '<ul>${m[0]}</ul>',
      );
    }
    
    // Wrap in body
    html = html.replaceAll('\n', '<br>');
    return '<div>$html</div>';
  }

  Widget _buildSummaryText(Article article, double zoom) {
    final text = article.contentText ?? _stripHtml(article.contentHtml ?? '') ?? '';
    return SelectableText(
      text,
      style: TextStyle(fontSize: 16 * zoom, height: 1.6),
    );
  }

  Future<void> _fetchArticleContent(Article article) async {
    try {
      // Check file cache first
      final cached = await _fileCache.loadArticleHtml(article.id);
      if (cached != null && cached.isNotEmpty) {
        if (mounted) setState(() { _loadingArticle = false; _articleHtml = cached; });
        return;
      }

      // Use Feedbin content_html if present
      if (article.contentHtml != null && article.contentHtml!.length > 100) {
        final cleaned = _cleanArticleHtml(article.contentHtml!, article.url);
        await _fileCache.saveArticleHtml(article.id, cleaned);
        if (mounted) setState(() { _loadingArticle = false; _articleHtml = cleaned; });
        return;
      }

      // Fallback: fetch from source URL
      if (article.url != null) {
        final response = await http.get(
          Uri.parse(article.url!),
          headers: {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'},
        );
        if (response.statusCode == 200 && mounted) {
          final cleaned = _cleanArticleHtml(response.body, article.url);
          await _fileCache.saveArticleHtml(article.id, cleaned);
          setState(() { _loadingArticle = false; _articleHtml = cleaned; });
          return;
        }
      }

      final fallback = '<p>${article.contentText ?? "No content available"}</p>';
      if (mounted) setState(() { _loadingArticle = false; _articleHtml = fallback; });
    } catch (e) {
      final fallback = '<p>${article.contentText ?? "No content available"}</p>';
      if (mounted) setState(() { _loadingArticle = false; _articleHtml = fallback; });
    }
  }

  Future<void> _fetchOriginalHtml(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'},
      );
      if (mounted) {
        final fixed = response.statusCode == 200 ? _fixOriginalHtml(response.body, url) : null;
        if (widget.article != null && fixed != null) {
          await _fileCache.saveOriginalHtml(widget.article!.id, fixed);
        }
        setState(() {
          _loadingOriginal = false;
          _originalHtml = fixed;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingOriginal = false; _originalHtml = null; });
    }
  }

  /// Clean article HTML for reader mode using a proper DOM parser.
  /// - Remove scripts, styles, noscript, iframes, forms, nav, header, footer, aside, svg, object, embed
  /// - Fix lazy-loaded images (data-src → src)
  /// - Make all URLs absolute
  /// - Strip event handlers, class, id, style, data-*, aria-* attributes
  /// - Preserve semantic tags (p, h1-h6, ul, ol, li, blockquote, img, figure, pre, code, strong, em, a, table, thead, tbody, tr, th, td)
  String _cleanArticleHtml(String html, String? baseUrl) {
    final base = baseUrl ?? 'about:blank';
    final doc = html_parser.parse(html);

    // 1. Strip dangerous tags (with their children)
    for (final tag in [
      'script', 'style', 'noscript', 'iframe', 'frame', 'frameset',
      'form', 'input', 'textarea', 'button', 'select',
      'nav', 'header', 'footer', 'aside', 'menu', 'menubar',
      'svg', 'math', 'object', 'embed', 'applet', 'canvas',
      'audio', 'video', 'track', 'source',
      'ad', 'ads', 'amp-ad', 'advertisement',
    ]) {
      doc.getElementsByTagName(tag).forEach((e) => e.remove());
    }

    // 2. Walk all elements and sanitize attributes
    for (final el in doc.querySelectorAll('*')) {
      el.attributes.removeWhere((k, _) => (k as String).toLowerCase().startsWith('on'));
      el.attributes.removeWhere((k, _) =>
        {'class', 'id', 'style', 'width', 'height', 'align', 'valign',
         'bgcolor', 'border', 'cellpadding', 'cellspacing', 'frameborder',
         'marginwidth', 'marginheight', 'scrolling'}.contains((k as String).toLowerCase()));
      el.attributes.removeWhere((k, _) =>
        (k as String).toLowerCase().startsWith('data-') || (k as String).toLowerCase().startsWith('aria-'));
      el.attributes.remove('role');

      // Fix lazy-loaded images
      if (el.localName == 'img') {
        for (final attr in ['data-src', 'data-original', 'data-lazy-src', 'data-lazyload', 'srcset']) {
          if (el.attributes.containsKey(attr)) {
            el.attributes.remove(attr);
          }
        }
        if (el.attributes['src'] != null) {
          el.attributes['src'] = _makeAbsolute(el.attributes['src']!, base);
        }
      }

      // Fix links
      if (el.localName == 'a') {
        final href = el.attributes['href'];
        if (href != null) {
          if (href.startsWith('#') || href.startsWith('mailto:') || href.startsWith('tel:') || href.startsWith('javascript:')) {
            el.attributes.remove('href');
          } else {
            el.attributes['href'] = _makeAbsolute(href, base);
            el.attributes['target'] = '_blank';
          }
        }
      }
    }

    // 3. Remove empty divs/spans (no text, no children with meaning)
    bool removedAny;
    do {
      removedAny = false;
      for (final el in doc.querySelectorAll('div, span')) {
        if (el.text.trim().isEmpty && el.children.isEmpty) {
          el.remove();
          removedAny = true;
        }
      }
    } while (removedAny);

    // 4. Wrap bare text nodes in body inside a div if needed
    final body = doc.body;
    if (body != null) {
      return body.innerHtml;
    }
    return doc.outerHtml;
  }

  String _fixOriginalHtml(String html, String baseUrl) {
    final doc = html_parser.parse(html);

    // Strip scripts/styles
    for (final tag in ['script', 'style', 'noscript', 'iframe', 'svg']) {
      doc.getElementsByTagName(tag).forEach((e) => e.remove());
    }

    // Fix images and links
    for (final el in doc.querySelectorAll('*')) {
      el.attributes.removeWhere((k, _) => (k as String).toLowerCase().startsWith('on'));
      el.attributes.removeWhere((k, _) =>
        {'class', 'id', 'style', 'width', 'height'}.contains((k as String).toLowerCase()));

      if (el.localName == 'img') {
        for (final attr in ['data-src', 'data-original', 'data-lazy-src', 'srcset']) {
          el.attributes.remove(attr);
        }
        if (el.attributes['src'] != null) {
          el.attributes['src'] = _makeAbsolute(el.attributes['src']!, baseUrl);
        }
      }
      if (el.localName == 'a') {
        final href = el.attributes['href'];
        if (href != null && !href.startsWith('#') && !href.startsWith('mailto:') && !href.startsWith('tel:') && !href.startsWith('javascript:')) {
          el.attributes['href'] = _makeAbsolute(href, baseUrl);
          el.attributes['target'] = '_blank';
        }
      }
    }

    final body = doc.body;
    return body?.innerHtml ?? doc.outerHtml;
  }

  String _makeAbsolute(String url, String base) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) {
      final uri = Uri.parse(base);
      return '${uri.scheme}://${uri.host}$url';
    }
    return Uri.parse(base).resolve(url).toString();
  }

  String? _stripHtml(String html) {
    return html.replaceAll(RegExp(r"<[^>]*>"), ' ').replaceAll(RegExp(r"\s+"), ' ').trim();
  }

  Future<void> _summarizeArticle(BuildContext context, Article article) async {
    setState(() => _summary = null);
    final result = await Provider.of<AppState>(context, listen: false).summarizeArticle(article);
    if (mounted) {
      setState(() => _summary = result ?? 'Failed to generate summary');
      if (result != null) {
        article.summary = result;
        await _fileCache.saveSummary(article.id, result);
      }
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
            children: ['English', 'Spanish', 'French', 'German', 'Chinese', 'Japanese', 'Korean'].map((lang) => ListTile(
              title: Text(lang),
              onTap: () async {
                Navigator.pop(context);
                final result = await Provider.of<AppState>(context, listen: false).translateArticle(article, lang);
                if (mounted) setState(() => _translation = result ?? 'Translation failed');
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _shareArticle(Article article) {
    if (article.url != null) Share.share(article.url!, subject: article.title);
  }

  Future<void> _openInBrowser(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
