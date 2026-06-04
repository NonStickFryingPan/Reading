import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/url_utils.dart';

class FeedHttpResponse {
  final Uri uri;
  final int statusCode;
  final String body;
  final String? contentType;

  const FeedHttpResponse({
    required this.uri,
    required this.statusCode,
    required this.body,
    required this.contentType,
  });
}

class FeedHttpClient {
  static const Duration timeout = Duration(seconds: 10);
  static const int maxResponseBytes = 5 * 1024 * 1024;
  static const String userAgent =
      'Reading/1.0 (+https://github.com/NonStickFryingPan/Reading)';

  Future<FeedHttpResponse?> getText(String url) async {
    final uri = UrlUtils.parseHttpUrl(url);
    if (uri == null) {
      debugPrint('Rejected unsafe URL: $url');
      return null;
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = userAgent
        ..headers['Accept'] =
            'application/rss+xml, application/atom+xml, application/xml, text/xml, */*';
      final response = await client.send(request).timeout(timeout);

      if (response.statusCode != 200) {
        debugPrint('Request failed (${response.statusCode}): $uri');
        return null;
      }

      final contentLength = response.contentLength;
      if (contentLength != null && contentLength > maxResponseBytes) {
        debugPrint('Rejected oversized response ($contentLength bytes): $uri');
        return null;
      }

      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(timeout)) {
        bytes.add(chunk);
        if (bytes.length > maxResponseBytes) {
          debugPrint('Rejected response after exceeding size cap: $uri');
          return null;
        }
      }

      return FeedHttpResponse(
        uri: uri,
        statusCode: response.statusCode,
        body: utf8.decode(bytes.takeBytes()),
        contentType: response.headers['content-type'],
      );
    } catch (error, stackTrace) {
      debugPrint('Request failed for $uri: $error\n$stackTrace');
      return null;
    } finally {
      client.close();
    }
  }
}
