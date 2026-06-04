import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../services/document_file_service.dart';
import '../utils/url_utils.dart';

class SettingsView extends StatelessWidget {
  static final DocumentFileService _documents = DocumentFileService();

  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, provider, _) {
        final enabledFeeds = provider.enabledFeeds;
        final availableFeeds = provider.availableFeeds;

        return CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              title: Text('Settings'),
            ),

            // Appearance section
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Appearance'),
            ),
            SliverToBoxAdapter(
              child: SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Follow system or toggle manually'),
                value: provider.darkMode,
                onChanged: (_) async {
                  await provider.toggleDarkMode();
                },
                secondary: Icon(
                  provider.darkMode ? Icons.dark_mode : Icons.light_mode,
                ),
              ),
            ),

            // Active feeds section
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Active Feeds'),
            ),
            if (enabledFeeds.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No feeds enabled. Add some from the list below.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              SliverReorderableList(
                itemCount: enabledFeeds.length,
                itemBuilder: (context, index) {
                  final feed = enabledFeeds[index];
                  return Material(
                    key: ValueKey(feed.url),
                    color: Colors.transparent,
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const SizedBox.square(
                          dimension: 48,
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                      title: Text(feed.name),
                      subtitle: Text(
                        UrlUtils.displayUrl(feed.url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.red,
                        onPressed: () async {
                          await provider.removeFeed(feed);
                        },
                      ),
                    ),
                  );
                },
                onReorderItem: (oldIndex, newIndex) async {
                  await provider.reorderFeeds(oldIndex, newIndex);
                },
              ),

            // Available feeds section
            if (availableFeeds.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(context, 'Available Feeds'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final feed = availableFeeds[index];
                    return ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(feed.name),
                      subtitle: Text(
                        UrlUtils.displayUrl(feed.url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await provider.toggleFeed(feed);
                      },
                    );
                  },
                  childCount: availableFeeds.length,
                ),
              ),
            ],

            // Add custom feed
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'Add Custom Feed'),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.add_link),
                title: const Text('Add RSS Feed'),
                subtitle: const Text('Enter a site, RSS, or Atom URL'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAddFeedDialog(context, provider),
              ),
            ),

            // OPML
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, 'OPML'),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Import OPML'),
                subtitle: const Text('Add feeds from another reader'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importOpml(context, provider),
              ),
            ),
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Export OPML'),
                subtitle: const Text('Save your feed list'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportOpml(context, provider),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
            ),
      ),
    );
  }

  void _showAddFeedDialog(BuildContext context, FeedProvider provider) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add RSS Feed'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/feed.xml',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;

              Navigator.pop(dialogContext);

              // Show loading
              var loadingVisible = false;
              if (context.mounted) {
                loadingVisible = true;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Finding feed...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              try {
                await provider.validateAndAddFeed(url);
                if (context.mounted) {
                  if (loadingVisible) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feed added successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  if (loadingVisible) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  final message = e.toString().replaceFirst('Exception: ', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $message')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _importOpml(BuildContext context, FeedProvider provider) async {
    try {
      final content = await _documents.importText(
        mimeTypes: const [
          'text/x-opml',
          'text/xml',
          'application/xml',
          'application/octet-stream',
        ],
      );
      if (content == null) return;

      final count = await provider.importFeedsFromOpml(content);
      if (!context.mounted) return;

      final message = count == 0
          ? 'No new feeds found.'
          : 'Imported $count feed${count == 1 ? '' : 's'}. Pull to refresh.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $message')),
      );
    }
  }

  Future<void> _exportOpml(BuildContext context, FeedProvider provider) async {
    try {
      final exported = await _documents.exportText(
        fileName: 'reading-feeds.opml',
        mimeType: 'text/x-opml',
        content: provider.exportOpml(),
      );
      if (!context.mounted || !exported) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feeds exported.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $message')),
      );
    }
  }
}
