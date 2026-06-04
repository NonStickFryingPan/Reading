import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/article_tile.dart';
import 'article_screen.dart';

class BookmarksView extends StatelessWidget {
  const BookmarksView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, provider, _) {
        final bookmarks = provider.bookmarks;

        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              title: Text('Bookmarks'),
            ),
            if (bookmarks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No bookmarks yet',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Long-press or tap the bookmark icon\non any article to save it here',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final article = bookmarks[index];
                    return ArticleTile(
                      article: article,
                      index: index,
                      isBookmarked: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArticleScreen(
                              title: article.title,
                              url: article.url,
                            ),
                          ),
                        );
                      },
                      onBookmark: () async {
                        await provider.toggleBookmark(article);
                      },
                    );
                  },
                  childCount: bookmarks.length,
                ),
              ),
          ],
        );
      },
    );
  }
}
