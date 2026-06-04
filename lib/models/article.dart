class Article {
  final String title;
  final String url;
  final String? description;
  final DateTime? publishDate;
  final String sourceName;

  Article({
    required this.title,
    required this.url,
    this.description,
    this.publishDate,
    required this.sourceName,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'description': description,
      'publishDate': publishDate?.toIso8601String(),
      'sourceName': sourceName,
    };
  }

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      description: map['description'],
      publishDate: map['publishDate'] != null
          ? DateTime.tryParse(map['publishDate'])
          : null,
      sourceName: map['sourceName'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}
