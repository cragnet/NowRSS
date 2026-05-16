import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

class HtmlProcessor {
  /// Fix image URLs and lazy loading in HTML content
  static String fixImages(String html, String baseUrl) {
    final document = parse(html);

    // Add base tag so relative URLs resolve
    final head = document.head;
    if (head != null) {
      final existingBase = head.querySelector('base');
      if (existingBase == null) {
        final baseTag = Element.tag('base')..attributes['href'] = baseUrl;
        head.insertBefore(baseTag, head.firstChild);
      }
    }

    // Fix all img tags
    for (final img in document.querySelectorAll('img')) {
      // Handle data-src (lazy loading) -> copy to src
      final dataSrc = img.attributes['data-src'];
      if (dataSrc != null && dataSrc.isNotEmpty) {
        img.attributes['src'] = _makeAbsolute(dataSrc, baseUrl);
        img.attributes.remove('data-src');
      }

      // Handle data-srcset, data-original, etc.
      for (final attr in ['data-original', 'data-lazy-src', 'data-srcset']) {
        final val = img.attributes[attr];
        if (val != null && val.isNotEmpty) {
          img.attributes['src'] = _makeAbsolute(val, baseUrl);
          img.attributes.remove(attr);
        }
      }

      // Make src absolute if relative
      final src = img.attributes['src'];
      if (src != null && src.isNotEmpty) {
        img.attributes['src'] = _makeAbsolute(src, baseUrl);
      }

      // Remove lazy loading classes/attributes that might hide images
      img.attributes.remove('loading');
      img.attributes.remove('class');

      // Ensure images have display style
      final style = img.attributes['style'] ?? '';
      if (!style.contains('display')) {
        img.attributes['style'] = '$style; display: block; max-width: 100%; height: auto;'.trim();
      }
    }

    // Fix all links to be absolute
    for (final a in document.querySelectorAll('a')) {
      final href = a.attributes['href'];
      if (href != null && href.isNotEmpty && !href.startsWith('#')) {
        a.attributes['href'] = _makeAbsolute(href, baseUrl);
      }
    }

    // Remove script tags (they won't execute anyway)
    for (final script in document.querySelectorAll('script')) {
      script.remove();
    }

    // Remove noscript tags (unwrap their contents)
    for (final noscript in document.querySelectorAll('noscript')) {
      // If noscript contains an img, move it out
      final img = noscript.querySelector('img');
      if (img != null) {
        noscript.replaceWith(img);
      } else {
        noscript.remove();
      }
    }

    // Remove iframe tags
    for (final iframe in document.querySelectorAll('iframe')) {
      iframe.remove();
    }

    return document.outerHtml;
  }

  /// Strip HTML to plain text for Summary view
  static String stripHtml(String html) {
    final document = parse(html);
    return document.body?.text ?? '';
  }

  /// Extract first image URL from HTML
  static String? extractFirstImage(String html) {
    final document = parse(html);
    final img = document.querySelector('img');
    return img?.attributes['src'];
  }

  static String _makeAbsolute(String url, String base) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      final protocol = base.startsWith('https') ? 'https:' : 'http:';
      return '$protocol$url';
    }
    if (url.startsWith('/')) {
      final uri = Uri.parse(base);
      return '${uri.scheme}://${uri.host}$url';
    }
    if (url.startsWith('./') || url.startsWith('../')) {
      return Uri.parse(base).resolve(url).toString();
    }
    // Data URIs
    if (url.startsWith('data:')) {
      return url;
    }
    return Uri.parse(base).resolve(url).toString();
  }
}
