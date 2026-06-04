import 'package:flutter/material.dart';
import '../models/feed_source.dart';
import '../models/article.dart';
import 'source_header.dart';
import 'article_tile.dart';

class FeedSection extends StatelessWidget {
  final FeedSource source;
  final List<Article> articles;
  final int totalArticles;
  final int visibleCount;
  final bool isLoading;
  final bool Function(Article) isBookmarked;
  final Function(Article) onArticleTap;
  final Function(Article) onBookmarkToggle;
  final VoidCallback onShowMore;

  const FeedSection({
    super.key,
    required this.source,
    required this.articles,
    required this.totalArticles,
    required this.visibleCount,
    required this.isLoading,
    required this.isBookmarked,
    required this.onArticleTap,
    required this.onBookmarkToggle,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final displayCount =
        visibleCount > articles.length ? articles.length : visibleCount;
    final hasMore = displayCount < totalArticles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SourceHeader(
          name: source.name,
          favicon: source.favicon,
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (displayCount == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Text(
              'No articles available',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          for (int i = 0; i < displayCount; i++)
            ArticleTile(
              article: articles[i],
              index: i,
              isBookmarked: isBookmarked(articles[i]),
              onTap: () => onArticleTap(articles[i]),
              onBookmark: () => onBookmarkToggle(articles[i]),
            ),
          if (hasMore)
            GestureDetector(
              onTap: onShowMore,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Show more',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ),
        ],
        const Divider(height: 1),
      ],
    );
  }
}
