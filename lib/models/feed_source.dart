class FeedSource {
  final String name;
  final String url;
  final String favicon;
  final bool enabled;
  final int order;

  FeedSource({
    required this.name,
    required this.url,
    required this.favicon,
    this.enabled = false,
    this.order = 0,
  });

  FeedSource copyWith({
    String? name,
    String? url,
    String? favicon,
    bool? enabled,
    int? order,
  }) {
    return FeedSource(
      name: name ?? this.name,
      url: url ?? this.url,
      favicon: favicon ?? this.favicon,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'favicon': favicon,
      'enabled': enabled,
      'order': order,
    };
  }

  factory FeedSource.fromMap(Map<String, dynamic> map) {
    final name = map['name'] as String?;
    final url = map['url'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw FormatException('Feed source is missing a name.');
    }
    if (url == null || url.trim().isEmpty) {
      throw FormatException('Feed source is missing a URL.');
    }

    return FeedSource(
      name: name,
      url: url,
      favicon: map['favicon'] as String? ?? '',
      enabled: map['enabled'] ?? false,
      order: map['order'] ?? 0,
    );
  }
}
