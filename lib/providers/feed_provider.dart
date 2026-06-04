import 'package:flutter/foundation.dart';
import '../models/feed_source.dart';
import '../models/article.dart';
import '../services/feed_discovery_service.dart';
import '../services/opml_service.dart';
import '../services/rss_service.dart';
import '../services/storage_service.dart';
import '../utils/url_utils.dart';

class FeedProvider extends ChangeNotifier {
  static const int initialVisibleArticleCount = 10;
  static const int articleRevealIncrement = 5;

  final StorageService _storage;
  final RssService _rss;
  late final FeedDiscoveryService _discovery = FeedDiscoveryService(rss: _rss);
  final OpmlService _opml = OpmlService();

  List<FeedSource> _feeds = [];
  List<FeedSource>? _enabledFeedsCache;
  List<FeedSource>? _availableFeedsCache;
  final Map<String, List<Article>> _articles = {};
  final Map<String, bool> _loading = {};
  final Map<String, int> _visibleArticleCounts = {};
  List<Article> _bookmarks = [];
  final Set<String> _bookmarkUrls = {};
  bool _darkMode = false;
  bool _initialized = false;
  bool _isRefreshing = false;
  Future<void>? _refreshFuture;
  String? _errorMessage;

  FeedProvider(this._storage, {RssService? rss}) : _rss = rss ?? RssService();

  List<FeedSource> get feeds => _feeds;
  Map<String, List<Article>> get articles => _articles;
  Map<String, bool> get loading => _loading;
  Map<String, int> get visibleArticleCounts => _visibleArticleCounts;
  List<Article> get bookmarks => _bookmarks;
  bool get darkMode => _darkMode;
  bool get initialized => _initialized;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;

  List<FeedSource> get enabledFeeds {
    final cached = _enabledFeedsCache;
    if (cached != null) return cached;

    final enabled = _feeds.where((f) => f.enabled).toList();
    enabled.sort((a, b) => a.order.compareTo(b.order));
    _enabledFeedsCache = enabled;
    return enabled;
  }

  List<FeedSource> get availableFeeds {
    final cached = _availableFeedsCache;
    if (cached != null) return cached;

    final available = _feeds.where((f) => !f.enabled).toList();
    _availableFeedsCache = available;
    return available;
  }

  List<Article> articlesForSource(String sourceName, {int? limit}) {
    final sourceArticles = _articles[sourceName] ?? [];
    if (limit == null) return sourceArticles;
    return sourceArticles.take(limit).toList();
  }

  int totalArticlesForSource(String sourceName) {
    return _articles[sourceName]?.length ?? 0;
  }

  int visibleArticleCountForSource(String sourceName) {
    final total = totalArticlesForSource(sourceName);
    if (total <= initialVisibleArticleCount) return total;

    final requested =
        _visibleArticleCounts[sourceName] ?? initialVisibleArticleCount;
    if (requested < initialVisibleArticleCount) {
      return initialVisibleArticleCount;
    }
    return requested > total ? total : requested;
  }

  bool isBookmarked(Article article) {
    return _bookmarkUrls.contains(article.url);
  }

  Future<void> init() async {
    try {
      _darkMode = _storage.isDarkMode();
      _setFeeds(_normalizeFeedOrder(await _storage.loadFeeds()));
      _setBookmarks(_storage.loadBookmarks());
      _errorMessage = null;
    } catch (error, stackTrace) {
      debugPrint('Provider init failed: $error\n$stackTrace');
      _errorMessage =
          'Could not load saved data. Defaults were used where possible.';
      _setFeeds([]);
      _setBookmarks([]);
    } finally {
      _initialized = true;
      notifyListeners();
    }

    await refreshAll();
  }

  Future<void> refreshAll() {
    final existingRefresh = _refreshFuture;
    if (existingRefresh != null) return existingRefresh;

    final refresh = _refreshAll();
    _refreshFuture = refresh;
    return refresh;
  }

  Future<void> _refreshAll() async {
    final feeds = enabledFeeds;
    _isRefreshing = true;
    _errorMessage = null;
    for (final feed in feeds) {
      _loading[feed.name] = true;
    }
    notifyListeners();

    var successCount = 0;
    var failedCount = 0;
    try {
      final futures = feeds.map((feed) async {
        try {
          final result = await _rss.fetchAnyResult(feed.url, feed.name);
          if (result.isSuccess) {
            _articles[feed.name] = result.articles;
            successCount++;
          } else {
            failedCount++;
          }
        } catch (error, stackTrace) {
          debugPrint('Failed to refresh ${feed.name}: $error\n$stackTrace');
          failedCount++;
        } finally {
          _loading[feed.name] = false;
          notifyListeners();
        }
      });

      await Future.wait(futures);
      if (successCount == 0 && failedCount > 0) {
        _errorMessage = 'Feeds could not refresh. Try again in a bit.';
      }
    } finally {
      _isRefreshing = false;
      _refreshFuture = null;
      notifyListeners();
    }
  }

  Future<List<Article>> validateAndAddFeed(String url) async {
    final discovered = await _discovery.discover(url);
    final normalizedUrl = UrlUtils.normalize(discovered.url);
    final duplicate = _feeds.any(
      (feed) => UrlUtils.normalize(feed.url) == normalizedUrl,
    );
    if (duplicate) {
      throw Exception('This feed is already in your sources.');
    }

    final uri = UrlUtils.parseHttpUrl(normalizedUrl);
    if (uri == null) throw Exception('Could not add this feed.');

    final uniqueName = _uniqueFeedName(_cleanFeedName(discovered.title, uri));
    final favicon = UrlUtils.isSafeHttpUrl(discovered.favicon ?? '')
        ? discovered.favicon!
        : '${uri.scheme}://${uri.host}/favicon.ico';
    final newFeed = FeedSource(
      name: uniqueName,
      url: normalizedUrl,
      favicon: favicon,
      enabled: true,
      order: _feeds.length,
    );

    _setFeeds(_normalizeFeedOrder([..._feeds, newFeed]));
    await _storage.saveFeeds(_feeds);

    final result = await _rss.fetchAnyResult(normalizedUrl, newFeed.name);
    if (result.isSuccess) {
      _articles[newFeed.name] = result.articles;
    } else {
      _errorMessage = 'Feed was added, but articles could not be loaded yet.';
    }

    notifyListeners();
    return result.articles;
  }

  String exportOpml() => _opml.exportFeeds(_feeds);

  Future<int> importFeedsFromOpml(String content) async {
    final importedFeeds = _opml.importFeeds(content);
    if (importedFeeds.isEmpty) {
      throw Exception('No valid feeds were found in this OPML file.');
    }

    var importedCount = 0;
    var nextFeeds = [..._feeds];

    for (final feed in importedFeeds) {
      final normalizedUrl = UrlUtils.normalize(feed.url);
      final duplicate = nextFeeds.any(
        (existing) => UrlUtils.normalize(existing.url) == normalizedUrl,
      );
      if (duplicate) continue;

      final uri = UrlUtils.parseHttpUrl(normalizedUrl);
      if (uri == null) continue;

      nextFeeds.add(
        feed.copyWith(
          name: _uniqueFeedNameIn(_cleanFeedName(feed.name, uri), nextFeeds),
          url: normalizedUrl,
          order: nextFeeds.length,
        ),
      );
      importedCount++;
    }

    if (importedCount == 0) return 0;

    _setFeeds(_normalizeFeedOrder(nextFeeds));
    await _storage.saveFeeds(_feeds);
    notifyListeners();
    return importedCount;
  }

  Future<void> toggleFeed(FeedSource feed) async {
    final index = _feeds.indexWhere((f) => f.url == feed.url);
    if (index == -1) return;

    final updated = _feeds[index].copyWith(enabled: !feed.enabled);
    final updatedFeeds = [..._feeds];
    updatedFeeds[index] = updated;
    _setFeeds(_normalizeFeedOrder(updatedFeeds));

    if (!updated.enabled) {
      _articles.remove(updated.name);
      _visibleArticleCounts.remove(updated.name);
    }

    await _storage.saveFeeds(_feeds);
    notifyListeners();

    if (updated.enabled) {
      await _fetchForFeed(updated);
    }
  }

  Future<void> _fetchForFeed(FeedSource feed) async {
    _loading[feed.name] = true;
    notifyListeners();

    try {
      final result = await _rss.fetchAnyResult(feed.url, feed.name);
      if (result.isSuccess) {
        _articles[feed.name] = result.articles;
      } else {
        _errorMessage = 'Could not load ${feed.name}. Try refreshing again.';
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch ${feed.name}: $error\n$stackTrace');
      _errorMessage = 'Could not load ${feed.name}. Try refreshing again.';
    } finally {
      _loading[feed.name] = false;
      notifyListeners();
    }
  }

  Future<void> reorderFeeds(int oldIndex, int newIndex) async {
    final enabled = enabledFeeds;
    if (oldIndex < 0 || oldIndex >= enabled.length) return;
    if (newIndex < 0 || newIndex > enabled.length) return;
    if (oldIndex == newIndex) return;

    final item = enabled.removeAt(oldIndex);
    enabled.insert(newIndex, item);

    var reordered = _feeds;
    for (int i = 0; i < enabled.length; i++) {
      final feed = enabled[i].copyWith(order: i);
      final idx = reordered.indexWhere((f) => f.url == feed.url);
      if (idx != -1) {
        final next = [...reordered];
        next[idx] = feed;
        reordered = next;
      }
    }

    _setFeeds(reordered);
    await _storage.saveFeeds(_feeds);
    notifyListeners();
  }

  Future<void> removeFeed(FeedSource feed) async {
    final index = _feeds.indexWhere((f) => f.url == feed.url);
    if (index == -1) return;

    final updatedFeeds = [..._feeds];
    updatedFeeds[index] = _feeds[index].copyWith(
      enabled: false,
      order: _feeds.length,
    );
    _setFeeds(_normalizeFeedOrder(updatedFeeds));
    _articles.remove(feed.name);
    _visibleArticleCounts.remove(feed.name);
    await _storage.saveFeeds(_feeds);
    notifyListeners();
  }

  void showMoreArticles(String sourceName) {
    final total = totalArticlesForSource(sourceName);
    if (total <= 0) return;

    final current = visibleArticleCountForSource(sourceName);
    final next = current + articleRevealIncrement;
    _visibleArticleCounts[sourceName] = next > total ? total : next;
    notifyListeners();
  }

  Future<void> toggleBookmark(Article article) async {
    if (isBookmarked(article)) {
      _bookmarks.removeWhere((b) => b.url == article.url);
      _bookmarkUrls.remove(article.url);
    } else {
      _bookmarks.insert(0, article);
      _bookmarkUrls.add(article.url);
    }
    await _storage.saveBookmarks(_bookmarks);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    await _storage.setDarkMode(_darkMode);
    notifyListeners();
  }

  void _setFeeds(List<FeedSource> feeds) {
    _feeds = feeds;
    _enabledFeedsCache = null;
    _availableFeedsCache = null;
  }

  void _setBookmarks(List<Article> bookmarks) {
    _bookmarks = bookmarks;
    _bookmarkUrls
      ..clear()
      ..addAll(bookmarks.map((bookmark) => bookmark.url));
  }

  List<FeedSource> _normalizeFeedOrder(List<FeedSource> feeds) {
    final enabled = feeds.where((feed) => feed.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final disabled = feeds.where((feed) => !feed.enabled).toList();

    final normalized = [...feeds];
    for (int i = 0; i < enabled.length; i++) {
      final index = normalized.indexWhere((feed) => feed.url == enabled[i].url);
      if (index != -1) normalized[index] = enabled[i].copyWith(order: i);
    }

    for (int i = 0; i < disabled.length; i++) {
      final index =
          normalized.indexWhere((feed) => feed.url == disabled[i].url);
      if (index != -1) {
        normalized[index] = disabled[i].copyWith(order: enabled.length + i);
      }
    }

    return normalized;
  }

  String _uniqueFeedName(String baseName) {
    return _uniqueFeedNameIn(baseName, _feeds);
  }

  String _uniqueFeedNameIn(String baseName, List<FeedSource> feeds) {
    final existing = feeds.map((feed) => feed.name).toSet();
    if (!existing.contains(baseName)) return baseName;

    var counter = 2;
    while (existing.contains('$baseName $counter')) {
      counter++;
    }
    return '$baseName $counter';
  }

  String _cleanFeedName(String? value, Uri uri) {
    final fallback =
        uri.host.replaceFirst(RegExp(r'^www\.'), '').split('.').first;
    var name =
        (value == null || value.trim().isEmpty) ? fallback : value.trim();
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return 'Feed';
    if (name.length > 60) name = name.substring(0, 60).trim();
    return name[0].toUpperCase() + name.substring(1);
  }
}
