import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import '../models/article.dart';
import '../utils/url_utils.dart';

class FeedFetchResult {
  final List<Article> articles;
  final String? errorMessage;

  const FeedFetchResult.success(this.articles) : errorMessage = null;

  const FeedFetchResult.failure(this.errorMessage) : articles = const [];

  bool get isSuccess => errorMessage == null;
}

class RssService {
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxArticlesPerFeed = 30;
  static const int _maxResponseBytes = 5 * 1024 * 1024;

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
    final uri = UrlUtils.parseHttpUrl(url);
    if (uri == null) {
      debugPrint('Rejected unsafe feed URL: $url');
      return null;
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response = await client.send(request).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('Feed request failed (${response.statusCode}): $uri');
        return null;
      }

      final contentLength = response.contentLength;
      if (contentLength != null && contentLength > _maxResponseBytes) {
        debugPrint('Rejected oversized feed ($contentLength bytes): $uri');
        return null;
      }

      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(_timeout)) {
        bytes.add(chunk);
        if (bytes.length > _maxResponseBytes) {
          debugPrint('Rejected feed after exceeding size cap: $uri');
          return null;
        }
      }

      return utf8.decode(bytes.takeBytes());
    } catch (error, stackTrace) {
      debugPrint('Feed request failed for $uri: $error\n$stackTrace');
      return null;
    } finally {
      client.close();
    }
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
