import 'package:flutter_test/flutter_test.dart';
import 'package:reading/models/article.dart';
import 'package:reading/models/feed_source.dart';
import 'package:reading/providers/feed_provider.dart';
import 'package:reading/services/rss_service.dart';
import 'package:reading/services/storage_service.dart';

void main() {
  test('moves the top enabled feed to the bottom', () async {
    final storage = _MemoryStorageService();
    final provider = FeedProvider(storage);

    await provider.importFeedsFromOpml('''
<opml version="2.0">
  <body>
    <outline text="First" xmlUrl="https://example.com/first.xml" />
    <outline text="Second" xmlUrl="https://example.com/second.xml" />
    <outline text="Third" xmlUrl="https://example.com/third.xml" />
  </body>
</opml>
''');

    await provider.reorderFeeds(0, 2);

    expect(provider.enabledFeeds.map((feed) => feed.name), [
      'Second',
      'Third',
      'First',
    ]);
    expect(provider.enabledFeeds.map((feed) => feed.order), [0, 1, 2]);

    final savedByOrder = [...storage.savedFeeds]
      ..sort((a, b) => a.order.compareTo(b.order));
    expect(savedByOrder.map((feed) => feed.name), [
      'Second',
      'Third',
      'First',
    ]);
    expect(storage.savedFeeds.map((feed) => feed.name), [
      'First',
      'Second',
      'Third',
    ]);
  });

  test('does not show the global refresh banner for partial feed failures',
      () async {
    final storage = _MemoryStorageService(
      feeds: [
        _feed('Good', 'https://example.com/good.xml'),
        _feed('Bad', 'https://example.com/bad.xml'),
      ],
    );
    final provider = FeedProvider(
      storage,
      rss: _FakeRssService(failingUrls: {'https://example.com/bad.xml'}),
    );

    await provider.init();

    expect(provider.errorMessage, isNull);
    expect(provider.articlesForSource('Good'), hasLength(1));
    expect(provider.articlesForSource('Bad'), isEmpty);
  });

  test('shows the global refresh banner when every feed fails', () async {
    final storage = _MemoryStorageService(
      feeds: [
        _feed('Bad One', 'https://example.com/bad-one.xml'),
        _feed('Bad Two', 'https://example.com/bad-two.xml'),
      ],
    );
    final provider = FeedProvider(
      storage,
      rss: _FakeRssService(
        failingUrls: {
          'https://example.com/bad-one.xml',
          'https://example.com/bad-two.xml',
        },
      ),
    );

    await provider.init();

    expect(
        provider.errorMessage, 'Feeds could not refresh. Try again in a bit.');
  });
}

class _MemoryStorageService extends StorageService {
  List<FeedSource> savedFeeds;

  _MemoryStorageService({List<FeedSource>? feeds}) : savedFeeds = feeds ?? [];

  @override
  Future<List<FeedSource>> loadFeeds() async => savedFeeds;

  @override
  Future<void> saveFeeds(List<FeedSource> feeds) async {
    savedFeeds = [...feeds];
  }

  @override
  List<Article> loadBookmarks() => [];

  @override
  bool isDarkMode() => false;

  @override
  Future<void> setDarkMode(bool value) async {}
}

class _FakeRssService extends RssService {
  final Set<String> failingUrls;

  _FakeRssService({required this.failingUrls});

  @override
  Future<FeedFetchResult> fetchAnyResult(String url, String sourceName) async {
    if (failingUrls.contains(url)) {
      return const FeedFetchResult.failure('Nope.');
    }
    return FeedFetchResult.success([
      Article(
        title: '$sourceName article',
        url: 'https://example.com/$sourceName',
        sourceName: sourceName,
      ),
    ]);
  }
}

FeedSource _feed(String name, String url) {
  return FeedSource(
    name: name,
    url: url,
    favicon: '',
    enabled: true,
  );
}
