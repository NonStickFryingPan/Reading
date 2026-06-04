import 'package:flutter_test/flutter_test.dart';
import 'package:reading/services/feed_http_client.dart';
import 'package:reading/services/rss_service.dart';

void main() {
  test('falls through from empty RSS parsing to Atom parsing', () async {
    final service = RssService(
      http: _FakeFeedHttpClient('''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>reddit: the front page of the internet</title>
  <entry>
    <title>Reddit story</title>
    <link href="https://www.reddit.com/r/test/comments/abc/story/" />
    <published>2026-06-04T12:00:00+00:00</published>
    <summary>Example summary</summary>
  </entry>
</feed>
'''),
    );

    final result = await service.fetchAnyResult(
      'https://www.reddit.com/.rss',
      'Reddit Frontpage',
    );

    expect(result.isSuccess, isTrue);
    expect(result.articles, hasLength(1));
    expect(result.articles.single.title, 'Reddit story');
    expect(result.articles.single.url,
        'https://www.reddit.com/r/test/comments/abc/story/');
  });
}

class _FakeFeedHttpClient extends FeedHttpClient {
  final String body;

  _FakeFeedHttpClient(this.body);

  @override
  Future<FeedHttpResponse?> getText(String url) async {
    return FeedHttpResponse(
      uri: Uri.parse(url),
      statusCode: 200,
      body: body,
      contentType: 'application/atom+xml',
    );
  }
}
