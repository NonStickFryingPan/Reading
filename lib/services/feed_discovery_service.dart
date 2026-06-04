import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import '../utils/url_utils.dart';
import 'feed_http_client.dart';
import 'rss_service.dart';

class DiscoveredFeed {
  final String url;
  final String? title;
  final String? favicon;

  const DiscoveredFeed({
    required this.url,
    this.title,
    this.favicon,
  });
}

class FeedDiscoveryService {
  final RssService _rss;
  final FeedHttpClient _http;

  FeedDiscoveryService({
    RssService? rss,
    FeedHttpClient? http,
  })  : _rss = rss ?? RssService(),
        _http = http ?? FeedHttpClient();

  Future<DiscoveredFeed> discover(String input) async {
    final uri = UrlUtils.parseHttpUrl(input);
    if (uri == null) {
      throw Exception('Enter a valid http or https URL without credentials.');
    }

    final normalizedUrl = UrlUtils.normalize(uri.toString());
    if (await _rss.validateFeed(normalizedUrl)) {
      return DiscoveredFeed(
        url: normalizedUrl,
        title: _titleFromUri(uri),
        favicon: _defaultFavicon(uri),
      );
    }

    final response = await _http.getText(normalizedUrl);
    if (response == null) {
      throw Exception('Could not load this site or feed.');
    }

    final document = html_parser.parse(response.body);
    final candidates = _alternateFeedLinks(document, response.uri);
    for (final candidate in candidates) {
      final feedUrl = UrlUtils.normalize(candidate.url);
      if (await _rss.validateFeed(feedUrl)) {
        return DiscoveredFeed(
          url: feedUrl,
          title: candidate.title ??
              _siteTitle(document) ??
              _titleFromUri(response.uri),
          favicon: _faviconFromHtml(document, response.uri) ??
              _defaultFavicon(response.uri),
        );
      }
    }

    throw Exception('No RSS or Atom feed was found for this URL.');
  }

  List<DiscoveredFeed> _alternateFeedLinks(
      html_dom.Document document, Uri baseUri) {
    final links = <DiscoveredFeed>[];
    for (final element in document.querySelectorAll('link[rel]')) {
      final rel = element.attributes['rel']?.toLowerCase() ?? '';
      final type = element.attributes['type']?.toLowerCase() ?? '';
      final href = element.attributes['href'];
      if (!rel.split(RegExp(r'\s+')).contains('alternate')) continue;
      if (!_isFeedType(type)) continue;
      if (href == null || href.trim().isEmpty) continue;

      final resolved = baseUri.resolve(href.trim());
      if (!UrlUtils.isSafeHttpUrl(resolved.toString())) continue;
      links.add(
        DiscoveredFeed(
          url: resolved.toString(),
          title: element.attributes['title']?.trim(),
        ),
      );
    }
    return links;
  }

  bool _isFeedType(String type) {
    return type.contains('rss') ||
        type.contains('atom') ||
        type == 'text/xml' ||
        type == 'application/xml';
  }

  String? _faviconFromHtml(html_dom.Document document, Uri baseUri) {
    const relPriority = ['apple-touch-icon', 'icon', 'shortcut icon'];
    for (final relName in relPriority) {
      for (final element in document.querySelectorAll('link[rel]')) {
        final rel = element.attributes['rel']?.toLowerCase() ?? '';
        final href = element.attributes['href'];
        if (href == null || href.trim().isEmpty) continue;
        if (!rel.split(RegExp(r'\s+')).join(' ').contains(relName)) continue;

        final resolved = baseUri.resolve(href.trim());
        if (UrlUtils.isSafeHttpUrl(resolved.toString())) {
          return resolved.toString();
        }
      }
    }
    return null;
  }

  String? _siteTitle(html_dom.Document document) {
    final title = document.querySelector('title')?.text.trim();
    if (title == null || title.isEmpty) return null;
    return title;
  }

  String _titleFromUri(Uri uri) {
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    final first = host.split('.').first;
    if (first.isEmpty) return 'Feed';
    return first[0].toUpperCase() + first.substring(1);
  }

  String _defaultFavicon(Uri uri) => '${uri.scheme}://${uri.host}/favicon.ico';
}
