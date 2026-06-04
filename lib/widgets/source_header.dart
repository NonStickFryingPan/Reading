import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SourceHeader extends StatelessWidget {
  final String name;
  final String favicon;
  final VoidCallback? onTap;

  const SourceHeader({
    super.key,
    required this.name,
    required this.favicon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackIcon = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.rss_feed,
        size: 12,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            favicon.isEmpty
                ? fallbackIcon
                : CachedNetworkImage(
                    imageUrl: favicon,
                    width: 20,
                    height: 20,
                    errorWidget: (_, __, ___) => fallbackIcon,
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
