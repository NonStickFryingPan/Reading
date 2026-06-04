import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/feed_section.dart';
import 'article_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          FeedView(),
          BookmarksView(),
          SettingsView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.rss_feed_outlined),
            selectedIcon: Icon(Icons.rss_feed),
            label: 'Feeds',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, provider, _) {
        if (!provider.initialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final enabledFeeds = provider.enabledFeeds;

        if (enabledFeeds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rss_feed_outlined,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No feeds enabled',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Go to Settings to enable some feeds',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshAll(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                title: const Text('Reading'),
                actions: [
                  IconButton(
                    icon: Icon(
                      provider.darkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    onPressed: () async {
                      await provider.toggleDarkMode();
                    },
                  ),
                ],
              ),
              if (provider.errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          provider.errorMessage!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              for (final feed in enabledFeeds)
                SliverToBoxAdapter(
                  child: FeedSection(
                    source: feed,
                    articles: provider.articlesForSource(feed.name),
                    totalArticles: provider.totalArticlesForSource(feed.name),
                    visibleCount:
                        provider.visibleArticleCountForSource(feed.name),
                    isLoading: provider.loading[feed.name] ?? false,
                    isBookmarked: provider.isBookmarked,
                    onArticleTap: (article) {
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
                    onBookmarkToggle: (article) async {
                      await provider.toggleBookmark(article);
                    },
                    onShowMore: () {
                      provider.showMoreArticles(feed.name);
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }
}
