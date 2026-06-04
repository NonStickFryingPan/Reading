class UrlUtils {
  static Uri? parseHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return uri;
  }

  static bool isSafeHttpUrl(String value) => parseHttpUrl(value) != null;

  static Uri upgradeToHttps(Uri uri) {
    if (uri.scheme != 'http') return uri;
    return uri.replace(scheme: 'https');
  }

  static String normalize(String value) {
    final uri = parseHttpUrl(value);
    if (uri == null) return value.trim();
    return uri.replace(fragment: '').toString();
  }

  static String displayUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value;

    final redactedParams = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      final key = entry.key.toLowerCase();
      final isSensitive = key.contains('token') ||
          key.contains('key') ||
          key.contains('secret') ||
          key.contains('password') ||
          key.contains('auth');
      redactedParams[entry.key] = isSensitive ? 'redacted' : entry.value;
    }

    return uri
        .replace(
            queryParameters: redactedParams.isEmpty ? null : redactedParams)
        .toString();
  }
}
