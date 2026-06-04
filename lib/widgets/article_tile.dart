import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/article.dart';

class ArticleTile extends StatelessWidget {
  final Article article;
  final int index;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  const ArticleTile({
    super.key,
    required this.article,
    required this.index,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () => _copyLink(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.description != null &&
                      article.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _stripHtml(article.description!),
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onBookmark,
              child: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
                color: isBookmarked
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.labelSmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stripHtml(String html) {
    final exp = RegExp(r'<[^>]*>');
    return html.replaceAll(exp, '').trim();
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: article.url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }
}
