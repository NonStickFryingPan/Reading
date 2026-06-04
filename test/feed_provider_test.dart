import 'package:flutter_test/flutter_test.dart';
import 'package:reading/models/article.dart';
import 'package:reading/models/feed_source.dart';
import 'package:reading/providers/feed_provider.dart';
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
}

class _MemoryStorageService extends StorageService {
  List<FeedSource> savedFeeds = [];

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
