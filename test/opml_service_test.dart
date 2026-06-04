import 'package:flutter_test/flutter_test.dart';
import 'package:reading/models/feed_source.dart';
import 'package:reading/services/opml_service.dart';

void main() {
  test('exports feed sources as OPML outlines', () {
    final opml = OpmlService().exportFeeds([
      FeedSource(
        name: 'Lobsters',
        url: 'https://lobste.rs/rss',
        favicon: 'https://lobste.rs/favicon.ico',
        enabled: true,
      ),
    ]);

    expect(opml, contains('<opml version="2.0">'));
    expect(opml, contains('text="Lobsters"'));
    expect(opml, contains('xmlUrl="https://lobste.rs/rss"'));
  });

  test('imports valid OPML feed outlines', () {
    const opml = '''
<?xml version="1.0"?>
<opml version="2.0">
  <body>
    <outline text="Example" xmlUrl="https://example.com/feed.xml" />
    <outline text="Unsafe" xmlUrl="javascript:alert(1)" />
  </body>
</opml>
''';

    final feeds = OpmlService().importFeeds(opml);

    expect(feeds, hasLength(1));
    expect(feeds.single.name, 'Example');
    expect(feeds.single.url, 'https://example.com/feed.xml');
    expect(feeds.single.enabled, isTrue);
  });
}
