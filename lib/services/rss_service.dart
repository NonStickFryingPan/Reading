import 'package:flutter/foundation.dart';
import 'package:webfeed/webfeed.dart';
import '../models/article.dart';
import '../utils/url_utils.dart';
import 'feed_http_client.dart';

class FeedFetchResult {
  final List<Article> articles;
  final String? errorMessage;

  const FeedFetchResult.success(this.articles) : errorMessage = null;

  const FeedFetchResult.failure(this.errorMessage) : articles = const [];

  bool get isSuccess => errorMessage == null;
}

class RssService {
  static const int _maxArticlesPerFeed = 30;
  final FeedHttpClient _http;

  RssService({FeedHttpClient? http}) : _http = http ?? FeedHttpClient();

  Future<List<Article>> fetchFeed(String url, String sourceName) async {
    try {
      final body = await _fetchBody(url);
      if (body == null) return [];
      final feed = RssFeed.parse(body);
      return _parseArticles(feed, sourceName);
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch RSS feed "$sourceName": $error\n$stackTrace');
      return [];
    }
  }

  Future<List<Article>> fetchAtomFeed(String url, String sourceName) async {
    try {
      final body = await _fetchBody(url);
      if (body == null) return [];
      final feed = AtomFeed.parse(body);
      return _parseAtomArticles(feed, sourceName);
    } catch (error, stackTrace) {
      debugPrint(
          'Failed to fetch Atom feed "$sourceName": $error\n$stackTrace');
      return [];
    }
  }

  Future<List<Article>> fetchAny(String url, String sourceName) async {
    final result = await fetchAnyResult(url, sourceName);
    return result.articles;
  }

  Future<FeedFetchResult> fetchAnyResult(String url, String sourceName) async {
    final body = await _fetchBody(url);
    if (body == null) {
      return const FeedFetchResult.failure('Could not load feed.');
    }

    try {
      final rssFeed = RssFeed.parse(body);
      return FeedFetchResult.success(_parseArticles(rssFeed, sourceName));
    } catch (error) {
      debugPrint('RSS parse failed for "$sourceName", trying Atom: $error');
    }

    try {
      final atomFeed = AtomFeed.parse(body);
      return FeedFetchResult.success(_parseAtomArticles(atomFeed, sourceName));
    } catch (error, stackTrace) {
      debugPrint('Atom parse failed for "$sourceName": $error\n$stackTrace');
    }

    return const FeedFetchResult.failure('Could not parse feed.');
  }

  Future<bool> validateFeed(String url) async {
    final body = await _fetchBody(url);
    if (body == null) return false;

    try {
      RssFeed.parse(body);
      return true;
    } catch (error) {
      debugPrint('RSS validation parse failed, trying Atom: $error');
    }

    try {
      AtomFeed.parse(body);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Atom validation parse failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<String?> _fetchBody(String url) async {
    return (await _http.getText(url))?.body;
  }

  List<Article> _parseArticles(RssFeed feed, String sourceName) {
    return (feed.items ?? [])
        .take(_maxArticlesPerFeed)
        .map((item) {
          return Article(
            title: item.title ?? 'Untitled',
            url: _safeUrl(item.link),
            description: item.description,
            publishDate: item.pubDate,
            sourceName: sourceName,
          );
        })
        .where((a) => a.url.isNotEmpty)
        .toList();
  }

  List<Article> _parseAtomArticles(AtomFeed feed, String sourceName) {
    return (feed.items ?? [])
        .take(_maxArticlesPerFeed)
        .map((item) {
          return Article(
            title: item.title ?? 'Untitled',
            url: _atomArticleUrl(item),
            description: item.summary,
            publishDate:
                DateTime.tryParse(item.published ?? '') ?? item.updated,
            sourceName: sourceName,
          );
        })
        .where((a) => a.url.isNotEmpty)
        .toList();
  }

  String _atomArticleUrl(AtomItem item) {
    final links = item.links ?? [];
    for (final link in links) {
      final rel = link.rel;
      final href = _safeUrl(link.href);
      if (href.isNotEmpty && (rel == null || rel == 'alternate')) return href;
    }

    for (final link in links) {
      final href = _safeUrl(link.href);
      if (href.isNotEmpty) return href;
    }

    return '';
  }

  String _safeUrl(String? value) {
    if (value == null) return '';
    final uri = UrlUtils.parseHttpUrl(value);
    return uri?.toString() ?? '';
  }
}
