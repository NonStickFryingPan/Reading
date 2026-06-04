import 'package:flutter_test/flutter_test.dart';
import 'package:reading/utils/url_utils.dart';

void main() {
  test('accepts only safe HTTP URLs', () {
    expect(UrlUtils.isSafeHttpUrl('https://example.com/feed.xml'), isTrue);
    expect(UrlUtils.isSafeHttpUrl('http://example.com/rss'), isTrue);
    expect(UrlUtils.isSafeHttpUrl('javascript:alert(1)'), isFalse);
    expect(UrlUtils.isSafeHttpUrl('file:///etc/passwd'), isFalse);
    expect(
        UrlUtils.isSafeHttpUrl('https://user:pass@example.com/rss'), isFalse);
  });

  test('redacts sensitive query parameters for display', () {
    expect(
      UrlUtils.displayUrl('https://example.com/rss?token=abc&category=tech'),
      'https://example.com/rss?token=redacted&category=tech',
    );
  });

  test('upgrades http article URLs to https for in-app loading', () {
    final uri = Uri.parse('http://example.com/story');

    expect(
        UrlUtils.upgradeToHttps(uri).toString(), 'https://example.com/story');
  });
}
