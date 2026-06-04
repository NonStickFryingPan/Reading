import 'package:xml/xml.dart';
import '../models/feed_source.dart';
import '../utils/url_utils.dart';

class OpmlService {
  String exportFeeds(List<FeedSource> feeds) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('opml', attributes: {'version': '2.0'}, nest: () {
      builder.element('head', nest: () {
        builder.element('title', nest: 'Reading feeds');
      });
      builder.element('body', nest: () {
        for (final feed in feeds) {
          builder.element('outline', attributes: {
            'text': feed.name,
            'title': feed.name,
            'type': 'rss',
            'xmlUrl': feed.url,
          });
        }
      });
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }

  List<FeedSource> importFeeds(String content) {
    final document = XmlDocument.parse(content);
    final imported = <FeedSource>[];

    for (final outline in document.findAllElements('outline')) {
      final url = outline.getAttribute('xmlUrl') ?? outline.getAttribute('url');
      if (url == null) continue;

      final uri = UrlUtils.parseHttpUrl(url);
      if (uri == null) continue;

      final title = outline.getAttribute('title') ??
          outline.getAttribute('text') ??
          _titleFromUri(uri);
      final name = title.trim().isEmpty ? _titleFromUri(uri) : title.trim();
      imported.add(
        FeedSource(
          name: name,
          url: UrlUtils.normalize(uri.toString()),
          favicon: '${uri.scheme}://${uri.host}/favicon.ico',
          enabled: true,
          order: imported.length,
        ),
      );
    }

    return imported;
  }

  String _titleFromUri(Uri uri) {
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    final first = host.split('.').first;
    if (first.isEmpty) return 'Feed';
    return first[0].toUpperCase() + first.substring(1);
  }
}
